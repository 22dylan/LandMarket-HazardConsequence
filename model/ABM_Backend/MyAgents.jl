#= 
file for functions related to agent actions
=#
count_agnt_types(model, agent_type) = count(i->(typeof(i.second)==agent_type), model.agents)
cnt_UnoccupiedOwner_agnts(model) = count_agnt_types(model, UnoccupiedOwnerAgent)
cnt_IndividualOwner_agnts(model) = count_agnt_types(model, IndividualAgent)
cnt_Landlord_agnts(model) = count_agnt_types(model, LandlordAgent)
cnt_Developer_agnts(model) = count_agnt_types(model, DeveloperAgent)
cnt_n_people_parcel(model) = sum(GetParcelsAttribute(model, model.space.n_people))

function cnt_n_people(model)
	ppl = 0
	for a in allagents(model)
		if typeof(a)==IndividualAgent
			ppl += a.num_people
		end
	end
	return ppl
end


"""
	agent_step!(agent, model)
general agent step. If 'IndividualAgent', the agent ages; if age is 80 or above,
agent dies/moves to nursing home and parcel becomes Unoccupied (UnoccupiedOwnerAgent)
"""
function agent_step!(agent::UnoccupiedOwnerAgent, model)
	return agent
end


function agent_step!(agent::IndividualAgent, model)
	agent.age+=1 		# aging agent
	if agent.age >= 80
		agent_dies!(agent, model)
		return
	end

	if occursin("none", agent.pos) == false		# if agent is in parcel, compute utility
		agent.utility = utility_calc(model, agent, agent.pos)
	end

	# todo: figure out what household_change_rate should be
	household_change_rate = 0.00
	if rand(model.rng) < household_change_rate
		agent.num_people += rand(Bool) ? 1 : -1  # randomly getting +/- 1
		if agent.num_people == 0
			agent_dies!(agent, model)
		end
	end
	return agent
end

function agent_step!(agent::LandlordAgent, model)
	agent.age+=1
	if agent.age >= 80
		agent_dies!(agent, model)
		return
	end

	# if agent is assigned to parcel; can potentially switch between losr and rentl_res
	if occursin("none", agent.pos) == false
		check_switch_landuse!(agent, model)
		agent.utility, _ = utility_calc(model, agent, agent.pos)

	end
	return agent
end

function agent_step!(agent::DeveloperAgent, model)
	return agent
end



"""
	agent_on_market_step!(agent, model)
put parcel on market steps
Unoccupied: always on market
individualAgent: Not on market; these get put on market if the agent dies (e.g., parcel becomes unoccupied)
LandlordAgent: 
	if rental_res: check whether number of occupying agents are less than max occupancy
	if losr: not on market 
"""
function agent_on_market_step!(agent::UnoccupiedOwnerAgent, model)
	agent.prcl_on_mrkt = true
end

function agent_on_market_step!(agent::IndividualAgent, model)
	agent.prcl_on_mrkt = false
	return agent
end


function agent_on_market_step!(agent::LandlordAgent, model)
	max_n_agents = GetParcelAttribute(model, model.space.max_n_agents, agent.pos)
	agents = GetParcelAttribute(model, model.space.s, agent.pos)
	landuse = GetParcelAttribute(model, model.space.landuse, agent.pos)

	if landuse[1] == "rentl_res"
		if length(agents) < max_n_agents[1]
			agent.prcl_on_mrkt = true
			return agent
		else
			agent.prcl_on_mrkt = false
			return agent
		end
	elseif landuse[1] == "losr"
		agent.prcl_on_mrkt = false
		return agent
	end
	return agent
end

function agent_on_market_step!(agent::DeveloperAgent, model)
	max_n_agents = GetParcelAttribute(model, model.space.max_n_agents, agent.pos)
	agents = GetParcelAttribute(model, model.space.s, agent.pos)
	landuse = GetParcelAttribute(model, model.space.landuse, agent.pos)

	if landuse[1] == "hor"
		if length(agents) < max_n_agents[1]
			agent.prcl_on_mrkt = true
			return agent
		else
			agent.prcl_on_mrkt = false
			return agent
		end
	elseif landuse[1] == "hosr"
		agent.prcl_on_mrkt = false
		return agent
	end
end



"""
	agent_looking_for_parcel_step!(agent, model)
checks if the agent is looking to purchase a parcel
currently a dummy step.
this function is called only on agents that are not in a parcel.
Could update to run on all agents in model (both in parcel and not in parcel)
	to consider whether they are dissatistifed with current living condition
"""
function agent_looking_for_parcel_step!(agent::UnoccupiedOwnerAgent, model)
	agent.looking_to_purchase = false
	return agent
