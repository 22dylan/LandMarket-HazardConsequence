module my_model  # defining module
#= module for model. used to keep run.jl clean 
=#

# setting up packages for this module
using Agents
using Random
using Distributions
# using StatsBase
using Pkg
using DataFrames
using ProgressMeter


# importing local modules
include("MiscFunc.jl")
include("MyParcelSpace.jl")
include("MyAgents.jl")



#= attempting to setup pyCall with julia distribution of conda
	See Conda.jl for how to install conda pacakages to julia distribution of conda
	See pyCall.jl for additional instructions of using pyton modules
	If adding new packages to Julia's conda environment, may need to run Pkg.build again
=#
# ENV["PYTHON"] = ""
# Pkg.build("PyCall")
using PyCall

# preparing python script with misc. python operations that will be used (e.g., incore)
scriptdir = @__DIR__
pushfirst!(PyVector(pyimport("sys")."path"), scriptdir)
pycall_jl = pyimport("PythonOperations")
PYTHON_OPS = pycall_jl.misc_python_ops() # setting up python operations




"""
	initialize()
Sets up the initial model using the input directory
Sets up the parcel space
Assigns agents to the model
"""
function initialize(input_dict, input_folder; seed=1337, iter=1)
	seed = seed + iter 
	# Random.seed!(seed)
	rng = Random.MersenneTwister(seed)	 # setting seed

	# preparing parcel dataframe
	parcel_df = PYTHON_OPS.prepare_parcel_df(input_folder, seed=seed)
	println("initial dataframe prepared")

	# converting parcel datafarme from python to julia
	parcel_df = pd_to_df(parcel_df)

	# getting model property dictionary
	properties = set_up_model_properties(input_dict, parcel_df, iter)

	# pre-calculating number of agents at end of iteration; pre-allocating space in model
	n_agents_end_iteration = 1000
	# setting up ABM space
	space = ParcelSpace(parcel_df, n_agents_end_iteration)

	# setting up the model
	model = ABM(
				Union{	
						MyAgents.UnoccupiedOwnerAgent,
						MyAgents.IndividualAgent
					}, 
					space;
					rng=rng, 
					properties=properties
				)

	# --- adding agents to model; either in parcel or general environment
	for i = 1:size(parcel_df)[1]
		p = parcel_df[i,:]
		# if p["owner_type"]=="unocc_owner"
		if rand(model.rng)<0.5 		# TODO: Temporary 
			agent = MyAgents.UnoccupiedOwnerAgent(
						i,							# id
						p["guid"],					# position in model (parcel guid)
						model.parcel_base_price, 	# WTA (willingness to accept)
						true, 						# associated parcel on market?
						false,						# looking to buy?
					)
		else
			agent = MyAgents.IndividualAgent(
						i,							# id
						p["guid"],					# position in model (parcel guid)
						model.OR_alpha,				# alpha
						model.OR_beta, 				# beta
						model.OR_gamma,				# gamma
						rand(model.rng, model.OR_budget_dist, 1)[1],	# budget
						model.parcel_base_price, 	# WTA (willingness to accept)
						false,						# associated parcel on market?
						false,						# looking to purchase?
						model.OR_price_goods,		# price of other goods agent must consider

					)
		end
		add_agent_pos!(agent, model)
	end
	MyAgents.AgentsUpdateLandUse!(model)

	# TODO: temporary!!
	model.n_individuals_init = count_agnt_types(model, MyAgents.IndividualAgent)

	return model
end



"""
	complex_model_step(model)
function for custom model step.
checks time in model. 
if pre-csz, housing market is simulated and populationg grows
if csz, pyincore is called to damage the built environment
"""
function complex_model_step!(model)
	if model.tick < model.t_csz			# pre-CSZ
		PopulationGrowth!(model)
		SimulateMarketStep!(model)
	# elseif model.tick == model.t_csz 	# CSZ
	# 	csz!(model)	# running CSZ for Seaside
	# 	PYTHON_OPS.complete_run()
	end
	model.tick += 1
	next!(model.progress_bar)	# advancing progress bar
