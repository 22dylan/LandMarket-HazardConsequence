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



function length_iter(iter)
	n=0
	for i in iter  
		n+=1
	end
	return n
end


# ------------
end









