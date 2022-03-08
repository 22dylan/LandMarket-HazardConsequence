#= 
file for functions related to agent actions
=#
count_agnt_types(model, agent_type) = count(i->(typeof(i.second)==agent_type), model.agents)
cnt_UnoccupiedOwner_agnts(model) = count_agnt_types(model, UnoccupiedOwnerAgent)
cnt_Household_agnts(model) = count_agnt_types(model, HouseholdAgent)
cnt_Landlord_agnts(model) = count_agnt_types(model, LandlordAgent)
cnt_Firm_agnts(model) = count_agnt_types(model, FirmAgent)
cnt_Visitor_agnts(model) = count_agnt_types(model, VisitorAgent)
cnt_n_people_parcel(model) = sum(GetParcelsAttribute(model, model.space.n_people))

function cnt_n_people_parcel(model, agent_type)
	ppl = 0
	for a in allagents(model)
		if typeof(a)==agent_type
			if agent_type == HouseholdAgent
				if a.pos != "none"
					ppl += a.num_people
				end
			elseif agent_type == VisitorAgent
				if a.pos != "none_v"
					ppl += a.num_people
				end
			end
		end
	end
	return ppl
end


function cnt_n_people_searching(model, agent_type)
	ppl = 0
	for a in allagents(model)
		if typeof(a)==agent_type
			if agent_type == HouseholdAgent
				if a.pos == "none"
					ppl += a.num_people
				end
			elseif agent_type == VisitorAgent
				if a.pos == "none_v"
					ppl += a.num_people
				end
			end
		end
	end
	return ppl
end


function cnt_n_people(model, agent_type)
	ppl = 0
	for a in allagents(model)
		if typeof(a)==agent_type
			ppl += a.num_people
		end
	end
	return ppl
end


"""
	agent_step!(agent, model)
general agent step. If 'HouseholdAgent', the agent ages; if age is 80 or above,
agent dies/moves to nursing home and parcel becomes Unoccupied (UnoccupiedOwnerAgent)
"""
function agent_step!(agent::UnoccupiedOwnerAgent, model)
	return agent
end

function agent_step!(agent::RealEstateAgent, model)
	# prcl_zones = GetParcelsAttribute(model, model.space.zone_type)
	NB = model.n_households_searching + model.n_landlords_searching + model.n_firms_searching
	NS = model.n_unoccupied
	eps = eps_calc(NB, NS)
	for i = 1:model.n_prcls
		u_H = utility_calc_idx(model, model.Household_alphas, i)
		u_V = utility_calc_idx(model, model.Visitor_alphas, i)
		u = max(u_H, u_V)
		lv = agent.LandBasePrice*(u/100)*(1+eps)
		model.space.landvalue[i] = [lv]
	end 
	return agent
end


function agent_step!(agent::HouseholdAgent, model)
	agent.age+=1 		# aging agent
	if agent.age >= 80
		agent_dies!(agent, model)
		return
	end
	if model.tick in agent.household_change_times
		agent.num_people += rand(model.rng, Bool) ? 1 : -1  # randomly getting +/- 1
	end
	if agent.num_people <= 0
		agent_dies!(agent, model)
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
	if agent.pos != "none"
		check_switch_landuse!(agent, model)
	end

	
	return agent
end

function agent_step!(agent::FirmAgent, model)
	return agent
end

function agent_step!(agent::VisitorAgent, model)
	return agent
end

"""
	agent_on_market_step!(agent, model)
put parcel on market steps
Unoccupied: always on market
householdAgent: Not on market; these get put on market if the agent dies (e.g., parcel becomes unoccupied)
LandlordAgent: 
	if rental_res: check whether number of occupying agents are less than max occupancy
	if losr: not on market 
"""
function agent_on_market_step!(agent::UnoccupiedOwnerAgent, model)
	agent.prcl_on_mrkt = true
	agent.WTA = model.space.landvalue[agent.pos_idx][1] #* 2.0
end

function agent_on_market_step!(agent::HouseholdAgent, model)
	agent.prcl_on_mrkt = false
	return agent
end


function agent_on_market_step!(agent::LandlordAgent, model)
	max_n_agents = GetParcelAttribute(model, model.space.max_n_agents, agent.pos_idx)
	agents = GetParcelAttribute(model, model.space.s, agent.pos_idx)
	landuse = GetParcelAttribute(model, model.space.landuse, agent.pos_idx)

	if landuse[1] == "rentl_res"
		if length(agents) < max_n_agents[1]
			agent.prcl_on_mrkt = true
			NB = model.n_households_searching
			NS = model.FullTimeResidents_vacancy
			eps = eps_calc(NB, NS)


			Y = mean(model.Household_budget) #* 0.75		# TODO: figure this out
			b = model.Household_price_goods

			u = utility_calc_idx(model, model.Household_alphas, agent.pos_idx)
			agent.WTA = (Y*u^2)/(b^2 + u^2)*(1+eps)

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

