#=
File for space actions.
This was taken from Agents.jl space_interaction_API.jl file:
	https://github.com/JuliaDynamics/Agents.jl/blob/master/src/core/space_interaction_API.jl
=#

cnt_u_prcls(model) = count(lu=="unoccupied" for lu in GetParcelsAttribute(model, model.space.landuse))
cnt_or_prcls(model) = count(lu=="owned_res" for lu in GetParcelsAttribute(model, model.space.landuse))
cnt_rr_prcls(model) = count(lu=="rentl_res" for lu in GetParcelsAttribute(model, model.space.landuse))
cnt_losr_prcls(model) = count(lu=="losr" for lu in GetParcelsAttribute(model, model.space.landuse))
cnt_hor_prcls(model) = count(lu=="hor" for lu in GetParcelsAttribute(model, model.space.landuse))
cnt_hosr_prcls(model) = count(lu=="hosr" for lu in GetParcelsAttribute(model, model.space.landuse))
cnt_comm_prcls(model) = count(lu=="commercial" for lu in GetParcelsAttribute(model, model.space.landuse))


function ParcelSpace(df::DataFrames.DataFrame, d::Int)
	s = Array{Vector{Int},1}(undef, d)
	OWNER = Array{Vector{Int},1}(undef, d)

	LANDUSE = Array{Vector{String},1}(undef, d)
	PREV_LANDUSE = Array{Vector{String},1}(undef, d)
	LANDVALUE = Array{Vector{Float64},1}(undef, d)
	N_AGENTS = Array{Vector{Int},1}(undef, d)
	MAX_N_AGENTS = Array{Vector{Int},1}(undef, d)
	N_PEOPLE = Array{Vector{Int},1}(undef, d)
	ZONE_TYPE = Array{Vector{String},1}(undef, d)
	Xs = Array{Vector{Float64},1}(undef, d)
	Ys = Array{Vector{Float64},1}(undef, d)
	GUIDs = Array{Vector{String},1}(undef, d)
	STRCT_TYPS = Array{Vector{String},1}(undef, d)
	YEAR_BUILTs = Array{Vector{Int},1}(undef, d)
	NO_STORIESs = Array{Vector{Int},1}(undef, d)

	# damage stuff
	LS_0s = Array{Vector{Float64},1}(undef, d)
	LS_1s = Array{Vector{Float64},1}(undef, d)
	LS_2s = Array{Vector{Float64},1}(undef, d)
	AVG_DSs = Array{Vector{Int},1}(undef, d)
	MC_DSs = Array{Vector{Int},1}(undef, d)
	
	D_COASTs = Array{Vector{Float64},1}(undef, d)
	D_COMMASSTs = Array{Vector{Float64},1}(undef, d)
	D_CBDs = Array{Vector{Float64},1}(undef, d)

	for i in eachindex(s)
		if i <= size(df)[1]
			p = df[i,:]
			
			s[i] = Int[]
			OWNER[i] = Int[]
			
			LANDUSE[i] = String[p["landuse"]]
			PREV_LANDUSE[i] = String[p["landuse"]]
			LANDVALUE[i] = Float64[0.0]
			N_AGENTS[i] = Int[1]
			MAX_N_AGENTS[i] = Int[p["max_n_agents"]]
			N_PEOPLE[i] = Int[p["numprec"]]
			ZONE_TYPE[i] = String[p["zone_type"]]
			Xs[i] = Float64[p["x"]]
			Ys[i] = Float64[p["y"]]
			GUIDs[i] = String[p["guid"]]
			STRCT_TYPS[i] = String[p["struct_typ"]]
			YEAR_BUILTs[i] = Int[p["year_built"]]
			NO_STORIESs[i] = Int[p["no_stories"]]
			
			LS_0s[i] = Float64[0.0]
			LS_1s[i] = Float64[0.0]
			LS_2s[i] = Float64[0.0]
			AVG_DSs[i] = Float64[0.0]
			MC_DSs[i] = Int64[0]

			D_COASTs[i] = Float64[p["d_coast"]]
			D_COMMASSTs[i] = Float64[p["d_commasst"]]
			D_CBDs[i] = Float64[p["d_cbd"]]
		
		elseif i==size(df)[1]+1 		# space for agents searching to buy
			s[i] = Int[]
			OWNER[i] = Int[]
			
			LANDUSE[i] = String["none"]
			PREV_LANDUSE[i] = String["none"]
			LANDVALUE[i] = Float64[]
			N_AGENTS[i] = Int[]
			MAX_N_AGENTS[i] = Int[]
			N_PEOPLE[i] = Int[]
			ZONE_TYPE[i] = ["none"]
			Xs[i] = Float64[]
			Ys[i] = Float64[]
			GUIDs[i] = String[string("none")]
			STRCT_TYPS[i] = String[]
			YEAR_BUILTs[i] = Int[]
			NO_STORIESs[i] = Int[]

			LS_0s[i] = Float64[]
			LS_1s[i] = Float64[]
			LS_2s[i] = Float64[]
			AVG_DSs[i] = Float64[]
			MC_DSs[i] = Int64[]

			D_COASTs[i] = Float64[]
			D_COMMASSTs[i] = Float64[]
			D_CBDs[i] = Float64[]

		elseif i==size(df)[1]+2 						# space for visitor agents searching to stay
			s[i] = Int[]
			OWNER[i] = Int[]
			
			LANDUSE[i] = String["none"]
			PREV_LANDUSE[i] = String["none"]
			LANDVALUE[i] = Float64[]
			N_AGENTS[i] = Int[]
			MAX_N_AGENTS[i] = Int[]
			N_PEOPLE[i] = Int[]
			ZONE_TYPE[i] = ["none"]
			Xs[i] = Float64[]
			Ys[i] = Float64[]
			GUIDs[i] = String[string("none_v")]
			STRCT_TYPS[i] = String[]
			YEAR_BUILTs[i] = Int[]
			NO_STORIESs[i] = Int[]

			LS_0s[i] = Float64[]
			LS_1s[i] = Float64[]
			LS_2s[i] = Float64[]
			AVG_DSs[i] = Float64[]
			MC_DSs[i] = Int64[]

			D_COASTs[i] = Float64[]
			D_COMMASSTs[i] = Float64[]
			D_CBDs[i] = Float64[]
		
		elseif i==size(df)[1]+3 						# space for other agents not searching for place to stay
			s[i] = Int[]
			OWNER[i] = Int[]
			
			LANDUSE[i] = String["none"]
			PREV_LANDUSE[i] = String["none"]
			LANDVALUE[i] = Float64[]
			N_AGENTS[i] = Int[]
			MAX_N_AGENTS[i] = Int[]
			N_PEOPLE[i] = Int[]
			ZONE_TYPE[i] = ["none"]
			Xs[i] = Float64[]
			Ys[i] = Float64[]
			GUIDs[i] = String[string("none_o")]
			STRCT_TYPS[i] = String[]
			YEAR_BUILTs[i] = Int[]
			NO_STORIESs[i] = Int[]

			LS_0s[i] = Float64[]
			LS_1s[i] = Float64[]
			LS_2s[i] = Float64[]
			AVG_DSs[i] = Float64[]
			MC_DSs[i] = Int64[]

			D_COASTs[i] = Float64[]
			D_COMMASSTs[i] = Float64[]
			D_CBDs[i] = Float64[]
		end

	end

	PS = ParcelSpace(
					s=s, 
					owner=OWNER,

					landuse=LANDUSE, 
					prev_landuse=PREV_LANDUSE,
					landvalue=LANDVALUE,
					n_agents=N_AGENTS,
					max_n_agents=MAX_N_AGENTS,
					n_people=N_PEOPLE,

					zone_type=ZONE_TYPE,
					x=Xs, 
					y=Ys, 
					guid=GUIDs, 
					strct_typ=STRCT_TYPS,
					year_built=YEAR_BUILTs,
					no_stories=NO_STORIESs,

					LS_0=LS_0s,
					LS_1=LS_1s,
					LS_2=LS_2s,
					AVG_DS=AVG_DSs,
					MC_DS=MC_DSs, 

					d_coast=D_COASTs, 
					d_commasst=D_COMMASSTs,
					d_cbd=D_CBDs,
				)
	return PS
