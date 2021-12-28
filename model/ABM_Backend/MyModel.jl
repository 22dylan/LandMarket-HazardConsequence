"""
	initialize(input_dict, input_folder; seed, iter)
Sets up the initial model using the input directory
Sets up the parcel space
Assigns agents to the model
"""
function initialize(input_dict, input_folder; seed=1337, iter=1)
	seed = seed + iter 
	rng = Random.MersenneTwister(seed)	 # setting seed

	# preparing parcel dataframe and converting to julia
	parcel_df = PYTHON_OPS.prepare_parcel_df(input_folder, seed=seed)
	parcel_df = pd_to_df(parcel_df)
	
	# # TODO: Temporarily assuming commerical, high occupancy res/SR are unoccupied
	# parcel_df[parcel_df.owner_type .== "developer", :owner_type] .= "unocc_owner"
	# parcel_df[parcel_df.landuse .== "hor", :landuse] .= "unoccupied"
	# parcel_df[parcel_df.landuse .== "hosr", :landuse] .= "unoccupied"
	# parcel_df[parcel_df.landuse .== "commercial", :landuse] .= "unoccupied"

	println("initial dataframe prepared")

	# getting model property dictionary
	properties = set_up_model_properties(input_dict, parcel_df, iter)

	# setting up ABM space
	space = ParcelSpace(parcel_df, properties.n_agents_end_iteration)

	# setting up the model
	model = ABM(
				Union{	
						UnoccupiedOwnerAgent,
						IndividualAgent,
						LandlordAgent,
						DeveloperAgent
					}, 
					space;
					rng=rng, 
					properties=properties
				)

	# --- adding agents to model; either in parcel or general environment
	AddAgentsToModel!(model, parcel_df)
	UpdateModelCounts!(model, start=true)
	return model
end




"""
	AddAgentsToModel!(model::ABM, parcel_df::DataFrame)
adds agents to the model to initialize
"""
function AddAgentsToModel!(model::ABM, parcel_df::DataFrame)
	AddAgents_fromParcelDF!(model, parcel_df)
	AddAgents_fromModelParams!(model)
end