function agent_on_market_step!(agent::FirmAgent, model)
	max_n_agents = GetParcelAttribute(model, model.space.max_n_agents, agent.pos_idx)
	agents = GetParcelAttribute(model, model.space.s, agent.pos_idx)
	landuse = GetParcelAttribute(model, model.space.landuse, agent.pos_idx)

	if landuse[1] == "hor"
		if length(agents) < max_n_agents[1]
			agent.prcl_on_mrkt = true
			NB = model.n_households_searching
			NS = model.FullTimeResidents_vacancy
			eps = eps_calc(NB, NS)
			
			Y = mean(model.Household_budget) #* 0.75	# TODO: figure this out
			b = model.Household_price_goods

			u = utility_calc_idx(model, model.Household_alphas, agent.pos_idx)
			agent.WTA = (Y*u^2)/(b^2 + u^2)*(1+eps)
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
	agent_on_visitor_market_step!(agent, model)
put parcel on market steps
Unoccupied: always on market
householdAgent: Not on market; these get put on market if the agent dies (e.g., parcel becomes unoccupied)
LandlordAgent: 
	if rental_res: check whether number of occupying agents are less than max occupancy
	if losr: not on market 
"""

function agent_on_visitor_market_step!(agent::UnoccupiedOwnerAgent, model)
	agent.prcl_on_visitor_mrkt = false
end

function agent_on_visitor_market_step!(agent::HouseholdAgent, model)
	agent.prcl_on_visitor_mrkt = false
	return agent
end


function agent_on_visitor_market_step!(agent::LandlordAgent, model)
	max_n_agents = GetParcelAttribute(model, model.space.max_n_agents, agent.pos_idx)
	agents = GetParcelAttribute(model, model.space.s, agent.pos_idx)
	landuse = GetParcelAttribute(model, model.space.landuse, agent.pos_idx)
	
	if landuse[1] == "losr"
		if length(agents) < max_n_agents[1]
			agent.prcl_on_visitor_mrkt = true
			return agent
		else
			agent.prcl_on_visitor_mrkt = false
			return agent
		end
	elseif landuse[1] == "rentl_res"
		agent.prcl_on_visitor_mrkt = false
		return agent
	end
	return agent
end

function agent_on_visitor_market_step!(agent::FirmAgent, model)
	max_n_agents = GetParcelAttribute(model, model.space.max_n_agents, agent.pos_idx)
	agents = GetParcelAttribute(model, model.space.s, agent.pos_idx)
	landuse = GetParcelAttribute(model, model.space.landuse, agent.pos_idx)

	if landuse[1] == "hosr"
		if length(agents) < max_n_agents[1]
			agent.prcl_on_visitor_mrkt = true
			return agent
		else
			agent.prcl_on_visitor_mrkt = false
			return agent
		end
	elseif landuse[1] == "hor"
		agent.prcl_on_visitor_mrkt = false
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

function agent_looking_for_parcel_step!(agent::HouseholdAgent, model)
	agent.looking_to_purchase = true
	return agent
end

function agent_looking_for_parcel_step!(agent::LandlordAgent, model)
	agent.looking_to_purchase = true
	return agent
end

function agent_looking_for_parcel_step!(agent::FirmAgent, model)
	agent.looking_to_purchase = true
	return agent
end

function agent_looking_for_parcel_step!(agent::VisitorAgent, model)
	return agent
end

"""
	agent_WTP_step!(agent, model)
Generates bid for householdAgent based on utility of parcel

"""
function agent_WTP_step!(agent::UnoccupiedOwnerAgent, model, sellers)
	return agent
end

check_zone(zone_key, zone) = any(zone_key .∈ [split(zone, "-")])


"""
	agent_WTP_step!(agent, model, selelrs)