end


function GetNeighbors(p)
	nothing
end


pos2cell(pos::String, vector::Vector{String}) = findfirst(isequal(pos), vector)
pos2cell(pos::String, model::ABM) = pos2cell(pos, vcat(model.space.guid...))
pos2cell(a::AbstractAgent, model::ABM) = pos2cell(a.pos, model)

get_pos(agent) = agent.pos
get_pos_idx(agent) = agent.pos_idx


# function myfindfirst(testf::Function, A)
# 	for (i,a) in pairs(A)
# 		testf(a) && return i
# 	end
# end

notimplemented(model) = error("Not implemented for space type $(nameof(typeof(model.space)))")


#######################################################################################
# %% IMPLEMENT
#######################################################################################
"""
	move_agent!(agent [, pos], model::ABM) → agent
Move agent to the given position, or to a random one if a position is not given.
`pos` must have the appropriate position type depending on the space type.
The agent's position is updated to match `pos` after the move.
"""
function move_agent!(agent::AbstractAgent, pos, model)
	remove_agent_from_space!(agent, model)
	agent.pos = pos
	agent.pos_idx = pos2cell(pos, model)
	add_agent_pos!(agent, model)

	if pos == "none"
		agent.utility_cst = 0
		agent.utility_cms = 0	
		agent.utility_cbd = 0
		agent.utility =  0
	else
		u_vec  = utility_calc_component_idx(model, agent, agent.pos_idx)
		agent.utility_cst = u_vec[1]
		agent.utility_cms = u_vec[2]
		agent.utility_cbd = u_vec[3]
		agent.utility =  u_vec[1]*u_vec[2]*u_vec[3]
	end