"""
	AddAgents_fromParcelDF(model::ABM, parcel_df::DataFrame)
adds agents from the parcel dataframe
These are the agents that are initially associated with a parcel
"""
function AddAgents_fromParcelDF!(model::ABM, parcel_df::DataFrame)
	for i = 1:size(parcel_df)[1]
		id = i
		i !=1 && (id=next_avail_id(model))	 # if id!=1, then get the next available id
		p = parcel_df[i,:]
		if p["owner_type"]=="unocc_owner"
			agent = UnoccupiedOwnerAgent(
						id=id,
						pos=p["guid"],
						WTA=model.Unoccupied_WTA,
						prcl_on_mrkt=true,
						looking_to_purchase=false,
						own_parcel=true
					)
		elseif p["owner_type"]=="individual"
			agent = IndividualAgent(
						id=id,
						pos=p["guid"],
						alpha1=model.Individual_alpha1,
						alpha2=model.Individual_alpha2,
						alpha3=model.Individual_alpha3,
						budget=rand(model.rng, model.Individual_budget_dist, 1)[1],
						price_goods=model.Individual_price_goods,
						number_prcls_aware=model.Individual_number_parcels_aware,
						prcl_on_mrkt=false,
						looking_to_purchase=false,
						WTA=model.Individual_WTA,
						age=age_calc(model.Individual_age_dist, model),
						own_parcel=true,
						num_people=p["numprec"]
					)
		elseif p["owner_type"]=="landlord"
			agent = LandlordAgent(
						id=id,
						pos=p["guid"],
						alpha1_RR=model.Landlord_RR_alpha1,
						alpha2_RR=model.Landlord_RR_alpha2,
						alpha3_RR=model.Landlord_RR_alpha3,
						alpha1_LOSR=model.Landlord_LOSR_alpha1,
						alpha2_LOSR=model.Landlord_LOSR_alpha2,
						alpha3_LOSR=model.Landlord_LOSR_alpha3,
						budget=rand(model.rng, model.Landlord_budget_dist, 1)[1],
						price_goods=model.Landlord_price_goods,
						number_prcls_aware=model.Landlord_number_parcels_aware,
						prcl_on_mrkt=false,
						looking_to_purchase=false,
						WTA=model.Landlord_WTA,
						age=age_calc(model.Landlord_age_dist, model),
						own_parcel=true,
						transition_penalty=model.Landlord_transition_penalty
					)
		elseif p["owner_type"]=="developer"
			agent = DeveloperAgent(
						id=id,
						pos=p["guid"],
						alpha1_HOR=model.Developer_HOR_alpha1,
						alpha2_HOR=model.Developer_HOR_alpha2,
						alpha3_HOR=model.Developer_HOR_alpha3,
						alpha1_HOSR=model.Developer_HOSR_alpha1,
						alpha2_HOSR=model.Developer_HOSR_alpha2,
						alpha3_HOSR=model.Developer_HOSR_alpha3,
						budget=rand(model.rng, model.Developer_budget_dist, 1)[1],
						price_goods=model.Developer_price_goods,
						number_prcls_aware=model.Developer_number_parcels_aware,
						prcl_on_mrkt=false,
						looking_to_purchase=false,
						WTA=model.Developer_WTA,
						own_parcel=true
				)

		else	# TODO: temporarily setup as a placeholder
			agent = UnoccupiedOwnerAgent(
				id=id,
				pos=p["guid"],
				WTA=model.Unoccupied_WTA,
				prcl_on_mrkt=true,
				looking_to_purchase=false,
				own_parcel=true
			)
		end
		add_agent_pos_owner!(agent, model, init=true) # adding agent to model with intial land use from Nathanael's HUA
	end
end


"""
	AddAgents_fromModelParams(model)
Adds landlord/develoepr agents that are in the model space looking to purchase property
Not associated with a parcel yet
"""
function AddAgents_fromModelParams!(model)
	for i = 1:model.Landlord_number_searching
		id = next_avail_id(model)
		pos = next_avail_pos(model)
		agent = LandlordAgent(
					id=id,
					pos=string("none_",pos),
					alpha1_RR=model.Landlord_RR_alpha1,
					alpha2_RR=model.Landlord_RR_alpha2,
					alpha3_RR=model.Landlord_RR_alpha3,
					alpha1_LOSR=model.Landlord_LOSR_alpha1,
					alpha2_LOSR=model.Landlord_LOSR_alpha2,
					alpha3_LOSR=model.Landlord_LOSR_alpha3,
					budget=rand(model.rng, model.Landlord_budget_dist, 1)[1],
					price_goods=model.Landlord_price_goods,
					number_prcls_aware=model.Landlord_number_parcels_aware,
					prcl_on_mrkt=false,
					looking_to_purchase=true,
					WTA=model.Landlord_WTA,
					age=age_calc(model.Landlord_age_dist, model),
					own_parcel=false,
					transition_penalty=model.Landlord_transition_penalty
				)
		add_agent_pos!(agent, model)
	end

	for i = 1:model.Developer_number_searching
		id = next_avail_id(model)
		pos = next_avail_pos(model)
		agent = DeveloperAgent(
					id=id,
					pos=string("none_",pos),
					alpha1_HOR=model.Developer_HOR_alpha1,
					alpha2_HOR=model.Developer_HOR_alpha2,
					alpha3_HOR=model.Developer_HOR_alpha3,
					alpha1_HOSR=model.Developer_HOSR_alpha1,
					alpha2_HOSR=model.Developer_HOSR_alpha2,
					alpha3_HOSR=model.Developer_HOSR_alpha3,
					budget=rand(model.rng, model.Developer_budget_dist, 1)[1],
					price_goods=model.Developer_price_goods,
					number_prcls_aware=model.Developer_number_parcels_aware,
					prcl_on_mrkt=false,
					looking_to_purchase=true,
					WTA=model.Developer_WTA,
					own_parcel=false
				)
		add_agent_pos!(agent, model)
	end
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
		AllAgentsStep!(model)
		SimulateMarketStep!(model)
		UpdateModelCounts!(model)
	# elseif model.tick == model.t_csz 	# CSZ
	# 	csz!(model)	# running CSZ for Seaside
	end
	model.tick += 1
	next!(model.progress_bar)	# advancing progress bar
