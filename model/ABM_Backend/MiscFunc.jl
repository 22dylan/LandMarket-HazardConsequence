# file for miscellaneous functions


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


function read_csv(f::String)
	#= reading in CSV file at path "f"
	=#
	df = DataFrame(CSV.File(f))
	return df
end


"""  
	setup_pycall()
setup pyCall with julia distribution of conda
See Conda.jl for how to install conda pacakages to julia distribution of conda
See pyCall.jl for additional instructions of using pyton modules
If adding new packages to Julia's conda environment, may need to run Pkg.build again
"""	
function setup_pycall()
	# ENV["PYTHON"] = ""
	# Pkg.build("PyCall")

	# preparing python script with misc. python operations that will be used (e.g., incore)
	scriptdir = @__DIR__
	pushfirst!(PyVector(pyimport("sys")."path"), scriptdir)
	pycall_jl = pyimport("PythonOperations")
	PYTHON_OPS = pycall_jl.misc_python_ops() # setting up python operations
end


