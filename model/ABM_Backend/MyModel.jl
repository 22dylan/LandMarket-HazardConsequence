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
						IndividualAgent,
						LandlordAgent,
						CompanyAgent,
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

		elseif p["owner_type"]=="individual"
			alphas = alpha_calc(model, model.Household_alphas)			
			agent = IndividualAgent(
						id=id,
						pos=p["guid"],
						pos_idx=pos2cell(p["guid"], model),
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
						own_parcel=true,
						num_people=p["numprec"],
						household_change_times=get_household_change_times(model.Individual_household_change_dist, model)
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

		elseif p["owner_type"]=="company"
			alphas_HOR = alpha_calc(model, model.Company_alphas_HOR)
			alphas_HOSR = alpha_calc(model, model.Company_alphas_HOSR)
			agent = CompanyAgent(
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
						budget=budget_calc(model, model.Company_budget),
						price_goods=model.Company_price_goods,
						number_prcls_aware=model.Company_number_parcels_aware,
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
Adds landlord/company agents that are in the model space looking to purchase property
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

	for i = 1:model.Company_number_searching
		id = next_avail_id(model)
		alphas_HOR = alpha_calc(model, model.Company_alphas_HOR)
		alphas_HOSR = alpha_calc(model, model.Company_alphas_HOSR)
		agent = CompanyAgent(
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
					budget=budget_calc(model, model.Company_budget),
					price_goods=model.Company_price_goods,
					number_prcls_aware=model.Company_number_parcels_aware,
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
		AllAgentsStep!(model)			# 1s, 50k alct. --- (0.3s; 35k alct.)

		SimulateVisitorMarketStep!(model)	# simulating the visitor market step
		UpdateModelCounts!(model)

		# AllAgentsStep!(model)			# 1s, 50k alct. --- (0.3s; 35k alct.)
		SimulateMarketStep!(model)		# 2s, 35k alct. --- (0.1s; 17k alct.)
		UpdateModelCounts!(model)		# 0.3s, 130k alct. --- (0.25s; 140k alct.)

	elseif model.tick == model.t_csz 	# CSZ
		csz!(model)	# running CSZ for Seaside
		close_model!(model)
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
	PopulationGrowth_company!(model)
end

"""
	PopulationGrowth_individual!(model)
population growth for individuals/household agents in model
Note that the population growth curves are for number of people in the model, 
	whereas this adds agents (households) to the model

"""
function PopulationGrowth_individual!(model::ABM)
	n_people = cnt_n_people(model, IndividualAgent)
	n_people_t = logistic_population(model.tick, 
						model.FullTimeResident_carrying_cap, 
						model.FullTimeResident_init,
						model.FullTimeResident_growth_rate)
	n_people_add = n_people_t - n_people
	n_added = 0
	pos = "none"
	pos_idx = pos2cell(pos, model)
	while n_added < n_people_add
		id = next_avail_id(model)
		n_people = npeople_calc(model.nhousehold_dist, model)
		alphas = alpha_calc(model, model.Household_alphas)
		agent = IndividualAgent(
					id=id,
					pos=pos,
					pos_idx=pos_idx,
					alpha1=alphas[1],
					alpha2=alphas[2],
					alpha3=alphas[3],
					alpha4=alphas[4],
					budget=budget_calc(model, model.Individual_budget),
					price_goods=model.Individual_price_goods,
					number_prcls_aware=model.Individual_number_parcels_aware,
					prcl_on_mrkt=false,
					prcl_on_visitor_mrkt=false,
					looking_to_purchase=true,
					WTA=0.0,
					age=age_calc(model.age_dist, model),
					own_parcel=false,
					num_people=n_people,
					household_change_times=get_household_change_times(model.Individual_household_change_dist, model)
				)		
		add_agent_pos!(agent, model)
		n_added+=n_people
	end
end

"""
	PopulationGrowth_visitor!(model)
population growth fucntion for number of visitors. 
TODO: Update this description
Since visitors are not represented as agents, this function simply calls the 
logistic population function
"""
function PopulationGrowth_visitor!(model)
	# removing all visitors from previous step
	genocide!(model, VisitorAgent)

	# getting count of visitors for current step
	n_visitors_t = logistic_population(model.tick, 
						model.Visitor_carrying_cap, 
						model.Visitor_init,
						model.Visitor_growth_rate)

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
	PopulationGrowth_company!(model)
Population growth function for companies
This function keeps the number of companies searching for a parcel constant. 
"""
function PopulationGrowth_company!(model::ABM)
	n_companies_searching_t = length(GetAgentIdsNotInParcel(model, CompanyAgent))
	n_companies_add = model.Company_number_searching - n_companies_searching_t
	pos = "none"
	pos_idx = pos2cell(pos, model)
	for i in 1:n_companies_add
		id = next_avail_id(model)
		alphas_HOR = alpha_calc(model, model.Company_alphas_HOR)
		alphas_HOSR = alpha_calc(model, model.Company_alphas_HOSR)
		agent = CompanyAgent(
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
					budget=budget_calc(model, model.Company_budget),
					price_goods=model.Company_price_goods,
					number_prcls_aware=model.Company_number_parcels_aware,
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
	# initial model counts
	if start == true
		model.FullTimeResident_init = cnt_n_people(model, IndividualAgent)
		model.Visitor_init = cnt_n_people(model, VisitorAgent)
	end

	update_unoccupied_counts!(model)
	update_individual_counts!(model)
	update_landlord_counts!(model)
	update_company_counts!(model)
	update_visitor_counts!(model)

	update_SpaceCounts!(model)
	update_VacancyCounts!(model)
	
	# println()
	# println(model.tick)
	# println("I: ", model.n_individuals_searching) #, " ", model.n_individuals_inparcel, " ", model.n_individuals_total)
	# println("V: ", model.n_visitoragents_searching) #, " ", model.n_visitoragents_inparcel, " ", model.n_visitoragents_total)
	# println("vac_ftr: ", model.FullTimeResidents_vacancy)
	# println("eps_ftr: ", eps_calc(model.n_individuals_searching, model.FullTimeResidents_vacancy))
	# println("vac_vis: ", model.Visitors_vacancy)
	# println("eps_vis: ", eps_calc(model.n_visitoragents_searching, model.Visitors_vacancy))
	# println()

	return model
end

function update_unoccupied_counts!(model)
	# agent counts
	model.n_unoccupied_searching = length(GetAgentIdsNotInParcel(model, UnoccupiedOwnerAgent))
	model.n_unoccupied_total = cnt_UnoccupiedOwner_agnts(model)
	model.n_unoccupied_inparcel = model.n_unoccupied_total - model.n_unoccupied_searching

	model.n_unoccupied = cnt_u_prcls(model)
end

function update_individual_counts!(model)
	model.n_individuals_searching = length(GetAgentIdsNotInParcel(model, IndividualAgent))
	model.n_individuals_total = cnt_IndividualOwner_agnts(model)
	model.n_individuals_inparcel = model.n_individuals_total - model.n_individuals_searching

	model.n_OwnedRes = cnt_or_prcls(model)

	model.FullTimeResidents_total = cnt_n_people(model, IndividualAgent)
	model.FullTimeResidents_inparcel = cnt_n_people_parcel(model, IndividualAgent)
	model.FullTimeResidents_searching = cnt_n_people_searching(model, IndividualAgent)


end

function update_landlord_counts!(model)
	model.n_landlords_searching = length(GetAgentIdsNotInParcel(model, LandlordAgent))
	model.n_landlords_total = cnt_Landlord_agnts(model)
	model.n_landlords_inparcel = model.n_landlords_total - model.n_landlords_searching

	model.n_RentlRes = cnt_rr_prcls(model)
	model.n_LOSR = cnt_losr_prcls(model)

end

function update_company_counts!(model)
	model.n_companies_searching = length(GetAgentIdsNotInParcel(model, CompanyAgent))
	model.n_companies_total = cnt_Company_agnts(model)
	model.n_companies_inparcel = model.n_companies_total - model.n_companies_searching

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
			if typeof(model[agent_id])==IndividualAgent || typeof(model[agent_id])==VisitorAgent
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

	model.Visitors_vacancy = sum(max_n_agents_vs) - sum(n_agents_vs)
	model.Visitors_vacancy < 0 && (model.Visitors_vacancy = 0)
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

	t_csz = input[input[:,"Variable"] .== "n_years", "Value"][1]
	n_sims = input[input[:,"Variable"] .== "n_sims", "Value"][1]
	hazard_recurrence = input[input[:,"Variable"] .== "hazard_recurrence", "Value"][1]
	distance_decay_exponent = input[input[:,"Variable"] .== "distance_decay_exponent", "Value"][1]

	# --- population information
	FullTimeResident_growth_rate = input[input[:,"Variable"] .== "FullTimeResident_growth_rate", "Value"][1]
	FullTimeResident_carrying_cap = input[input[:,"Variable"] .== "FullTimeResident_carrying_cap", "Value"][1]

	Visitor_growth_rate = input[input[:,"Variable"] .== "Visitor_growth_rate", "Value"][1]
	Visitor_carrying_cap = input[input[:,"Variable"] .== "Visitor_carrying_cap", "Value"][1]

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
	Individual_budget_mean = input[input[:,"Variable"] .== "Individual_budget_mean", "Value"][1]
	Individual_budget_std = input[input[:,"Variable"] .== "Individual_budget_std", "Value"][1]
	Individual_price_goods = input[input[:,"Variable"] .== "Individual_price_goods", "Value"][1]
	Individual_number_parcels_aware = input[input[:,"Variable"] .== "Individual_number_parcels_aware", "Value"][1]	
	Individual_household_change_rate = input[input[:,"Variable"] .== "Individual_household_change_rate", "Value"][1]
	Individual_household_change_dist = Exponential(Individual_household_change_rate)
	Household_alphas = PreferenceMatrix[!, "household"][1:4]
	Household_alpha_std = PreferenceMatrix[!, "household"][5]
	
	Household_alphas = setup_alphas(Household_alphas, Household_alpha_std)
	Individual_budget = setup_budget(Individual_budget_mean, Individual_budget_std)


	# -- Visitor agent information
	Visitor_number_parcels_aware = input[input[:,"Variable"] .== "Visitor_number_parcels_aware", "Value"][1]	
	Visitor_alphas = PreferenceMatrix[!, "visitor"][1:4]
	Visitor_alpha_std = PreferenceMatrix[!, "visitor"][5]
	Visitor_alphas = setup_alphas(Visitor_alphas, Visitor_alpha_std)

	# -- Landlord agent information
	Landlord_budget_mean = input[input[:,"Variable"] .== "Landlord_budget_mean", "Value"][1]
	Landlord_budget_std = input[input[:,"Variable"] .== "Landlord_budget_std", "Value"][1]
	Landlord_price_goods = input[input[:,"Variable"] .== "Landlord_price_goods", "Value"][1]
	Landlord_number_parcels_aware = input[input[:,"Variable"] .== "Landlord_number_parcels_aware", "Value"][1]	
	Landlord_number_searching = input[input[:,"Variable"] .== "Landlord_number_searching", "Value"][1]	
	Landlord_transition_penalty = input[input[:,"Variable"] .== "Landlord_transition_penalty", "Value"][1]
	Landlord_alphas_RR = PreferenceMatrix[!, "rentl_res"][1:4]
	Landlord_alpha_RR_std = PreferenceMatrix[!, "rentl_res"][5]	
	Landlord_alphas_LOSR = PreferenceMatrix[!, "losr"][1:4]
	Landlord_alpha_LOSR_std = PreferenceMatrix[!, "losr"][5]

	Landlord_alphas_RR = setup_alphas(Landlord_alphas_RR, Landlord_alpha_RR_std)
	Landlord_alphas_LOSR = setup_alphas(Landlord_alphas_LOSR, Landlord_alpha_LOSR_std)
	Landlord_budget = setup_budget(Landlord_budget_mean, Landlord_budget_std)


	# -- Company agent information
	Company_budget_mean = input[input[:,"Variable"] .== "Company_budget_mean", "Value"][1]
	Company_budget_std = input[input[:,"Variable"] .== "Company_budget_std", "Value"][1]
	Company_price_goods = input[input[:,"Variable"] .== "Company_price_goods", "Value"][1]
	Company_number_parcels_aware = input[input[:,"Variable"] .== "Company_number_parcels_aware", "Value"][1]
	Company_number_searching = input[input[:,"Variable"] .== "Company_number_searching", "Value"][1]	
	Company_alphas_HOR = PreferenceMatrix[!, "hor"][1:4]
	Company_alpha_HOR_std = PreferenceMatrix[!, "hor"][5]	
	Company_alphas_HOSR = PreferenceMatrix[!, "hosr"][1:4]
	Company_alpha_HOSR_std = PreferenceMatrix[!, "hosr"][5]

	Company_alphas_HOR = setup_alphas(Company_alphas_HOR, Company_alpha_HOR_std)
	Company_alphas_HOSR = setup_alphas(Company_alphas_HOSR, Company_alpha_HOSR_std)
	Company_budget = setup_budget(Company_budget_mean, Company_budget_std)

	# -- Real estate agent information
	RealEstate_LandBasePrice = input[input[:,"Variable"] .== "RealEstate_LandBasePrice", "Value"][1]


	# --- conversions to correct datatypes
	n_sims = convert(Int64, n_sims)
	t_csz = convert(Int64, t_csz)
	hazard_recurrence = convert(Int64, hazard_recurrence)
	Individual_number_parcels_aware = convert(Int64, Individual_number_parcels_aware)

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
		
		nhousehold_dist=nhousehold_dist,
		nvisitor_dist=nvisitor_dist,
		age_dist=age_dist,
		
		Individual_budget=Individual_budget,
		Individual_price_goods=Individual_price_goods,
		Individual_number_parcels_aware=Individual_number_parcels_aware,
		Individual_household_change_dist=Individual_household_change_dist,
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

		Company_budget=Company_budget,
		Company_price_goods=Company_price_goods,
		Company_number_parcels_aware=Company_number_parcels_aware,
		Company_number_searching=Company_number_searching,
		Company_alphas_HOR=Company_alphas_HOR,
		Company_alphas_HOSR=Company_alphas_HOSR,

		LandBasePrice=RealEstate_LandBasePrice,

		FullTimeResident_growth_rate=FullTimeResident_growth_rate,
		FullTimeResident_carrying_cap=FullTimeResident_carrying_cap,
		Visitor_growth_rate=Visitor_growth_rate,
		Visitor_carrying_cap=Visitor_carrying_cap,
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