computes agent WTP
note that this returns "owned_res" regardless of whether agent is bidding on a 
rentl_res or hor property. If an agent is bidding on these latter landuses, and
it goes through, the landuse does not change (see agent_evaluate_bid_step! for
landlords and firms)
"""
function agent_WTP_step!(agent::HouseholdAgent, model::ABM, sellers)
	sellers_idx = get_agents_pos_idx(sellers, model)
	prcl_zones = GetParcelsAttribute_idx(model, model.space.zone_type, sellers_idx)
	landuses = GetParcelsAttribute_idx(model, model.space.landuse, sellers_idx)
	prev_landuses = GetParcelsAttribute_idx(model, model.space.prev_landuse, sellers_idx)

	# getting zone keys (e.g., C-R, R, R-SR, etc.) that household agent can consider
	zone_keys = model.zoning_params[model.zoning_params[!,"owned_res"].==1, "Zone"]

	#=
	 Getting all parcels that were previously an "owned_res" (only last landuse).
	 assuming that if an area is rezoned, as something that cannot accomodate 
	 owned_res, this takes effect if/when a different type of owner takes over, 
	 not immediately for all parcel.

	 Example:
	 	+ parcel A was previously owned res.
	 	+ the zone that parcel A is in was re-zoned as commercial-resort
	 	+ parcel A is for sale. 
	 	+ It can either transition to resort type property or transition to another owned_res.
	 	+ If it transitions to resort type, it can't go back to owned_res again
	 	+ If it remains as owned_res, it can again change hands to another owned_res.
	=#


	# Getting parcels in zones that an agent can purchase
	zone_for_buyer_tf = Vector{Bool}(undef, length(prcl_zones))
	for (i, zone) in enumerate(prcl_zones)
		zone_for_buyer_tf[i] = check_zone(zone_keys, zone)
	end

	seller_u = landuses.=="unoccupied"

	condition1 = zone_for_buyer_tf .& seller_u 		# C1: parcel is for sale and in appropriate zone
	condition2 = landuses.=="rentl_res"				# C2: parcel is a rental residential unit (rental house)
	condition3 = landuses.=="hor"					# C3: parcel is a high occupancy rental unit (apartment)
	condition4 = prev_landuses.=="owned_res"		# C4: parcel was previously an owned_res and can remain as such

	all_conditions = condition1 .| condition2 .| condition3 .| condition4		# relevant sellers are one of above with OR operators
	sellers = sellers[all_conditions]
	sellers_idx = sellers_idx[all_conditions]

	seller_bid_to, WTP = agent_bid_calc(agent, model, sellers, sellers_idx)
	return seller_bid_to, WTP, "owned_res"
end


function agent_WTP_step!(agent::LandlordAgent, model::ABM, sellers)	
	sellers_idx = get_agents_pos_idx(sellers, model)
	prcl_zones = GetParcelsAttribute_idx(model, model.space.zone_type, sellers_idx)
	landuses = GetParcelsAttribute_idx(model, model.space.landuse, sellers_idx)
	
	# getting zone keys (e.g., C-R, R, R-SR, etc.) that household agent can consider
	zone_keys_rr = model.zoning_params[model.zoning_params[!,"rentl_res"].==1, "Zone"]
	zone_keys_losr = model.zoning_params[model.zoning_params[!,"losr"].==1, "Zone"]

	# Getting parcels in zones that an agent can purchase
	zone_for_rr_tf = Vector{Bool}(undef, length(prcl_zones))
	zone_for_losr_tf = Vector{Bool}(undef, length(prcl_zones))
	for (i, zone) in enumerate(prcl_zones)
		zone_for_rr_tf[i] = check_zone(zone_keys_rr, zone)
		zone_for_losr_tf[i] = check_zone(zone_keys_losr, zone)
	end

	seller_u = landuses.=="unoccupied"
	condition_rr = zone_for_rr_tf .& seller_u
	condition_losr = zone_for_losr_tf .& seller_u

	sellers_rr = sellers[condition_rr]
	sellers_idx_rr = sellers_idx[condition_rr]
	
	sellers_losr = sellers[condition_losr]
	sellers_idx_losr = sellers_idx[condition_losr]

	seller_bid_to_rr, WTP_rr = agent_bid_calc(agent, model, sellers_rr, sellers_idx_rr, "rentl_res")
	seller_bid_to_losr, WTP_losr = agent_bid_calc(agent, model, sellers_losr, sellers_idx_losr, "losr")



	if (WTP_losr > WTP_rr) && (model.n_LOSR<model.max_n_LOSR)
		WTP_max = WTP_losr
		seller_bid_to = seller_bid_to_losr
		LU_bid = "losr"
	else
		WTP_max = WTP_rr
		seller_bid_to = seller_bid_to_rr
		LU_bid = "rentl_res"
	end

	return seller_bid_to, WTP_max, LU_bid

end


function agent_WTP_step!(agent::FirmAgent, model, sellers)
	# getting parcel zones
	sellers_idx = get_agents_pos_idx(sellers, model)
	prcl_zones = GetParcelsAttribute_idx(model, model.space.zone_type, sellers_idx)
	landuses = GetParcelsAttribute_idx(model, model.space.landuse, sellers_idx)
	
	# getting zone keys (e.g., C-R, R, R-SR, etc.) that household agent can consider
	zone_keys_hor = model.zoning_params[model.zoning_params[!,"ho_res"].==1, "Zone"]
	zone_keys_hosr = model.zoning_params[model.zoning_params[!,"hosr"].==1, "Zone"]

	# Getting parcels in zones that an agent can purchase
	zone_for_hor_tf = Vector{Bool}(undef, length(prcl_zones))
	zone_for_hosr_tf = Vector{Bool}(undef, length(prcl_zones))
	for (i, zone) in enumerate(prcl_zones)
		zone_for_hor_tf[i] = check_zone(zone_keys_hor, zone)
		zone_for_hosr_tf[i] = check_zone(zone_keys_hosr, zone)
	end

	seller_u = landuses.=="unoccupied"
	condition_hor = zone_for_hor_tf .& seller_u
	condition_hosr = zone_for_hosr_tf .& seller_u

	sellers_hor = sellers[condition_hor]
	sellers_idx_hor = sellers_idx[condition_hor]
	
	sellers_hosr = sellers[condition_hosr]
	sellers_idx_hosr = sellers_idx[condition_hosr]

	seller_bid_to_hor, WTP_hor = agent_bid_calc(agent, model, sellers_hor, sellers_idx_hor, "hor")
	seller_bid_to_hosr, WTP_hosr = agent_bid_calc(agent, model, sellers_hosr, sellers_idx_hosr, "hosr")

	if WTP_hor > WTP_hosr
		WTP_max = WTP_hor
		seller_bid_to = seller_bid_to_hor
		LU_bid = "hor"
	else
		WTP_max = WTP_hosr
		seller_bid_to = seller_bid_to_hosr
		LU_bid = "hosr"
	end
	return seller_bid_to, WTP_max, LU_bid
end

function agent_bid_calc(agent::HouseholdAgent, model::ABM, sellers, sellers_idx)
	# getting random subsample of parcels (bounding household rationality)
	if length(sellers) > agent.number_prcls_aware
		sample_idx = sample(model.rng, 1:length(sellers), agent.number_prcls_aware, replace=false)

		sellers = sellers[sample_idx]
		sellers_idx = sellers_idx[sample_idx]
	end

	# Getting parcel with maximum utility for household
	seller_bid_to = 0
	WTP_max = 0.0
	for i in eachindex(sellers)
		seller = sellers[i]
		seller_idx = sellers_idx[i]
		landuse = model.space.landuse[seller_idx][1]
		prev_lu = model.space.prev_landuse[seller_idx][1]
		current_code = model.space.dgn_lvl[seller_idx][1]

		u_parcel = utility_calc_idx(model, agent, seller_idx)
		NB = model.n_households_searching
		NS = model.FullTimeResidents_vacancy
		eps =  eps_calc(NB, NS)

		if landuse == "unoccupied"		# agent is bidding to put in house; need to consider building codes
			_, _, rho = check_bc_update(model, prev_lu, "owned_res", current_code)
			mv = model.space.landvalue[seller_idx][1]
			WTP = (agent.budget*u_parcel^2)/((agent.price_goods^2)+(u_parcel^2))*(1+eps) - rho*mv
		
		else 		# agent is considering rentl_res or hor; don't need to consider building codes
			WTP = (agent.budget*u_parcel^2)/((agent.price_goods^2)+(u_parcel^2))*(1+eps)
		end


		if (WTP > WTP_max) && (WTP > model[seller].WTA)
			seller_bid_to = seller
			WTP_max = WTP
		end
	end
	return seller_bid_to, WTP_max
end



function agent_bid_calc(agent::LandlordAgent, model::ABM, sellers, sellers_idx, proposed_LU)
	# getting random subsample of parcels (bounding landlord rationality)
	if length(sellers) > agent.number_prcls_aware
		sample_idx = sample(model.rng, 1:length(sellers), agent.number_prcls_aware, replace=false)
		sellers_idx = sellers_idx[sample_idx]
		sellers = sellers[sample_idx]
	end

	if proposed_LU == "rentl_res"
		NB = model.n_households_searching
		NS = model.FullTimeResidents_vacancy
		eps = eps_calc(NB, NS)

	elseif proposed_LU == "losr"
		NB = model.n_visitoragents_searching
		NS = model.Visitors_vacancy
		eps = eps_calc(NB, NS)
	end

	# Getting parcel with maximum utility for landlord
	seller_bid_to = 0
	WTP_max = 0.0
	for i in eachindex(sellers)
		seller = sellers[i]
		seller_idx = sellers_idx[i]
		landuse = model.space.landuse[seller_idx][1]
		prev_lu = model.space.prev_landuse[seller_idx][1]
		current_code = model.space.dgn_lvl[seller_idx][1]

		u_parcel = utility_calc_idx_LanduseIn(model, agent, seller_idx, proposed_LU, eps)
		_, _, rho = check_bc_update(model, prev_lu, proposed_LU, current_code)
		mv = model.space.landvalue[seller_idx][1]
		WTP = (agent.budget*u_parcel^2)/((agent.price_goods^2)+(u_parcel^2))*(1+eps) - rho*mv
		
		if (WTP > WTP_max) && (WTP > model[seller].WTA)
			seller_bid_to = seller
			WTP_max = WTP
		end
	end
	return seller_bid_to, WTP_max
end

function agent_bid_calc(agent::FirmAgent, model::ABM, sellers, sellers_idx, proposed_LU)
	# getting random subsample of parcels (bounding landlord rationality)
	if length(sellers) > agent.number_prcls_aware
		sample_idx = sample(model.rng, 1:length(sellers), agent.number_prcls_aware, replace=false)
		sellers_idx = sellers_idx[sample_idx]
		sellers = sellers[sample_idx]
	end

	if proposed_LU == "hor"
		NB = model.n_households_searching
		NS = model.FullTimeResidents_vacancy
		eps = eps_calc(NB, NS)
	elseif proposed_LU == "hosr"
		NB = model.n_visitoragents_searching
		NS = model.Visitors_vacancy
		eps = eps_calc(NB, NS)
	end

	# Getting parcel with maximum utility for landlord
	seller_bid_to = 0
	WTP_max = 0.0
	for i in eachindex(sellers)
		seller = sellers[i]
		seller_idx = sellers_idx[i]
		landuse = model.space.landuse[seller_idx][1]
		prev_lu = model.space.prev_landuse[seller_idx][1]
		current_code = model.space.dgn_lvl[seller_idx][1]
		
		u_parcel = utility_calc_idx_LanduseIn(model, agent, seller_idx, proposed_LU, eps)
		_, _, rho = check_bc_update(model, prev_lu, proposed_LU, current_code)
		mv = model.space.landvalue[seller_idx][1]
		WTP = (agent.budget*u_parcel^2)/((agent.price_goods^2)+(u_parcel^2))*(1+eps) - rho*mv

		if (WTP > WTP_max) && (WTP > model[seller].WTA)
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

function utility_calc(model::ABM, agent::HouseholdAgent, parcel::String)
	idx = pos2cell(parcel, model)
	u_parcel = utility_calc_idx(model, agent, idx)
	return u_parcel
end


"""
	_utility(alphas::Vector{Float64}, proxs::Vector{Float64})