end



"""
	PopulationGrowth(model)
function for growing the population in the model
adds more agents using logistic growth function
"""
function PopulationGrowth!(model)
	PopulationGrowth_individual!(model)
	PopulationGrowth_visitor!(model)

	PopulationGrowth_landlord!(model)
	PopulationGrowth_developer!(model)

	UpdateModelCounts!(model)

end

"""
	PopulationGrowth_individual!(model)
population growth for individuals/household agents in model
Note that the population growth curves are for number of people in the model, 
	whereas this adds agents (households) to the model

"""
function PopulationGrowth_individual!(model::ABM)
	n_people = cnt_n_people(model)
	n_people_t = logistic_population(model.tick, 
						model.FullTimeResident_carrying_cap, 
						model.FullTimeResident_init,
						model.FullTimeResident_growth_rate)
	n_people_add = n_people_t - n_people

	n_added = 0
	while n_added < n_people_add
		id = next_avail_id(model)
		pos = next_avail_pos(model)
		n_people = npeople_calc(model.Individual_nhousehold_dist, model)

		agent = IndividualAgent(
					id=id,
					pos=string("none_",pos),
					alpha1=model.Individual_alpha1,
					alpha2=model.Individual_alpha2,
					alpha3=model.Individual_alpha3,
					budget=rand(model.rng, model.Individual_budget_dist, 1)[1],
					price_goods=model.Individual_price_goods,
					number_prcls_aware=model.Individual_number_parcels_aware,
					prcl_on_mrkt=false,
					looking_to_purchase=true,
					WTA=model.Individual_WTA,
					age=age_calc(model.Individual_age_dist, model),
					own_parcel=false,
					num_people=n_people,
				)		
		add_agent_pos!(agent, model)
		n_added+=n_people
	end
end

"""
	PopulationGrowth_visitor!(model)
population growth fucntion for number of visitors. 
Since visitors are not represented as agents, this function simply calls the 
logistic population function
"""
function PopulationGrowth_visitor!(model)
	model.Visitor_total = logistic_population(model.tick, 
						model.Visitor_carrying_cap, 
						model.Visitor_init, 
						model.Visitor_growth_rate)
end


"""
	PopulationGrowth_landlord!(model)
Population growth function for landlords
This function keeps the number of landlords searching for a parcel constant. 
"""
function PopulationGrowth_landlord!(model::ABM)
	n_landlords_searching_t = length(GetAgentIdsNotInParcel(model, LandlordAgent))
	n_landlords_add = model.Landlord_number_searching - n_landlords_searching_t

	for i in 1:n_landlords_add
		id = next_avail_id(model)
		pos = next_avail_pos(model)
		agent = LandlordAgent(
					id=id,
					pos=string("none_",pos),
					alpha1_RR=model.Landlord_RR_alpha1,
					alpha2_RR=model.Landlord_RR_alpha2,
					alpha3_RR=model.Landlord_RR_alpha3,
					alpha1_LOSR=model.Landlord_LOSR_alpha1,
					alpha2_LOSR=model.Landlord_LOSR_alpha2,
					alpha3_LOSR=model.Landlord_LOSR_alpha3,
					budget=rand(model.rng, model.Landlord_budget_dist, 1)[1],
					price_goods=model.Landlord_price_goods,
					number_prcls_aware=model.Landlord_number_parcels_aware,
					prcl_on_mrkt=false,
					looking_to_purchase=true,
					WTA=model.Landlord_WTA,
					age=age_calc(model.Landlord_age_dist, model),
					own_parcel=false,
					transition_penalty=model.Landlord_transition_penalty
				)
		add_agent_pos!(agent, model)
	end
