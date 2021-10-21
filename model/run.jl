include(joinpath("ABM_Backend","misc_func.jl"))
include(joinpath("ABM_Backend","my_model.jl"))

using Agents
using CSV

using .misc_func
using .my_model


#=	
	NOTES
	-------
	+ to run from terminal with correct environment use:
		- julia --project=../ABM_env/ run.jl
=#


#= 
	TODO List:
	--------------
	+ figure out if there's a way to better handle multiple agents
		- LUCAgent doesn't have a position in Seaside, but needs to have it 
		  for the model to run. Issues with getting neighbors. 
		- called mixed model in documentation?
		- see also advanced stepping (https://juliadynamics.github.io/Agents.jl/stable/tutorial/#Advanced-stepping)
	+ figure out where to put PYTHON_OPS.complete_run()

=#


# ------------
function main(model_runname)

	input_folder = joinpath(pwd(), "model_in", model_runname)
	input_dict = misc_func.read_input_folder(input_folder)
	df_input = input_dict["Input"]

	display(df_input)
	println()

	n_sims = df_input[df_input[:,"Variable"] .== "n_sims", "Value"][1]
	n_sims = convert(Int64, n_sims)

	n_years = df_input[df_input[:,"Variable"] .== "n_years", "Value"][1]
	n_years = convert(Int64, n_years)

	seed = df_input[df_input[:,"Variable"] .== "seed", "Value"][1]
	seed = convert(Int64, seed)


	# identifying which output data to collect for agents
	adata = [:guid, :landuse, :MC_DS]


	# identifying which output data to collect for model
	cnt_u_prcls(model) = count(model[a].landuse=="unoccupied" for a in my_model.scheduler_by_type(model, "parcel", false)) 
	cnt_r_prcls(model) = count(model[a].landuse=="residential" for a in my_model.scheduler_by_type(model, "parcel", false)) 
	cnt_c_prcls(model) = count(model[a].landuse=="commercial" for a in my_model.scheduler_by_type(model, "parcel", false)) 
	cnt_sr_prcls(model) = count(model[a].landuse=="seasonal_rental" for a in my_model.scheduler_by_type(model, "parcel", false)) 
	mdata = [
			cnt_u_prcls, 
			cnt_r_prcls, 
			cnt_c_prcls,
			cnt_sr_prcls, 
			]



	# --- Running model
	for i = 1:n_sims
		model = my_model.initialize(input_dict, input_folder, seed=seed, iter=i)
		# run(`clear`)
		println("Starting iteration: $i/$n_sims")
		data_a, data_m = run!(model,
					dummystep,
					my_model.complex_model_step!,
					n_years;
					adata=adata,
					mdata=mdata
					)
		fn_agnts = "df_agnts_$i.csv"
		misc_func.write_out(data_a, model_runname, fn_agnts)

		fn_model = "df_model_$i.csv"
		misc_func.write_out(data_m, model_runname, fn_model)
	end

end



# ------------
model_runname = "S5_TestbedAlt"
println()
println("Running Model: $model_runname")
println()
main(model_runname)