lower level utility calc.
alpha and proxs are vectors of floats.
Loops through and computes cobb-douglas utilty function
"""
function _utility(alphas::Vector{Float64}, proxs::Vector{Float64})
	u = Vector{Float64}(undef, length(alphas))
	for i in eachindex(alphas)
		u[i] = proxs[i]^alphas[i]
	end
	return prod(u)
end


function _utility_comp(alphas::Vector{Float64}, proxs::Vector{Float64})
	u = Vector{Float64}(undef, length(alphas))
	for i in eachindex(alphas)
		u[i] = proxs[i]^alphas[i]
	end
	return u
end
"""	
	utility_calc_idx(model::ABM, agent::AbstractAgent, parcel_idx::Int64)
calculates utility of parcel for agent.
parcel is pre-identified via it's index in the parcel space
"""

function utility_calc_idx(model::ABM, alphas::Vector{Float64}, parcel_idx::Int64)
	d_coast = GetParcelAttribute(model, model.space.d_coast, parcel_idx)[1]
	d_commasst = GetParcelAttribute(model, model.space.d_commasst, parcel_idx)[1]
	d_cbd = GetParcelAttribute(model, model.space.d_cbd, parcel_idx)[1]

	p_coast = proximity_calc(d_coast, model)
	p_commasst = proximity_calc(d_commasst, model)
	p_cbd = proximity_calc(d_cbd, model)
	
	u_parcel = _utility(alphas, [p_coast, p_commasst, p_cbd])
	return u_parcel
end

function utility_calc_idx(model::ABM, alphas::Vector{Distribution}, parcel_idx::Int64)
	d_coast = GetParcelAttribute(model, model.space.d_coast, parcel_idx)[1]
	d_commasst = GetParcelAttribute(model, model.space.d_commasst, parcel_idx)[1]
	d_cbd = GetParcelAttribute(model, model.space.d_cbd, parcel_idx)[1]

	p_coast = proximity_calc(d_coast, model)
	p_commasst = proximity_calc(d_commasst, model)
	p_cbd = proximity_calc(d_cbd, model)

	alphas = [mean(alphas[1]), mean(alphas[2]), mean(alphas[3])]
	u_parcel = _utility(alphas, [p_coast, p_commasst, p_cbd])

	return u_parcel
end

function utility_calc_idx(model::ABM, agent::HouseholdAgent, parcel_idx::Int64)
	d_coast = GetParcelAttribute(model, model.space.d_coast, parcel_idx)[1]
	d_commasst = GetParcelAttribute(model, model.space.d_commasst, parcel_idx)[1]
	d_cbd = GetParcelAttribute(model, model.space.d_cbd, parcel_idx)[1]

	p_coast = proximity_calc(d_coast, model)
	p_commasst = proximity_calc(d_commasst, model)
	p_cbd = proximity_calc(d_cbd, model)
	# p_mkt = market_calc_CobbDouglas(model, eps)
	
	u_parcel = _utility([agent.alpha1, agent.alpha2, agent.alpha3], [p_coast, p_commasst, p_cbd])
	return u_parcel
end

function utility_calc_idx(model::ABM, agent::VisitorAgent, parcel_idx::Int64)
	d_coast = GetParcelAttribute(model, model.space.d_coast, parcel_idx)[1]
	d_commasst = GetParcelAttribute(model, model.space.d_commasst, parcel_idx)[1]
	d_cbd = GetParcelAttribute(model, model.space.d_cbd, parcel_idx)[1]

	p_coast = proximity_calc(d_coast, model)
	p_commasst = proximity_calc(d_commasst, model)
	p_cbd = proximity_calc(d_cbd, model)
	
	u_parcel = _utility([agent.alpha1, agent.alpha2, agent.alpha3], [p_coast, p_commasst, p_cbd])
	return u_parcel
end



"""
	utility_calc_component_idx(model::ABM, agent::AbstractAgent, parcel_idx::Int64)