end

"""
	PopulationGrowth_developer!(model)
Population growth function for developers
This function keeps the number of developers searching for a parcel constant. 
"""
function PopulationGrowth_developer!(model::ABM)
	n_developers_searching_t = length(GetAgentIdsNotInParcel(model, DeveloperAgent))
	n_developers_add = model.Developer_number_searching - n_developers_searching_t

	for i in 1:n_developers_add
		id = next_avail_id(model)
		pos = next_avail_pos(model)
		agent = DeveloperAgent(
					id=id,
					pos=string("none_",pos),
					alpha1_HOR=model.Developer_HOR_alpha1,
					alpha2_HOR=model.Developer_HOR_alpha2,
					alpha3_HOR=model.Developer_HOR_alpha3,
					alpha1_HOSR=model.Developer_HOSR_alpha1,
					alpha2_HOSR=model.Developer_HOSR_alpha2,
					alpha3_HOSR=model.Developer_HOSR_alpha3,
					budget=rand(model.rng, model.Developer_budget_dist, 1)[1],
					price_goods=model.Developer_price_goods,
					number_prcls_aware=model.Developer_number_parcels_aware,
					prcl_on_mrkt=false,
					looking_to_purchase=true,
					WTA=model.Developer_WTA,
					own_parcel=false
				)
		add_agent_pos!(agent, model)
	end

end



"""
	AllAgentsStep!(model)
general stepping function for all agents in model. 
UnoccupiedOwnerAgents do nothing
IndiviudalAgents age using this step.
LandlordAgents decide between renting as rental_res and losr
"""
function AllAgentsStep!(model)
	for agent in allagents(model)
		agent_step!(agent, model)
	end
end


"""
	SimulateMarketStep!(model) → prcls
Simulate market interaction step
Establishing parcels that are for sale
Identifies potential buyers
Simulates interaction between buyers and sellers
"""
function SimulateMarketStep!(model)
	bidders, sellers = EstablishMarket(model, shuff=true)
	SBTs, WTPs = MarketSearch(model, bidders, sellers)
	ParcelTransaction!(model, bidders, SBTs, WTPs, sellers)
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
	ids = GetParcelsAttribute(model, model.space.owner)
	shuff==true && (ids=shuffle(model.rng, ids))	 # if shuff==true, shuffle ids

	# updating parcels that are on market, getting list of those that are
	sellers_bool = Vector{Bool}(undef, length(ids))
	for i in eachindex(ids)
		agent_on_market_step!(model[ids[i]], model)
		if model[ids[i]].prcl_on_mrkt
			sellers_bool[i] = true
		else
			sellers_bool[i] = false
		end
	end
	sellers = ids[sellers_bool]


	# --- getting agents looking for parcel
	# getting all agent IDs that are not in a parcel, but in environment
	ids = GetAgentIdsNotInParcel(model)
	shuff==true && (ids=shuffle(model.rng, ids))	 # if shuff==true, shuffle ids
	
	# identifying list of agents looking to buy parcels
	buyers_bool = Vector{Bool}(undef, length(ids))
	for i in eachindex(ids)
		agent_looking_for_parcel_step!(model[ids[i]], model)
		if model[ids[i]].looking_to_purchase
			buyers_bool[i] = true
		else
			buyers_bool[i] = false
		end
	end
	buyers = ids[buyers_bool]
	return buyers, sellers
end


function MarketSearch(model, bidders, sellers)
	SBTs = Vector{Int}(undef, length(bidders))
	WTPs = Vector{Float64}(undef, length(bidders))
	cnt = 1
	for id in bidders
		seller_bid_to, WTP = agent_WTP_step!(model[id], model, sellers)
		SBTs[cnt] = seller_bid_to
		WTPs[cnt] = WTP
		cnt += 1
	end
	return SBTs, WTPs