end


function move_agent!(agent::VisitorAgent, pos, model)
	remove_agent_from_space!(agent, model)
	agent.pos = pos
	agent.pos_idx = pos2cell(pos, model)
	add_agent_pos!(agent, model)

	if pos == "none_v"
		agent.utility_cst = 0
		agent.utility_cbd = 0
		agent.utility =  0
	else
		u_vec  = utility_calc_component_idx(model, agent, agent.pos_idx)
		agent.utility_cst = u_vec[1]
		agent.utility_cbd = u_vec[2]
		agent.utility =  u_vec[1]*u_vec[2]
	end
end
"""
	_loop_agent_ids!(model, model_field, agent_ids, attrs)
Loops through agent_ids on the model_field. appends values to 'attrs'
'attrs' must be pre-allocated
"""
function _loop_agent_ids!(model, model_field, agent_ids, attrs)
	for i in eachindex(agent_ids)
		attrs[i] = model_field[model[agent_ids[i][1]].pos_idx][1]
	end
end


"""
	_loop_agent_idx!(model, model_field, agent_ids, attrs)
Loops through agent_idx on the model_field. appends values to 'attrs'
'attrs' must be pre-allocated
"""
function _loop_agent_idx!(model, model_field, agent_idx, attrs)
	guid_vec = vcat(model.space.guid...)
	for i in eachindex(agent_idx)
		attrs[i] = model_field[agent_idx[i]][1]
	end
end

"""
	_loop_parcels!(model, model_field, agent_ids, attrs)
Loops through parcels in the model. appends values to 'attrs'
'attrs' must be pre-allocated
"""
function _loop_parcels!(model, model_field::Vector{Vector{T}}, attrs::Vector{T}) where T
	# todo: confirm that pos2cell isn't actually necessary here
	guid_vec = vcat(model.space.guid...)
	for i = 1:model.n_prcls
		# attrs[i] = model_field[pos2cell(model.space.guid[i][1], guid_vec)][1]
		# println(pos2cell(model.space.guid[i][1], guid_vec))
		attrs[i] = model_field[i][1]
	end
end

"""
	get_agents_pos_idx(agents, model)
returns the index associated with "agents"
"""
function get_agents_pos_idx(agents, model)
	agnt_idx = Vector{Int}(undef, length(agents))
	for i in eachindex(agents)
		agnt_idx[i] = get_pos_idx(model[agents[i]])
	end
	return agnt_idx
end

""" 
	GetAgentIdsNotInParcel(model)
Gets the IDs of agents who are not associated with a parcel 
First checks non-parcel spaces
Second checks if non-parcel space has an agent
"""
function GetAgentIdsNotInParcel(model::ABM{<:ParcelSpace, A}) where {A<:AbstractAgent}
	IDs_f = model.space.s[pos2cell("none", model)]
	IDs_v = model.space.s[pos2cell("none_v", model)]
	IDs = vcat(IDs_f, IDs_v)
	return IDs
end

function GetAgentIdsNotInParcel(model::ABM{<:ParcelSpace, A}, agent_type) where {A<:AbstractAgent}
	# IDs = model.space.s[pos2cell("none", model)]
	IDs_f = model.space.s[pos2cell("none", model)]
	IDs_v = model.space.s[pos2cell("none_v", model)]
	IDs = vcat(IDs_f, IDs_v)

	IDs_type = Int64[]
	for ID in IDs
		if typeof(model[ID])==agent_type
			push!(IDs_type, ID)
		end
	end
	return IDs_type
end

count_agnt_types(model, agent_type) = count(i->(typeof(i.second)==agent_type), model.agents)

"""
	GetParcelAttributes(model::ABM, model_field::AbstractArray, prcl::String)
Function to return selected attribute (model_field) associated with a parcel
"""
function GetParcelAttribute(model::ABM, model_field::AbstractArray, prcl::String)
	prcl_attr = model_field[pos2cell(prcl, model)]
end

function GetParcelAttribute(model::ABM, model_field::AbstractArray, idx::Int64)
	prcl_attr = model_field[idx]
end


