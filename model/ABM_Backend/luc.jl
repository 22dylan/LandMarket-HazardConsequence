module luc


function luc_step!(agent, model)
	IDs = get_prcl_IDs(model)
	TPs = get_prcl_TPs(model, IDs)
	NSs = get_prcl_NSs(model, IDs)
	update_prcl_states!(model, agent, IDs, TPs, NSs)
	update_growthrate!(model, agent)
end


function get_prcl_IDs(model)
	#= get parcel IDs
	=#
	IDs = Int[]
	for id in keys(model.agents)
		if model[id].agent_type == "parcel"
			push!(IDs, id)
		end
	end
	return IDs
end


function get_prcl_TPs(model, IDs)
	#= Get parcel transition potentials
	=#
	TPs = Float64[]
	for id in IDs
		push!(TPs, model[id].tp)
	end
	return TPs

end


function get_prcl_NSs(model, IDs)
	#= get parcel next states
	=#
	NSs = String[]
	for id in IDs
		push!(NSs, model[id].ptnl_state)
	end
	return NSs


end


function update_prcl_states!(model, agent, IDs, TPs, NSs)
	#= updating the parcel states by sorting by transition potential
	=#
	sort_idx = sortperm(TPs, rev=true)
	TPs = TPs[sort_idx]
	IDs = IDs[sort_idx]
	NSs = NSs[sort_idx]
	bc = model.building_codes 	# getting building codes
	cnt = 0
	i = 1
	while cnt < agent.num_luc
		id = IDs[i]

		if model[id].landuse != NSs[i]	# if agent land use is different than potential next state
			model[id].landuse = NSs[i]	# update the land use

			# udpating building code
			bc_ = bc[bc[:,"lu_to"] .== NSs[i], "BuildingCode"][1]
			new_yb = seismiccode_to_year(bc_)
			if model[id].year_built < new_yb
				model[id].year_built = new_yb
			end
			cnt+=1 # updating counter for changes
		end
		i+=1 		# updating parcel to consider
	end
end


function update_growthrate!(model, agent)
	agent.num_luc_avail += agent.num_luc_avail*agent.luc_growthrate
	agent.num_luc = convert(Int64, round(agent.num_luc_avail))
end


function seismiccode_to_year(sc)
	#= The seismic codes are default mapped to years in pyIncore and HAZUS.
		Assuming that the mappings (None, L, M, and H) correspond to the mid point
		of the year built range.

		None:     before 1979
		Low:      1979-1995
		Moderate: 1995-2008
		High:     2008-Present
	=#
	s2y = Dict(
			"None" => 1,
			"L" => 1987,
			"M" => 2000,
			"H" => 2021
			)
	return s2y[sc]

end

end















