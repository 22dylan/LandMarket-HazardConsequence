# Design Concepts
Design concepts are outlined below:
* *Emergence*: Aggregate counts of the number of parcels and people in each land use under different policy scenarios emerge from the urban change model. The coupled hazard consequence model allows for the number of people in damaged buildings to emerge. 
* *Fitness*: Agents calculate the utility of parcels based on heterogeneous preferences. Utility is calculated using the Cobb-Douglas utility function. 
* *Prediction*: Landlord agents make predictions about whether to put their property on the market as rental residential or low occupancy seasonal rental based on immediate demand for full time residents and visitor agents respectively. Firms apply the same prediction to high-occupancy residential and seasonal rental based on immediate demand for full time residents and visitors. 
* *Sensing*: agents know both how many other agents are in the market searching for parcels and how many available parcels there are. 
* *Interaction*: agents interact with each other when submitting bid prices and reviewing incoming bids. 
* *Stochasticity*: Agent preferences and budgets are heterogeneous and modified for each iteration. Initial land uses are stochastic from the housing unit allocation. Building damages are returned as the probability of being in different damage states. These probabilities are used to both: (1) compute the expected damage state, and (2) sample a random damage state once per iteration. 
* *Observation*: Data is collected at three scales: (1) agent, (2) space, and (3) model. The data is output as CSV files. 