"""
	GetParcelsAttribute(model, model_field, prcl)
Returns array of attributes asssociated with parcels in either agent_ids or prcls
"""
function GetParcelsAttribute(model::ABM, model_field::Vector{Vector{T}}, agent_ids::Vector{Int}) where {T<:Real}
	attrs = Vector{T}(undef, length(agent_ids))		# pre-allocating space for attributes
	_loop_agent_ids!(model, model_field, agent_ids, attrs)
	return attrs
end

function GetParcelsAttribute(model::ABM, model_field::Vector{Vector{String}}, agent_ids::Vector{Int})
	attrs = Vector{String}(undef, length(agent_ids))
	_loop_agent_ids!(model, model_field, agent_ids, attrs)
	return attrs
end

function GetParcelsAttribute(model::ABM, model_field::Vector{Vector{T}}) where {T<:Real}
	attrs = Vector{T}(undef, model.n_prcls)
	_loop_parcels!(model, model_field, attrs)
	return attrs
end

function GetParcelsAttribute(model::ABM, model_field::Vector{Vector{String}})
	attrs = Vector{String}(undef, model.n_prcls)
	_loop_parcels!(model, model_field, attrs)
	return attrs
end


function GetParcelsAttribute_idx(model::ABM, model_field::Vector{Vector{T}}, agent_idx::Vector{Int}) where {T<:Real}
	attrs = Vector{T}(undef, length(agent_idx))		# pre-allocating space for attributes
	_loop_agent_idx!(model, model_field, agent_idx, attrs)
	return attrs
end

function GetParcelsAttribute_idx(model::ABM, model_field::Vector{Vector{String}}, agent_idx::Vector{Int})
	attrs = Vector{String}(undef, length(agent_idx))
	_loop_agent_idx!(model, model_field, agent_idx, attrs)
	return attrs
end

"""
	remove_agent_from_space!(agent, model)
Remove the agent from the underlying space structure.
This function is called after the agent is already removed from the model dictionary
"""
function remove_agent_from_space!(a::A, model::ABM{<:ParcelSpace,A}) where {A<:AbstractAgent}
	deleteat!(model.space.s[a.pos_idx], model.space.s[a.pos_idx] .== a.id)
	deleteat!(model.space.owner[a.pos_idx], model.space.owner[a.pos_idx] .== a.id)
end



"""
	simulate_parcel_transaction!(agent1::LandlordAgent, agent2::IndividualAgent, model)
if agent1 is a LandlordAgent and agent2 is an IndividualAgent, 
then this function adds agent2 to the parcel that agent1 owns.
e.g., agent2 is renting from agent1.
"""
function simulate_parcel_transaction!(agent1::LandlordAgent, agent2::IndividualAgent, model::ABM)
	a1_pos = agent1.pos
	a1_pos_idx = agent1.pos_idx

	remove_agent_from_space!(agent2, model)

	agent2.pos = a1_pos
	agent2.pos_idx = a1_pos_idx

	add_agent_pos_renter!(agent2, model)
end

"""
	simulate_parcel_transaction!(agent1::CompanyAgent, agent2::IndividualAgent, model)
if agent1 is a CompanyAgent and agent2 is an IndividualAgent, 
then this function adds agent2 to the parcel that agent1 owns.
e.g., agent2 is renting from agent1.
"""
function simulate_parcel_transaction!(agent1::CompanyAgent, agent2::IndividualAgent, model::ABM)
	a1_pos = agent1.pos
	a1_pos_idx = agent1.pos_idx

	remove_agent_from_space!(agent2, model)
	
	agent2.pos = a1_pos
	agent2.pos_idx = a1_pos_idx

	add_agent_pos_renter!(agent2, model)
end

"""
	simulate_parcel_transaction!(agent1::UnoccupiedOwnerAgent, agent2::CompanyAgent, model)
If a company takes over and converts to hosr, add visitors to parcel and udpate model counts
This will ensure that not too many company agents enter market at one step
"""
function simulate_parcel_transaction!(agent1::UnoccupiedOwnerAgent, agent2::AbstractAgent, LU::String, model::ABM)
	a1_pos = agent1.pos 	# parcel that is being traded
	a1_pos_idx = agent1.pos_idx
	
	remove_agent_from_space!(agent2, model)	# removing agent2 from it's current position in the model
	
	agent2.pos = a1_pos		# udpating agent2's position
	agent2.pos_idx = a1_pos_idx

	kill_agent!(agent1, model)		# removes agent1 (seller) from model
	add_agent_pos_owner!(agent2, model, LU)	# adds agent2 (buyer) to model
end

