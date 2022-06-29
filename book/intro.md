# Coupled Urban Change and Hazard Consequence Model

This document describes in detail the coupled urban change and hazard consequence model in [this repository](https://github.com/22dylan/UrbanChange-HazardConsequence). The urban change component of the model is an agent-based model (ABM). This is written in Julia using [Agents.jl](https://juliadynamics.github.io/Agents.jl/stable/) (Datseris et al., 2022). [IN-CORE](https://incore.ncsa.illinois.edu) is used to model damage and losses resulting from natural hazards (van de Lindt et al., 2018).

The model was developed and tested with Seaside, Oregon and seismic-tsunami hazards associated with the Cascadia Subduction Zone in mind. The model can be applied to other communities and natural hazards. 

This Jupyter book contains both the ODD protocol for describing the model and examples of how to run the source code. 

```{image} /images/TemporalSetting6.png
:width: 400px
:align: center
```

## Background on Seaside

The North American Pacific Northwest is subject to the rupture of the Cascadia Subduction Zone (CSZ), which is an approximately 1,000 km long fault located between Cape Mendocino California and Vancouver Island, Canada, and separates the Juan de Fuca and North America plates. Rupture of the CSZ can result in both strong earthquake ground shaking and tsunami inundation. The last full rupture of the CSZ occurred in 1700 and is estimated to have had a moment magnitude between 8.7 and 9.2. The city of Seaside is a small coastal town located along the northern Oregon coast, and has a full-time population of approximately 6,700 people. As a popular coastal town, Seaside sees large population flucuations both seasonally (e.g. winter vs. summer population) and weekly (e.g. weekday vs. weekend population). 


 ```{image} /images/CaseStudy_icon.png
:width: 400px
:align: center
```



## Funding


We acknowledge funding in part through Oregon Sea Grant under award no. NA18OAR170072 (CDFA no. 11.417) from NOAA’s National Sea Grant College Program, US Department of Commerce, and by appropriations made by the Oregon State Legislature; the cooperative agreement 70NANB15H044 between the National Institute of Standards and Technology (NIST) and Colorado State University through a subaward to Oregon State University; and the National Science Foundation through award NSF-2103713. The content expressed in this paper are the views of the authors and do not necessarily represent the opinions or views of the U.S Department of Commerce, NIST, or NSF.
