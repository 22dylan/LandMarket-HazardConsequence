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


	println("initial dataframe prepared")

	# getting model property dictionary
	properties = set_up_model_properties(input_dict, parcel_df, iter)

	# setting up ABM space
	space = ParcelSpace(parcel_df, size(parcel_df)[1]+3)

	# setting up the model
	model = ABM(
				Union{	
						UnoccupiedOwnerAgent,
						HouseholdAgent,
						LandlordAgent,
						FirmAgent,
						VisitorAgent,
						RealEstateAgent
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
						pos_idx=pos2cell(p["guid"], model),
						WTA=0.0,
						prcl_on_mrkt=true,
						prcl_on_visitor_mrkt=false,
						looking_to_purchase=false,
						own_parcel=true
					)
			add_agent_pos_owner!(agent, model, init=true)

		elseif p["owner_type"]=="household"
			alphas = alpha_calc(model, model.Household_alphas)			
			agent = HouseholdAgent(
						id=id,
						pos=p["guid"],
						pos_idx=pos2cell(p["guid"], model),
						alpha1=alphas[1],
						alpha2=alphas[2],
						alpha3=alphas[3],
						alpha4=alphas[4],
						budget=budget_calc(model, model.Household_budget),
						price_goods=model.Household_price_goods,
						number_prcls_aware=model.Household_number_parcels_aware,
						prcl_on_mrkt=false,
						prcl_on_visitor_mrkt=false,
						looking_to_purchase=false,
						WTA=0.0,
						age=age_calc(model.age_dist, model),
						own_parcel=true,
						num_people=p["numprec"],
						household_change_times=get_household_change_times(model.Household_change_dist, model)
					)
			add_agent_pos_owner!(agent, model, init=true)

		elseif p["owner_type"]=="landlord"
			alphas_RR = alpha_calc(model, model.Landlord_alphas_RR)
			alphas_LOSR = alpha_calc(model, model.Landlord_alphas_LOSR)
			agent = LandlordAgent(
						id=id,
						pos=p["guid"],
						pos_idx=pos2cell(p["guid"], model),
						alpha1_RR=alphas_RR[1],
						alpha2_RR=alphas_RR[2],
						alpha3_RR=alphas_RR[3],
						alpha4_RR=alphas_RR[4],
						alpha1_LOSR=alphas_LOSR[1],
						alpha2_LOSR=alphas_LOSR[2],
						alpha3_LOSR=alphas_LOSR[3],
						alpha4_LOSR=alphas_LOSR[4],
						budget=budget_calc(model, model.Landlord_budget),
						price_goods=model.Landlord_price_goods,
						number_prcls_aware=model.Landlord_number_parcels_aware,
						prcl_on_mrkt=false,
						prcl_on_visitor_mrkt=false,
						looking_to_purchase=false,
						WTA=0.0,
						age=age_calc(model.age_dist, model),
						own_parcel=true,
						transition_penalty=model.Landlord_transition_penalty
					)
			add_agent_pos_owner!(agent, model, init=true, n_people=p["numprec"])

		elseif p["owner_type"]=="firm"
			alphas_HOR = alpha_calc(model, model.Firm_alphas_HOR)
			alphas_HOSR = alpha_calc(model, model.Firm_alphas_HOSR)
			alphas_COMM = alpha_calc(model, model.Firm_alphas_COMM)
			agent = FirmAgent(
						id=id,
						pos=p["guid"],
						pos_idx=pos2cell(p["guid"], model),
						alpha1_HOR=alphas_HOR[1],
						alpha2_HOR=alphas_HOR[2],
						alpha3_HOR=alphas_HOR[3],
						alpha4_HOR=alphas_HOR[4],
						alpha1_HOSR=alphas_HOSR[1],
						alpha2_HOSR=alphas_HOSR[2],
						alpha3_HOSR=alphas_HOSR[3],
						alpha4_HOSR=alphas_HOSR[4],
						alpha1_COMM=alphas_COMM[1],
						alpha2_COMM=alphas_COMM[2],
						alpha3_COMM=alphas_COMM[3],
						alpha4_COMM=alphas_COMM[4],
						budget=budget_calc(model, model.Firm_budget),
						price_goods=model.Firm_price_goods,
						number_prcls_aware=model.Firm_number_parcels_aware,
						prcl_on_mrkt=false,
						prcl_on_visitor_mrkt=false,
						looking_to_purchase=false,
						WTA=0.0,
						own_parcel=true
				)
			add_agent_pos_owner!(agent, model, init=true, n_people=p["numprec"])

		else
			println("something went awry")
			fds
			agent = UnoccupiedOwnerAgent(
				id=id,
				pos=p["guid"],
				pos_idx=pos2cell(p["guid"], model),
				WTA=0.0,
				prcl_on_mrkt=true,
				prcl_on_visitor_mrkt=false,
				looking_to_purchase=false,
				own_parcel=true
			)
		end
	end
end


"""
	AddAgents_fromModelParams(model)
Adds landlord/firm agents that are in the model space looking to purchase property
Not associated with a parcel yet
"""
function AddAgents_fromModelParams!(model)
	for i = 1:model.Landlord_number_searching
		id = next_avail_id(model)
		alphas_RR = alpha_calc(model, model.Landlord_alphas_RR)
		alphas_LOSR = alpha_calc(model, model.Landlord_alphas_LOSR)
		agent = LandlordAgent(
					id=id,
					pos="none",
					pos_idx=pos2cell("none", model),
					alpha1_RR=alphas_RR[1],
					alpha2_RR=alphas_RR[2],
					alpha3_RR=alphas_RR[3],
					alpha4_RR=alphas_RR[4],
					alpha1_LOSR=alphas_LOSR[1],
					alpha2_LOSR=alphas_LOSR[2],
					alpha3_LOSR=alphas_LOSR[3],
					alpha4_LOSR=alphas_LOSR[4],
					budget=budget_calc(model, model.Landlord_budget),
					price_goods=model.Landlord_price_goods,
					number_prcls_aware=model.Landlord_number_parcels_aware,
					prcl_on_mrkt=false,
					prcl_on_visitor_mrkt=false,
					looking_to_purchase=true,
					WTA=0.0,
					age=age_calc(model.age_dist, model),
					own_parcel=false,
					transition_penalty=model.Landlord_transition_penalty
				)
		add_agent_pos!(agent, model)
	end

	for i = 1:model.Firm_number_searching
		id = next_avail_id(model)
		alphas_HOR = alpha_calc(model, model.Firm_alphas_HOR)
		alphas_HOSR = alpha_calc(model, model.Firm_alphas_HOSR)
		alphas_COMM = alpha_calc(model, model.Firm_alphas_COMM)
		agent = FirmAgent(
					id=id,
					pos="none",
					pos_idx=pos2cell("none", model),
					alpha1_HOR=alphas_HOR[1],
					alpha2_HOR=alphas_HOR[2],
					alpha3_HOR=alphas_HOR[3],
					alpha4_HOR=alphas_HOR[4],
					alpha1_HOSR=alphas_HOSR[1],
					alpha2_HOSR=alphas_HOSR[2],
					alpha3_HOSR=alphas_HOSR[3],
					alpha4_HOSR=alphas_HOSR[4],
					alpha1_COMM=alphas_COMM[1],
					alpha2_COMM=alphas_COMM[2],
					alpha3_COMM=alphas_COMM[3],
					alpha4_COMM=alphas_COMM[4],
					budget=budget_calc(model, model.Firm_budget),
					price_goods=model.Firm_price_goods,
					number_prcls_aware=model.Firm_number_parcels_aware,
					prcl_on_mrkt=false,
					prcl_on_visitor_mrkt=false,
					looking_to_purchase=true,
					WTA=0.0,
					own_parcel=false
				)
		add_agent_pos!(agent, model)
	end
	id=next_avail_id(model)
	agent = RealEstateAgent(
				id=next_avail_id(model),
				pos="none_o",
				pos_idx=pos2cell("none_o", model),
				LandBasePrice=model.LandBasePrice
				)
	add_agent_pos!(agent, model)
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
		PopulationGrowth!(model)		# updating population counts
		UpdateModelCounts!(model)		# updating model counts; visitors not yet in parcels for iteration

		AllAgentsStep!(model)			# generic agent step
		SimulateVisitorMarketStep!(model)	# simulating the visitor market step
		UpdateModelCounts!(model)		# updating model counts

		SimulateMarketStep!(model)		# housing market step
		UpdateModelCounts!(model)		# updating model counts
		PopulationOutMigration!(model)	# population out migration to account for overestimates in population
		UpdateModelCounts!(model)		# updating model counts

	else  	# CSZ occurs
	# elseif model.tick == model.t_csz 
		csz!(model)	# running CSZ for Seaside
		close_model!(model)
	end
	model.tick += 1
	next!(model.progress_bar)	# advancing progress bar
end



"""
	PopulationGrowth(model)
function for growing the population in the model
adds more agents using input population projections
"""
function PopulationGrowth!(model)
	PopulationGrowth_household!(model)
	PopulationGrowth_visitor!(model)

	PopulationGrowth_landlord!(model)
	PopulationGrowth_firm!(model)
end


function PopulationOutMigration!(model)
	# simulating out migration if excess people in Seaside
	ids = GetAgentIdsInParcel(model, HouseholdAgent)
	ids = shuffle(model.rng, ids)	 # shuffling ids
	i = 1
	while model.FullTimeResidents_inparcel > model.FullTimeResident_PopulationVector[model.tick]
		agent = model[ids[i]]
		agent_dies!(agent, model)
		update_household_counts!(model)
		i += 1
	end
end
"""
	PopulationGrowth_household!(model)
population growth for households/household agents in model
Note that the population growth curves are for number of people in the model, 
	whereas this adds agents (households) to the model
"""
function PopulationGrowth_household!(model::ABM)
	# keeping a constant number of agents in search space
	n_agents_add = model.Household_number_searching - model.n_households_searching

	pos = "none"
	pos_idx = pos2cell(pos, model)
	for i in 1:n_agents_add
		id = next_avail_id(model)
		n_people = npeople_calc(model.nhousehold_dist, model)
		alphas = alpha_calc(model, model.Household_alphas)
		agent = HouseholdAgent(
					id=id,
					pos=pos,
					pos_idx=pos_idx,
					alpha1=alphas[1],
					alpha2=alphas[2],
					alpha3=alphas[3],
					alpha4=alphas[4],
					budget=budget_calc(model, model.Household_budget),
					price_goods=model.Household_price_goods,
					number_prcls_aware=model.Household_number_parcels_aware,
					prcl_on_mrkt=false,
					prcl_on_visitor_mrkt=false,
					looking_to_purchase=true,
					WTA=0.0,
					age=age_calc(model.age_dist, model),
					own_parcel=false,
					num_people=n_people,
					household_change_times=get_household_change_times(model.Household_change_dist, model)
				)		
		add_agent_pos!(agent, model)
	end
end

"""
	PopulationGrowth_visitor!(model)
population growth fucntion for number of visitors. 
Note that the population growth curves are for number of people in the model, 
	whereas this adds agents (households) to the model
"""
function PopulationGrowth_visitor!(model)
	# removing all visitors from previous step
	genocide!(model, VisitorAgent)

	# getting count of visitors for current step
	n_visitors_t = model.Visitor_PopulationVector[model.tick]

	# adding visitors to model
	n_visitors = 0
	pos = "none_v"
	pos_idx = pos2cell(pos, model)
	while n_visitors < n_visitors_t
		n_people = npeople_calc(model.nvisitor_dist, model)			
		alphas = alpha_calc(model, model.Visitor_alphas)
		agent = VisitorAgent(
					id=next_avail_id(model),
					pos=pos,
					pos_idx=pos_idx,
					num_people=n_people,
					number_prcls_aware=model.Visitor_number_parcels_aware,
					alpha1=alphas[1],
					alpha2=alphas[2],
					alpha3=alphas[3],
					alpha4=alphas[4],
				)
		n_visitors += n_people
		add_agent_pos_visitor!(agent, model)
	end

	update_visitor_counts!(model)
end


"""
	PopulationGrowth_landlord!(model)
Population growth function for landlords
This function keeps the number of landlords searching for a parcel constant. 
"""
function PopulationGrowth_landlord!(model::ABM)
	n_landlords_searching_t = length(GetAgentIdsNotInParcel(model, LandlordAgent))
	n_landlords_add = model.Landlord_number_searching - n_landlords_searching_t
	pos = "none"
	pos_idx = pos2cell(pos, model)
	for i in 1:n_landlords_add
		id = next_avail_id(model)
		alphas_RR = alpha_calc(model, model.Landlord_alphas_RR)
		alphas_LOSR = alpha_calc(model, model.Landlord_alphas_LOSR)
		agent = LandlordAgent(
					id=id,
					pos=pos,
					pos_idx=pos_idx,
					alpha1_RR=alphas_RR[1],
					alpha2_RR=alphas_RR[2],
					alpha3_RR=alphas_RR[3],
					alpha4_RR=alphas_RR[4],
					alpha1_LOSR=alphas_LOSR[1],
					alpha2_LOSR=alphas_LOSR[2],
					alpha3_LOSR=alphas_LOSR[3],
					alpha4_LOSR=alphas_LOSR[4],
					budget=budget_calc(model, model.Landlord_budget),
					price_goods=model.Landlord_price_goods,
					number_prcls_aware=model.Landlord_number_parcels_aware,
					prcl_on_mrkt=false,
					prcl_on_visitor_mrkt=false,
					looking_to_purchase=true,
					WTA=0.0,
					age=age_calc(model.age_dist, model),
					own_parcel=false,
					transition_penalty=model.Landlord_transition_penalty
				)
		add_agent_pos!(agent, model)
	end
end

"""
	PopulationGrowth_firm!(model)
Population growth function for firms
This function keeps the number of firms searching for a parcel constant. 
"""
function PopulationGrowth_firm!(model::ABM)
	n_firms_searching_t = length(GetAgentIdsNotInParcel(model, FirmAgent))
	n_firms_add = model.Firm_number_searching - n_firms_searching_t
	pos = "none"
	pos_idx = pos2cell(pos, model)
	for i in 1:n_firms_add
		id = next_avail_id(model)
		alphas_HOR = alpha_calc(model, model.Firm_alphas_HOR)
		alphas_HOSR = alpha_calc(model, model.Firm_alphas_HOSR)
		alphas_COMM = alpha_calc(model, model.Firm_alphas_COMM)
		agent = FirmAgent(
					id=id,
					pos=pos,
					pos_idx=pos_idx,
					alpha1_HOR=alphas_HOR[1],
					alpha2_HOR=alphas_HOR[2],
					alpha3_HOR=alphas_HOR[3],
					alpha4_HOR=alphas_HOR[4],
					alpha1_HOSR=alphas_HOSR[1],
					alpha2_HOSR=alphas_HOSR[2],
					alpha3_HOSR=alphas_HOSR[3],
					alpha4_HOSR=alphas_HOSR[4],
					alpha1_COMM=alphas_COMM[1],
					alpha2_COMM=alphas_COMM[2],
					alpha3_COMM=alphas_COMM[3],
					alpha4_COMM=alphas_COMM[4],
					budget=budget_calc(model, model.Firm_budget),
					price_goods=model.Firm_price_goods,
					number_prcls_aware=model.Firm_number_parcels_aware,
					prcl_on_mrkt=false,
					prcl_on_visitor_mrkt=false,
					looking_to_purchase=true,
					WTA=0.0,
					own_parcel=false
				)
		add_agent_pos!(agent, model)
	end

end



"""
	AllAgentsStep!(model)
general stepping function for all agents in model. 
UnoccupiedOwnerAgents do nothing
HouseholdAgents age using this step.
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
	bidders, sellers = EstablishMarket!(model, shuff=true)
	SBTs, WTPs, LUs = MarketSearch(model, bidders, sellers)
	ParcelTransaction!(model, bidders, SBTs, WTPs, LUs, sellers)
end


"""
	EstablishMarket(model) → prcls
Establishes housing market by identifying which parcels are for sale and which 
bidders are searching. 
Agents step using "agent_on_market_step!" and "agent_looking_for_parcel_step"
"""
function EstablishMarket!(model; shuff::Bool=false)
	sellers = GetSellers!(model, shuff=shuff)
	bidders = GetBidders!(model, shuff=shuff)
	return bidders, sellers
end

"""
	GetSellers(model; shuff)
returns a list of sellers with parcel on market

"""
function GetSellers!(model::ABM; shuff::Bool=false)
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
end


"""
	GetBidders(model; shuff)
returns a list of bidders searching for parcel
"""
function GetBidders!(model; shuff::Bool=false)
	# --- getting agents looking for parcel
	# getting all agent IDs that are not in a parcel, but in environment
	ids = GetAgentIdsNotInParcel(model)
	shuff==true && (ids=shuffle(model.rng, ids))	 # if shuff==true, shuffle ids
	
	# identifying list of agents looking to buy parcels
	buyers_bool = Vector{Bool}(undef, length(ids))
	for i in eachindex(ids)
		if typeof(model[ids[i]])!=VisitorAgent
			agent_looking_for_parcel_step!(model[ids[i]], model)
			if model[ids[i]].looking_to_purchase
				buyers_bool[i] = true
			else
				buyers_bool[i] = false
			end
		else
			buyers_bool[i] = false
		end
	end
	buyers = ids[buyers_bool]
end


function MarketSearch(model, bidders, sellers)
	SBTs = Vector{Int}(undef, length(bidders))
	WTPs = Vector{Float64}(undef, length(bidders))
	LUs = Vector{String}(undef, length(bidders))
	cnt = 1
	for id in bidders
		seller_bid_to, WTP, LU = agent_WTP_step!(model[id], model, sellers)
		SBTs[cnt] = seller_bid_to
		WTPs[cnt] = WTP
		LUs[cnt] = LU
		cnt += 1
	end
	return SBTs, WTPs, LUs
end




function ParcelTransaction!(model, bidders, SBTs, WTPs, LUs, sellers)
	for seller in sellers
		agent_evaluate_bid_step!(model[seller], model, bidders, SBTs, WTPs, LUs)
	end
end


"""
	SimulateVisitorMarketStep!(model) → prcls
Simulate visitor market interaction step
Establishing parcels that are available for visitors
Gets list of visitors searching
Places visitors in parcels
"""
function SimulateVisitorMarketStep!(model)
	hosts = EstablishMarketHosts!(model, shuff=true)
	VisitorMarketSearch!(model, hosts, shuff=true)
end


"""
	EstablishVisitorMarket(model) → prcls
Establishes housing market by identifying which parcels are for sale and which 
buyers are interested. 
Agents step using "agent_on_market_step!" and "agent_looking_for_parcel_step"
"""
function EstablishMarketHosts!(model; shuff::Bool=true)
	# --- getting parcels on market for visitors
	# getting all agent IDs that are in a parcel
	ids = GetParcelsAttribute(model, model.space.owner)
	shuff==true && (ids=shuffle(model.rng, ids))	 # if shuff==true, shuffle ids
		
	# updating parcels that are on market, getting list of those that are
	hosts_bool = Vector{Bool}(undef, length(ids))
	for i in eachindex(ids)
		agent_on_visitor_market_step!(model[ids[i]], model)
		if model[ids[i]].prcl_on_visitor_mrkt
			hosts_bool[i] = true
		else
			hosts_bool[i] = false
		end
	end
	hosts = ids[hosts_bool]
	return hosts
end


function VisitorMarketSearch!(model, hosts; shuff::Bool=true)
	# --- getting agents looking for parcel
	# getting all agent IDs that are not in a parcel, but in environment
	ids = GetAgentIdsNotInParcel(model, VisitorAgent)
	shuff==true && (ids=shuffle(model.rng, ids))	 # if shuff==true, shuffle ids

	# identifying list of agents looking to visit Seaside
	for i in eachindex(ids)
		hosts_i = copy(hosts)
		agent = model[ids[i]]
		if length(hosts)==0
			break
		end

		if length(hosts_i) > agent.number_prcls_aware
			idx = sample(model.rng, 1:length(hosts_i), agent.number_prcls_aware, replace=false)
			hosts_i = hosts_i[idx]
		end

		host_bid_to = 0
		U_max = 0.0
		for h in eachindex(hosts_i)
			host = model[hosts_i[h]]
			u_parcel = utility_calc_idx(model, agent, host.pos_idx)
			
			if (u_parcel > U_max)
				host_bid_to = host.id
				U_max = u_parcel
			end
		end
		if host_bid_to != 0
			# moving visitor agent to place to stay
			move_agent!(agent, model[host_bid_to].pos, model)

			# checking vacancy of host
			agent_on_visitor_market_step!(model[host_bid_to], model)
			
			# if no vacancy, remove from visitor market
			if model[host_bid_to].prcl_on_visitor_mrkt == false
				deleteat!(hosts, hosts .== model[host_bid_to].id)
			end
		end

	end
end




"""
	UpdateModelCounts(model)
general step for model. Updates counts of each landuse type in model, and number
of unhoused agents searching for housing
"""
function UpdateModelCounts!(model; start::Bool=false)
	update_unoccupied_counts!(model)
	update_household_counts!(model)
	update_landlord_counts!(model)
	update_firm_counts!(model)
	update_visitor_counts!(model)

	update_SpaceCounts!(model)
	update_VacancyCounts!(model)
	
	update_BuildingCodeCounts!(model)

	return model
end

function update_unoccupied_counts!(model)
	# agent counts
	model.n_unoccupied_searching = length(GetAgentIdsNotInParcel(model, UnoccupiedOwnerAgent))
	model.n_unoccupied_total = cnt_UnoccupiedOwner_agnts(model)
	model.n_unoccupied_inparcel = model.n_unoccupied_total - model.n_unoccupied_searching

	model.n_unoccupied = cnt_u_prcls(model)
end

function update_household_counts!(model)
	model.n_households_searching = length(GetAgentIdsNotInParcel(model, HouseholdAgent))
	model.n_households_total = cnt_Household_agnts(model)
	model.n_households_inparcel = model.n_households_total - model.n_households_searching

	model.n_OwnedRes = cnt_or_prcls(model)

	model.FullTimeResidents_total = cnt_n_people(model, HouseholdAgent)
	model.FullTimeResidents_inparcel = cnt_n_people_parcel(model, HouseholdAgent)
	model.FullTimeResidents_searching = cnt_n_people_searching(model, HouseholdAgent)


end

function update_landlord_counts!(model)
	model.n_landlords_searching = length(GetAgentIdsNotInParcel(model, LandlordAgent))
	model.n_landlords_total = cnt_Landlord_agnts(model)
	model.n_landlords_inparcel = model.n_landlords_total - model.n_landlords_searching

	model.n_RentlRes = cnt_rr_prcls(model)
	model.n_LOSR = cnt_losr_prcls(model)

end

function update_firm_counts!(model)
	model.n_firms_searching = length(GetAgentIdsNotInParcel(model, FirmAgent))
	model.n_firms_total = cnt_Firm_agnts(model)
	model.n_firms_inparcel = model.n_firms_total - model.n_firms_searching

	model.n_HOR = cnt_hor_prcls(model)
	model.n_HOSR = cnt_hosr_prcls(model)
	model.n_comm = cnt_comm_prcls(model)
end

function update_visitor_counts!(model)
	model.n_visitoragents_searching = length(GetAgentIdsNotInParcel(model, VisitorAgent))
	model.n_visitoragents_total = cnt_Visitor_agnts(model)
	model.n_visitoragents_inparcel = model.n_visitoragents_total - model.n_visitoragents_searching

	model.Visitors_total = cnt_n_people(model, VisitorAgent)
	model.Visitors_inparcel = cnt_n_people_parcel(model, VisitorAgent)
	model.Visitors_searching = cnt_n_people_searching(model, VisitorAgent)
end



"""
	update_SpaceCounts!(model)
updates the following in the parcel space:
	number of agents associated with each parcel
	number of people associated with each parcel
"""
function update_SpaceCounts!(model)
	for i = 1:model.n_prcls
		cnt = 0
		for agent_id in model.space.s[i]
			if typeof(model[agent_id])==HouseholdAgent || typeof(model[agent_id])==VisitorAgent
				cnt += model[agent_id].num_people
			end
		end
		model.space.n_agents[i] = [length(model.space.s[i])]
		model.space.n_people[i] = [cnt]
	end
end


function update_VacancyCounts!(model)
	max_n_agents = GetParcelsAttribute(model, model.space.max_n_agents)
	n_agents = GetParcelsAttribute(model, model.space.n_agents)
	landuses = GetParcelsAttribute(model, model.space.landuse)

	# vacancies for full time residents
	UN_tf = [lu=="unoccupied" for lu in landuses]
	RR_tf = [lu=="rentl_res" for lu in landuses]
	HOR_tf = [lu=="hor" for lu in landuses]


	FullTimeResidence_tf = RR_tf .| HOR_tf
	max_n_agents_ft = max_n_agents[FullTimeResidence_tf]
	n_agents_ft = n_agents[FullTimeResidence_tf]

	model.FullTimeResidents_vacancy = (sum(max_n_agents_ft) - sum(n_agents_ft)) + count(UN_tf)
	model.FullTimeResidents_vacancy < 0 && (model.FullTimeResidents_vacancy = 0)

	# vacancies for visitors
	LOSR_tf = [lu=="losr" for lu in landuses]
	HOSR_tf = [lu=="hosr" for lu in landuses]

	VisitorResidence_tf = LOSR_tf .| HOSR_tf
	max_n_agents_vs = max_n_agents[VisitorResidence_tf]
	n_agents_vs = n_agents[VisitorResidence_tf]

	#= note: with count(UN_tf) here, the total visitor population does not 
		match projections
	=#
	model.Visitors_vacancy = (sum(max_n_agents_vs) - sum(n_agents_vs)) #+ count(UN_tf)
	model.Visitors_vacancy < 0 && (model.Visitors_vacancy = 0)
end




function interpolate_population(t, P_vec, n_years)
	P_vec_out = Vector{Int64}(undef, n_years+1)

	for i = 0:n_years
		if i in t
			P_vec_out[i+1] = P_vec[t.==i][1]
		else
			idx = div(i,5) + 1
			P1 = P_vec[idx]
			P5 = P_vec[idx+1]
			P = P_vec_out[i]*(P5/P1)^(1/5)
			P_vec_out[i+1] = round(Int64, P)
		end

	end
	return P_vec_out
end


function update_BuildingCodeCounts!(model)
	model.n_precode = cnt_pre_prcls(model)
	model.n_lowcode = cnt_low_prcls(model)
	model.n_modcode = cnt_mod_prcls(model)
	model.n_hghcode = cnt_hgh_prcls(model)
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
	dgn_lvl = GetParcelsAttribute(model, model.space.dgn_lvl)
	no_stories = GetParcelsAttribute(model, model.space.no_stories)
	x = GetParcelsAttribute(model, model.space.x)
	y = GetParcelsAttribute(model, model.space.y)

	# running pyincore
	rt = model.hazard_recurrence
	PYTHON_OPS.pyincore_CSZ(guids=guids,
							strct_typ=strct_typ,
							year_built=year_built,
							dgn_lvl=dgn_lvl,
							no_stories=no_stories,
							x=x,
							y=y,
							rt=rt)

	# getting results from pyincore back to the agents
	path_to_dmg = joinpath("temp", "cm_out.csv")
	dmg_reslts = read_csv(path_to_dmg)

	UpdateParcelAttr!(model, dmg_reslts[:,"LS_0"], :LS_0)
	UpdateParcelAttr!(model, dmg_reslts[:,"LS_1"], :LS_1)
	UpdateParcelAttr!(model, dmg_reslts[:,"LS_2"], :LS_2)
	Average_DS!(model)
	MC_Sample_DS!(model)
end


function close_model!(model)
	for agent in allagents(model)
		agent_close_step!(agent, model)
	end
end

function set_up_model_properties(input_dict, parcel_df, iter)
	input = input_dict["Input"]
	PreferenceMatrix = input_dict["PreferenceMatrix"]
	PopulationGrowth = input_dict["PopulationGrowth"]

	t_csz = input[input[:,"Variable"] .== "n_years", "Value"][1]
	n_sims = input[input[:,"Variable"] .== "n_sims", "Value"][1]
	hazard_recurrence = input[input[:,"Variable"] .== "hazard_recurrence", "Value"][1]
	distance_decay_exponent = input[input[:,"Variable"] .== "distance_decay_exponent", "Value"][1]
	max_n_LOSR = input[input[:,"Variable"] .== "max_n_LOSR", "Value"][1]

	t_csz = convert(Int64, t_csz)
	n_sims = convert(Int64, n_sims)
	hazard_recurrence = convert(Int64, hazard_recurrence)
	max_n_LOSR = convert(Int64, max_n_LOSR)

	AllowNew_OwnedRes = input[input[:,"Variable"] .== "AllowNew_OwnedRes", "Value"][1]
	AllowNew_RentalRes = input[input[:,"Variable"] .== "AllowNew_RentalRes", "Value"][1]
	AllowNew_LOSR = input[input[:,"Variable"] .== "AllowNew_LOSR", "Value"][1]
	AllowNew_HOR = input[input[:,"Variable"] .== "AllowNew_HOR", "Value"][1]
	AllowNew_HOSR = input[input[:,"Variable"] .== "AllowNew_HOSR", "Value"][1]

	AllowNew_OwnedRes = convert(Bool, AllowNew_OwnedRes)
	AllowNew_RentalRes = convert(Bool, AllowNew_RentalRes)
	AllowNew_LOSR = convert(Bool, AllowNew_LOSR)
	AllowNew_HOR = convert(Bool, AllowNew_HOR)
	AllowNew_HOSR = convert(Bool, AllowNew_HOSR)

	# --- population information
	FullTimeResident_PopulationVector = interpolate_population(PopulationGrowth[:,"Tick"], PopulationGrowth[:,"FullTimeResidents"], t_csz)
	Visitor_PopulationVector = interpolate_population(PopulationGrowth[:,"Tick"], PopulationGrowth[:,"Visitors"], t_csz)


	nhousehold_alpha = input[input[:,"Variable"] .== "nhousehold_alpha", "Value"][1]
	nhousehold_theta = input[input[:,"Variable"] .== "nhousehold_theta", "Value"][1]
	nhousehold_dist = Gamma(nhousehold_alpha, nhousehold_theta)

	nvisitor_alpha = input[input[:,"Variable"] .== "nvisitor_alpha", "Value"][1]
	nvisitor_theta = input[input[:,"Variable"] .== "nvisitor_theta", "Value"][1]
	nvisitor_dist = Gamma(nvisitor_alpha, nvisitor_theta)

	age_alpha = input[input[:,"Variable"] .== "age_alpha", "Value"][1]
	age_theta = input[input[:,"Variable"] .== "age_theta", "Value"][1]
	age_dist = Gamma(age_alpha, age_theta)

	# -- Household agent information
	Household_budget_mean = input[input[:,"Variable"] .== "Household_budget_mean", "Value"][1]
	Household_budget_std = input[input[:,"Variable"] .== "Household_budget_std", "Value"][1]
	Household_price_goods = input[input[:,"Variable"] .== "Household_price_goods", "Value"][1]
	Household_number_parcels_aware = input[input[:,"Variable"] .== "Household_number_parcels_aware", "Value"][1]	
	Household_number_searching = input[input[:,"Variable"] .== "Household_number_searching", "Value"][1]	
	Household_change_rate = input[input[:,"Variable"] .== "Household_change_rate", "Value"][1]
	Household_change_dist = Exponential(Household_change_rate)
	Household_alphas = PreferenceMatrix[:, "household"][1:4]
	Household_alpha_std = PreferenceMatrix[:, "household"][5]
	
	Household_alphas = setup_alphas(Household_alphas, Household_alpha_std)
	Household_budget = setup_budget(Household_budget_mean, Household_budget_std)
	Household_number_parcels_aware = convert(Int64, Household_number_parcels_aware)

	# -- Visitor agent information
	Visitor_number_parcels_aware = input[input[:,"Variable"] .== "Visitor_number_parcels_aware", "Value"][1]	
	Visitor_alphas = PreferenceMatrix[:, "visitor"][1:4]
	Visitor_alpha_std = PreferenceMatrix[:, "visitor"][5]
	Visitor_alphas = setup_alphas(Visitor_alphas, Visitor_alpha_std)

	# -- Landlord agent information
	Landlord_budget_mean = input[input[:,"Variable"] .== "Landlord_budget_mean", "Value"][1]
	Landlord_budget_std = input[input[:,"Variable"] .== "Landlord_budget_std", "Value"][1]
	Landlord_price_goods = input[input[:,"Variable"] .== "Landlord_price_goods", "Value"][1]
	Landlord_number_parcels_aware = input[input[:,"Variable"] .== "Landlord_number_parcels_aware", "Value"][1]	
	Landlord_number_searching = input[input[:,"Variable"] .== "Landlord_number_searching", "Value"][1]	
	Landlord_transition_penalty = input[input[:,"Variable"] .== "Landlord_transition_penalty", "Value"][1]
	Landlord_alphas_RR = PreferenceMatrix[:, "rentl_res"][1:4]
	Landlord_alpha_RR_std = PreferenceMatrix[:, "rentl_res"][5]	
	Landlord_alphas_LOSR = PreferenceMatrix[:, "losr"][1:4]
	Landlord_alpha_LOSR_std = PreferenceMatrix[:, "losr"][5]

	Landlord_alphas_RR = setup_alphas(Landlord_alphas_RR, Landlord_alpha_RR_std)
	Landlord_alphas_LOSR = setup_alphas(Landlord_alphas_LOSR, Landlord_alpha_LOSR_std)
	Landlord_budget = setup_budget(Landlord_budget_mean, Landlord_budget_std)
	Landlord_number_parcels_aware = convert(Int64, Landlord_number_parcels_aware)


	# -- Firm agent information
	Firm_budget_mean = input[input[:,"Variable"] .== "Firm_budget_mean", "Value"][1]
	Firm_budget_std = input[input[:,"Variable"] .== "Firm_budget_std", "Value"][1]
	Firm_price_goods = input[input[:,"Variable"] .== "Firm_price_goods", "Value"][1]
	Firm_number_parcels_aware = input[input[:,"Variable"] .== "Firm_number_parcels_aware", "Value"][1]
	Firm_number_searching = input[input[:,"Variable"] .== "Firm_number_searching", "Value"][1]	
	Firm_alphas_HOR = PreferenceMatrix[:, "hor"][1:4]
	Firm_alpha_HOR_std = PreferenceMatrix[:, "hor"][5]	
	Firm_alphas_HOSR = PreferenceMatrix[:, "hosr"][1:4]
	Firm_alpha_HOSR_std = PreferenceMatrix[:, "hosr"][5]
	Firm_alphas_COMM = PreferenceMatrix[:, "comm"][1:4]
	Firm_alpha_COMM_std = PreferenceMatrix[:, "comm"][5]

	Firm_alphas_HOR = setup_alphas(Firm_alphas_HOR, Firm_alpha_HOR_std)
	Firm_alphas_HOSR = setup_alphas(Firm_alphas_HOSR, Firm_alpha_HOSR_std)
	Firm_alphas_COMM = setup_alphas(Firm_alphas_COMM, Firm_alpha_COMM_std)
	Firm_budget = setup_budget(Firm_budget_mean, Firm_budget_std)
	Firm_number_parcels_aware = convert(Int64, Firm_number_parcels_aware)


	# -- Real estate agent information
	RealEstate_LandBasePrice = input[input[:,"Variable"] .== "RealEstate_LandBasePrice", "Value"][1]


	bc2y = Dict("Pre - Code"=>1970, 
				"Low - Code"=>1987,
				"Moderate - Code"=>2001, 
				"High - Code"=>2022
				)


	zoning_params = input_dict["zoning_params"]
	BuildingCodes = input_dict["BuildingCodes"]

	p = ProgressBar(iter, n_sims, t_csz)
	update!(p)

	# ----------------------------------------
	properties = Parameters(
		t_csz=t_csz,
		hazard_recurrence=hazard_recurrence,
		distance_decay_exponent=distance_decay_exponent,
		zoning_params=zoning_params,
		building_codes=BuildingCodes,
		progress_bar=p,
		n_prcls=size(parcel_df)[1],
		
		nhousehold_dist=nhousehold_dist,
		nvisitor_dist=nvisitor_dist,
		age_dist=age_dist,
		BuildingCode2Year=bc2y,
		max_n_LOSR=max_n_LOSR,
		
		AllowNew_OwnedRes = AllowNew_OwnedRes,
		AllowNew_RentalRes = AllowNew_RentalRes,
		AllowNew_LOSR = AllowNew_LOSR,
		AllowNew_HOR = AllowNew_HOR,
		AllowNew_HOSR = AllowNew_HOSR,

		Household_budget=Household_budget,
		Household_price_goods=Household_price_goods,
		Household_number_parcels_aware=Household_number_parcels_aware,
		Household_number_searching=Household_number_searching,
		Household_change_dist=Household_change_dist,
		Household_alphas=Household_alphas,

		Visitor_number_parcels_aware=Visitor_number_parcels_aware,
		Visitor_alphas=Visitor_alphas,

		Landlord_budget=Landlord_budget,
		Landlord_price_goods=Landlord_price_goods,
		Landlord_number_parcels_aware=Landlord_number_parcels_aware,
		Landlord_number_searching=Landlord_number_searching,
		Landlord_transition_penalty=Landlord_transition_penalty,
		Landlord_alphas_RR=Landlord_alphas_RR,
		Landlord_alphas_LOSR=Landlord_alphas_LOSR,

		Firm_budget=Firm_budget,
		Firm_price_goods=Firm_price_goods,
		Firm_number_parcels_aware=Firm_number_parcels_aware,
		Firm_number_searching=Firm_number_searching,
		Firm_alphas_HOR=Firm_alphas_HOR,
		Firm_alphas_HOSR=Firm_alphas_HOSR,
		Firm_alphas_COMM=Firm_alphas_COMM,

		LandBasePrice=RealEstate_LandBasePrice,

		FullTimeResident_PopulationVector=FullTimeResident_PopulationVector,
		Visitor_PopulationVector=Visitor_PopulationVector,
		)
	return properties
end




"""
	ProgressBar(i, iters, n_years)
prints status of model to terminal
"""
function ProgressBar(i, iters, n_years)
	p = Progress(n_years, 
			desc="Iteration: $i/$iters | ",
			barlen=30, 
			color=:cyan
		)
	return p
end



"""
	pd_to_df(df_pd)
convert from pandas pyobject to a julia dataframe; Pandas in python stores strings as "objects".
Manually convertin gsome of these
"""
function pd_to_df(df_pd)
	colnames = map(String, df_pd[:columns])
	df = DataFrame(Any[Array(df_pd[c].values) for c in colnames], colnames)
	df[!,"guid"] = convert.(String,df[!,"guid"])
	df[!,"struct_typ"] = convert.(String,df[!,"struct_typ"])
	df[!,"dgn_lvl"] = convert.(String,df[!,"dgn_lvl"])
	df[!,"zone"] = convert.(String,df[!,"zone"])
	df[!,"zone_type"] = convert.(String,df[!,"zone_type"])
	df[!,"landuse"] = convert.(String,df[!,"landuse"])
	df[!,"numprec"] = convert.(Int64,df[!,"numprec"])
    return df
end

"""
	age_calc(dist::Distribution, model::ABM)
returns an age for head of household; limited to be older than 18;
draws from distribution setup in model dictionary
"""
function age_calc(dist::Distribution, model::ABM)
	age = rand(model.rng, dist, 1)[1]
	age = convert(Int64,round(age))
	if age < 18
		age = 18
	end
	return age
end

"""
	get_household_change_times()
sets up occurrences of when a household will +/- one person.
Follows a poisson process
"""
function get_household_change_times(dist::Distribution, model::ABM)
	inter_arrival_times = rand(model.rng, dist, 100)
	arrival_times = cumsum(inter_arrival_times)
	arrival_times = arrival_times[arrival_times.<=model.t_csz]
	change_times = Vector{Int64}(undef, length(arrival_times))

	for i in eachindex(arrival_times)
		change_times[i] = convert(Int64, round(arrival_times[i]))
	end
	return change_times

end

"""
	npeople_calc(dist::Distribution, model::ABM)
sets up number of people in one household
"""
function npeople_calc(dist::Distribution, model::ABM)
	npeople = rand(model.rng, dist, 1)[1]
	npeople = convert(Int64,round(npeople))
	if npeople < 1
		npeople = 1
	end
	return npeople
end


"""
	budget_calc(model::ABM, budget::Distribution)
returns budget for household drawn from budget distribution
"""
function budget_calc(model::ABM, budget::Distribution)
	return rand(model.rng, budget, 1)[1]
end

"""
	budget_calc(model::ABM, budget::Distribution)
returns budget for household; constant value
"""
function budget_calc(model::ABM, budget::Float64)
	return budget
end

"""
	setup_budget(budget_mean, budget_std)
sets up a budget to be used later in model.
if std is nonzero, a distribution is setup and later sampled from
if std is zero, a single value (constant) is used for all agents.
"""
function setup_budget(budget_mean, budget_std)
	if budget_std != 0.0
		budget = Normal(budget_mean, budget_std)
	else
		budget = budget_mean
	end
	return budget
end


"""
	alpha_dists(model::ABM, alpha_dists::Vector{Distribution})
returns alpha values for agent preferences drawn from distributions
scales alpha values to sum to 1
"""
function alpha_calc(model::ABM, alpha_dists::Vector{<:Distribution})
	alpha_vals = inner_alpha_calc(model, alpha_dists)
	
	while isnan(sum(alpha_vals)) # some alpha_vals are NaN
		alpha_vals = inner_alpha_calc(model, alpha_dists)
	end
	return alpha_vals

end

function inner_alpha_calc(model::ABM, alpha_dists::Vector{<:Distribution})
	alpha_vals = Vector{Float64}(undef, length(alpha_dists))
	for i in eachindex(alpha_dists)
		if mean(alpha_dists[i]) != 0
			rv = rand(model.rng, alpha_dists[i], 1)[1]
			rv < 0.01 && (rv = 0)	# if less than 0.01, assume 0 and not important for agent
			alpha_vals[i] = rv
		else
			alpha_vals[i] = 0
		end
	end
	alpha_vals .= alpha_vals./sum(alpha_vals)
	return alpha_vals
end

"""
	alpha_dists(model::ABM, alpha_dists::Vector{Distribution})
returns alpha values for agent preferences as constant
"""
function alpha_calc(model::ABM, alphas::Vector{Float64})
	return alphas
end

"""
	setup_alphas(alphas::Vector{Float64}, alpha_std::Float64)
sets up a alpha to be used later in model; for agent preferences
if std is nonzero, a distribution is setup and later sampled from
if std is zero, a single value (constant) is used for all agents.
"""
function setup_alphas(alphas::Vector{Float64}, alpha_std::Float64)
	if alpha_std != 0.0
		alpha_out = Vector{Distribution}(undef, length(alphas))
		for i in eachindex(alphas)
			alpha_out[i] = Normal(alphas[i], alpha_std)
		end
	elseif alpha_std == 0.0
		alpha_out = alphas
	end
	return alpha_out
end