end

function agent_looking_for_parcel_step!(agent::IndividualAgent, model)
	agent.looking_to_purchase = true
	return agent
end

function agent_looking_for_parcel_step!(agent::LandlordAgent, model)
	agent.looking_to_purchase = true
	return agent
end

function agent_looking_for_parcel_step!(agent::DeveloperAgent, model)
	agent.looking_to_purchase = true
	return agent
end

"""
	agent_WTP_step!(agent, model)
Generates bid for agent based on utility of parcel
"""
function agent_WTP_step!(agent::UnoccupiedOwnerAgent, model, sellers)
	return agent
end

function agent_WTP_step!(agent::IndividualAgent, model::ABM, sellers)
	prcl_zones = GetParcelsAttribute(model, model.space.zone_type, sellers)

	# getting zone keys (e.g., C-R, R, R-SR, etc.) that individual agent can consider
	zone_keys = model.zoning_params[model.zoning_params[!,"owned_res"].==1, "Zone"]
	sellers_in_zone = Vector{Bool}(undef, length(prcl_zones))
	for (i, zone) in enumerate(prcl_zones)
		if zone in zone_keys
			sellers_in_zone[i] = true
		else
			sellers_in_zone[i] = false
		end
	end
	sellers = sellers[sellers_in_zone]

	if length(sellers) > agent.number_prcls_aware
		sellers = sample(model.rng, sellers, agent.number_prcls_aware, replace=false)
	end

	seller_bid_to = 0
	WTP_max = 0
	for seller in sellers
		parcel = model[seller].pos
		u_parcel = utility_calc(model, agent, parcel)
		WTP = (agent.budget*u_parcel^2)/((agent.price_goods^2)+(u_parcel^2))
		if (WTP > WTP_max) || (WTP > model[seller].WTA)
			seller_bid_to = seller
			WTP_max = WTP
		end
	end
	return seller_bid_to, WTP_max
end


function agent_WTP_step!(agent::LandlordAgent, model::ABM, sellers)	
	prcl_zones = GetParcelsAttribute(model, model.space.zone_type, sellers)
	
	# getting zone keys (e.g., C-R, R, R-SR, etc.) that individual agent can consider
	zone_keys_rr = model.zoning_params[model.zoning_params[!,"rentl_res"].==1, "Zone"]
	zone_keys_losr = model.zoning_params[model.zoning_params[!,"losr"].==1, "Zone"]

	# TODO: Figure out if landlord needs to consider zones separately.
	sellers_in_zone = Vector{Bool}(undef, length(prcl_zones))
	for (i, zone) in enumerate(prcl_zones)
		if (zone in zone_keys_rr) || (zone in zone_keys_losr)
			sellers_in_zone[i] = true
		else
			sellers_in_zone[i] = false
		end
	end
	sellers = sellers[sellers_in_zone]

	sellers_unocc = Vector{Bool}(undef, length(sellers))
	for (i, seller) in enumerate(sellers)
		if typeof(model[seller]) == UnoccupiedOwnerAgent
			sellers_unocc[i] = true
		else
			sellers_unocc[i] = false
		end
	end
	sellers = sellers[sellers_unocc]


	if length(sellers) > agent.number_prcls_aware
		sellers = sample(model.rng, sellers, agent.number_prcls_aware, replace=false)
	end

	seller_bid_to = 0
	WTP_max = 0
	for seller in sellers
		parcel = model[seller].pos
		u_parcel, _ = utility_calc(model, agent, parcel)
		WTP = (agent.budget*u_parcel^2)/((agent.price_goods^2)+(u_parcel^2))
		if (WTP > WTP_max) || (WTP > model[seller].WTA)
			seller_bid_to = seller
			WTP_max = WTP
		end
	end
	return seller_bid_to, WTP_max
end