returns utility of parcel broken up into it's different components
(e.g., preferences + market term)
the parcel is identified by its index in the parcel space
"""

function utility_calc_component_idx(model::ABM, agent::HouseholdAgent, parcel_idx::Int64)
	d_coast = GetParcelAttribute(model, model.space.d_coast, parcel_idx)[1]
	d_commasst = GetParcelAttribute(model, model.space.d_commasst, parcel_idx)[1]
	d_cbd = GetParcelAttribute(model, model.space.d_cbd, parcel_idx)[1]

	p_coast = proximity_calc(d_coast, model)
	p_commasst = proximity_calc(d_commasst, model)
	p_cbd = proximity_calc(d_cbd, model)

	utility_vector = _utility_comp([agent.alpha1, agent.alpha2, agent.alpha3], [p_coast, p_commasst, p_cbd])
	return utility_vector
end

function utility_calc_component_idx(model::ABM, agent::RealEstateAgent, alphas::Vector{Float64}, parcel_idx::Int64)
	d_coast = GetParcelAttribute(model, model.space.d_coast, parcel_idx)[1]
	d_commasst = GetParcelAttribute(model, model.space.d_commasst, parcel_idx)[1]
	d_cbd = GetParcelAttribute(model, model.space.d_cbd, parcel_idx)[1]

	p_coast = proximity_calc(d_coast, model)
	p_commasst = proximity_calc(d_commasst, model)
	p_cbd = proximity_calc(d_cbd, model)
	
	utility_vector = _utility_comp(alphas, [p_coast, p_commasst, p_cbd])
	return utility_vector
end

function utility_calc_component_idx(model::ABM, agent::VisitorAgent, parcel_idx::Int64)
	d_coast = GetParcelAttribute(model, model.space.d_coast, parcel_idx)[1]
	d_commasst = GetParcelAttribute(model, model.space.d_commasst, parcel_idx)[1]
	d_cbd = GetParcelAttribute(model, model.space.d_cbd, parcel_idx)[1]

	p_coast = proximity_calc(d_coast, model)
	p_commasst = proximity_calc(d_commasst, model)
	p_cbd = proximity_calc(d_cbd, model)

	utility_vector = _utility_comp([agent.alpha1, agent.alpha2, agent.alpha3], [p_coast, p_commasst, p_cbd])
	return utility_vector
end



"""
	utility_calc_idx_LanduseIn(model::ABM, agent::LandlordAgent, parcel_idx::Int64, landuse::String)
