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

	nhousehold_dist::Distribution
	nvisitor_dist::Distribution
	age_dist::Distribution

	# Individual/Household agent
	Individual_budget
	Individual_price_goods::Float64
	Individual_number_parcels_aware::Int64
	Individual_household_change_dist::Distribution
	Household_alphas
	
	# Visitor agent
	Visitor_number_parcels_aware::Int64 = 0
	Visitor_alphas

	# Landlord agent
	Landlord_budget
	Landlord_price_goods::Float64
	Landlord_number_parcels_aware::Int64
	Landlord_number_searching::Int64
	Landlord_transition_penalty::Float64
	Landlord_alphas_RR
	Landlord_alphas_LOSR

	# Company agent
	Company_budget
	Company_price_goods::Float64
	Company_number_parcels_aware::Int64
	Company_number_searching::Int64
	Company_alphas_HOR
	Company_alphas_HOSR
	
	# people counts/population growth
	FullTimeResident_growth_rate::Float64
	FullTimeResident_carrying_cap::Float64
	FullTimeResident_init::Float64 = 0
	FullTimeResidents_inparcel::Int64 = 0
	FullTimeResidents_searching::Int64 = 0
	FullTimeResidents_total::Int64 = 0
	FullTimeResidents_vacancy::Int64 = 0

	# visitor counts/growth
	Visitor_growth_rate::Float64
	Visitor_carrying_cap::Float64
	Visitor_init::Float64 = 0
	Visitors_inparcel::Int64 = 0
	Visitors_searching::Int64 = 0
	Visitors_total::Int64 = 0
	Visitors_vacancy::Int64 = 0

	# Real Estate Agent
	LandBasePrice::Float64 = 0.0
	

	# agent counts
	n_unoccupied_inparcel::Int64 = 0
	n_unoccupied_searching::Int64 = 0
	n_unoccupied_total::Int64 = 0

	n_individuals_inparcel::Int64 = 0
	n_individuals_searching::Int64 = 0
	n_individuals_total::Int64 = 0

	n_landlords_inparcel::Int64 = 0
	n_landlords_searching::Int64 = 0
	n_landlords_total::Int64 = 0

	n_companies_inparcel::Int64 = 0
	n_companies_searching::Int64 = 0
	n_companies_total::Int64 = 0

	n_visitoragents_inparcel::Int64 = 0
	n_visitoragents_searching::Int64 = 0
	n_visitoragents_total::Int64 = 0

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
	
	landuse::Array{Vector{String},1}		# landuse
	prev_landuse::Array{Vector{String},1}	# previous landuse
	landvalue::Array{Vector{Float64},1}		# landuse
	n_agents::Array{Vector{Int},1}			# number of agents associated with parcel (e.g., number of households, landlords, companys)
	max_n_agents::Array{Vector{Int},1}		# maximum number of agents
	n_people::Array{Vector{Int},1}			# number of people in parcel (actual num. of people)

	zone_type::Array{Vector{String},1}		# zone type
	x::Array{Vector{Float64},1}				# x-location of s
	y::Array{Vector{Float64},1}				# y-location of s
	guid::Array{Vector{String},1}			# guid of parcel
	strct_typ::Array{Vector{String},1} 		# structure type
	year_built::Array{Vector{Int},1}		# year built
	no_stories::Array{Vector{Int},1}		# number of stories

	LS_0::Array{Vector{Float64},1}			# limit state 0
	LS_1::Array{Vector{Float64},1}			# limit state 1
	LS_2::Array{Vector{Float64},1}			# limit state 2
	AVG_DS::Array{Vector{Float64},1}			# average damage state
	MC_DS::Array{Vector{Int},1}				# monte-carlo damage state
	
	d_coast::Array{Vector{Float64},1}		# distance to coast
	d_commasst::Array{Vector{Float64},1}	# distance to community-asset
	d_cbd::Array{Vector{Float64},1}	# distance to central business district
end


