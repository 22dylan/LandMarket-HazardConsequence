# Overview
## Purpose
The purpose of this model is to explore the risks that emerge with respect to acute natural hazards as a result of planning policies. Modeling and simulation are commonly used to inform disaster theory and understand emerging phenomena. However, many modeling efforts of infrastructure damage, societal loss, and mitigation plans associated with natural hazards often consider static representations of communities despite their dynamic and complex nature. Homeowners, urban planners, and policy makers can influence changes to the built environment, but no single entity has autonomous control over a community and outcomes of policy are difficult to fully envision. The model described herein is an coupled urban change and hazard consequence model with consideration given to population growth, a changing built environment, natural hazard mitigation planning, and future acute hazards.

## State Variables and Scales

Agents in the model represent entities that own and modify the built environment. There are six agents and six land uses in the model. The model operates at the community level with each time step representing one year. The model is intended to be ran for about 30-timesteps. The model is driven by supply and demand for places of residence for both full time residents and visitors. The figure below shows how each agent is related to the land uses. Arrows denote that the agent occupies a parcel, whereas colors indicate that an agent owns a parcel.

 ```{image} /images/AgentsLanduse_noComm.png
:width: 600px
:align: center
```


### Agents
#### Unoccupied Owner
These agents are associated with unoccupied parcels and act as “sellers” in the model. As other agents bid on their parcel, they review the bids selecting the maximum if it exceeds their willingness to accept the price.  

| Variable      | Description |
| :---        	|    :----:   |
| id      		| Unique identifying number for agent |
| pos   		| Position in model space; string that is either the unique id of a parcel or “none” indicating the agent is not associated with a parcel |
| pos_idx 		| position index; used to quickly identify agent location in model |
| WTA 			| willingness to accept price |
| prcl_on_mrkt 	| Boolean indicating whether the parcel is on the market for agents to buy |
| prlc_on_visitor_mrkt | Boolean indicating whether the parcel is on the market for visitor agents to occupy |
| AVG_bldg_dmg 	| average building damage for parcel that agent is in (if applicable) |
| MC_bldg_dmg 	| monte-carlo sample of building damage for parcel that agent is in (if applicable) |


#### Household
These agents are associated with full-time residents. They either reside in a parcel or are searching for a place to live. They can either own an “owned residential” property (i.e.., a single-family home), or reside in a rental or high occupancy residential property (i.e., a rental home or apartment respectively). The number of people associated with newly added household agents are randomly drawn from a Gamma distribution. A household will randomly gain or lose one person following a Poisson process. A single age is randomly assigned to represent the head of the household following a Gamma distribution and increasing at each time step. Once the head of the household turns 80 years of age, the agent is removed and their place of residence becomes vacant. 

| Variable 	| Description 	|
| :---		| :----			|
| id 		| Unique identifying number for agent | 
| pos 		| Position in model space; string that is either the unique id of a parcel or “none” indicating the agent is not associated with a parcel |  
| pos_idx	| position index; used to quickly identify agent location in model |
| alpha1	| agent preference for distance to coast; weighted from 0-1 |
| alpha2	| agent preference for distance to community asset; weighted from 0-1 |
| alpha3	| agent preference for distance to CBD; weighted from 0-1 |
| alpha4	| agent preference for market pressure; weighted from 0-1 |
| budget	| budget assigned to agent; sampled from normal distribution |
| price_goods | price representing other goods that agents buys; used in bid formulation |
| number_prcls_aware | number of parcels the agent is aware of in search; bounds agent rationality |
| looking_to_purchase | Boolean indicating whether the agent is looking to purchase a property |
| WTA 		| willingness to accept price |
| age 		| age of agent |
| own_parcel | Boolean indicating whether the agent owns the parcel |
| num_people | number of people associated with agent |
| utility 	| utility gained from parcel |
| utility_cst | utility deaggregated by distance to coast |
| utility_cms | utility deaggregated by distance to community asset |
| utility_cbd | utility deaggregated by distance to CBD |
| utility_mkt | utility deaggregated by market pressure |
| household_change_times | vector developed from Poisson process representing when number of people in household increase/decrease by one. |
| AVG_bldg_dmg | average building damage for parcel that agent is in (if applicable) |
| MC_bldg_dmg | Monte-Carlo sample of building damage for parcel that agent is in (if applicable) |


#### Landlord
These agents own parcels and rent them to household agents as “rental residential” or to visitor agents as “low occupancy seasonal rentals” (i.e., vacation homes). At any point in the simulation, landlord agents can choose to switch between these two land uses based on a net utility gain. Like household agents, landlord agents are removed from the model when they turn 80 and their property becomes vacant. Landlord agents do not reside in parcels.

