#=
This file establishes the agent-space interaction API.
All space types should implement this API (and obviously be subtypes of `AbstractSpace`)
Some functions DO NOT need to be implemented for every space, they are space agnostic.
These functions have complete source code here, while the functions that DO need to
be implemented for every space have only documentation strings here and an
error message.
In short: IMPLEMENT ALL FUNCTIONS IN SECTION "IMPLEMENT", WITH SAME ARGUMENTS!
In addition to the required functions, a minimal `AbstractAgent` struct with REQUIRED
fields should be supplied. See the top of src/core/agents.jl for examples.
TODO: do_checks needs to be updated for each new space type
=#

using Agents
using DataFrames

export ParcelSpace






struct ParcelSpace <: Agents.AbstractSpace
	s::Array{Vector{Int},1}							# agent id associated with the parcel
	
	landuse::Array{Vector{String},1}		# land use
	zone_type::Array{Vector{String},1}	# zone type
	x::Array{Vector{Float64},1}					# x-location of s
	y::Array{Vector{Float64},1}					# y-location of s
	guid::Array{Vector{String},1}				# guid of parcel
	strct_typ::Array{Vector{String},1} 	# structure type
	year_built::Array{Vector{Int},1}		# year built
	no_stories::Array{Vector{Int},1}		# number of stories

	LS_0::Array{Vector{Float64},1}					# monte-carlo damage state
	LS_1::Array{Vector{Float64},1}					# monte-carlo damage state
	LS_2::Array{Vector{Float64},1}					# monte-carlo damage state
	MC_DS::Array{Vector{Int},1}					# monte-carlo damage state
	
	d_coast::Array{Vector{Float64},1}		# distance to coast
	d_road::Array{Vector{Float64},1}		# distance to road
	d_grnspc::Array{Vector{Float64},1}	# distance to green space
	nghbrs::Array{Vector{String},1}			# neightbors of parcel
end


function ParcelSpace(df::DataFrames.DataFrame, d::Int)	
	s = Array{Vector{Int},1}(undef, d)

	LANDUSE = Array{Vector{String},1}(undef, d)
	ZONE_TYPE = Array{Vector{String},1}(undef, d)
	Xs = Array{Vector{Float64},1}(undef, d)
	Ys = Array{Vector{Float64},1}(undef, d)
	GUIDs = Array{Vector{String},1}(undef, d)
	STRCT_TYPS = Array{Vector{String},1}(undef, d)
	YEAR_BUILTs = Array{Vector{Int},1}(undef, d)
	NO_STORIESs = Array{Vector{Int},1}(undef, d)

	LS_0s = Array{Vector{Float64},1}(undef, d)
	LS_1s = Array{Vector{Float64},1}(undef, d)
	LS_2s = Array{Vector{Float64},1}(undef, d)
	MC_DSs = Array{Vector{Int},1}(undef, d)
	

	D_COASTs = Array{Vector{Float64},1}(undef, d)
	D_ROADs = Array{Vector{Float64},1}(undef, d)
	D_GRNSPCs = Array{Vector{Float64},1}(undef, d)
	NGHBRSs = Array{Vector{String},1}(undef, d)

	for i in eachindex(s)
		if i <= size(df)[1]
			p = df[i,:]
			s[i] = Int[]
			
			LANDUSE[i] = String[]
			ZONE_TYPE[i] = [p["zone_type"]]
			Xs[i] = [p["x"]]
			Ys[i] = [p["y"]]
			GUIDs[i] = [p["guid"]]
			STRCT_TYPS[i] = [p["struct_typ"]]
			YEAR_BUILTs[i] = [p["year_built"]]
			NO_STORIESs[i] = [p["no_stories"]]
			
			LS_0s[i] = [0]
			LS_1s[i] = [0]
			LS_2s[i] = [0]
			MC_DSs[i] = [0]

			D_COASTs[i] = [p["d_coast"]]
			D_ROADs[i] = [p["d_road1"]]
			D_GRNSPCs[i] = [p["d_grnspc"]]
			NGHBRSs[i] = String[]
		
		else
			s[i] = Int[]
			
			LANDUSE[i] = ["none"]
			ZONE_TYPE[i] = ["none"]
			Xs[i] = Float64[]
			Ys[i] = Float64[]
			GUIDs[i] = String[string("none_",i)]
			STRCT_TYPS[i] = String[]
			YEAR_BUILTs[i] = Int[]
			NO_STORIESs[i] = Int[]

			LS_0s[i] = Float64[]
			LS_1s[i] = Float64[]
			LS_2s[i] = Float64[]
			MC_DSs[i] = Int[]

			D_COASTs[i] = Float64[]
			D_ROADs[i] = Float64[]
			D_GRNSPCs[i] = Float64[]
			NGHBRSs[i] = String[]
		end

	end

	PS = ParcelSpace(
									s, 

									LANDUSE, 
									ZONE_TYPE,
									Xs, 
									Ys, 
									GUIDs, 
									STRCT_TYPS,
									YEAR_BUILTs,
									NO_STORIESs,

									LS_0s,
									LS_1s,
									LS_2s,
									MC_DSs, 

									D_COASTs, 
									D_ROADs, 
									D_GRNSPCs, 
									NGHBRSs, 
								)
	return PS
end


function GetNeighbors(p)
	#= TODO: add this function
	=#
	nothing
end

pos2cell(pos::String, model::ABM) = findfirst(x->x==[pos], model.space.guid)
pos2cell(a::AbstractAgent, model::ABM) = pos2cell(a.pos, model)

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
move_agent!(agent, pos, model) = notimplemented(model)