end



function ParcelTransaction!(model, bidders, SBTs, WTPs, sellers)
	for seller in sellers
		agent_evaluate_bid_step!(model[seller], model, bidders, SBTs, WTPs)
	end
end



"""
	UpdateModelCounts(model)
general step for model. Updates counts of each landuse type in model, and number
of unhoused agents searching for housing
"""
function UpdateModelCounts!(model; start::Bool=false)
	# initial model counts
	if start == true
		n_unoccupied_init = count_agnt_types(model, UnoccupiedOwnerAgent)
		n_individuals_init = count_agnt_types(model, IndividualAgent)
		n_landlords_init = count_agnt_types(model, LandlordAgent)
		n_developers_init = count_agnt_types(model, DeveloperAgent)

		model.FullTimeResident_init = cnt_n_people(model)
	end

	# agent counts
	model.n_unoccupied_searching = length(GetAgentIdsNotInParcel(model, UnoccupiedOwnerAgent))
	model.n_unoccupied_total = cnt_UnoccupiedOwner_agnts(model)
	model.n_unoccupied_inparcel = model.n_unoccupied_total - model.n_unoccupied_searching

	model.n_individuals_searching = length(GetAgentIdsNotInParcel(model, IndividualAgent))
	model.n_individuals_total = cnt_IndividualOwner_agnts(model)
	model.n_individuals_inparcel = model.n_individuals_total - model.n_individuals_searching

	model.n_landlords_searching = length(GetAgentIdsNotInParcel(model, LandlordAgent))
	model.n_landlords_total = cnt_Landlord_agnts(model)
	model.n_landlords_inparcel = model.n_landlords_total - model.n_landlords_searching

	model.n_developers_searching = length(GetAgentIdsNotInParcel(model, DeveloperAgent))
	model.n_developers_total = cnt_Developer_agnts(model)
	model.n_developers_inparcel = model.n_developers_total - model.n_developers_searching

	# count of landuses
	model.n_unoccupied = cnt_u_prcls(model)
	model.n_OwnedRes = cnt_or_prcls(model)
	model.n_RentlRes = cnt_rr_prcls(model)
	model.n_LOSR = cnt_losr_prcls(model)
	model.n_HOR = cnt_hor_prcls(model)
	model.n_HOSR = cnt_hosr_prcls(model)
	model.n_comm = cnt_comm_prcls(model)

	# counts of people
	update_CountsInParcel!(model)
	update_CountsNotInParcel!(model)

	model.FullTimeResidents_total = model.FullTimeResidents_inparcel + model.FullTimeResidents_searching

	# println("Un ", model.n_unoccupied)
	# println("OR ", model.n_OwnedRes)
	# println("RR ", model.n_RentlRes)
	# println("LS ", model.n_LOSR)
	# println("HR ", model.n_HOR)
	# println("HS ", model.n_HOSR)
	# println()
	# fds

	return model
end

"""
	update_CountsInParcel!(model)
updates the following:
	number of agents associated with each parcel
	number of people associated with each parcel
"""
function update_CountsInParcel!(model)
	cnt_total = 0
	for i = 1:model.n_prcls
		model.space.n_agents[i] = [length(model.space.s[i])]
		cnt = 0
		for agent_id in model.space.s[i]
			if typeof(model[agent_id])==IndividualAgent
				cnt += model[agent_id].num_people
			end
		end
		model.space.n_people[i] = [cnt]
		cnt_total += cnt
	end
	model.FullTimeResidents_inparcel = cnt_total
end

"""
	update_CountsNotInParcel!(model)
update the number of full time residents that are searching for a parcel, but 
	not yet in one
"""
function update_CountsNotInParcel!(model)
	ids = GetAgentIdsNotInParcel(model, IndividualAgent)
	cnt = 0
	for id in ids
		cnt += model[id].num_people
	end
	model.FullTimeResidents_searching = cnt