end



"""
	SimulateMarketStep(model) → prcls
Simulate market interaction step
Establishing parcels that are for sale
Identifies potential buyers
Simulates interaction between buyers and sellers
"""
function SimulateMarketStep!(model)
	bidders, sellers = EstablishMarket(model, shuff=true)
	SBTs, WTPs = MarketSearch(model, bidders, sellers)
	SuccessfulBidders = ParcelTransaction(model, bidders, SBTs, WTPs, sellers)
	UpdateLandUses(model, SuccessfulBidders)
end


"""
	EstablishMarket(model) → prcls
Establishes housing market by identifying which parcels are for sale and which 
buyers are interested. 
Agents step using "agent_on_market_step!" and "agent_looking_for_parcel_step"
"""
function EstablishMarket(model; shuff::Bool=false)
	# --- getting parcels on market
	# getting all agent IDs that are in a parcel
	ids = GetAgentIdsInParcel(model)

	# shuffling (if true)
	if shuff == true
		ids = shuffle(model.rng, ids)
	end

	# updating parcels that are on market, getting list of those that are
	sellers = Int[]
	for id in ids
		MyAgents.agent_on_market_step!(model[id], model)
		if model[id].prcl_on_mrkt
			push!(sellers, id)
		end
	end


	# --- getting agents looking for parcel
	# getting all agent IDs that are not in a parcel, but in environment
	ids = GetAgentIdsNotInParcel(model)
	
	# shuffling (if true)
	if shuff==true
		ids = shuffle(model.rng, ids)
	end
	
	# identifying list of agents looking to buy parcels
	buyers = Int[]
	for id in ids
		MyAgents.agent_looking_for_parcel_step!(model[id], model)
		if model[id].looking_to_purchase
			push!(buyers, id)
		end
	end
	return buyers, sellers
end


function MarketSearch(model, bidders, sellers)
	SBTs = Int[]		# Sellers to Bid To
	WTPs = Float64[]
	for id in bidders
		seller_bid_to, WTP = MyAgents.agent_WTP_step!(model[id], model, sellers)
		if seller_bid_to != "none"
			push!(SBTs, seller_bid_to)
			push!(WTPs, WTP)
		end
	end
	return SBTs, WTPs
end



function ParcelTransaction(model, bidders, SBTs, WTPs, sellers)
	SuccessfulBidders = Int[]
	for seller in sellers
		bidder = MyAgents.agent_evaluate_bid_step!(model[seller], model, bidders, SBTs, WTPs)
		if bidder != false
			push!(SuccessfulBidders, bidder)
		end
	end
	return SuccessfulBidders
end


function UpdateLandUses(model, SuccessfulBidders)
	for bidder in SuccessfulBidders
		MyAgents.agent_update_landuse_step!(model[bidder], model)
	end

end


"""
	PopulationGrowth(model)
function for growing the population in the model
adds more agents using logistic growth function
"""
function PopulationGrowth!(model)
	n_individuals = count_agnt_types(model, MyAgents.IndividualAgent)
	n_individuals_t = logistic_population(model.tick, 
						model.Individual_carrying_cap, 
						model.n_individuals_init, 
						model.Individual_growth_rate)
	n_individuals_add = n_individuals_t - n_individuals

	for i in 1:n_individuals_add
		agent_id = i + n_individuals_t
		pos = next_avail_pos(model)
		agent = MyAgents.IndividualAgent(
					pos, 							# id
					string("none_",pos),			# position in model (none; lookng to purchase)
					model.OR_alpha,					# alpha
					model.OR_beta, 					# beta
					model.OR_gamma,					# gamma
					rand(model.rng, model.OR_budget_dist, 1)[1],	# budget
					model.parcel_base_price, 		# WTA (willingness to accept)
					false,							# associated parcel on market?
					true,							# looking to purchase
					model.OR_price_goods,			# price of other goods agent must consider
				)
		add_agent_pos!(agent, model)
	end