Base.@kwdef mutable struct UnoccupiedOwnerAgent <: AbstractAgent
	id::Int
	pos::String
	pos_idx::Int64
	WTA::Float64 = 0.0
	prcl_on_mrkt::Bool
	prcl_on_visitor_mrkt::Bool
	looking_to_purchase::Bool
	own_parcel::Bool
	utility::Float64 = 0.0
	AVG_bldg_dmg::Float64 = 0.0
	MC_bldg_dmg::Int = 0 
end

Base.@kwdef mutable struct IndividualAgent <: AbstractAgent
	id::Int64
	pos::String
	pos_idx::Int64
	alpha1::Float64
	alpha2::Float64
	alpha3::Float64
	alpha4::Float64
	budget::Float64
	price_goods::Float64
	number_prcls_aware::Int64
	prcl_on_mrkt::Bool
	prcl_on_visitor_mrkt::Bool
	looking_to_purchase::Bool
	WTA::Float64 = 0.0
	age::Int64
	own_parcel::Bool
	num_people::Int64

	utility::Float64 = 0.0
	utility_cst::Float64 = 0.0
	utility_cms::Float64 = 0.0
	utility_cbd::Float64 = 0.0
	utility_mkt::Float64 = 0.0

	household_change_times::Vector{Int64}
	AVG_bldg_dmg::Float64 = 0.0
	MC_bldg_dmg::Int = 0 
end


Base.@kwdef mutable struct LandlordAgent <: AbstractAgent
	id::Int
	pos::String
	pos_idx::Int64
	alpha1_RR::Float64
	alpha2_RR::Float64
	alpha3_RR::Float64
	alpha4_RR::Float64
	alpha1_LOSR::Float64
	alpha2_LOSR::Float64
	alpha3_LOSR::Float64
	alpha4_LOSR::Float64
	budget::Float64
	price_goods::Float64
	number_prcls_aware::Int64
	prcl_on_mrkt::Bool
	prcl_on_visitor_mrkt::Bool
	looking_to_purchase::Bool
	WTA::Float64 = 0.0
	age::Int64
	own_parcel::Bool
	transition_penalty::Float64
	utility::Float64 = 0.0
	AVG_bldg_dmg::Float64 = 0.0
	MC_bldg_dmg::Int = 0 
end


Base.@kwdef mutable struct CompanyAgent <: AbstractAgent
	id::Int
	pos::String
	pos_idx::Int64
	alpha1_HOR::Float64
	alpha2_HOR::Float64
	alpha3_HOR::Float64
	alpha4_HOR::Float64
	alpha1_HOSR::Float64
	alpha2_HOSR::Float64
	alpha3_HOSR::Float64
	alpha4_HOSR::Float64
	budget::Float64
	price_goods::Float64
	number_prcls_aware::Int64
	prcl_on_mrkt::Bool
	prcl_on_visitor_mrkt::Bool
	looking_to_purchase::Bool
	WTA::Float64 = 0.0
	own_parcel::Bool
	utility::Float64 = 0.0
	AVG_bldg_dmg::Float64 = 0.0
	MC_bldg_dmg::Int = 0 
end


Base.@kwdef mutable struct VisitorAgent <: AbstractAgent
	id::Int
	pos::String
	pos_idx::Int64
	num_people::Int64
	number_prcls_aware::Int64
	alpha1::Float64
	alpha2::Float64
	alpha3::Float64
	alpha4::Float64
	
	utility::Float64 = 0.0
	utility_cst::Float64 = 0.0
	utility_cms::Float64 = 0.0
	utility_cbd::Float64 = 0.0
	utility_mkt::Float64 = 0.0

	AVG_bldg_dmg::Float64 = 0.0
	MC_bldg_dmg::Int = 0 
end


Base.@kwdef mutable struct RealEstateAgent <: AbstractAgent
	id::Int
	pos::String
	pos_idx::Int64
	LandBasePrice::Int64
end