"""
	simulate_parcel_transaction!(agent1::UnoccupiedOwnerAgent, agent2::CompanyAgent, model)
If a company takes over and converts to hosr, add visitors to parcel and udpate model counts
This will ensure that not too many company agents enter market at one step
"""
function simulate_parcel_transaction!(agent1::UnoccupiedOwnerAgent, agent2::CompanyAgent, LU::String, model::ABM)
	a1_pos = agent1.pos 	# parcel that is being traded
	a1_pos_idx = agent1.pos_idx
	
	remove_agent_from_space!(agent2, model)	# removing agent2 from it's current position in the model
	
	agent2.pos = a1_pos		# udpating agent2's position
	agent2.pos_idx = a1_pos_idx

	kill_agent!(agent1, model)		# removes agent1 (seller) from model
	add_agent_pos_owner!(agent2, model, LU)	# adds agent2 (buyer) to model
	
	if LU == "hosr" 	# if transitioning to hosr, simulate visitor market search
		VisitorMarketSearch!(model, [agent2.id], shuff=true)
	# elseif LU == "hor"	# if transitioning to hor, simulate full time resident market search
	# 	bidders = GetBidders!(model, shuff=true)	
	# 	SBTs, WTPs, LUs = MarketSearch(model, bidders, [agent2.id])
	# 	ParcelTransaction!(model, bidders, SBTs, WTPs, LUs, [agent2.id])
	end
end




#######################################################################################
# %% IMPLEMENT: Neighbors and stuff
#######################################################################################
"""
	nearby_ids(position, model::ABM, r; kwargs...) → ids
Return an iterable of the ids of the agents within "radius" `r` of the given `position`
(which must match type with the spatial structure of the `model`).
What the "radius" means depends on the space type:
- `GraphSpace`: the degree of neighbors in the graph (thus `r` is always an integer),
  always including ids of the same node as `position`.
  For example, for `r=2` include first and second degree neighbors.
  If `r=0`, only ids in the same node as `position` are returned.
- `GridSpace`: Either Chebyshev (also called Moore) or Euclidean distance,
  in the space of cartesian indices.
- `GridSpace` can also take a tuple argument, e.g. `r = (5, 2)` for a 2D space, which
  extends 5 positions in the x direction and 2 in the y. Only possible with Chebyshev
  spaces.
- `ContinuousSpace`: Standard distance according to the space metric.
- `OpenStreetMapSpace`: `r` is equivalent with distance (in meters) needed to be travelled
  according to existing roads in order to reach given `position`.
## Keywords
Keyword arguments are space-specific.
For `GraphSpace` the keyword `neighbor_type=:default` can be used to select differing
neighbors depending on the underlying graph directionality type.
- `:default` returns neighbors of a vertex (position). If graph is directed, this is equivalent
  to `:out`. For undirected graphs, all options are equivalent to `:out`.
- `:all` returns both `:in` and `:out` neighbors.
- `:in` returns incoming vertex neighbors.
- `:out` returns outgoing vertex neighbors.
For `ContinuousSpace`, the keyword `exact=false` controls whether the found neighbors are
exactly accurate or approximate (with approximate always being a strict over-estimation),
see [`ContinuousSpace`](@ref).
"""
nearby_ids(position, model, r = 1) = notimplemented(model)

"""
	nearby_positions(position, model::ABM, r=1; kwargs...) → positions
Return an iterable of all positions within "radius" `r` of the given `position`
(which excludes given `position`).
The `position` must match type with the spatial structure of the `model`.
The value of `r` and possible keywords operate identically to [`nearby_ids`](@ref).
This function only makes sense for discrete spaces with a finite amount of positions.
	nearby_positions(position, model::ABM{<:OpenStreetMapSpace}; kwargs...) → positions
For [`OpenStreetMapSpace`](@ref) this means "nearby intersections" and operates directly
on the underlying graph of the OSM, providing the intersection nodes nearest to the
given position.
"""
nearby_positions(position, model, r = 1) = notimplemented(model)



#######################################################################################
# %% Space agnostic killing and moving
#######################################################################################
"""
	kill_agent!(agent::AbstractAgent, model::ABM)
	kill_agent!(id::Int, model::ABM)
Remove an agent from the model.
"""
function kill_agent!(a::A, model::ABM) where {A<:AbstractAgent}
	delete!(model.agents, a.id)
	remove_agent_from_space!(a, model)
end

kill_agent!(id::Integer, model::ABM) = kill_agent!(model[id], model)

"""
	genocide!(model::ABM)
Kill all the agents of the model.
"""
function genocide!(model::ABM)
	for a in allagents(model)
		kill_agent!(a, model)
	end
	model.maxid[] = 0
end

"""
	genocide(model::ABM, agent_type)
Kills all agents of type agent_type
"""
function genocide!(model::ABM, agent_type)
	for a in allagents(model)
		if typeof(a) == agent_type
			kill_agent!(a, model)
		end
	end
	for i = 1:model.n_prcls
		model.space.n_agents[i] = [length(model.space.s[i])]
	end
	# model.maxid[] = 0
end