end

"""
	logistic_population()
"""
function logistic_population(t, k, P0, r)
	A = (k-P0)/P0
	P = k/(1+A*exp(-r*t))
	return round(Int, P)
end

function count_agnt_types(model, agent_type) 
	count(i->(typeof(i.second)==agent_type), model.agents)
end

"""
	csz!(model)
simulation of csz! for model
prepares output from ABM for input to IN-CORE
Invokes python and calls pyIncore 
"""
function csz!(model)
	#= CSZ occurs in model. 
		calling passing data back to python and calling pyIncore 
	=#
	
	# getting iterator of agents in model
	guids = GetAllParcelAttributes(model, model.space.guid)
	strct_typ = GetAllParcelAttributes(model, model.space.strct_typ)
	year_built = GetAllParcelAttributes(model, model.space.year_built)
	no_stories = GetAllParcelAttributes(model, model.space.no_stories)
	x = GetAllParcelAttributes(model, model.space.x)
	y = GetAllParcelAttributes(model, model.space.y)

	# running pyincore
	rt = model.hazard_recurrence
	PYTHON_OPS.pyincore_CSZ(guids=guids,
							strct_typ=strct_typ,
							year_built=year_built,
							no_stories=no_stories,
							x=x,
							y=y,
							rt=rt)

	# getting results from pyincore back to the agents
	path_to_dmg = joinpath("temp", "cm_out.csv")
	dmg_reslts = misc_func.read_csv(path_to_dmg)
	
	UpdateParcelAttr!(model, dmg_reslts[:,"LS_0"], :LS_0)
	UpdateParcelAttr!(model, dmg_reslts[:,"LS_1"], :LS_1)
	UpdateParcelAttr!(model, dmg_reslts[:,"LS_2"], :LS_2)
	MC_Sample_DS!(model)
end


