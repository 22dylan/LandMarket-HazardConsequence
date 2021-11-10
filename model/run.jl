include(joinpath("ABM_Backend","MiscFunc.jl"))
include(joinpath("ABM_Backend","MyModel.jl"))
include(joinpath("ABM_Backend","MyParcelSpace.jl"))
# include(joinpath("ABM_Backend","MyAgents.jl"))

using Agents
using CSV
using DataFrames

using .misc_func
using .my_model

# println((my_model.MyAgents.IndividualAgent))
# fds
#=	
	NOTES
	-------
	+ to run from terminal with correct environment use:
		- julia --project=../ABM_env run.jl
=#


#= 
	TODO List:
	--------------
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
	adata = [:pos]

	sdata = [
			:s, 
			:landuse, 
			:strct_typ, 
			:year_built, 
			:no_stories, 
			:MC_DS, 
			:LS_0,
			:LS_1,
			:LS_2,
			]

	# TODO: resetup these. identifying which model-level output data to collect
	# cnt_u_prcls(model) = count(model[a].landuse=="unoccupied" for a in my_model.scheduler_by_type(model, "parcel", false)) 
	cnt_u_prcls(model) = count(lu=="unoccupied" for lu in GetAllParcelAttributes(model, model.space.landuse))
	cnt_or_prcls(model) = count(lu=="owned_res" for lu in GetAllParcelAttributes(model, model.space.landuse))
	cnt_UnoccupiedOwner_agnts(model) = my_model.count_agnt_types(model, my_model.MyAgents.UnoccupiedOwnerAgent)
	cnt_IndividualOwner_agnts(model) = my_model.count_agnt_types(model, my_model.MyAgents.IndividualAgent)

	mdata = [
			cnt_u_prcls, 
			cnt_or_prcls, 
			cnt_UnoccupiedOwner_agnts,
			cnt_IndividualOwner_agnts,
			]


	# --- Running model
	for i = 1:n_sims
		model = my_model.initialize(input_dict, input_folder, seed=seed, iter=i)
		println("Starting iteration: $i/$n_sims")
		data_a, data_m, data_s = my_run!(
									model,
									dummystep,
									my_model.complex_model_step!,
									n_years;
									adata=adata,
									mdata=mdata,
									sdata=sdata,
									)

		# --- saving results for iteration
		fn_agnts = "df_agnts_$i.csv"
		misc_func.write_out(data_a, model_runname, fn_agnts)

		fn_model = "df_model_$i.csv"
		misc_func.write_out(data_m, model_runname, fn_model)

		fn_space = "df_space_$i.csv"
		misc_func.write_out(data_s, model_runname, fn_space)
	end
end

"""
	my_run!()
Custom model run function. 
Started from example on Agents.jl docs
Needed to customize to collect space (pacel) data during model time steps
"""
function my_run!(model,
				agent_step!,
				model_step!,
				n;
				when = true,
				when_model = when,
				mdata = nothing,
				adata = nothing,
				sdata = nothing,
				)

	df_agent = init_agent_dataframe(model, adata)
	df_model = init_model_dataframe(model, mdata)
	df_space = init_space_dataframe(model, sdata)
	s = 0
	while Agents.until(s, n, model)
	  if should_we_collect(s, model, when)
		  collect_agent_data!(df_agent, model, adata, s)
		  collect_model_data!(df_model, model, mdata, s)
		  collect_space_data!(df_space, model, sdata, s)
	  end
	  step!(model, agent_step!, model_step!, 1)
	  s += 1
	end
	if should_we_collect(s, model, when)
		collect_agent_data!(df_agent, model, adata, s)
		collect_model_data!(df_model, model, mdata, s)
		collect_space_data!(df_space, model, sdata, s)
	end
	return df_agent, df_model, df_space
end


"""
	init_space_dataframe()
Function to initialize space dataframe.
Used to store space (parcel) results for output
"""
function init_space_dataframe(Model::ABM{S,A}, properties::AbstractArray) where {S,A<:AbstractAgent}
	std_headers = 2

	headers = Vector{String}(undef, std_headers + length(properties))
	headers[1] = "step"
	headers[2] = "guid"

	for i in 1:length(properties)
		headers[i+std_headers] = dataname(properties[i])
	end

	types = Vector{Vector}(undef, std_headers + length(properties))
	types[1] = Int[]
	types[2] = String[]
	for (i, field) in enumerate(properties)
		types[i+2] = eltype(eltype(typeof(getfield(Model.space, field))))[]
	end

	return DataFrame(types, headers)
end



"""
	collect_space_data!()
Function to collect space (parcel) data from model at each time step
"""
function collect_space_data!(df, model, properties::Vector, step::Int = 0)
    guid = GetAllParcelAttributes(model, model.space.guid)

    dd = DataFrame()
    dd[!, :step] = fill(step, length(guid))
    dd[!, :guid] = guid
    for fn in properties
    	data = GetAllParcelAttributes(model, getfield(model.space, fn))
        dd[!, fn] = data
    end
    append!(df, dd)
    return df
end



# ------------
model_runname = "S0_testbed"
println()
println("Running Model: $model_runname")
println()
main(model_runname)