#######################################################################################
# %% Space adding
#######################################################################################
"""
	add_agent_pos!(agent::AbstractAgent, model::ABM) → agent
Add the agent to the `model` at the agent's own position.
"""
function add_agent_pos!(agent::AbstractAgent, model::ABM)
	model[agent.id] = agent
	_add_agent_to_space!(agent, model)
	return agent
end

"""
	_add_agent_to_space!(agent, model)
Add the agent to the underlying space structure at the agent's own position.
"""
function _add_agent_to_space!(a::AbstractAgent, model::ABM)
	push!(model.space.s[a.pos_idx], a.id)
end


"""
	add_agent_pos!(agent::AbstractAgent, model::ABM) → agent
Add the agent to the `model` at the agent's own position.
if 'init' is true/present, then the agent is simply added
if 'init' not present, then the landuse is updated (e.g., it's not the first time 'add_agent_pos' is called)
if it's a landlord agent, check whethe landuse is initially 'rental_res' or 'losr'
	if 'rental_res', then add an individual agent to the same space
"""
function add_agent_pos_owner!(agent::AbstractAgent, model::ABM; init::Bool)
	model[agent.id] = agent
	agent.own_parcel = true
	_add_agent_to_space_owner!(agent, model)
	return agent
end

function add_agent_pos_owner!(agent::LandlordAgent, model::ABM; init::Bool, n_people::Int64)
	model[agent.id] = agent 		# adding agent to model
	agent.own_parcel = true			# does the landlord agent own the parcel
	_add_agent_to_space_owner!(agent, model) 	# adding landlord agent to model space

	# is the property initiated as rentl_res or losr?
	lu_init = model.space.landuse[agent.pos_idx][1]

	#=
	+ if rentl_res, then assume another agent is renting 
	+ if losr, then assume a visitor agent is staying there
	+ e.g., model starts in equlibrium)
	=#
	if lu_init == "rentl_res"
		max_n_agents = GetParcelAttribute(model, model.space.max_n_agents, agent.pos)
		for i = 1:max_n_agents[1]-1
			id = next_avail_id(model)
			pos = agent.pos
			alphas = alpha_calc(model, model.Household_alphas)
			a2 = IndividualAgent(
				id=id,
				pos=pos,
				pos_idx=pos2cell(pos, model),
				alpha1=alphas[1],
				alpha2=alphas[2],
				alpha3=alphas[3],
				alpha4=alphas[4],
				budget=budget_calc(model, model.Individual_budget),
				price_goods=model.Individual_price_goods,
				number_prcls_aware=model.Individual_number_parcels_aware,
				prcl_on_mrkt=false,
				prcl_on_visitor_mrkt=false,
				looking_to_purchase=false,
				WTA=0.0,
				age=age_calc(model.age_dist, model),
				own_parcel=false,
				num_people=n_people,
				household_change_times=get_household_change_times(model.Individual_household_change_dist, model)

			)
			add_agent_pos_renter!(a2, model)
		end
	elseif lu_init == "losr"
		max_n_agents = GetParcelAttribute(model, model.space.max_n_agents, agent.pos)
		for i = 1:max_n_agents[1]-1
			id = next_avail_id(model)
			pos = agent.pos
			alphas = alpha_calc(model, model.Visitor_alphas)
			a2 = VisitorAgent(
				id=id,
				pos=pos,
				pos_idx=pos2cell(pos, model),
				num_people=npeople_calc(model.nvisitor_dist, model),
				number_prcls_aware=model.Visitor_number_parcels_aware,
				alpha1=alphas[1],
				alpha2=alphas[2],
				alpha3=alphas[3],
				alpha4=alphas[4],

			)
			add_agent_pos_visitor!(a2, model)
		end
	end
	return agent
end

