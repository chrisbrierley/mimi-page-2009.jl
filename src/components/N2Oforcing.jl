using Mimi

@defcomp n2oforcing begin
    c_N2Oconcentration=Parameter(index=[time],unit="ppbv")
    c_CH4concentration=Parameter(index=[time],unit="ppbv")
    f0_N2Obaseforcing=Parameter(unit="W/m2")
    fslope_N2Oforcingslope=Parameter(unit="W/m2")
    c0_baseN2Oconc=Parameter(unit="ppbv")
    c0_baseCH4conc=Parameter(unit="ppbv")
    f_N2Oforcing=Variable(index=[time],unit="W/m2")
    over_baseoverlap=Variable(unit="W/m2")
end

function run_timestep(s::n2oforcing, t::Int64)
    v = s.Variables
    p = s.Parameters

    #from p.16 in Hope 2009
    if t==1
        #calculate baseline forcing overlap in first time period
        v.over_baseoverlap=-0.47*log(1+2.0e-5*(p.c0_baseN2Oconc*p.c0_baseCH4conc)^0.75+5.3e-15*p.c0_baseCH4conc*(p.c0_baseCH4conc*p.c0_baseN2Oconc)^1.52)
    end

    over=-0.47*log(1+2.0e-5*(p.c0_baseCH4conc*p.c_N2Oconcentration[t])^0.75+5.3e-15*p.c0_baseCH4conc*(p.c0_baseCH4conc*p.c_N2Oconcentration[t])^1.52)
    v.f_N2Oforcing[t]=p.f0_N2Obaseforcing+p.fslope_N2Oforcingslope*(sqrt(p.c_N2Oconcentration[t])-sqrt(p.c0_baseN2Oconc))+over-v.over_baseoverlap
end


function addN2Oforcing(model::Model)
    n2oforcingcomp = addcomponent(model, n2oforcing)

    n2oforcingcomp[:fslope_N2Oforcingslope] = 0.12
    n2oforcingcomp[:f0_N2Obaseforcing] = 0.180
    n2oforcingcomp[:c0_baseN2Oconc] = 322.
    n2oforcingcomp[:c0_baseCH4conc] = 1860.

    n2oforcingcomp
end
