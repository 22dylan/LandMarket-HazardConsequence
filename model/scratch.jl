# struct ParcelSpace
# 	s::Array{Vector{Int},1}					# agent id(s) in parcel
# 	owner::Array{Vector{Int},1}				# agent id that owns parcel
# 	guid::Array{Vector{String},1}
# end


# mutable struct Agent
# 	id::Int
# 	pos::String
# end


# pos2cell(pos::String, space) = findfirst(x->x==[pos], space.guid)


# function remove_agent!(agent, space)
# 	idx = pos2cell(agent.pos, space)
# 	# pop!(space.s[idx], agent.id)
# 	deleteat!(space.s[idx], space.s[idx] .== agent.id)
# end


# function add_agent_to_space!(agent, space)
# 	idx = pos2cell(agent.pos, space)
# 	push!(space.s[idx], agent.id)
# end


# s = [[], [], []]
# owner = [[1], [2], [3]]
# guid = [["a"], ["b"], ["c"], ["none"]]

# agent1 = Agent(1, "a")
# agent2 = Agent(2, "b")
# agent3 = Agent(3, "c")

# PS = ParcelSpace(s, owner, guid)
# add_agent_to_space!(agent1, PS)
# add_agent_to_space!(agent2, PS)
# add_agent_to_space!(agent3, PS)

# println()
# println(PS.s)
# println(PS.owner)
# println(PS.guid)
# println()

# remove_agent!(agent1, PS)
# println()
# println(PS.s)
# println(PS.owner)
# println(PS.guid)
# println()

# agent1.pos = "b"
# add_agent_to_space!(agent1, PS)

# println()
# println(PS.s)
# println(PS.owner)
# println(PS.guid)
# println()


# remove_agent!(agent1, PS)
# println()
# println(PS.s)
# println(PS.owner)
# println(PS.guid)
# println()

# agent1.pos = "c"
# add_agent_to_space!(agent1, PS)
# println()
# println(PS.s)
# println(PS.owner)
# println(PS.guid)
# println()

a = [[1], [2], [3,4]]
push!(a[3],10)
println(a)
deleteat!(a[3], a[3].==4)

println(a)