module my_model  # defining module
#= module for model. used to keep run.jl clean 
=#

# setting up packages for this module
using Agents
using Random
using Pkg
using DataFrames
using ProgressMeter


# importing local modules
include("misc_func.jl")
include("parcel.jl")
include("luc.jl")

using .misc_func
using .parcel
using .luc

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
pycall_jl = pyimport("misc_operations")
PYTHON_OPS = pycall_jl.misc_python_ops() # setting up python operations


# using agent macro
@agent ParcelAgent ContinuousAgent{2} begin
	agent_type::String
	guid::String
	year_built::Int64
	strct_typ::String
	no_stories::Int64
	dgn_lvl::String
	d_coast::Float64
	d_grnspc::Float64
	d_road1::Float64
	zone::String
	zone_type::String
	landuse::String
	numprec::Float64
	LS_0::Float64
	LS_1::Float64
	LS_2::Float64
	MC_DS::Int64
	tp::Float64
	ptnl_state::String
end

@agent LUCAgent ContinuousAgent{2} begin
	agent_type::String
	num_luc_avail::Float64
	num_luc::Int64
	luc_growthrate::Float64
end




function initialize(input_dict, input_folder; seed=1337, iter=1)
	seed = seed + iter 
	# Random.seed!(seed)
	rng = Random.MersenneTwister(seed)	 # setting seed

	# preparing parcel dataframe
	parcel_df, space_conv = PYTHON_OPS.prepare_parcel_df(input_folder, seed=seed)
	println("initial dataframe prepared")

	# converting parcel datafarme from python to julia
	parcel_df = misc_func.pd_to_df(parcel_df)

	# getting boundaries for space
	minx, miny, maxx, maxy = misc_func.geom_bounds(parcel_df, get_ceil=true)
	griddims = (maxx, maxy)

	# getting model property dictionary
	properties = misc_func.set_up_model_properties(input_dict, space_conv, iter)

	# setting up ABM space
	space = ContinuousSpace(griddims, 1, periodic=false)
	
	# setting up the model
	model = ABM(Union{ParcelAgent, LUCAgent}, space;
				rng=rng, 
				properties=properties,
				# scheduler=Schedulers.randomly
				)


	# populating the model with agents
	numagents = size(parcel_df)[1]
	for i = 1:numagents
		p = parcel_df[i,:]
		pos = (p["x"], p["y"])
		agent = ParcelAgent(i, 					# agent id; needs to be Int;  can't use guid
							pos, 				# position of agent
							(0.0,0.0),			# velocity; necessary for continous space
							"parcel",			# agent type
							p["guid"], 			# agent guid
							p["year_built"],	# year built 
							p["struct_typ"], 	# structure type
							p["no_stories"],	# number of stories
							p["dgn_lvl"],		# design level
							p["d_coast"],		# distance to coast
							p["d_grnspc"],		# distance to greenspace
							p["d_road1"],		# distance to major road
							p["zone"],			# zone that parcel is in
							p["zone_type"],		# type of zone that parcel is in
							p["landuse"],		# current landuse of parcel
							p["numprec"],		# number of preople in parcel
							0,					# limit state 0 (LS_0)
							0,					# limit state 1 (LS_1)
							0,					# limit state 2 (LS_2)
							0,					# Monte-Carlo sample of damage state
							0.0,				# transition potential
							p["landuse"]		# potential next land use
						)
		add_agent_pos!(agent, model)
	end
	luc_agent = LUCAgent(numagents+1,			# agent id
						(0.0, 0.0),				# position; just placing at 0,0
						(0.0, 0.0),				# velocity
						"LUCAgent",				# agent type
						model.luc_initial, 		# number luc availabile (Float)
						model.luc_initial,		# initial luc; "num_luc" (Int)
						model.luc_growthrate,	# growthrate of luc
						)
	add_agent!(luc_agent, model)
	return model

end


function complex_model_step!(model)
	if model.tick < model.t_csz			# pre-CSZ
		all_parcels_step(model)
		luc_step(model)

	elseif model.tick == model.t_csz 	# CSZ
		csz!(model)	# running CSZ for Seaside
		all_parcels_csz_step(model)
		# PYTHON_OPS.complete_run()
	end

	model.tick += 1

	next!(model.progress_bar)	# advancing progress bar

end


function all_parcels_step(model)
	for id in scheduler_by_type(model, "parcel", true)
		parcel.parcel_step!(model[id], model)	# updates transition potentials
	end
end

function luc_step(model)
	for id in scheduler_by_type(model, "LUCAgent", false)
		luc.luc_step!(model[id], model)		# picks parcels to transition
	end

end

function all_parcels_csz_step(model)
	for id in scheduler_by_type(model, "parcel", true)
		parcel.parcel_CSZ_step!(model[id], model)
	end

end

function scheduler_by_type(model::ABM, type::String, shuff::Bool=false)
	#= scheduler function; 
	   filters by type of agent; 
	   optionally shuffles order
	=#
	
	IDs = Int[]
	for id in keys(model.agents)
		if model[id].agent_type == type
			push!(IDs, id)
		end
	end
	if shuff==true
		return shuffle(model.rng, IDs)
	else
		return IDs
	end
end



function csz!(model)
	#= CSZ occurs in model. 
		calling passing data back to python and calling pyIncore 
	=#
	
	# getting iterator of agents in model
	prcl_agnts = allagents(model)
	prcl_agnts = [a for a in prcl_agnts if a.agent_type=="parcel"]
	n_prcl = misc_func.length_iter(prcl_agnts)

	# preallocating space to create dataframe
	guids = Array{String}(undef,n_prcl)
	strct_typ = Array{String}(undef,n_prcl)
	year_built = Array{Int64}(undef,n_prcl)
	no_stories = Array{Int64}(undef,n_prcl)
	x = Array{Float64}(undef,n_prcl)
	y = Array{Float64}(undef,n_prcl)

	# loop through agents and get needed info for pyincore
	i = 1
	for agent in prcl_agnts
		guids[i] = agent.guid
		strct_typ[i] = agent.strct_typ
		year_built[i] = agent.year_built
		no_stories[i] = agent.no_stories
		x[i] = agent.pos[1] + model.space_conv[1]
		y[i] = agent.pos[2] + model.space_conv[2]
		i+=1
	end

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
	for agent in prcl_agnts
		row = dmg_reslts[dmg_reslts[:,"guid"].==agent.guid, :]
		agent.LS_0 = row.LS_0[1]
		agent.LS_1 = row.LS_1[1]
		agent.LS_2 = row.LS_2[1]
	end
	
end




function cnt_u_prcls(model)
	cnt = 0
	for id in scheduler_by_type(model, "parcel", false)
		if model[id].landuse=="unoccupied"
			cnt += 1
		end
	end
end


function cnt_r_prcls(model)
	cnt = 0
	for id in scheduler_by_type(model, "parcel", false)
		if model[id].landuse=="residential"
			cnt += 1
		end
	end
end

function cnt_c_prcls(model)
	cnt = 0
	for id in scheduler_by_type(model, "parcel", false)
		if model[id].landuse=="commercial"
			cnt += 1
		end
	end
end

function cnt_sr_prcls(model)
	cnt = 0
	for id in scheduler_by_type(model, "parcel", false)
		if model[id].landuse=="seasonal_rental"
			cnt += 1
		end
	end
end

end




