function agent_WTP_step!(agent::DeveloperAgent, model, sellers)
	# getting parcel zones
	prcl_zones = GetParcelsAttribute(model, model.space.zone_type, sellers)
	
	# getting zone keys (e.g., C-R, R, R-SR, etc.) that individual agent can consider
	zone_keys_hor = model.zoning_params[model.zoning_params[!,"ho_res"].==1, "Zone"]
	zone_keys_hosr = model.zoning_params[model.zoning_params[!,"hosr"].==1, "Zone"]

	# TODO: make developer consider zones separately; 
	# Getting parcels in zones that an agent can purchase
	sellers_in_zone = Vector{Bool}(undef, length(prcl_zones))
	for (i, zone) in enumerate(prcl_zones)
		if (zone in zone_keys_hor) || (zone in zone_keys_hosr)
			sellers_in_zone[i] = true
		else
			sellers_in_zone[i] = false
		end
	end
	sellers = sellers[sellers_in_zone]

	#= ensuring that the seller is an UnoccupiedOwnerAgent; 
		e.g., so developer doesn't purchase a property for rent from landlord agent
	=#
	sellers_unocc = Vector{Bool}(undef, length(sellers))
	for (i, seller) in enumerate(sellers)
		if typeof(model[seller]) == UnoccupiedOwnerAgent
			sellers_unocc[i] = true
		else
			sellers_unocc[i] = false
		end
	end
	sellers = sellers[sellers_unocc]

	# getting random subsample of parcels (bounding develoepr rationality)
	if length(sellers) > agent.number_prcls_aware
		sellers = sample(model.rng, sellers, agent.number_prcls_aware, replace=false)
	end

	# Getting parcel with maximum utility for developer
	seller_bid_to = 0
	WTP_max = 0
	for seller in sellers
		parcel = model[seller].pos
		u_parcel, _ = utility_calc(model, agent, parcel)
		WTP = (agent.budget*u_parcel^2)/((agent.price_goods^2)+(u_parcel^2))
		if (WTP > WTP_max) || (WTP > model[seller].WTA)
			seller_bid_to = seller
			WTP_max = WTP
		end
	end
	return seller_bid_to, WTP_max

end


"""
	utility_calc(model::ABM, agent::AgentType, parcel::String)
Calculates utility of 'parcel' for 'agent'
"""
function utility_calc(model::ABM, agent::UnoccupiedOwnerAgent, parcel::String)
	d_coast = GetParcelAttribute(model, model.space.d_coast, parcel)[1]
	d_commasst = GetParcelAttribute(model, model.space.d_commasst, parcel)[1]

	p_coast = proximity_calc(d_coast, model)
	p_commasst = proximity_calc(d_commasst, model)

	NB = model.FullTimeResidents_searching
	NS = model.n_unoccupied
	p_market = tanh(NB/NS)*100

	u_parcel = p_coast^agent.alpha1 * p_commasst^agent.alpha2 * p_market^agent.alpha3
	return u_parcel
end

function utility_calc(model::ABM, agent::IndividualAgent, parcel::String)
	d_coast = GetParcelAttribute(model, model.space.d_coast, parcel)[1]
	d_commasst = GetParcelAttribute(model, model.space.d_commasst, parcel)[1]

	p_coast = proximity_calc(d_coast, model)
	p_commasst = proximity_calc(d_commasst, model)

	NB = model.FullTimeResidents_searching
	NS = model.n_unoccupied
	p_market = tanh(NB/NS)*100

	u_parcel = p_coast^agent.alpha1 * p_commasst^agent.alpha2 * p_market^agent.alpha3
	return u_parcel
end

function utility_calc(model::ABM, agent::LandlordAgent, parcel::String)
	d_coast = GetParcelAttribute(model, model.space.d_coast, parcel)[1]
	d_commasst = GetParcelAttribute(model, model.space.d_commasst, parcel)[1]
	landuse = GetParcelAttribute(model, model.space.landuse, parcel)[1]

	p_coast = proximity_calc(d_coast, model)
	p_commasst = proximity_calc(d_commasst, model)
	
	# -- market calcs for rental residential (rr)
	NB = model.FullTimeResidents_searching
	NS = model.n_unoccupied
	NS == 0 && (NS=1)	 # if NS is 0, set to 1 (avoid division by 0)
	p_market_rr = tanh(NB/NS)*100


	# -- market calcs for low occupancy seasonal rental (losr)
	NV = max((model.Visitor_total-model.n_LOSR), 0) #+ model.n_HOSR
	NS = model.n_unoccupied
	NS == 0 && (NS=1)	 # if NS is 0, set to 1 (avoid division by 0)
	p_market_losr = tanh(NV/NS)*100


	# -------------------------
	u_parcel_rr = p_coast^agent.alpha1_RR * p_commasst^agent.alpha2_RR * p_market_rr^agent.alpha3_RR
	u_parcel_losr = p_coast^agent.alpha1_LOSR * p_commasst^agent.alpha2_LOSR * p_market_losr^agent.alpha3_LOSR

	# new LandlordAgent owner; decides initial landuse for parcel
	if (landuse in ["rentl_res", "losr"]) == false
		max_idx = findmax([u_parcel_rr, u_parcel_losr])[2]
		landuse = ["rentl_res", "losr"][max_idx]
		return max(u_parcel_rr, u_parcel_losr), landuse
	end

	if u_parcel_losr - agent.transition_penalty > u_parcel_rr
		return u_parcel_losr, "losr"
	elseif u_parcel_rr - agent.transition_penalty > u_parcel_losr
		return u_parcel_rr, "rentl_res"

	else
		return max(u_parcel_rr, u_parcel_losr), landuse
	end