utility calc for landlord and firm agents for a parcel in a specific landuse
returns utility for the parcel for the specific landuse type
the parcel is identified by its index in the parcel space
"""
function utility_calc_idx_LanduseIn(model::ABM, agent::LandlordAgent, parcel_idx::Int64, landuse::String, eps::Float64)
	d_coast = GetParcelAttribute(model, model.space.d_coast, parcel_idx)[1]
	d_commasst = GetParcelAttribute(model, model.space.d_commasst, parcel_idx)[1]
	d_cbd = GetParcelAttribute(model, model.space.d_cbd, parcel_idx)[1]

	p_coast = proximity_calc(d_coast, model)
	p_commasst = proximity_calc(d_commasst, model)
	p_cbd = proximity_calc(d_cbd, model)
	
	if landuse == "rentl_res"
		p_mrkt = market_calc_CobbDouglas(eps)
		u_parcel = _utility([agent.alpha1_RR, agent.alpha2_RR, agent.alpha3_RR, agent.alpha4_RR], [p_coast, p_commasst, p_cbd, p_mrkt])


	elseif landuse == "losr"
		p_mrkt = market_calc_CobbDouglas(eps)
		u_parcel = _utility([agent.alpha1_LOSR, agent.alpha2_LOSR, agent.alpha3_LOSR, agent.alpha4_LOSR], [p_coast, p_commasst, p_cbd, p_mrkt])

	end
	return u_parcel

end

function utility_calc_idx_LanduseIn(model::ABM, agent::FirmAgent, parcel_idx::Int64, landuse::String, eps::Float64)
	d_coast = GetParcelAttribute(model, model.space.d_coast, parcel_idx)[1]
	d_commasst = GetParcelAttribute(model, model.space.d_commasst, parcel_idx)[1]
	d_cbd = GetParcelAttribute(model, model.space.d_cbd, parcel_idx)[1]


	p_coast = proximity_calc(d_coast, model)
	p_commasst = proximity_calc(d_commasst, model)
	p_cbd = proximity_calc(d_cbd, model)

	if landuse == "hor"
		p_mrkt = market_calc_CobbDouglas(eps)
		u_parcel = _utility([agent.alpha1_HOR, agent.alpha2_HOR, agent.alpha3_HOR, agent.alpha4_HOR], [p_coast, p_commasst, p_cbd, p_mrkt])
	elseif landuse == "hosr"
		p_mrkt = market_calc_CobbDouglas(eps)
		u_parcel = _utility([agent.alpha1_HOSR, agent.alpha2_HOSR, agent.alpha3_HOSR, agent.alpha4_HOSR], [p_coast, p_commasst, p_cbd, p_mrkt])
	end
	return u_parcel

end



"""
	agent_evaluate_bid_step!(agent, model)
