module MyAgents
#= --- module for MyAgents --- =#

using Agents
using Random
using Distributions
using StatsBase
include("MyParcelSpace.jl")


export UnoccupiedOwnerAgent,
	IndividualAgent

mutable struct UnoccupiedOwnerAgent <: AbstractAgent
	id::Int
	pos::String
	WTA::Float64
	prcl_on_mrkt::Bool
	looking_to_purchase::Bool
end

mutable struct IndividualAgent <: AbstractAgent
	id::Int
	pos::String
	alpha::Float64
	beta::Float64
	gamma::Float64
	budget::Float64
	WTA::Float64
	prcl_on_mrkt::Bool
	looking_to_purchase::Bool
	price_goods::Float64
end




"""
	agent_on_market_step!(agent, model)
put parcel on market steps
"""
function agent_on_market_step!(agent::UnoccupiedOwnerAgent, model)
	agent.prcl_on_mrkt = true
end

function agent_on_market_step!(agent::IndividualAgent, model)
	return agent
end




"""
	agent_looking_for_parcel_step!(agent, model)
checks if the agent is looking to purchase a parcel
"""
function agent_looking_for_parcel_step!(agent::UnoccupiedOwnerAgent, model)
	agent.looking_to_purchase = false
	return agent
end

function agent_looking_for_parcel_step!(agent::IndividualAgent, model)
	if occursin("none", agent.pos)
		agent.looking_to_purchase = true
	else
		agent.looking_to_purchase = false
	end
	return agent
end


"""
	agent_WTP_step!(agent, model)
Generates bid for agent based on utility of parcel
"""
function agent_WTP_step!(agent::UnoccupiedOwnerAgent, model, sellers)
	return agent
end

function agent_WTP_step!(agent::IndividualAgent, model, sellers)
	prcl_zones = GetParcelsAttribute(model, model.space.zone_type, sellers)
	
	# getting zone keys (e.g., C-R, R, R-SR, etc.) that individual agent can consider
	zone_keys = model.zoning_params[model.zoning_params[!,"owned_res"].==1, "Zone"]

	sellers_in_zone = []
	for (i, zone) in enumerate(prcl_zones)
		if zone in zone_keys
			push!(sellers_in_zone, sellers[i])
		end
	end

	if length(sellers_in_zone) > model.number_parcels_aware
		sellers_in_zone = sample(model.rng, sellers_in_zone, model.number_parcels_aware, replace=false)
	end
	u_max = 0
	seller_bid_to = "none"
	for seller in sellers_in_zone
		parcel = model[seller].pos
		d_coast = GetParcelAttribute(model, model.space.d_coast, parcel)[1]
		d_grnspc = GetParcelAttribute(model, model.space.d_grnspc, parcel)[1]
		p_coast = proximity_calc(d_coast, model)
		p_grnspc = proximity_calc(d_grnspc, model)
		p_market = ((model.n_prcls + 1 - length(sellers))/model.n_prcls)*100

		u_parcel = p_coast^agent.alpha * p_grnspc^agent.beta * p_market^agent.gamma
		if u_parcel > u_max
			u_max = u_parcel
			seller_bid_to = seller
		end
	end
	WTP = (agent.budget*u_max^2)/((agent.price_goods^2)+(u_max^2))
	return seller_bid_to, WTP
end


"""
	agent_evaluate_bid_step!(agent, model)
Generates bid for agent based on utility of parcel
"""
function agent_evaluate_bid_step!(agent::UnoccupiedOwnerAgent, model::ABM, bidders, SBTs, WTPs)
	bids_to_seller_tf = SBTs .==agent.id
	if sum(bids_to_seller_tf) == 0
		return false
	end
	bidders = bidders[bids_to_seller_tf]
	WTPs = WTPs[bids_to_seller_tf]

	max_idx = argmax(WTPs)
	WTP = WTPs[max_idx]
	bidder = bidders[max_idx]

	if WTP > agent.WTA
		switch_agent_pos!(agent, model[bidder], model)
		return bidder
	end
	return false
end

function agent_evaluate_bid_step!(agent::IndividualAgent, model::ABM)
	return agent
end




"""
	AgentsUpdateLandUse(model)
similar to agent_update_landuse_step!, this function loops through all agents
associated with a parcel and updates the land use of that parcel. 
"""
function AgentsUpdateLandUse!(model::ABM)
	for i = 1:length(model.space.s)
		if occursin("none", model.space.guid[i][1]) == false
			agent_id = model.space.s[i]
			agent_update_landuse_step!(model[agent_id[1]], model)
		end

	end
end


"""
	agent_update_landuse_step!(agent, model)
Updates parcel land use for agents who successfully completed transaction
the function 'update_landuse!' is in MyParcelSpace.jl
"""
function agent_update_landuse_step!(agent::UnoccupiedOwnerAgent, model::ABM)
	update_landuse!(agent, model, ["unoccupied"])
end

function agent_update_landuse_step!(agent::IndividualAgent, model::ABM)
	update_landuse!(agent, model, ["owned_res"])
end




"""
	proximity_calc(d_feat::Float64, model; add_one::Bool=false)
used to calculate proximity to a feature. 
uses a distance decay function given as "exp(-d*k)"
where 'd' is the distance to the feature and 'k' is used to parameterize the 
	shape of the curve. 
The value of 'k' is defined in the input file
"""
function proximity_calc(d_feat::Float64, model)
	proximity = exp(-d_feat*model.distance_decay_exponent)*100
	return proximity
end



# ------------
end