function add_agent_pos_owner!(agent::CompanyAgent, model::ABM; init::Bool, n_people::Int64)
	model[agent.id] = agent 		# adding agent to model
	agent.own_parcel = true			# does the landlord agent own the parcel
	_add_agent_to_space_owner!(agent, model) 	# adding landlord agent to model space

	# is the property initiated as rentl_res or losr?
	lu_init = model.space.landuse[agent.pos_idx][1]

	#=
	+ if hor, then assume other agents are renting 
	+ if hosr, then assume visitor agents are staying there
	+ e.g., model starts in equlibrium)
	=#
	if lu_init == "hor"
		max_n_agents = GetParcelAttribute(model, model.space.max_n_agents, agent.pos)
		n_people_added = 0

		# for i = 1:max_n_agents[1] - 1
		cnt = 1
		while n_people_added < n_people
			n_people_prcl = npeople_calc(model.nhousehold_dist, model)
			cnt == max_n_agents[1]-1 && (n_people_prcl = n_people - n_people_added)

			id = next_avail_id(model)
			pos = agent.pos
			alphas = alpha_calc(model, model.Household_alphas)
			a2 = IndividualAgent(
				id=id,
				pos=pos,
				pos_idx=pos2cell(pos, model),
				alpha1=alphas[1],
				alpha2=alphas[2],
				alpha3=alphas[3],
				alpha4=alphas[4],
				budget=budget_calc(model, model.Individual_budget),
				price_goods=model.Individual_price_goods,
				number_prcls_aware=model.Individual_number_parcels_aware,
				prcl_on_mrkt=false,
				prcl_on_visitor_mrkt=false,
				looking_to_purchase=false,
				WTA=0.0,
				age=age_calc(model.age_dist, model),
				own_parcel=false,
				num_people=n_people_prcl,
				household_change_times=get_household_change_times(model.Individual_household_change_dist, model)
			)
			add_agent_pos_renter!(a2, model)
			n_people_added += n_people_prcl
			cnt += 1
		end
	elseif lu_init == "hosr"
		max_n_agents = GetParcelAttribute(model, model.space.max_n_agents, agent.pos)
		for i = 1:max_n_agents[1]-1
			id = next_avail_id(model)
			pos = agent.pos
			alphas = alpha_calc(model, model.Visitor_alphas)
			a2 = VisitorAgent(
				id=id,
				pos=pos,
				pos_idx=pos2cell(pos, model),
				num_people=npeople_calc(model.nvisitor_dist, model),
				number_prcls_aware=model.Visitor_number_parcels_aware,
				alpha1=alphas[1],
				alpha2=alphas[2],
				alpha3=alphas[3],
				alpha4=alphas[4],
				)
			add_agent_pos_visitor!(a2, model)
		end
	end
	return agent
end

function add_agent_pos_owner!(agent::AbstractAgent, model::ABM, lu::String)
	model[agent.id] = agent
	agent.own_parcel = true
	_add_agent_to_space_owner!(agent, model)
	agent_update_landuse_step!(agent, model, lu)
	return agent
end

# function add_agent_pos_owner!(agent::LandlordAgent, lu::String, model::ABM)
# 	model[agent.id] = agent
# 	agent.own_parcel = true
# 	_add_agent_to_space_owner!(agent, model)
# 	agent_update_landuse_step!(agent, model, lu)
# 	return agent
# end


function add_agent_pos_owner!(agent::CompanyAgent, lu::String, model::ABM)
	model[agent.id] = agent
	agent.own_parcel = true
	_add_agent_to_space_owner!(agent, model)
	agent_update_landuse_step!(agent, model, lu)
	return agent
end


function add_agent_pos_renter!(agent::IndividualAgent, model::ABM)
	model[agent.id] = agent
	agent.own_parcel = false
	_add_agent_to_space_renter!(agent, model)
	return agent
end

function add_agent_pos_visitor!(agent::VisitorAgent, model::ABM)
	model[agent.id] = agent
	# agent.own_parcel = false
	_add_agent_to_space_visitor!(agent, model)
	return agent
end


"""
	_add_agent_to_space_owner!(agent, model)
Add the agent to the underlying space structure at the agent's own position.
"""
function _add_agent_to_space_owner!(a::A, model::ABM{<:ParcelSpace,A}) where {A<:AbstractAgent}
	model.space.s[a.pos_idx] = [a.id]
	model.space.owner[a.pos_idx] = [a.id]
end


function _add_agent_to_space_renter!(a::IndividualAgent, model::ABM)
	push!(model.space.s[a.pos_idx], a.id)
end

function _add_agent_to_space_visitor!(a::VisitorAgent, model::ABM)
	push!(model.space.s[a.pos_idx], a.id)
end

"""
	next_avail_id(model)
returns the next available id in the model space
"""
function next_avail_id(model::ABM{<:ParcelSpace})
	id = maximum(allids(model)) + 1
	return convert(Int, id)
end

"""
	next_avail_visitor_pos(model)
returns the next available visitor position in the model
if there is space for the visitor, the position is randomly assigned.
if there is no space, "none" is returned
"""
function next_avail_visitor_pos(model::ABM{<:ParcelSpace})
	idxs = collect(1:model.n_prcls)
	ss = GetParcelsAttribute_idx(model, model.space.s, idxs)
	max_ns = GetParcelsAttribute_idx(model, model.space.max_n_agents, idxs)

	idxs = shuffle(model.rng, idxs)

	for idx in idxs
		landuse = model.space.landuse[idx][1]
		if landuse in ["losr", "hosr"]
			# n_occ = length(ss[idx])
			# max_n = max_ns[idx]
			if length(ss[idx]) < max_ns[idx]
				pos = model.space.guid[idx][1]
				return pos
			end
		end
	end
	return "none"