end


function utility_calc(model::ABM, agent::DeveloperAgent, parcel::String)
	d_coast = GetParcelAttribute(model, model.space.d_coast, parcel)[1]
	d_commasst = GetParcelAttribute(model, model.space.d_commasst, parcel)[1]
	landuse = GetParcelAttribute(model, model.space.landuse, parcel)[1]

	p_coast = proximity_calc(d_coast, model)
	p_commasst = proximity_calc(d_commasst, model)

	# -- market calcs for rental residential (rr)
	NB = model.FullTimeResidents_searching
	NS = model.n_unoccupied
	NS == 0 && (NS=1)	 # if NS is 0, set to 1 (avoid division by 0)
	p_market_hor = tanh(NB/NS)*100


	# -- market calcs for low occupancy seasonal rental (losr)
	NV = max((model.Visitor_total-model.n_LOSR), 0) #+ model.n_HOSR
	NS = model.n_unoccupied
	NS == 0 && (NS=1)	 # if NS is 0, set to 1 (avoid division by 0)
	p_market_hosr = tanh(NV/NS)*100


	# -------------------------
	u_parcel_hor = p_coast^agent.alpha1_HOR * p_commasst^agent.alpha2_HOR * p_market_hor^agent.alpha3_HOR
	u_parcel_hosr = p_coast^agent.alpha1_HOSR * p_commasst^agent.alpha2_HOSR * p_market_hosr^agent.alpha3_HOSR

	# new Developer owner; decides initial landuse for parcel
	if (landuse in ["hor", "hosr"]) == false
		max_idx = findmax([u_parcel_hor, u_parcel_hosr])[2]
		landuse = ["hor", "hosr"][max_idx]
		return max(u_parcel_hor, u_parcel_hosr), landuse
	end

	# TODO: come back to this; figure out how to not let develoepr switch land uses like landlord can
	if u_parcel_hosr - agent.transition_penalty > u_parcel_hor
		return u_parcel_hosr, "hosr"
	elseif u_parcel_hor - agent.transition_penalty > u_parcel_hosr
		return u_parcel_hor, "hor"

	else
		return max(u_parcel_hor, u_parcel_hosr), landuse
	end
end

"""
	agent_evaluate_bid_step!(agent, model)
Agent evaluates bids that are recieved on parcel
"""
function agent_evaluate_bid_step!(agent::UnoccupiedOwnerAgent, model::ABM, bidders, SBTs, WTPs)
	bids_to_seller_tf = SBTs .==agent.id
	if sum(bids_to_seller_tf) == 0  		# if seller recieves not bids, return
		return
	end
	bidders = bidders[bids_to_seller_tf] 	# identify bidders on the sellers parcel
	WTPs = WTPs[bids_to_seller_tf]			# get WTP of these bids

	max_idx = argmax(WTPs)					# get max index of WTP
	WTP = WTPs[max_idx]						# get max WTP
	bidder = bidders[max_idx]				# get bidder with highest bid

	simulate_parcel_transaction!(agent, model[bidder], model)
end


function agent_evaluate_bid_step!(agent::IndividualAgent, model::ABM, bidders, SBTs, WTPs)
	return agent
end


function agent_evaluate_bid_step!(agent::LandlordAgent, model::ABM, bidders, SBTs, WTPs)
	bids_to_seller_tf = SBTs .==agent.id
	if sum(bids_to_seller_tf) == 0  		# if seller recieves no bids, return
		return
	end
	bidders = bidders[bids_to_seller_tf] 	# identify bidders on the sellers parcel
	WTPs = WTPs[bids_to_seller_tf]			# get WTP of these bids

	max_idx = argmax(WTPs)					# get max index of WTP
	WTP = WTPs[max_idx]						# get max WTP
	bidder = bidders[max_idx]				# get bidder with highest bid

	simulate_parcel_transaction!(agent, model[bidder], model)