| Variable | Description |
| :------	| :--------	|
| id | Unique identifying number for agent |
| pos | Position in model space; string that is either the unique id of a parcel or “none” indicating the agent is not associated with a parcel |
| pos_idx | position index; used to quickly identify agent location in model |
| alpha1_RR | agent preference for distance to coast for rental residential; weighted from 0-1 |
| alpha2_RR | agent preference for distance to community asset for rental residential; weighted from 0-1 |
| alpha3_RR | agent preference for distance to CBD for rental residential; weighted from 0-1 |
| alpha4_RR | agent preference for market pressure for rental residential; weighted from 0-1 |
| alpha1_LOSR | agent preference for distance to coast for low occupancy seasonal rental; weighted from 0-1 |
| alpha2_LOSR | agent preference for distance to community asset for low occupancy seasonal rental; weighted from 0-1 |
| alpha3_LOSR | agent preference for distance to CBD for low occupancy seasonal rental; weighted from 0-1 |
| alpha4_LOSR | agent preference for market pressure for low occupancy seasonal rental; weighted from 0-1 |
| budget | budget assigned to agent; sampled from normal distribution |
| price_goods | price representing other goods that agents buys; used in bid formulation |
| number_prcls_aware | number of parcels the agent is aware of in search; bounds agent rationality |
| looking_to_purchase | Boolean indicating whether the agent is looking to purchase a property |
| WTA | willingness to accept price |
| age | age of agent |
| own_parcel | Boolean indicating whether the agent owns the parcel |
| transition_penalty | float representing penalty cost of landlord agent transitioning between rental residential and low occupancy seasonal rental; used to keep all landlords from transitioning every time step |
| utility | utility gained from parcel |
| AVG_bldg_dmg | average building damage for parcel that agent is in (if applicable) |
| MC_bldg_dmg | monte-carlo sample of building damage for parcel that agent is in (if applicable) |

#### Firm
These agents purchase properties for development as either “high occupancy rental” (i.e., apartments) or “high occupancy seasonal rental” (i.e., hotels). Firm agents cannot switch between these land uses during the simulation. After a parcel is developed into one of these land uses, it remains as such for the remainder of the simulation. Firm agents do not age and are not removed from the model at any point. Firm agents do not reside in a parcels.

| Variable | Description |
| :------	| :--------	|
| id | Unique identifying number for agent |
| pos | Position in model space; string that is either the unique id of a parcel or “none” indicating the agent is not associated with a parcel |
| pos_idx | position index; used to quickly identify agent location in model |
| alpha1_HOR | agent preference for distance to coast for high occupancy residential; weighted from 0-1 |
| alpha2_HOR | agent preference for distance to community asset for high occupancy residential; weighted from 0-1 |
| alpha3_HOR | agent preference for distance to CBD for high occupancy residential; weighted from 0-1 |
| alpha4_HOR | agent preference for market pressure for high occupancy residential; weighted from 0-1 |
| alpha1_HOSR | agent preference for distance to coast for high occupancy seasonal rental; weighted from 0-1 |
| alpha2_HOSR | agent preference for distance to community asset for high occupancy seasonal rental; weighted from 0-1 |
| alpha3_HOSR | agent preference for distance to CBD for high occupancy seasonal rental; weighted from 0-1 |
| alpha4_HOSR | agent preference for market pressure for high occupancy seasonal rental; weighted from 0-1 |
| budget | budget assigned to agent; sampled from normal distribution |
| price_goods | price representing other goods that agents buys; used in bid formulation |
| number_prcls_aware | number of parcels the agent is aware of in search; bounds agent rationality |
| looking_to_purchase | Boolean indicating whether the agent is looking to purchase a property |
| WTA | willingness to accept price |
| own_parcel | Boolean indicating whether the agent owns the parcel |
| utility | utility gained from parcel |
| AVG_bldg_dmg | average building damage for parcel that agent is in (if applicable) |
| MC_bldg_dmg | monte-carlo sample of building damage for parcel that agent is in (if applicable) |




#### Visitor
These agents represent a transient seasonal visitor or portion of the tourist population and temporarily reside in either “low occupancy seasonal rental” (i.e., vacation homes) or “high occupancy seasonal rental” properties (i.e., hotels). The number of people associated with a visitor agent is sampled from a Gamma distribution. At the start of each time step, all visitors in the model are removed and new visitor agents are reassigned to vacant low occupancy or high occupancy seasonal rental parcels. 

| Variable | Description |
| :------	| :--------	|
| id | Unique identifying number for agent |
| pos | Position in model space; string that is either the unique id of a parcel or “none” indicating the agent is not associated with a parcel |
| pos_idx | position index; used to quickly identify agent location in model |
| num_people | number of people associated with agent |
| number_prcls_aware | number of parcels the agent is aware of in search; bounds agent rationality |
| alpha1 | agent preference for distance to coast; weighted from 0-1 |
| alpha2 | agent preference for distance to community asset; weighted from 0-1 |
| alpha3 | agent preference for distance to CBD; weighted from 0-1 |
| alpha4 | agent preference for market pressure; weighted from 0-1 |
| utility | utility gained from parcel |
| utility_cst | utility deaggregated by distance to coast |
| utility_cms | utility deaggregated by distance to community asset |
| utility_cbd | utility deaggregated by distance to CBD |
| utility_mkt | utility deaggregated by market pressure |
| AVG_bldg_dmg | average building damage for parcel that agent is in (if applicable) |
| MC_bldg_dmg | monte-carlo sample of building damage for parcel that agent is in (if applicable) |