end


"""
	agent_update_landuse_step!(agent, model)
Updates parcel land use for agents who successfully completed transaction
the function 'update_landuse!' is in MyParcelSpace.jl
"""
function agent_update_landuse_step!(agent::AbstractAgent, model::ABM, lu::String)
	update_landuse!(agent, model, [lu])
end

"""
	update_landuse!(agent, mdoel, landuse)
updates the landuse associated with the parcel
"""
function update_landuse!(agent::AbstractAgent, model::ABM, landuse::Vector{String})
	model.space.prev_landuse[agent.pos_idx] = model.space.landuse[agent.pos_idx]
	model.space.landuse[agent.pos_idx] = landuse
	if landuse == ["unoccupied"]
		model.space.max_n_agents[agent.pos_idx] = [1]
	elseif landuse == ["owned_res"]
		model.space.max_n_agents[agent.pos_idx] = [1]
	elseif landuse==["rentl_res"]
		model.space.max_n_agents[agent.pos_idx] = [2]
	elseif landuse==["losr"]
		model.space.max_n_agents[agent.pos_idx] = [2]
	elseif landuse==["hor"]
		model.space.max_n_agents[agent.pos_idx] = [5]	# todo: figure out how big this should be
		model.space.strct_typ[agent.pos_idx] = ["RC"]
		model.space.year_built[agent.pos_idx] = [2021]
		model.space.no_stories[agent.pos_idx] = [6]
	elseif landuse==["hosr"]
		model.space.max_n_agents[agent.pos_idx] = [15]	# todo: figure out how big this should be
		model.space.strct_typ[agent.pos_idx] = ["RC"]
		model.space.year_built[agent.pos_idx] = [2021]
		model.space.no_stories[agent.pos_idx] = [6]
	end
end




""" UpdateParcelAttr!()
"""
function UpdateParcelAttr!(model::ABM, col::Vector, fn)
	i = 1
	for guid in model.space.guid
		guid[1] == "none" && continue
		guid[1] == "none_v" && continue
		guid[1] == "none_o" && continue
		cell_idx = pos2cell(guid[1], model)
		getfield(model.space, fn)[cell_idx] = [col[i]]
		i += 1
	end
end




""

""
function Average_DS!(model::ABM)
	LS_0 = getfield(model.space, :LS_0)
	LS_1 = getfield(model.space, :LS_1)
	LS_2 = getfield(model.space, :LS_2)

	for guid in model.space.guid
		guid[1] == "none" && continue
		guid[1] == "none_v" && continue
		guid[1] == "none_o" && continue
		cell_idx = pos2cell(guid[1], model)
		ls_0_ = LS_0[cell_idx][1]
		ls_1_ = LS_1[cell_idx][1]
		ls_2_ = LS_2[cell_idx][1]
		model.space.AVG_DS[cell_idx] = [avg_dmg!(ls_0_, ls_1_, ls_2_)]
	end
end

function avg_dmg!(ls_0, ls_1, ls_2)
	ds_0 = 1-ls_0
	ds_1 = ls_0-ls_1
	ds_2 = ls_1-ls_2
	ds_3 = ls_2
	dmg = 0*ds_0 + 1*ds_1 + 2*ds_2 + 3*ds_3
	return dmg
end

""" 
	MC_Sample_DS!()
Single monte-carlo sample of damage state. 
Applies this to all parcels in the model
"""
function MC_Sample_DS!(model::ABM)
	i = 1

	LS_0 = getfield(model.space, :LS_0)
	LS_1 = getfield(model.space, :LS_1)
	LS_2 = getfield(model.space, :LS_2)

	for guid in model.space.guid
		guid[1] == "none" && continue
		guid[1] == "none_v" && continue
		guid[1] == "none_o" && continue
		cell_idx = pos2cell(guid[1], model)
		ls_0_ = LS_0[cell_idx][1]
		ls_1_ = LS_1[cell_idx][1]
		ls_2_ = LS_2[cell_idx][1]
		getfield(model.space, :MC_DS)[cell_idx] = [mc_sample(ls_0_, ls_1_, ls_2_, model)]
		i += 1
	end
end


"""
	mc_sample(LS_0, LS_1, LS_2)
Monte-Carlo sample function using limit states of LS_0, LS_1, and LS_2
"""
function mc_sample(LS_0, LS_1, LS_2, model)::Int64
	#= Monte-Carlo sample of damage state
		given limit states LS_0, LS_1, LS_2
		returns a discrete value associated with the Monte-Carlo damage state
	=#
	rv = rand(model.rng)
	DS = 0
	LS = [LS_0, LS_1, LS_2]
	for ls in LS
		if rv > ls
			break
		end
		DS += 1
	end
	return DS

end