end

function agent_evaluate_bid_step!(agent::DeveloperAgent, model::ABM, bidders, SBTs, WTPs)
	bids_to_seller_tf = SBTs .==agent.id
	if sum(bids_to_seller_tf) == 0  		# if seller recieves no bids, return
		return
	end
	bidders = bidders[bids_to_seller_tf] 	# identify bidders on the sellers parcel
	WTPs = WTPs[bids_to_seller_tf]			# get WTP of these bids

	max_n_agents = GetParcelAttribute(model, model.space.max_n_agents, agent.pos)
	occupying_agents = GetParcelAttribute(model, model.space.s, agent.pos)

	n_space_avail = max_n_agents[1] - length(occupying_agents)
	
	if n_space_avail < length(bidders)
		sorted_idx = sortperm(WTPs)[1:n_space_avail]
		bidders = bidders[sorted_idx]
	end

	for bidder in bidders
		simulate_parcel_transaction!(agent, model[bidder], model)
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

function agent_update_landuse_step!(agent::LandlordAgent, model::ABM)
	_, landuse = utility_calc(model, agent, agent.pos)
	update_landuse!(agent, model, [landuse])
end


function agent_update_landuse_step!(agent::DeveloperAgent, model::ABM)
	_, landuse = utility_calc(model, agent, agent.pos)
	update_landuse!(agent, model, [landuse])
end

"""
	check_switch_landuse!(agent, model)
checks whehter the agent wants to switch the landuse
For landlord agent: can switch between 'rental_res' and 'losr'
if: 
	'rentl_res' and an agent is occupying, then can't switch
else: 
	switches by trying to maximize utility
"""
function check_switch_landuse!(agent::LandlordAgent, model::ABM)
	landuse = GetParcelAttribute(model, model.space.landuse, agent.pos)[1]

	# currently rental_res
	if landuse == "rentl_res"
		agents = GetParcelAttribute(model, model.space.s, agent.pos)
		# another agent is occupying; don't update landuse
		if length(agents)>1
			return 
		end
	end

	_, new_landuse = utility_calc(model, agent, agent.pos)
	if new_landuse != landuse
		update_landuse!(agent, model, [new_landuse])
	end
end


"""
	agent_dies!(agent::AbstractAgent, model)
removing the agent from the model and making the parcel Unoccupied
occurs if an agent is older than 80
if agent is a LandlordAgent, then any occupying agents must find a new place to live
"""
function agent_dies!(agent::A, model::ABM) where {A<:AbstractAgent}
	pos = agent.pos
	kill_agent!(agent, model)
	if occursin("none", agent.pos) == false	# if agent was in parcel
		if agent.own_parcel==true
			id = next_avail_id(model)		# new agent is UnoccupiedOwnerAgent
			new_agent = UnoccupiedOwnerAgent(
						id=id,
						pos=pos,
						WTA=model.Unoccupied_WTA,
						prcl_on_mrkt=true,
						looking_to_purchase=false,
						own_parcel=true
						)
			add_agent_pos_owner!(new_agent, model)
		end
	end
end


function agent_dies!(agent::LandlordAgent, model::ABM)
	pos = agent.pos
	kill_agent!(agent, model)
	idx = pos2cell(pos, model)
	agents_in_parcel = model.space.s[idx]
	if agents_in_parcel != []
		for a in agents_in_parcel
			new_pos = next_avail_pos(model)
			new_pos = string("none_",new_pos)
			move_agent!(model[a], new_pos, model)
		end
	end

	if occursin("none", agent.pos) == false		# if agent was in parcel
		id = next_avail_id(model)				# new agent is UnoccupiedOwnerAgent
		new_agent = UnoccupiedOwnerAgent(
					id=id,
					pos=pos,
					WTA=model.Unoccupied_WTA,
					prcl_on_mrkt=true,
					looking_to_purchase=false,
					own_parcel=true
					)
		add_agent_pos_owner!(new_agent, model)
	end
end


"""
	proximity_calc(d_feat::Float64, model; add_one::Bool=false)
used to calculate proximity to a feature. 
uses a distance decay function given as "exp(-d*k)"
where 'd' is the distance to the feature and 'k' is used to parameterize the 
	shape of the curve. 
The value of 'k' is defined in the input file
"""
function proximity_calc(d_feat::Float64, model)::Float64
	proximity = exp(-d_feat*model.distance_decay_exponent)*100
	return proximity
end