#### Real estate
This agent sets the market value of every parcel throughout the simulation. This market value is used to inform both the unoccupied owner agents’ willingness to accept price and the cost of structural retrofits. The market value of a parcel is based on a user-defined base price of land, the maximum expected utility that either household or visitor agents will get from the parcel, and the overall demand for parcels. The Real Estate Agent is not associated with any parcel.

| Variable | Description |
| :------	| :--------	|
| id | Unique identifying number for agent |
| pos | Position in model space; string that is either the unique id of a parcel or “none” indicating the agent is not associated with a parcel |
| pos_idx | position index; used to quickly identify agent location in model |
| LandBasePrice | base price of land in model; modified based on general land market |


### Land Uses

The six land uses are in the table below

| Land use | Description | 
| :------	| :--------	|
| Unoccupied | Parcels that are marked as unoccupied are available for agents to bid on and purchase. Parcels become unoccupied if an agent is removed from the model. |
| Owned Residential | These parcels are associated with household agents and represent single-family homes. As such, only on household agent can reside in an owned residential property.  |
| Rental Residential | These parcels are owned by landlords and occupied by households. At each time step, landlords can decide to switch between rental residential properties and low occupancy seasonal rental based on demand for each. |
| Low Occupancy Seasonal Rental | These parcels are owned by landlords and occupied by visitor agents. At each time step, landlords can decide to switch between rental residential properties and low occupancy seasonal rental based on demand for each. |
| High Occupancy Residential | These parcels are owned by firms and occupied by households. 20 household agents can occupy a single high occupancy residential property |
| High Occupancy Seasonal Rental | These parcels are owned by firms and occupied by visitors. 45 visitor agents can occupy a single high occupancy seasonal rental property |


## Process overview and scheduling
The figure below shows a flowchart representation of the modeling framework. The urban change model is shown with the grey dash-dot box on the left, whereas the hazard consequence model, IN-CORE, is shown with the blue dash-dot box on the right.

### Process Overview
 ```{image} /images/Flowchart4.png
:width: 600px
:align: center
```

The model begins with the identification of natural hazard mitigation policies (b). A population allocation is called once per iteration to initially assign population characteristics to each tax-lot (c). The population growth model (d) then updates the number of full-time residents and visitors in the model to match input population growth trajectories. A land market is simulated with agents bidding on parcels and the highest bidder obtaining ownership of a parcel (e). The land market results in an updated community description (f) with parcel owners, seismic codes, and land uses. This process repeats until a user defined time of hazard event in the simulation. Each step represents one year. 
When the model is at the time step of the hazard occurring, the community description is passed to the hazard consequence model. Here IN-CORE is used to determine damages to the built environment. Hazard models (g) represent spatially explicit hazard intensity measures. Damage models (h) are fragility functions that map a hazard intensity measure to damages to each building. The fragility functions return the probability of exceeding a given damage state based on the hazard intensity measure, representing damage to the built environment (i). This overall process is then repeated for a user-defined number of iterations. 

### Scheduling

Each time steps in the model represent one year and consists of the following processes:
* *Population Growth (PopulationGrowth!)*: The number of household, visitor, landlord, and firm agents that are searching for parcels are updated. These agents are added to the general model space (i.e., not associated with a parcel) based on a user defined constant number of agents searching for parcels. The model updates parcel and agent counts after this step.
* *All Agents Step (AllAgentsStep!)*: All agents take an individual step. Stepping is ordered based on ID (not randomized) and the agents do not interact with each other during this step. This step is used to age agents (Household and Landlord agents), model the number of people in a household (if applicable; Household agents), check to switch land use (Landlord agent) and update land prices (Real Estate agent).
* *Simulate Visitor Market Step (SimulateVisitorMarketStep!)*: This step identifies all properties that can host visitors and simulates visitor agents being assigned to parcels for the iteration. The order of visitor agents in this market are randomized for each time step. Visitor agents search for parcels that meet their preferences. This market is first-come-first-served in that visitor agents are not bidding against each other but occupy the parcel that is available and meet’s their preferences. The model updates parcel and agent counts after this step.
* *Simulate Market Step (SimulateMarketStep!)*: This step simulates the land market for agents looking to purchase properties (Household, Landlord, and Firm). The order of these agents are randomized. Buyers formulate bids based on utility and budget. Sellers (unoccupied owner agents) receive the bids and select the one that is the highest. IF the bid price is larger than the unoccupied owner’s WTA price, the successful bidder become the new owner of the parcel. The land use is then updated based on the owner. 
* *Population Out Migration (PopulationOutMigration!)*: This step is used to represent out-migration from the community. If the number of full-time residents or visitors are larger than the input population trajectories, then out migration occurs. This constrains the population to the input population trajectories. The model updates parcel and agent counts after this step. 

