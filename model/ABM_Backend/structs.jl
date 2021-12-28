#=
File for defining structs that are used in model.
Includes structs for model parameters, agents, and space
=#

Base.@kwdef mutable struct Parameters
	# model values
	tick::Int64 = 1
	t_csz::Int64
	hazard_recurrence::Int64
	distance_decay_exponent::Float64
	zoning_params::DataFrame
	progress_bar::Progress 
	n_prcls::Int64

	# Unoccupied owner agent
	Unoccupied_WTA::Float64

	# Individual/Household agent
	Individual_WTA::Float64
	Individual_alpha1::Float64
	Individual_alpha2::Float64
	Individual_alpha3::Float64
	Individual_budget_dist::Distribution
	Individual_price_goods::Float64
	Individual_number_parcels_aware::Int64
	Individual_age_dist::Distribution
	Individual_nhousehold_dist::Distribution

	# Landlord agent
	Landlord_WTA::Float64
	Landlord_RR_alpha1::Float64
	Landlord_RR_alpha2::Float64
	Landlord_RR_alpha3::Float64
	Landlord_LOSR_alpha1::Float64
	Landlord_LOSR_alpha2::Float64
	Landlord_LOSR_alpha3::Float64
	Landlord_budget_dist::Distribution
	Landlord_price_goods::Float64
	Landlord_number_parcels_aware::Int64
	Landlord_number_searching::Int64
	Landlord_age_dist::Distribution
	Landlord_transition_penalty::Int64

	# Develoepr agent
	Developer_WTA::Float64
	Developer_HOR_alpha1::Float64
	Developer_HOR_alpha2::Float64
	Developer_HOR_alpha3::Float64
	Developer_HOSR_alpha1::Float64
	Developer_HOSR_alpha2::Float64
	Developer_HOSR_alpha3::Float64
	Developer_budget_dist::Distribution
	Developer_price_goods::Float64
	Developer_number_parcels_aware::Int64
	Developer_number_searching::Int64
	
	# people counts/population growth
	FullTimeResident_growth_rate::Float64
	FullTimeResident_carrying_cap::Float64
	FullTimeResident_init::Float64 = 0
	FullTimeResidents_inparcel::Int64 = 0
	FullTimeResidents_searching::Int64 = 0
	FullTimeResidents_total::Int64 = 0

	Visitor_growth_rate::Float64
	Visitor_carrying_cap::Float64
	Visitor_init::Float64 = 0	
	Visitor_total::Int64 = 0


	# agent counts
	n_unoccupied_init::Int64 = 0
	n_unoccupied_inparcel::Int64 = 0
	n_unoccupied_searching::Int64 = 0
	n_unoccupied_total::Int64 = 0

	n_individuals_init::Int64 = 0
	n_individuals_inparcel::Int64 = 0
	n_individuals_searching::Int64 = 0
	n_individuals_total::Int64 = 0

	n_landlords_init::Int64 = 0
	n_landlords_inparcel::Int64 = 0
	n_landlords_searching::Int64 = 0
	n_landlords_total::Int64 = 0

	n_developers_init::Int64 = 0
	n_developers_inparcel::Int64 = 0
	n_developers_searching::Int64 = 0
	n_developers_total::Int64 = 0

	n_agents_end_iteration::Int64

	# parcel counts
	n_unoccupied::Int64 = 0
	n_OwnedRes::Int64 = 0
	n_RentlRes::Int64 = 0
	n_LOSR::Int64 = 0
	n_HOR::Int64 = 0
	n_HOSR::Int64 = 0
	n_comm::Int64 = 0
end



Base.@kwdef struct ParcelSpace <: Agents.AbstractSpace
	s::Array{Vector{Int},1}					# agent id(s) in parcel
	owner::Array{Vector{Int},1}				# agent id that owns parcel
	
	landuse::Array{Vector{String},1}		# land use
	n_agents::Array{Vector{Int},1}			# number of agents associated with parcel (e.g., number of households, landlords, developers)
	max_n_agents::Array{Vector{Int},1}		# maximum number of agents
	n_people::Array{Vector{Int},1}			# number of people in parcel (actual num. of people)

	zone_type::Array{Vector{String},1}		# zone type
	x::Array{Vector{Float64},1}				# x-location of s
	y::Array{Vector{Float64},1}				# y-location of s
	guid::Array{Vector{String},1}			# guid of parcel
	strct_typ::Array{Vector{String},1} 		# structure type
	year_built::Array{Vector{Int},1}		# year built
	no_stories::Array{Vector{Int},1}		# number of stories

	LS_0::Array{Vector{Float64},1}			# monte-carlo damage state
	LS_1::Array{Vector{Float64},1}			# monte-carlo damage state
	LS_2::Array{Vector{Float64},1}			# monte-carlo damage state
	MC_DS::Array{Vector{Int},1}				# monte-carlo damage state
	
	d_coast::Array{Vector{Float64},1}		# distance to coast
	d_commasst::Array{Vector{Float64},1}	# distance to community-asset
end


Base.@kwdef mutable struct UnoccupiedOwnerAgent <: AbstractAgent
	id::Int
	pos::String
	WTA::Float64
	prcl_on_mrkt::Bool
	looking_to_purchase::Bool
	own_parcel::Bool
	utility::Float64 = 0
end

Base.@kwdef mutable struct IndividualAgent <: AbstractAgent
	id::Int
	pos::String
	alpha1::Float64
	alpha2::Float64
	alpha3::Float64
	budget::Float64
	price_goods::Float64
	number_prcls_aware::Int64
	prcl_on_mrkt::Bool
	looking_to_purchase::Bool
	WTA::Float64
	age::Int64
	own_parcel::Bool
	num_people::Int64
	utility::Float64 = 0
end


Base.@kwdef mutable struct LandlordAgent <: AbstractAgent
	id::Int
	pos::String
	alpha1_RR::Float64
	alpha2_RR::Float64
	alpha3_RR::Float64
	alpha1_LOSR::Float64
	alpha2_LOSR::Float64
	alpha3_LOSR::Float64
	budget::Float64
	price_goods::Float64
	number_prcls_aware::Int64
	prcl_on_mrkt::Bool
	looking_to_purchase::Bool
	WTA::Float64
	age::Int64
	own_parcel::Bool
	transition_penalty::Int64
	utility::Float64 = 0
end


Base.@kwdef mutable struct DeveloperAgent <: AbstractAgent
	id::Int
	pos::String
	alpha1_HOR::Float64
	alpha2_HOR::Float64
	alpha3_HOR::Float64
	alpha1_HOSR::Float64
	alpha2_HOSR::Float64
	alpha3_HOSR::Float64
	budget::Float64
	price_goods::Float64
	number_prcls_aware::Int64
	prcl_on_mrkt::Bool
	looking_to_purchase::Bool
	WTA::Float64
	own_parcel::Bool
	utility::Float64 = 0
end


