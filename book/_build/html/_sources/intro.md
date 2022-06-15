# Integrated Land Market and Hazard Consequence Model

This document describes in detail the integrated land market and hazard consequence model in this repository. The ABM is written in Julia using Agents.jl (Datseris et al., 2022). [IN-CORE](https://incore.ncsa.illinois.edu) is used to model damage and losses resulting from natural hazards (van de Lindt et al., 2018).

The model was developed and tested with Seaside, Oregon and seismic-tsunami hazards associated with the Cascadia Subduction Zone in mind. 

This Jupyter book contains both the ODD protocol for describing the model and examples of how to run the source code. 

```{image} /images/TemporalSetting6.png
:width: 400px
:align: center
```

## ODD
The ODD (Overview, Design concepts, and Details) protocol is commonly used to describe agent-based models (Grimm et al., 2006). This section describes the integrated land market and hazard consequence model in this repository following the ODD protocol. 

## Background on Seaside

The North American Pacific Northwest is subject to the rupture of the Cascadia Subduction Zone (CSZ), which is an approximately 1,000 km long fault located between Cape Mendocino California and Vancouver Island, Canada, and separates the Juan de Fuca and North America plates. Rupture of the CSZ can result in both strong earthquake ground shaking and tsunami inundation. The last full rupture of the CSZ occurred in 1700 and is estimated to have had a moment magnitude between 8.7 and 9.2. The city of Seaside is a small coastal town located along the northern Oregon coast, and has a full-time population of approximately 6,700 people. As a popular coastal town, Seaside see's large population flucuations both seasonally (e.g. winter vs. summer population) and weekly (e.g. weekday vs. weekend population). 


 ```{image} /images/CaseStudy_icon.png
:width: 400px
:align: center
```



## Funding


This work was funded by the cooperative agreement 70NANB15H044 between the National Institute of Standards and Technology (NIST) and Colorado State University through a subaward to Oregon State University. The content expressed in this book are the views of the authors and do not necessarily represent the opinions or views of NIST or the U.S Department of Commerce.

