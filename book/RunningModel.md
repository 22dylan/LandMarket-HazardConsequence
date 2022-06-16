# Running the Model

The source code for the model is available in [this repository](https://github.com/22dylan/UrbanChange-HazardConsequence). The source code and input files can be downloaded here.

## Code and Package Versions
The model was written using both Julia and Python. The urban change part of the model is written in Julia whereas the damage and loss component is written in python using [IN-CORE](https://incore.ncsa.illinois.edu). As tested, **Julia 1.7.1** and **python 3.9.5** were used.

The Julia packages used are in the table below.

| Package 	| Version 	| 
| ---		| --- 		|
| Agents	| 4.5.7		|
| CSV		| 0.8.5		|
| Conda		| 1.5.2 	|
| DataFrames | 1.2.2 	|
| Distributions | 0.25.41 |
| PyCall	| 1.92.3	|
| Random	| -		|
| StatsBase	| 0.33.12	|
| ProgressMeter | 1.7.1 |

The python packages used are in the table below:

| Package 	| Version 	| 
| ---		| --- 		|
| os 		| -			|
| shutil	| - 		|
| numpy		| 1.21.2 	|
| pandas 	| 1.3.3 	|
| geopandas	| 0.9.0		|
| pyincore 	| 1.3.0		|

## Run the Model

To run the model, install the necessary codes and pacakage versions as shown above. Next download the source code in [this repository](https://github.com/22dylan/UrbanChange-HazardConsequence). The model is contained in the subdirectory `UrbanChange-HazardConsequence/model` There are 10 input model runs in the subfolder `UrbanChange-HazardConsequence/model/model_in`. The user can change input files and parameters as discussed [here](input-label). 

The user can define which input model to run by opening the `run.jl` file, navigating to the end of this file and updating the model runname to consider in the variable *model_runnames*. 

After downloading the source code and input files, updating which model run to consider in `run.jl`, navigate to the main model folder, `UrbanChange-HazardConsequence/model/`, and type the following in the terminal:

```
julia --project=ABM_env run.jl
```