Agent evaluates bids that are recieved on parcel
"""
function agent_evaluate_bid_step!(agent::UnoccupiedOwnerAgent, model::ABM, bidders, SBTs, WTPs, LUs)
	bids_to_seller_tf = SBTs .==agent.id
	if sum(bids_to_seller_tf) == 0  		# if seller recieves not bids, return
		return
	end
	bidders = bidders[bids_to_seller_tf] 	# identify bidders on the sellers parcel
	WTPs = WTPs[bids_to_seller_tf]			# get WTP of these bids
	LUs = LUs[bids_to_seller_tf]

	max_idx = argmax(WTPs)					# get max index of WTP
	WTP = WTPs[max_idx]						# get max WTP
	bidder = bidders[max_idx]				# get bidder with highest bid
	LU = LUs[max_idx]

	simulate_parcel_transaction!(agent, model[bidder], LU, model)
end



function agent_evaluate_bid_step!(agent::HouseholdAgent, model::ABM, bidders, SBTs, WTPs, LUs)
	return agent
end


function agent_evaluate_bid_step!(agent::LandlordAgent, model::ABM, bidders, SBTs, WTPs, LUs)
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

function agent_evaluate_bid_step!(agent::FirmAgent, model::ABM, bidders, SBTs, WTPs, LUs)
	bids_to_seller_tf = SBTs .==agent.id
	if sum(bids_to_seller_tf) == 0  		# if seller recieves no bids, return
		return
	end
	bidders = bidders[bids_to_seller_tf] 	# identify bidders on the sellers parcel
	WTPs = WTPs[bids_to_seller_tf]			# get WTP of these bids

	max_n_agents = GetParcelAttribute(model, model.space.max_n_agents, agent.pos_idx)[1]
	occupying_agents = GetParcelAttribute(model, model.space.s, agent.pos_idx)

	n_space_avail = max_n_agents[1] - length(occupying_agents)
	
	if n_space_avail < length(bidders)
		sorted_idx = sortperm(WTPs)[1:n_space_avail]
		bidders = bidders[sorted_idx]
	end

	for bidder in bidders
		simulate_parcel_transaction!(agent, model[bidder], model)
	end	
end



function agent_close_step!(agent::AbstractAgent, model::ABM)
	return agent
end


function agent_close_step!(agent::HouseholdAgent, model::ABM)
	if agent.pos != "none"		# if agent is in parcel, compute utility
		u_vec  = utility_calc_component_idx(model, agent, agent.pos_idx)
		agent.utility_cst = u_vec[1]
		agent.utility_cms = u_vec[2]
		agent.utility_cbd = u_vec[3]
		agent.utility =  u_vec[1]*u_vec[2]*u_vec[3]
		agent.AVG_bldg_dmg = model.space.AVG_DS[agent.pos_idx][1]
		agent.MC_bldg_dmg = model.space.MC_DS[agent.pos_idx][1]
	end
	return agent
end


function agent_close_step!(agent::VisitorAgent, model::ABM)
	if agent.pos != "none_v"		# if agent is in parcel, compute utility
		u_vec  = utility_calc_component_idx(model, agent, agent.pos_idx)
		agent.utility_cst = u_vec[1]
		agent.utility_cms = u_vec[2]
		agent.utility_cbd = u_vec[3]
		agent.utility =  u_vec[1]*u_vec[2]*u_vec[3]
		agent.AVG_bldg_dmg = model.space.AVG_DS[agent.pos_idx][1]
		agent.MC_bldg_dmg = model.space.MC_DS[agent.pos_idx][1]
	end
	return agent
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
	NB = model.n_households_searching
	NS = model.FullTimeResidents_vacancy
	eps_ftr = eps_calc(NB, NS)
	
	NB = model.n_visitoragents_searching
	NS = model.Visitors_vacancy
	eps_vis = eps_calc(NB, NS)

	# println("    ", eps_ftr, " ", eps_vis, " (", eps_ftr - eps_vis, ") ", NB, " ", NS)
	# checking if its advantageous to switch between full time residence and seasonal rental unit
	if (eps_ftr - agent.transition_penalty > eps_vis) && (model.space.landuse[agent.pos_idx]==["losr"])

		# remove all visitor agents
		agents_in_parcel = model.space.s[agent.pos_idx]
		for a in agents_in_parcel
			if a != agent.id
				move_agent!(model[a], "none_v", model)
			end
		end
		update_landuse!(agent, model, ["rentl_res"])

		# simulate market search for this parcel
		bidders = GetBidders!(model, shuff=true)	
		SBTs, WTPs, LUs = MarketSearch(model, bidders, [agent.id])
		ParcelTransaction!(model, bidders, SBTs, WTPs, LUs, [agent.id])
	
		update_household_counts!(model)
		update_visitor_counts!(model)
		update_VacancyCounts!(model)

	elseif (eps_vis - agent.transition_penalty > eps_ftr) && (model.space.landuse[agent.pos_idx]==["rentl_res"]) && (model.n_LOSR<model.max_n_LOSR)

		# remove all agents that are renting
		agents_in_parcel = model.space.s[agent.pos_idx]
		for a in agents_in_parcel
			if a != agent.id
				move_agent!(model[a], "none", model)
			end
		end
		update_landuse!(agent, model, ["losr"])

		# simulate visitor market search for this parcel
		VisitorMarketSearch!(model, [agent.id], shuff=true)

		update_household_counts!(model)
		update_visitor_counts!(model)
		update_VacancyCounts!(model)
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
	pos_idx = agent.pos_idx
	kill_agent!(agent, model)
	if agent.pos != "none"	# if agent was in parcel
		if agent.own_parcel==true
			id = next_avail_id(model)		# new agent is UnoccupiedOwnerAgent
			new_agent = UnoccupiedOwnerAgent(
						id=id,
						pos=pos,
						pos_idx=pos_idx,
						prcl_on_mrkt=true,
						prcl_on_visitor_mrkt=false,
						looking_to_purchase=false,
						own_parcel=true
						)
			add_agent_pos_owner!(new_agent, model, "unoccupied")
		end
	end
end


function agent_dies!(agent::LandlordAgent, model::ABM)
	pos = agent.pos
	pos_idx = agent.pos_idx
	
	kill_agent!(agent, model) # not temp

	if pos != "none"					# if agent was in parcel
		# remove all occupying agents
		agents_in_parcel = model.space.s[pos_idx]
		if agents_in_parcel != []
			for a in agents_in_parcel
				if typeof(model[a])==HouseholdAgent
					move_agent!(model[a], "none", model)
				else
					move_agent!(model[a], "none_v", model)
				end
			end
		end

		# and new owning agent is UnoccupiedOwnerAgent
		id = next_avail_id(model) 
		new_agent = UnoccupiedOwnerAgent(
					id=id,
					pos=pos,
					pos_idx=pos_idx,
					prcl_on_mrkt=true,
					prcl_on_visitor_mrkt=false,
					looking_to_purchase=false,
					own_parcel=true
					)
		add_agent_pos_owner!(new_agent, model, "unoccupied")



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
	proximity < 1 && (proximity = 1)
	# shuff==true && (ids=shuffle(model.rng, ids))	 # if shuff==true, shuffle ids
	return proximity
end

function market_calc_CobbDouglas(eps)
	p_mrkt = (0.5*eps + 0.5)*100
	return p_mrkt
end


"""
	eps_calc(NB, NS)
returns epsilon value for number of buyers (NB) and number of sellers (NS)
This term is used to drive the market.
e.g., if NB > NS, eps > 0 and it's a sellers market
	if NB < NS, eps < 0 and it's a buyers market
Taken from Filatova et al., 2009
"""	

function eps_calc(NB, NS)
	(NS==0) && (NS=1)
	eps = (NB-NS)/(NB+NS)
	(NB==0) && (NS==0) && (eps=-1.0) # if NS & NB are 0, epsilon is -1
	return eps
end




