using Mimi
using Base.Test

include("../src/utils/load_parameters.jl")
include("../src/components/N2Oemissions.jl")

m = Model()
setindex(m, :time, [2009.,2010.,2020.,2030.,2040.,2050.,2075.,2100.,2150.,2200.])
setindex(m, :region, ["EU", "USA", "OECD","USSR","China","SEAsia","Africa","LatAmerica"])

addcomponent(m, n2oemissions)


setparameter(m, :n2oemissions, :e0_baselineN2Oemissions, readpagedata(m,"data/e0_baselineN2Oemissions.csv"))
setparameter(m, :n2oemissions, :er_N2Oemissionsgrowth, readpagedata(m, "data/er_N2Oemissionsgrowth.csv"))

##running Model
run(m)

# Generated data
emissions= m[:n2oemissions,  :e_regionalN2Oemissions]
# Recorded data
emissions_compare=readpagedata(m, "test/validationdata/e_regionalN2Oemissions.csv")

@test emissions ≈ emissions_compare rtol=1e-3
