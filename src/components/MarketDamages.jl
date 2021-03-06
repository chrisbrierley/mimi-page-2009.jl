using Mimi
using Distributions
include("../utils/mctools.jl")

@defcomp MarketDamages begin
    region = Index()
    y_year = Parameter(index=[time], unit="year")

    #incoming parameters from Climate
    rtl_realizedtemperature = Parameter(index=[time, region], unit="degreeC")

    #tolerability variables
    atl_adjustedtolerableleveloftemprise = Parameter(index=[time,region], unit="degreeC")
    imp_actualreduction = Parameter(index=[time, region], unit= "%")
    i_regionalimpact = Variable(index=[time, region], unit="degreeC")

    #impact Parameters
    rcons_per_cap_SLRRemainConsumption = Parameter(index=[time, region], unit = "\$/person")
    rgdp_per_cap_SLRRemainGDP = Parameter(index=[time, region], unit = "\$/person")

    save_savingsrate = Parameter(unit= "%")
    WINCF_weightsfactor =Parameter(index=[region], unit="")
    W_MarketImpactsatCalibrationTemp =Parameter(unit="%GDP")
    ipow_MarketIncomeFxnExponent =Parameter()
    iben_MarketInitialBenefit=Parameter()
    tcal_CalibrationTemp = Parameter()
    GDP_per_cap_focus_0_FocusRegionEU = Parameter()

    #impact variables
    isatg_impactfxnsaturation = Parameter(unit="unitless")
    rcons_per_cap_MarketRemainConsumption = Variable(index=[time, region], unit = "\$/person")
    rgdp_per_cap_MarketRemainGDP = Variable(index=[time, region], unit = "\$/person")
    iref_ImpactatReferenceGDPperCap=Variable(index=[time, region])
    igdp_ImpactatActualGDPperCap=Variable(index=[time, region])
    impmax_maxtempriseforadaptpolicyM = Parameter(index=[region], unit= "degreeC")

    isat_ImpactinclSaturationandAdaptation= Variable(index=[time,region])
    isat_per_cap_ImpactperCapinclSaturationandAdaptation = Variable(index=[time,region])
    pow_MarketImpactExponent=Parameter(unit="")

end

function run_timestep(s::MarketDamages, t::Int64)
    v = s.Variables
    p = s.Parameters
    d = s.Dimensions

    for r in d.region
        #calculate tolerability
        if (p.rtl_realizedtemperature[t,r]-p.atl_adjustedtolerableleveloftemprise[t,r]) < 0
            v.i_regionalimpact[t,r] = 0
        else
            v.i_regionalimpact[t,r] = p.rtl_realizedtemperature[t,r]-p.atl_adjustedtolerableleveloftemprise[t,r]
        end

        v.iref_ImpactatReferenceGDPperCap[t,r]= p.WINCF_weightsfactor[r]*((p.W_MarketImpactsatCalibrationTemp + p.iben_MarketInitialBenefit * p.tcal_CalibrationTemp)*
            (v.i_regionalimpact[t,r]/p.tcal_CalibrationTemp)^p.pow_MarketImpactExponent - v.i_regionalimpact[t,r] * p.iben_MarketInitialBenefit)

        v.igdp_ImpactatActualGDPperCap[t,r]= v.iref_ImpactatReferenceGDPperCap[t,r]*
            (p.rgdp_per_cap_SLRRemainGDP[t,r]/p.GDP_per_cap_focus_0_FocusRegionEU)^p.ipow_MarketIncomeFxnExponent

        if v.igdp_ImpactatActualGDPperCap[t,r] < p.isatg_impactfxnsaturation
            v.isat_ImpactinclSaturationandAdaptation[t,r] = v.igdp_ImpactatActualGDPperCap[t,r]
        else
            v.isat_ImpactinclSaturationandAdaptation[t,r] = p.isatg_impactfxnsaturation+
                ((100-p.save_savingsrate)-p.isatg_impactfxnsaturation)*
                ((v.igdp_ImpactatActualGDPperCap[t,r]-p.isatg_impactfxnsaturation)/
                (((100-p.save_savingsrate)-p.isatg_impactfxnsaturation)+
                (v.igdp_ImpactatActualGDPperCap[t,r]-
                p.isatg_impactfxnsaturation)))
            end

        if v.i_regionalimpact[t,r] < p.impmax_maxtempriseforadaptpolicyM[r]
            v.isat_ImpactinclSaturationandAdaptation[t,r]=v.isat_ImpactinclSaturationandAdaptation[t,r]*(1-p.imp_actualreduction[t,r]/100)
        else
            v.isat_ImpactinclSaturationandAdaptation[t,r] = v.isat_ImpactinclSaturationandAdaptation[t,r] *
                (1-(p.imp_actualreduction[t,r]/100)* p.impmax_maxtempriseforadaptpolicyM[r] /
                v.i_regionalimpact[t,r])
        end

        v.isat_per_cap_ImpactperCapinclSaturationandAdaptation[t,r] = (v.isat_ImpactinclSaturationandAdaptation[t,r]/100)*p.rgdp_per_cap_SLRRemainGDP[t,r]
        v.rcons_per_cap_MarketRemainConsumption[t,r] = p.rcons_per_cap_SLRRemainConsumption[t,r] - v.isat_per_cap_ImpactperCapinclSaturationandAdaptation[t,r]
        v.rgdp_per_cap_MarketRemainGDP[t,r] = v.rcons_per_cap_MarketRemainConsumption[t,r]/(1-p.save_savingsrate/100)
    end

end

function addmarketdamages(model::Model)
    marketdamagescomp = addcomponent(model, MarketDamages)

    marketdamagescomp[:tcal_CalibrationTemp]= 3.
    marketdamagescomp[:iben_MarketInitialBenefit] = .1333333333333
    marketdamagescomp[:ipow_MarketIncomeFxnExponent] = -0.13333333333333333
    marketdamagescomp[:save_savingsrate]= 15.
    marketdamagescomp[:GDP_per_cap_focus_0_FocusRegionEU]= 27934.244777382406
    marketdamagescomp[:pow_MarketImpactExponent]=2.16666666666665
    marketdamagescomp[:W_MarketImpactsatCalibrationTemp] = 0.5
    marketdamagescomp[:impmax_maxtempriseforadaptpolicyM] = readpagedata(model, "data/impmax_economic.csv")

    return marketdamagescomp
end

function randomizemarketdamages(model::Model)
    update_external_parameter(model, :tcal_CalibrationTemp, rand(TriangularDist(2.5, 3.5, 3.)))
    update_external_parameter(model, :iben_MarketInitialBenefit, rand(TriangularDist(0, .3, .1)))
    update_external_parameter(model, :W_MarketImpactsatCalibrationTemp, rand(TriangularDist(.2, .8, .5)))
    update_external_parameter(model, :pow_MarketImpactExponent, rand(TriangularDist(1.5, 3, 2)))
    update_external_parameter(model, :ipow_MarketIncomeFxnExponent, rand(TriangularDist(-.3, 0, -.1)))
    update_external_parameter(model, :save_savingsrate, rand(TriangularDist(10, 20, 15)))
    wincf = [1.0,
             rand(TriangularDist(.6, 1, .8)),
             rand(TriangularDist(.4, 1.2, .8)),
             rand(TriangularDist(.2, .6, .4)),
             rand(TriangularDist(.4, 1.2, .8)),
             rand(TriangularDist(.4, 1.2, .8)),
             rand(TriangularDist(.4, .8, .6)),
             rand(TriangularDist(.4, .8, .6))]
    update_external_parameter(model, :WINCF_weightsfactor, wincf)
end