end

"""
	logistic_population(t, k, P0, r)
t: time in model
k: carrying capacity
P0: initial population
r: growthrate
"""
function logistic_population(t, k, P0, r)
	A = (k-P0)/P0
	P = k/(1+A*exp(-r*t))
	return round(Int, P)
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
	guids = GetParcelsAttribute(model, model.space.guid)
	strct_typ = GetParcelsAttribute(model, model.space.strct_typ)
	year_built = GetParcelsAttribute(model, model.space.year_built)
	no_stories = GetParcelsAttribute(model, model.space.no_stories)
	x = GetParcelsAttribute(model, model.space.x)
	y = GetParcelsAttribute(model, model.space.y)

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
	hazard_recurrence = input[input[:,"Variable"] .== "hazard_recurrence", "Value"][1]
	distance_decay_exponent = input[input[:,"Variable"] .== "distance_decay_exponent", "Value"][1]

	# --- population information
	FullTimeResident_growth_rate = input[input[:,"Variable"] .== "FullTimeResident_growth_rate", "Value"][1]
	FullTimeResident_carrying_cap = input[input[:,"Variable"] .== "FullTimeResident_carrying_cap", "Value"][1]

	Visitor_init = input[input[:,"Variable"] .== "Visitor_init", "Value"][1]
	Visitor_growth_rate = input[input[:,"Variable"] .== "Visitor_growth_rate", "Value"][1]
	Visitor_carrying_cap = input[input[:,"Variable"] .== "Visitor_carrying_cap", "Value"][1]


	# -- Unoccupied agent properties
	Unoccupied_WTA = input[input[:,"Variable"] .== "Unoccupied_WTA", "Value"][1]

	# -- Individual agent information
	Individual_WTA = input[input[:,"Variable"] .== "Individual_WTA", "Value"][1]
	Individual_alpha1 = input[input[:,"Variable"] .== "Individual_alpha1", "Value"][1]
	Individual_alpha2 = input[input[:,"Variable"] .== "Individual_alpha2", "Value"][1]
	Individual_alpha3 = input[input[:,"Variable"] .== "Individual_alpha3", "Value"][1]
	Individual_budget_mean = input[input[:,"Variable"] .== "Individual_budget_mean", "Value"][1]
	Individual_budget_std = input[input[:,"Variable"] .== "Individual_budget_std", "Value"][1]
	Individual_price_goods = input[input[:,"Variable"] .== "Individual_price_goods", "Value"][1]
	Individual_number_parcels_aware = input[input[:,"Variable"] .== "Individual_number_parcels_aware", "Value"][1]	
	Individual_age_gamma_alpha = input[input[:,"Variable"] .== "Individual_age_gamma_alpha", "Value"][1]
	Individual_age_gamma_theta = input[input[:,"Variable"] .== "Individual_age_gamma_theta", "Value"][1]
	Individual_nhousehold_alpha = input[input[:,"Variable"] .== "Individual_nhousehold_alpha", "Value"][1]
	Individual_nhousehold_theta = input[input[:,"Variable"] .== "Individual_nhousehold_theta", "Value"][1]
	
	Individual_budget_dist = Normal(Individual_budget_mean, Individual_budget_std)
	Individual_age_dist = Gamma(Individual_age_gamma_alpha, Individual_age_gamma_theta)
	Individual_nhousehold_dist = Gamma(Individual_nhousehold_alpha, Individual_nhousehold_theta)

	# -- Landlord agent information
	Landlord_WTA = input[input[:,"Variable"] .== "Landlord_WTA", "Value"][1]
	Landlord_RR_alpha1 = input[input[:,"Variable"] .== "Landlord_RR_alpha1", "Value"][1]
	Landlord_RR_alpha2 = input[input[:,"Variable"] .== "Landlord_RR_alpha2", "Value"][1]
	Landlord_RR_alpha3 = input[input[:,"Variable"] .== "Landlord_RR_alpha3", "Value"][1]
	Landlord_LOSR_alpha1 = input[input[:,"Variable"] .== "Landlord_LOSR_alpha1", "Value"][1]
	Landlord_LOSR_alpha2 = input[input[:,"Variable"] .== "Landlord_LOSR_alpha2", "Value"][1]
	Landlord_LOSR_alpha3 = input[input[:,"Variable"] .== "Landlord_LOSR_alpha3", "Value"][1]
	Landlord_budget_mean = input[input[:,"Variable"] .== "Landlord_budget_mean", "Value"][1]
	Landlord_budget_std = input[input[:,"Variable"] .== "Landlord_budget_std", "Value"][1]
	Landlord_price_goods = input[input[:,"Variable"] .== "Landlord_price_goods", "Value"][1]
	Landlord_number_parcels_aware = input[input[:,"Variable"] .== "Landlord_number_parcels_aware", "Value"][1]	
	Landlord_number_searching = input[input[:,"Variable"] .== "Landlord_number_searching", "Value"][1]	
	Landlord_age_gamma_alpha = input[input[:,"Variable"] .== "Landlord_age_gamma_alpha", "Value"][1]
	Landlord_age_gamma_theta = input[input[:,"Variable"] .== "Landlord_age_gamma_theta", "Value"][1]
	Landlord_transition_penalty = input[input[:,"Variable"] .== "Landlord_transition_penalty", "Value"][1]
	
	Landlord_budget_dist = Normal(Landlord_budget_mean, Landlord_budget_std)
	Landlord_age_dist = Gamma(Landlord_age_gamma_alpha, Landlord_age_gamma_theta)

	# -- Developer agent information
	Developer_WTA = input[input[:,"Variable"] .== "Developer_WTA", "Value"][1]
	Developer_HOR_alpha1 = input[input[:,"Variable"] .== "Developer_HOR_alpha1", "Value"][1]
	Developer_HOR_alpha2 = input[input[:,"Variable"] .== "Developer_HOR_alpha2", "Value"][1]
	Developer_HOR_alpha3 = input[input[:,"Variable"] .== "Developer_HOR_alpha3", "Value"][1]
	Developer_HOSR_alpha1 = input[input[:,"Variable"] .== "Developer_HOSR_alpha1", "Value"][1]
	Developer_HOSR_alpha2 = input[input[:,"Variable"] .== "Developer_HOSR_alpha2", "Value"][1]
	Developer_HOSR_alpha3 = input[input[:,"Variable"] .== "Developer_HOSR_alpha3", "Value"][1]
	Developer_budget_mean = input[input[:,"Variable"] .== "Developer_budget_mean", "Value"][1]
	Developer_budget_std = input[input[:,"Variable"] .== "Developer_budget_std", "Value"][1]
	Developer_price_goods = input[input[:,"Variable"] .== "Developer_price_goods", "Value"][1]
	Developer_number_parcels_aware = input[input[:,"Variable"] .== "Developer_number_parcels_aware", "Value"][1]
	Developer_number_searching = input[input[:,"Variable"] .== "Developer_number_searching", "Value"][1]	

	Developer_budget_dist = Normal(Developer_budget_mean, Developer_budget_std)


	# --- population counts
	n_unocc_init = size(filter(row->row.owner_type=="unocc_owner", parcel_df))[1]
	# n_individuals_init = size(filter(row->row.owner_type=="individual", parcel_df))[1] + size(filter(row->row.landuse=="rentl_res", parcel_df))[1]
	# n_landlords_init = size(filter(row->row.owner_type=="landlord", parcel_df))[1]
	# n_developers_init = size(filter(row->row.owner_type=="developer", parcel_df))[1]

	# # todo: temporary
	# TODO: temporary while developers are not in model
	# n_unocc_init = n_unocc_init + n_developers_init

	# --- end population counts
	# TODO: update end population counts. Runtime is sensitive to this value (larger=longer runs) 
	n_agents_end_iteration = n_unocc_init + FullTimeResident_carrying_cap/2 + Landlord_number_searching + Developer_number_searching
	n_agents_end_iteration = convert(Int64, n_agents_end_iteration)


	# --- conversions to correct datatypes
	n_sims = convert(Int64, n_sims)
	t_csz = convert(Int64, t_csz)
	hazard_recurrence = convert(Int64, hazard_recurrence)
	Individual_number_parcels_aware = convert(Int64, Individual_number_parcels_aware)

	building_codes = input_dict["BuildingCodes"]
	zoning_params = input_dict["zoning_params"]

	p = ProgressBar(iter, n_sims, t_csz)
	update!(p)

	# ----------------------------------------
	properties = Parameters(
		t_csz=t_csz,
		hazard_recurrence=hazard_recurrence,
		distance_decay_exponent=distance_decay_exponent,
		zoning_params=zoning_params,
		progress_bar=p,
		n_prcls=size(parcel_df)[1],

		Unoccupied_WTA=Unoccupied_WTA,

		Individual_WTA=Individual_WTA,
		Individual_alpha1=Individual_alpha1,
		Individual_alpha2=Individual_alpha2,
		Individual_alpha3=Individual_alpha3,
		Individual_budget_dist=Individual_budget_dist,
		Individual_price_goods=Individual_price_goods,
		Individual_number_parcels_aware=Individual_number_parcels_aware,			
		Individual_age_dist=Individual_age_dist,
		Individual_nhousehold_dist=Individual_nhousehold_dist,

		Landlord_WTA=Landlord_WTA,
		Landlord_RR_alpha1=Landlord_RR_alpha1,
		Landlord_RR_alpha2=Landlord_RR_alpha2,
		Landlord_RR_alpha3=Landlord_RR_alpha3,
		Landlord_LOSR_alpha1=Landlord_LOSR_alpha1,
		Landlord_LOSR_alpha2=Landlord_LOSR_alpha2,
		Landlord_LOSR_alpha3=Landlord_LOSR_alpha3,
		Landlord_budget_dist=Landlord_budget_dist,
		Landlord_price_goods=Landlord_price_goods,
		Landlord_number_parcels_aware=Landlord_number_parcels_aware,
		Landlord_number_searching=Landlord_number_searching,
		Landlord_age_dist=Landlord_age_dist,
		Landlord_transition_penalty=Landlord_transition_penalty,

		Developer_WTA=Developer_WTA,
		Developer_HOR_alpha1=Developer_HOR_alpha1,
		Developer_HOR_alpha2=Developer_HOR_alpha2,
		Developer_HOR_alpha3=Developer_HOR_alpha3,
		Developer_HOSR_alpha1=Developer_HOSR_alpha1,
		Developer_HOSR_alpha2=Developer_HOSR_alpha2,
		Developer_HOSR_alpha3=Developer_HOSR_alpha3,
		Developer_budget_dist=Developer_budget_dist,
		Developer_price_goods=Developer_price_goods,
		Developer_number_parcels_aware=Developer_number_parcels_aware,
		Developer_number_searching=Developer_number_searching,


		FullTimeResident_growth_rate=FullTimeResident_growth_rate,
		FullTimeResident_carrying_cap=FullTimeResident_carrying_cap,
		Visitor_init=Visitor_init,
		Visitor_growth_rate=Visitor_growth_rate,
		Visitor_carrying_cap=Visitor_carrying_cap,
		Visitor_total=Visitor_init,

		n_agents_end_iteration=n_agents_end_iteration,
		)

	return properties
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

function age_calc(dist::Distribution, model::ABM)
	age = rand(model.rng, dist, 1)[1]
	age = convert(Int64,round(age))
	if age < 18
		age = 18
	end
	return age
end

function npeople_calc(dist::Distribution, model::ABM)
	npeople = rand(model.rng, dist, 1)[1]
	npeople = convert(Int64,round(npeople))
	if npeople < 1
		npeople = 1
	end
	return npeople
end
























