module parcel
# module for parcels

using Agents
using Random
using Distributions



function parcel_step!(agent, model)
	#= 
		Step function for parcels in model
	=#
	transition_calc(agent, model)
	return
end


function check_agent_status(agent; guid::String="81de8e94-b42c-4810-9142-b02fd740c147", vari=nothing)
	if agent.guid == guid
		println()
		display(vari)
		println()
	end
end


function parcel_CSZ_step!(agent, model)
	agent.MC_DS = mc_sample!(agent.LS_0, agent.LS_1, agent.LS_2)
end


function transition_calc(agent, model)
	#= transition rules adapted from White and Engelen (2000)
		also used in Hemmati et al. (2021)

		# TODO: description

	=#
	to_states = ["unoccupied", "residential", "commercial", "seasonal_rental"]
	n_states = length(to_states)
	#= pre-allocating space, each row corresponds to a potential state, each
		column to a contributing feature. Here defined as:
			0 - stochastic term
			1 - accessibility to transportation network
			2 - intrisic suitability
			3 - zoning status
			4 - neighborhood effect
	=#
	transition_potentials = ones(Float64, n_states, 5)

	# --- stochastic term
	alpha = ones(n_states)*model.stochastic_alpha
	transition_potentials[:,1] .= stochastic_term.(alpha)


	# --- accessibility term
	accessibility = dist_to_feature_calcs("road", agent.d_road1, model, add_one=true)
	transition_potentials[:,2] = accessibility


	# --- suitability term
	features = ["coast", "greenspace"]
	dists = [agent.d_coast, agent.d_grnspc]
	suitability = zeros(length(to_states), length(dists))
	for (f_i, feat) in enumerate(features)
		suit_ = dist_to_feature_calcs(feat, dists[f_i], model, add_one=false)
		suitability[:,f_i] = suit_
	end

	suitability = sum(suitability, dims=2)
	suitability .+= 1
	transition_potentials[:,3] = suitability

	# --- zoning term
	zoning_status = filter(row->row.Zone==agent.zone_type, model.zoning_params)
	transition_potentials[:,4] = Vector(zoning_status[1, 2:5])


	# --- neighborhood term
	# nghbrhd_df = filter(row->row.from==agent.landuse, model.nghbrhg_params)
	# neighbrs = nearby_agents(agent, model, model.luc_radius)
	# nghr_df = zeros(length(to_states), length_iter(neighbrs))
	# i = 1
	# for neighbr in neighbrs
	# 	if neighbr.agent_type == "LUCAgent"
	# 		continue
	# 	end
	# 	temp = filter(row->row.k==neighbr.landuse, nghbrhd_df)
	# 	d_nghbr = edistance(agent, neighbr, model)
	# 	d_nghbr = ones(Float64, size(temp)[1])*d_nghbr
	# 	m = gaussian_function.(temp.a, temp.b, temp.c, temp.d, d_nghbr)
	# 	nghr_df[:,i] = m
	# 	i += 1
	# end
	# n = sum(nghr_df, dims=2)
	# n = n.*model.nghbr_weight
	# n .+= 1
	# transition_potentials[:,5] = n



	# --- NOTE: Temporary neighborhood term
	nghbrhd_df = filter(row->row.from==agent.landuse, model.nghbrhg_params)
	neighbrs = nearby_agents(agent, model, model.luc_radius)
	nghr_df = zeros(length(to_states), length_iter(neighbrs))
	i = 1
	cnt = 1
	for neighbr in neighbrs
		if neighbr.agent_type == "LUCAgent"
			continue
		end
		if cnt == 9
			break
		end
		temp = filter(row->row.k==neighbr.landuse, nghbrhd_df)
		d_nghbr = edistance(agent, neighbr, model)
		d_nghbr = ones(Float64, size(temp)[1])*d_nghbr
		m = gaussian_function.(temp.a, temp.b, temp.c, temp.d, d_nghbr)
		nghr_df[:,i] = m
		i += 1
		cnt += 1
	end
	n = sum(nghr_df, dims=2)
	n = n.*model.nghbr_weight
	n .+= 1
	transition_potentials[:,5] = n

	# ---



	# --- inertia effect 
	H = [agent.landuse==i for i in to_states]
	H = H.*model.parcel_inertia	# inertia effect


	# --- getting total transition potential
	transition_potentials = prod(transition_potentials, dims=2)
	transition_potentials = transition_potentials .+ H
	# check_agent_status(agent, guid="c94c3f94-7a78-4ee2-a0a2-3067fdf893dc", vari=transition_potentials)

	ptnl_idx = argmax(transition_potentials)
	agent.tp = transition_potentials[ptnl_idx[1]]
	agent.ptnl_state = to_states[ptnl_idx[1]]

end


function dist_to_feature_calcs(feat, d_feat, model; add_one::Bool=false)
	#= function for getting accessibility and suitability terms.
		uses the gaussian function and distance from feature
		gaussian function parameterization must be in the suitability_params input file
	=#
	temp = filter(row -> row.d_to ==feat, model.suitability_params)
	d_feat = ones(Float64, size(temp)[1])*d_feat
	accessibility = gaussian_function.(temp.a, temp.b, temp.c, temp.d, d_feat, model.suitability_radius)
	if add_one == true
		accessibility .+= 1
	end
	return accessibility
end


function gaussian_function(a, b, c, d, x, trunc::Float64=Inf)
	#= gaussian function used throughout
	=#
	if x > trunc  # truncating gaussian function to maximum distance.
		return 0
	else
		f = a*exp(-((x-b)^2)/(2*(c^2))) + d
		return f
	end
end

function length_iter(iter)
	#= returns length of an iterator
	=#
	n=0
	for i in iter  
		n+=1
	end
	return n
end

function stochastic_term(alpha)
	#= returns stochastic term in transition potential
	=#
	rv = rand()
	eps = 1 + (-log(rv))^alpha
	return eps
end

function mc_sample!(LS_0, LS_1, LS_2)::Int64
	#= Monte-Carlo sample of damage state
		given limit states LS_0, LS_1, LS_2
		returns a discrete value associated with the Monte-Carlo damage state
	=#
	rv = rand()
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



# ------------
end