function set_up_model_properties(input_dict, parcel_df, iter)
	input = input_dict["Input"]
	
	t_csz = input[input[:,"Variable"] .== "n_years", "Value"][1]
	n_sims = input[input[:,"Variable"] .== "n_sims", "Value"][1]
	n_sims = convert(Int64, n_sims)
	hazard_recurrence = input[input[:,"Variable"] .== "hazard_recurrence", "Value"][1]

	# -- Owned residential/Individual information
	OR_alpha = input[input[:,"Variable"] .== "OR_alpha", "Value"][1]
	OR_beta = input[input[:,"Variable"] .== "OR_beta", "Value"][1]
	OR_gamma = input[input[:,"Variable"] .== "OR_gamma", "Value"][1]
	OR_budget_mean = input[input[:,"Variable"] .== "OR_budget_mean", "Value"][1]
	OR_budget_std = input[input[:,"Variable"] .== "OR_budget_std", "Value"][1]
	OR_price_goods = input[input[:,"Variable"] .== "OR_price_goods", "Value"][1]
	Individual_init_num = input[input[:,"Variable"] .== "Individual_init_num", "Value"][1]
	Individual_growth_rate = input[input[:,"Variable"] .== "Individual_growth_rate", "Value"][1]
	Individual_carrying_cap = input[input[:,"Variable"] .== "Individual_carrying_cap", "Value"][1]

	# -- Rental Residential/LOSR/Landlord information
	# RR_alpha = input[input[:,"Variable"] .== "RR_alpha", "Value"][1]
	# RR_beta = input[input[:,"Variable"] .== "RR_beta", "Value"][1]
	# LOSR_alpha = input[input[:,"Variable"] .== "LOSR_alpha", "Value"][1]
	# LOSR_beta = input[input[:,"Variable"] .== "LOSR_beta", "Value"][1]
	# Landlord_budget_mean = input[input[:,"Variable"] .== "Landlord_budget_mean", "Value"][1]
	# Landlord_budget_std = input[input[:,"Variable"] .== "Landlord_budget_std", "Value"][1]

	number_parcels_aware = input[input[:,"Variable"] .== "number_parcels_aware", "Value"][1]
	distance_decay_exponent = input[input[:,"Variable"] .== "distance_decay_exponent", "Value"][1]
	parcel_base_price = input[input[:,"Variable"] .== "parcel_base_price", "Value"][1]

	# --- population counts
	n_unocc_init = size(filter(row->row.owner_type=="unocc_owner", parcel_df))[1]
	n_individuals_init = size(filter(row->row.owner_type=="individual", parcel_df))[1]
	# n_landlords_init = size(filter(row->row.owner_type=="landlord", parcel_df))[1]
	# n_developers_init = size(filter(row->row.owner_type=="developer", parcel_df))[1]


	# -----------
	OR_budget_dist = Normal(OR_budget_mean, OR_budget_std)			# owned residential parcel distribution


	t_csz = convert(Int64, t_csz)
	hazard_recurrence = convert(Int64, hazard_recurrence)
	number_parcels_aware = convert(Int64, number_parcels_aware)

	building_codes = input_dict["BuildingCodes"]
	# nghbrhg_params = input_dict["Nghbrhd_Transition_params"]
	zoning_params = input_dict["zoning_params"]

	p = ProgressBar(iter, n_sims, t_csz)
	update!(p)

	prop_dict = Dict(
			:tick => 1,
			:t_csz => t_csz,
			:hazard_recurrence => hazard_recurrence,

			:OR_alpha=>OR_alpha,
			:OR_beta=>OR_beta,
			:OR_gamma=>OR_gamma,
			:OR_budget_dist=>OR_budget_dist,
			:OR_price_goods=>OR_price_goods,
			:n_individuals_init=>n_individuals_init,
			:Individual_growth_rate=>Individual_growth_rate,
			:Individual_carrying_cap=>Individual_carrying_cap,

			# :RR_dist=>RR_dist,
			# :LOSR_dist=>LOSR_dist,

			:number_parcels_aware => number_parcels_aware,
			:distance_decay_exponent => distance_decay_exponent,
			:parcel_base_price => parcel_base_price,
			:zoning_params => zoning_params,
			:progress_bar => p,
			:n_prcls => size(parcel_df)[1]

		)
	return prop_dict
end

function ProgressBar(i, iters, n_years)
	p = Progress(n_years, 
			desc="Iteration: $i/$iters | ",
			barlen=30, 
			color=:cyan
		)
	return p
end



function pd_to_df(df_pd)
	#= convert from pandas pyobject to a julia dataframe
		Pandas in python stores strings as "objects".
		Manually converting the following cols julia strings:
			struct_typ
			dgn_lvl
			zone
			zone_type
	=#

	colnames = map(String, df_pd[:columns])
	df = DataFrame(Any[Array(df_pd[c].values) for c in colnames], colnames)
	df[!,"guid"] = convert.(String,df[!,"guid"])
	df[!,"struct_typ"] = convert.(String,df[!,"struct_typ"])
	df[!,"dgn_lvl"] = convert.(String,df[!,"dgn_lvl"])
	df[!,"zone"] = convert.(String,df[!,"zone"])
	df[!,"zone_type"] = convert.(String,df[!,"zone_type"])
	df[!,"landuse"] = convert.(String,df[!,"landuse"])
    return df
end


# function geom_bounds(gdf; get_ceil::Bool=true)
# 	#=	getting geometry boundaries
# 		returns 4 items: (1) minx, (2) maxx, (3) miny, and (4) maxy
# 	=#

# 	minx = minimum(gdf[:,"x"])
# 	maxx = maximum(gdf[:,"x"])
# 	miny = minimum(gdf[:,"y"])
# 	maxy = maximum(gdf[:,"y"])
# 	if get_ceil==true
# 		maxx = ceil(maxx)
# 		maxy = ceil(maxy)
# 	end
# 	return minx, miny, maxx, maxy

# end





#----
end




















