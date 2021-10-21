module misc_func

using Agents
using DataFrames
using CSV
using PyCall
using ProgressMeter

# module for miscellaneous options


function read_input_folder(path::String)

	all_in_dir = readdir(path)
	files = String[]
	dirs = String[]
	for f in all_in_dir
		if '.' in f
			push!(files, f)
		else
			push!(dirs, f)
		end
	end

	input_dict = Dict()
	for f in files
		key = split(f, ".")[1]
		f = joinpath(path, f)
		input_dict[key] = read_csv(f)
	end
	return input_dict
end

function makedir(dir)
	if ~isdir(dir)
		mkpath(dir)
	end
end


function write_out(data, model_runname, filename)
	#= writing output dataframe to file
	=#
	i = 0
	path_out = joinpath(pwd(), "model_out", model_runname)
	makedir(path_out)
	fn = joinpath(path_out, filename)
	CSV.write(fn, data)
	
end

function gdf_from_subdirectory(path::String, d::String)
	all_in_dir = readdir(joinpath(path, d))
	for f in all_in_dir
		if occursin("shp", f)
			path = joinpath(path, d, f)
			df = read_shapefile(path)
			return df
		end
	end


end

function pd_to_df(df_pd)
	#= convert from pandas pyobject to a julia dataframe
		Pandas in python stores strings as "objects".
		Manually converting the following cols julia strings:
			struct_typ
			dgn_lvl
			zone
			zone_type
	=#

	colnames = map(String, df_pd[:columns])
	df = DataFrame(Any[Array(df_pd[c].values) for c in colnames], colnames)
	df[!,"guid"] = convert.(String,df[!,"guid"])
	df[!,"struct_typ"] = convert.(String,df[!,"struct_typ"])
	df[!,"dgn_lvl"] = convert.(String,df[!,"dgn_lvl"])
	df[!,"zone"] = convert.(String,df[!,"zone"])
	df[!,"zone_type"] = convert.(String,df[!,"zone_type"])
	df[!,"landuse"] = convert.(String,df[!,"landuse"])
    return df
end


function read_csv(f::String)
	#= reading in CSV file at path "f"
	=#
	df = DataFrame(CSV.File(f))
	return df
end

function read_shapefile(f::String, return_only_geoms::Bool=false)
	#= reading in shapefile at path "f"
	=#
	table = Shapefile.Table(f)
	if return_only_geoms==true
		geoms = Shapefile.shapes(table)
		return geoms
	end
	df = DataFrame(table)
	return df
end



function geom_bounds(gdf; get_ceil::Bool=true)
	#=	getting geometry boundaries
		returns 4 items: (1) minx, (2) maxx, (3) miny, and (4) maxy
	=#

	minx = minimum(gdf[:,"x"])
	maxx = maximum(gdf[:,"x"])
	miny = minimum(gdf[:,"y"])
	maxy = maximum(gdf[:,"y"])
	if get_ceil==true
		maxx = ceil(maxx)
		maxy = ceil(maxy)
	end
	return minx, miny, maxx, maxy

end


function set_up_model_properties(input_dict, space_conv, iter)
	input = input_dict["Input"]
	t_csz = input[input[:,"Variable"] .== "n_years", "Value"][1]
	n_sims = input[input[:,"Variable"] .== "n_sims", "Value"][1]
	n_sims = convert(Int64, n_sims)
	
	hazard_recurrence = input[input[:,"Variable"] .== "hazard_recurrence", "Value"][1]

	luc_radius = input[input[:,"Variable"] .== "luc_radius_m", "Value"][1]
	luc_initial = input[input[:,"Variable"] .== "luc_initial", "Value"][1]
	luc_growthrate = input[input[:,"Variable"] .== "luc_growthrate", "Value"][1]
	
	suitability_radius = input[input[:,"Variable"] .== "suitability_radius_m", "Value"][1]
	parcel_inertia = input[input[:,"Variable"] .== "parcel_inertia", "Value"][1]
	stochastic_alpha = input[input[:,"Variable"] .== "stochastic_alpha", "Value"][1]
	nghbr_weight = input[input[:,"Variable"] .== "nghbr_weight", "Value"][1]

	t_csz = convert(Int64, t_csz)
	hazard_recurrence = convert(Int64, hazard_recurrence)

	building_codes = input_dict["BuildingCodes"]
	nghbrhg_params = input_dict["Nghbrhd_Transition_params"]
	suitability_params = input_dict["Suitability_params"]
	zoning_params = input_dict["zoning_params"]

	p = ProgressBar(iter, n_sims, t_csz)
	update!(p)

	prop_dict = Dict(
			:t_csz => t_csz,
			:hazard_recurrence => hazard_recurrence,
			:luc_radius => luc_radius,
			:luc_initial => luc_initial, 
			:luc_growthrate => luc_growthrate,
			:suitability_radius => suitability_radius,
			:parcel_inertia => parcel_inertia,
			:stochastic_alpha => stochastic_alpha,
			:nghbr_weight => nghbr_weight,
			:tick => 1,
			:building_codes => building_codes,
			:nghbrhg_params => nghbrhg_params,
			:suitability_params => suitability_params,
			:zoning_params => zoning_params,
			:space_conv => space_conv,
			:progress_bar => p
		)
	return prop_dict
end


function length_iter(iter)
	n=0
	for i in iter  
		n+=1
	end
	return n
end

function ProgressBar(i, iters, n_years)
	p = Progress(n_years, 
			desc="Iteration: $i/$iters | ",
			barlen=30, 
			color=:cyan
		)
	return p
end


# ------------
end