""" 
	GetAgentIdsInParcel(model)
Gets the agent id associated with each parcel. 
"""
function GetAgentIdsInParcel(model::ABM{<:ParcelSpace, A}) where {A<:AbstractAgent}
	IDs = Int[]
	for i = 1:length(model.space.s)
		if occursin("none", model.space.guid[i][1]) == false
			push!(IDs, model.space.s[i][1])
		end
	end
	return IDs
end


function GetAgentIdsInParcel(model::ABM, parcels::AbstractArray)
	IDs = Int[]
	for prcl in parcels
		push!(IDs, model.space.s[pos2cell(prcl, model)][1])
	end
	return IDs
end



""" 
	GetAgentIdsNotInParcel(model)
Gets the IDs of agents who are not associated with a parcel 
First checks non-parcel spaces
Second checks if non-parcel space has an agent
"""
function GetAgentIdsNotInParcel(model::ABM{<:ParcelSpace, A}) where {A<:AbstractAgent}
	IDs = Int[]
	for i = 1:length(model.space.s)
		if occursin("none", model.space.guid[i][1]) == true
			if model.space.s[i] != []
				push!(IDs, model.space.s[i][1])
			end
		end
	end
	return IDs
end


"""
	GetParcelAttributes(model::ABM, prcl::String)
Function to return selected attribute associated with a parcel
"""
function GetParcelAttribute(model::ABM, model_field::AbstractArray, prcl::String)
	prcl_attr = model_field[pos2cell(prcl, model)]
end


"""
	GetParcelsAttribute(model, model_field, prcl)
Returns array of attributes asssociated with parcels in 
"""
function GetParcelsAttribute(model::ABM, model_field::AbstractArray, agent_ids::Vector{Int})
	attrs = []
	for agent_id in agent_ids
		push!(attrs, model_field[pos2cell(model[agent_id[1]].pos, model)][1])
	end
	return attrs
end

function GetParcelsAttribute(model::ABM, model_field::AbstractArray, prcls::Vector{String})
	attrs = []
	for guid in prcls
		push!(attrs, model_field[pos2cell(guid, model)][1])
	end
	return attrs
end

"""
	GetAllParcelAttributes(model::ABM, prcl::String)
Function to return all attributes associated with a parcel
"""
function GetAllParcelAttributes(model::ABM, model_field::AbstractArray)
	attrs = []
	for guid in model.space.guid
		if occursin("none", guid[1]) == false
			push!(attrs, model_field[pos2cell(guid[1], model)][1])
		end
	end
	return attrs
end



"""
	remove_agent_from_space!(agent, model)
Remove the agent from the underlying space structure.
This function is called after the agent is already removed from the model dictionary
This function is NOT part of the public API.
"""
function remove_agent_from_space!(a::AbstractAgent, model::ABM)
	model.space.s[pos2cell(a, model)] = []
end


"""
	switch_agent_pos!(agent1, agent2, model)
switches the 2 agents positions.
e.g. simulate parcel transaction 
"""
function switch_agent_pos!(agent1::AbstractAgent, agent2::AbstractAgent, model::ABM)
	a1_pos = agent1.pos
	a2_pos = agent2.pos

	remove_agent_from_space!(agent1, model)
	remove_agent_from_space!(agent2, model)

	agent1.pos = a2_pos
	agent2.pos = a1_pos

	add_agent_to_space!(agent1, model)
	add_agent_to_space!(agent2, model)
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
function kill_agent!(a::AbstractAgent, model::ABM)
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
	genocide!(model::ABM, n::Int)
Kill the agents whose IDs are larger than n.
"""
function genocide!(model::ABM, n::Integer)
	for (k, v) in model.agents
		k > n && kill_agent!(v, model)
	end
	model.maxid[] = n
end

"""
	genocide!(model::ABM, IDs)
Kill the agents with the given IDs.
"""
function genocide!(model::ABM, ids)
	for id in ids
		kill_agent!(id, model)
	end
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
	add_agent_to_space!(agent, model)
	return agent
end

"""
	add_agent_to_space!(agent, model)
Add the agent to the underlying space structure at the agent's own position.
"""
function add_agent_to_space!(a::A, model::ABM{<:ParcelSpace,A}) where {A<:AbstractAgent}
	push!(model.space.s[pos2cell(a.pos, model)], a.id)
end

function add_agent_to_space!(a::AbstractAgent, model::ABM)
	push!(model.space.s[pos2cell(a.pos, model)], a.id)
end

"""
	next_avail_pos(model)
returns the next available position in the model space
Checks for empty spaces in 's' and returns this index
"""
function next_avail_pos(model::ABM{<:ParcelSpace})
	s = findfirst(x->x==[], model.space.s)
	return convert(Int, s)
end


function update_landuse!(agent::AbstractAgent, model::ABM, landuse::Vector{String})
	cell_idx = pos2cell(agent, model)
	model.space.landuse[pos2cell(agent, model)] = landuse
end


""" UpdateParcelAttr!()
"""
function UpdateParcelAttr!(model::ABM, col::Vector, fn)
	i = 1
	for guid in model.space.guid
		if occursin("none", guid[1]) == false
			cell_idx = pos2cell(guid[1], model)
			temp = getfield(model.space, fn)			
			getfield(model.space, fn)[cell_idx] = [col[i]]
			i += 1
		end
	end
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
		if occursin("none", guid[1]) == false
			cell_idx = pos2cell(guid[1], model)
			ls_0_ = LS_0[cell_idx][1]
			ls_1_ = LS_1[cell_idx][1]
			ls_2_ = LS_2[cell_idx][1]
			getfield(model.space, :MC_DS)[cell_idx] = [mc_sample(ls_0_, ls_1_, ls_2_, model)]
			i += 1
		end
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
