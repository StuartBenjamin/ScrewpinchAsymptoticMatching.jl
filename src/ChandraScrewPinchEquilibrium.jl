using ForwardDiff
using Plots
using QuadGK
using DelimitedFiles
using HypergeometricFunctions_Mod

#General Constants
##########################################################################################################################################################
#mu0 = 4*pi*1e-7

#Inputs (Chandra 2007)
##########################################################################################################################################################
#β = 0.1 #Core beta
#ν = 1   #Current shape modulation parameter
#rs0 = 1.0   #radial normalisation unit, setting of singular layer (Chandra)
#xb = 2.0    #wall location in normalised units
##a = rb old wall location
#rb = xb*rs0 #wall physical location
#R0 = 20

#Defining Bp, q_initial (Chandra 2007)
##########################################################################################################################################################
q0_(ν) = 2^(1 - (1/ν)) #ensures q(0) = 1 or something
Bp0_(rs0,R0,ν;Bp0=0.0) = Bp0==0.0 ? (return rs0/(R0*q0_(ν))) : (return Bp0)
qold(ν,rs0) = r -> q0_(ν)*((1 + (r/rs0)^(2*ν))^(1/ν))
q_Furth(q0,ν,rs0) = r -> q0*qold(ν,rs0)(r)
q_Furth_find_rs(q0,ν,rs0) = qtest -> (-1 + qtest^ν*(2^(-1 + 1/ν)/q0)^ν)^((1/2)/ν)

Bp_Chand(rs0,R0,ν;Bp0=0.0) = r -> Bp0_(rs0,R0,ν;Bp0=Bp0)*(r/rs0)/((1 + (r/rs0)^(2*ν))^(1/ν))
BpDivr(rs0,R0,ν;Bp0=0.0) = r -> Bp0_(rs0,R0,ν;Bp0=Bp0)*(1/rs0)/((1 + (r/rs0)^(2*ν))^(1/ν)) #has units Bp0/m

#Solving for toroidal field 
##########################################################################################################################################################
BtTemp(rs0,R0,ν;Bp0=0.0,q0=1.0) = r -> R0*BpDivr(rs0,R0,ν;Bp0=Bp0)(r)*q_Furth(q0,ν,rs0)(r) #has units (m)*(Bp0/m)*qold = Bp0
P0(β,rs0,R0,ν;Bp0=0.0,q0=1.0) = β*BtTemp(rs0,R0,ν;Bp0=Bp0,q0=q0)(0.0)^2/(2*mu0)

p_Chand(β,rs0,R0,ν,xb;Bp0=0.0,q0=1.0) = r -> P0(β,rs0,R0,ν;Bp0=Bp0,q0=q0)*(1 - ((r/rs0)/xb)^2)
dpdr_Chand(β,rs0,R0,ν,xb;Bp0=0.0,q0=1.0) = r -> -2*mu0*P0(β,rs0,R0,ν;Bp0=Bp0,q0=q0)*r/(rs0^2*xb^2)

internalInt_Chand(rs0,R0,ν;Bp0=0.0) = r -> (Bp0_(rs0,R0,ν;Bp0=Bp0)^2*r^2*_₂F₁(1/ν, (2 + ν)/ν, 1 + 1/ν, -(r/rs0)^(2*ν)))/rs0^2 - (Bp0_(rs0,R0,ν;Bp0=Bp0)^2*0.0^2*_₂F₁(1/ν, (2 + ν)/ν, 1 + 1/ν, -(0.0/rs0)^(2*ν)))/rs0^2
internalInt_rb_Chand(rs0,R0,rb,ν;Bp0=0.0) = r -> (Bp0_(rs0,R0,ν;Bp0=Bp0)^2*r^2*_₂F₁(1/ν, (2 + ν)/ν, 1 + 1/ν, -(r/rs0)^(2*ν)))/rs0^2 - (Bp0_(rs0,R0,ν;Bp0=Bp0)^2*rb^2*_₂F₁(1/ν, (2 + ν)/ν, 1 + 1/ν, -(rb/rs0)^(2*ν)))/rs0^2

Bt_Chand(β,rs0,R0,ν,xb;Bp0=0.0,q0=1.0) = r -> sqrt(BtTemp(rs0,R0,ν;Bp0=Bp0,q0=q0)(0.0)^2 - 2*mu0*(p_Chand(β,rs0,R0,ν,xb;Bp0=Bp0,q0=q0)(r) - p_Chand(β,rs0,R0,ν,xb;Bp0=Bp0,q0=q0)(0.0)) - 2*internalInt_Chand(rs0,R0,ν;Bp0=Bp0)(r))
Bt_Scaffidi(β,rs0,R0,ν,xb;Bp0=0.0,q0=1.0) = r -> sqrt(BtTemp(rs0,R0,ν;Bp0=Bp0,q0=q0)(xb*rs0)^2 - 2*mu0*p_Chand(β,rs0,R0,ν,xb;Bp0=Bp0,q0=q0)(r) - 2*(internalInt_Chand(rs0,R0,ν;Bp0=Bp0)(r)-internalInt_Chand(rs0,R0,ν;Bp0=Bp0)(xb*rs0)))

Bt_Chand_NoPressure(β,rs0,R0,ν,xb;Bp0=0.0,q0=1.0) = r -> R0*BpDivr(rs0,R0,ν;Bp0=Bp0)(r)*q_Furth(q0,ν,rs0)
Bt_Furth(q0,rs0,R0,ν,xb;Bp0=0.0) = r -> R0*BpDivr(rs0,R0,ν;Bp0=Bp0)(r)*q_Furth(q0,ν,rs0)(r) #Furth equilibrium instead

dpdr_Furth(q0,rs0,R0,ν,xb;Bp0=0.0) = r -> -mu0*(Bp_Chand(rs0,R0,ν;Bp0=Bp0)(r)/(mu0*r))*(Bp_Chand(rs0,R0,ν;Bp0=Bp0)(r)+r*-1*((Bp0_(rs0,R0,ν;Bp0=Bp0)*(-1 + (r/rs0)^(2*ν))*(1 + (r/rs0)^(2*ν))^(-((1 + ν)/ν)))/rs0))
dpdr_Furth2(q0,rs0,R0,ν,xb;Bp0=0.0) = r -> -mu0*(-Bt_Furth(q0,rs0,R0,ν,xb;Bp0=Bp0)(r)*ForwardDiff.derivative(Bt_Furth(q0,rs0,R0,ν,xb;Bp0=Bp0),r)/(mu0) - (Bp_Chand(rs0,R0,ν;Bp0=Bp0)(r)/(mu0*r))*ForwardDiff.derivative(x->x*Bp_Chand(rs0,R0,ν;Bp0=Bp0)(x),r))
p_Furth(rs0,R0,rb,ν;Bp0=0.0) = r -> -internalInt_rb_Chand(rs0,R0,rb,ν;Bp0=Bp0)(r)/mu0 #All pressure supplied by poloidal field

#Deprecated solution for toroidal field using numerical integration (Corrent to 6 sig fig relative to Mathematica)
##########################################################################################################################################################
    #internalDerivFunc(rs0,R0,ν) = r->r*Bp(rs0,R0,ν)(r)
    #internalDeriv(rs0,R0,ν) = r -> ForwardDiff.derivative(internalDerivFunc(rs0,R0,ν),r)
    #internalIntFunc(rs0,R0,ν) = r -> (Bp(rs0,R0,ν)(r)/r)*internalDeriv(rs0,R0,ν)(r)
    #internalInt(rs0,R0,ν;rtol=1e-10) = r -> quadgk(internalIntFunc(rs0,R0,ν), 0.0, r, rtol=rtol)[1]
    #BtPrime2(β,rs0,R0,ν,xb;rtol=1e-10) = r -> (1/2)*(BtTemp(rs0,R0,ν;Bp0=Bp0,q0=q0)(0.0)^2 - 2*mu0*(p_Chand(β,rs0,R0,ν,xb;Bp0=Bp0,q0=q0)(r) - p_Chand(β,rs0,R0,ν,xb;Bp0=Bp0,q0=q0)(0.0)) - 2*quadgk(internalIntFunc(rs0,R0,ν), 0.0, r, rtol=rtol)[1])^(-1/2)*(ForwardDiff.derivative(x -> (BtTemp(rs0,R0,ν;Bp0=Bp0,q0=q0)(0.0)^2 - 2*mu0*(p_Chand(β,rs0,R0,ν,xb;Bp0=Bp0,q0=q0)(x) - p_Chand(β,rs0,R0,ν,xb;Bp0=Bp0,q0=q0)(0.0))), r) -2*internalIntFunc(rs0,R0,ν)(r))
    #qprime(Bt,Btprime,Bp,R0) = r -> Bt(r)*ForwardDiff.derivative(x -> x/(R0*Bp(x)),r)+(r/(R0*Bp(r)))*Btprime(r)

#Solving for q, magnetic pressure 
##########################################################################################################################################################
q_(Bt,Bp,R0) = r -> r*Bt(r)/(R0*Bp(r))
pm(Bt,Bp) = r -> (1/(2*mu0))*(Bp(r)^2 + Bt(r)^2)

local_beta(p,Bt,Bp) = r -> p(r)/pm(Bt,Bp)(r)

#Solving for current densities (Corrent to 5,6 sig fig relative to Mathematica)
##########################################################################################################################################################
function Jt_(Bp) 
    function Jt(r)
        if r==0.0
            return 1/(mu0*1e-20)*ForwardDiff.derivative(x->x*Bp(x),1e-20)
        else
            return 1/(mu0*r)*ForwardDiff.derivative(x->x*Bp(x),r)
        end
    end
    return Jt
end

Jp_(Bt) = r -> -(1/(mu0))*ForwardDiff.derivative(Bt,r)

#Confirming screw pinch equilibrium:
##########################################################################################################################################################
#dpdr2(Bt,Bp) = r -> mu0*(-Bt(r)*ForwardDiff.derivative(Bt,r)/(mu0) - (Bp(r)/(mu0*r))*ForwardDiff.derivative(x->x*Bp(x),r)) 
#dpdrFurth2(Bt,Bp) = r -> -mu0*(Bp(r)/(mu0*r))*ForwardDiff.derivative(x->x*Bp(x),r) 
#dpdr(p) 

#Printing data to go: 
##########################################################################################################################################################
function print_equil_data(Jt,Bt,p; rvec=nothing, filename_prefactor="", destination="")
    if rvec isa Nothing
        throw("Define vector of r-values 'rvec' to print equilibrium data on.")
    end

    Jtvec = Jt.(rvec)
    Btvec = Bt.(rvec)
    pvec = p.(rvec)

    open(string(destination,filename_prefactor,"profile_j.txt"), "w") do io
        writedlm(io, Jtvec, ' ')
    end
    open(string(destination,filename_prefactor,"profile_f.txt"), "w") do io
        writedlm(io, Btvec, ' ')
    end
    open(string(destination,filename_prefactor,"profile_p.txt"), "w") do io
        writedlm(io, pvec, ' ')
    end

    return Jtvec,Btvec,pvec
end

#Pre-packaged equilibria!!! 
##########################################################################################################################################################
function Furth_Equil(q0,rs0,R0,ν,xb; Bp0=1.0, plot_equil=true, print_mathematica_inputs=true, plotrvec = range(0.000001,xb*rs0,200), rvec=range(0.02,xb*rs0,step=0.02), kwargs...)
    rb = xb*rs0

    Bp = Bp_Chand(rs0,R0,ν;Bp0=Bp0)
    Bt = Bt_Furth(q0,rs0,R0,ν,xb;Bp0=Bp0)
    q = q_Furth(q0,ν,rs0)

    dpdr = dpdr_Furth(q0,rs0,R0,ν,xb;Bp0=Bp0)
    p = p_Furth(rs0,R0,rb,ν;Bp0=Bp0)

    Jt = Jt_(Bp)
    Jp = Jp_(Bt)

    if print_mathematica_inputs
        print_equil_data(Jt,Bt,p; rvec=rvec, kwargs...)
    end
    if plot_equil
        p1=plot(plotrvec,Bp.(plotrvec),title = "Bp",xlabel="r (m)",ylabel="T",label=false)
        p2=plot(plotrvec,Bt.(plotrvec),title = "Bt",label=false,ylims=(0.0,2*Bt(rb)),xlabel="r (m)",ylabel="T")
        p3=plot(plotrvec,q.(plotrvec),title = "q",label=false,xlabel="r (m)")
        p4=plot(plotrvec,local_beta(p,Bt,Bp).(plotrvec),title = "Local Plasma β",xlabel="r (m)",label=false)
        p5=plot(plotrvec,Jt.(plotrvec),title = "Toroidal current",xlabel="r (m)",ylabel="\$\\textrm{A/m}^{2}\$",label=false)
        p6=plot(plotrvec,Jp.(plotrvec),title = "Poloidal current",xlabel="r (m)",ylabel="\$\\textrm{A/m}^{2}\$",label=false)

        outerp6 = plot(p1,p2,p3,p4,p5,p6)
        display(outerp6)
    else
        outerp6=nothing
    end

    return Bp,Bt,q,dpdr,p,Jt,Jp,rb,outerp6
end

Furth_Peaked(q0,rs0,R0,xb; Bp0=1.0, plot_equil=true, print_mathematica_inputs=true, plotrvec = range(0.000001,xb*rs0,200), kwargs...) = Furth_Equil(q0,rs0,R0,1,xb; Bp0=Bp0, plot_equil=plot_equil, print_mathematica_inputs=print_mathematica_inputs, plotrvec = plotrvec, kwargs...)
Furth_Rounded(q0,rs0,R0,xb; Bp0=1.0, plot_equil=true, print_mathematica_inputs=true, plotrvec = range(0.000001,xb*rs0,200), kwargs...) = Furth_Equil(q0,rs0,R0,2,xb; Bp0=Bp0, plot_equil=plot_equil, print_mathematica_inputs=print_mathematica_inputs, plotrvec = plotrvec, kwargs...)
Furth_Flattened(q0,rs0,R0,xb; Bp0=1.0, plot_equil=true, print_mathematica_inputs=true, plotrvec = range(0.000001,xb*rs0,200), kwargs...) = Furth_Equil(q0,rs0,R0,4,xb; Bp0=Bp0, plot_equil=plot_equil, print_mathematica_inputs=print_mathematica_inputs, plotrvec = plotrvec, kwargs...)

function Chandra_Equil(β,rs0,R0,ν,xb; Bp0=0.0, q0 = 1.0, plot_equil=true, print_mathematica_inputs=true, plotrvec = range(0.000001,xb*rs0,200), rvec=range(0.02,xb*rs0,step=0.02), kwargs...)
    rb = xb*rs0

    Bp = Bp_Chand(rs0,R0,ν;Bp0=Bp0)
    Bt = Bt_Chand(β,rs0,R0,ν,xb;Bp0=Bp0,q0=q0)
    q = q_(Bt,Bp,R0)

    dpdr = dpdr_Chand(β,rs0,R0,ν,xb;Bp0=Bp0,q0=q0)
    p = p_Chand(β,rs0,R0,ν,xb;Bp0=Bp0,q0=q0)

    Jt = Jt_(Bp)
    Jp = Jp_(Bt)

    if print_mathematica_inputs
        print_equil_data(Jt,Bt,p; rvec=rvec, kwargs...)
    end
    if plot_equil
        p1=plot(plotrvec,Bp.(plotrvec),title = "Bp",xlabel="r (m)",ylabel="T",label=false)
        p2=plot([plotrvec,plotrvec],[BtTemp(rs0,R0,ν;Bp0=Bp0,q0=q0).(plotrvec),Bt.(plotrvec)],title = "Bt",label=["approx"  "exact"],ylims=(0.0,2*BtTemp(rs0,R0,ν;Bp0=Bp0,q0=q0)(rb)),xlabel="r (m)",ylabel="T")
        p3=plot([plotrvec,plotrvec],[q_Furth(q0,ν,rs0).(plotrvec),q.(plotrvec)],title = "q",label=["approx"  "exact"],xlabel="r (m)")
        p4=plot(plotrvec,local_beta(p,Bt,Bp).(plotrvec),title = "Local Plasma β",xlabel="r (m)",label=false)
        p5=plot(plotrvec,Jt.(plotrvec),title = "Toroidal current",xlabel="r (m)",ylabel="\$\\textrm{A/m}^{2}\$",label=false)
        p6=plot(plotrvec,Jp.(plotrvec),title = "Poloidal current",xlabel="r (m)",ylabel="\$\\textrm{A/m}^{2}\$",label=false)

        outerp6 = plot(p1,p2,p3,p4,p5,p6)
        display(outerp6)
    else
        outerp6=nothing
    end

    return Bp,Bt,q,dpdr,p,Jt,Jp,rb,outerp6
end

function Scaffidi_Equil(β,rs0,R0,ν,xb; Bp0=0.0, q0=1.0, plot_equil=true, print_mathematica_inputs=true, plotrvec = range(0.000001,xb*rs0,200), rvec=range(0.02,xb*rs0,step=0.02), kwargs...)
    rb = xb*rs0

    Bp = Bp_Chand(rs0,R0,ν;Bp0=Bp0)
    Bt = Bt_Scaffidi(β,rs0,R0,ν,xb;Bp0=Bp0,q0=q0)
    q = q_(Bt,Bp,R0)

    dpdr = dpdr_Chand(β,rs0,R0,ν,xb;Bp0=Bp0,q0=q0)
    p = p_Chand(β,rs0,R0,ν,xb;Bp0=Bp0,q0=q0)

    Jt = Jt_(Bp)
    Jp = Jp_(Bt)

    if print_mathematica_inputs
        print_equil_data(Jt,Bt,p; rvec=rvec, kwargs...)
    end
    if plot_equil
        p1=plot(plotrvec,Bp.(plotrvec),title = "Bp",xlabel="r (m)",ylabel="T",label=false)
        p2=plot([plotrvec,plotrvec],[BtTemp(rs0,R0,ν;Bp0=Bp0,q0=q0).(plotrvec),Bt.(plotrvec)],title = "Bt",label=["approx"  "exact"],ylims=(0.0,2*BtTemp(rs0,R0,ν;Bp0=Bp0,q0=q0)(rb)),xlabel="r (m)",ylabel="T")
        p3=plot([plotrvec,plotrvec],[q_Furth(q0,ν,rs0).(plotrvec),q.(plotrvec)],title = "q",label=["approx"  "exact"],xlabel="r (m)")
        p4=plot(plotrvec,local_beta(p,Bt,Bp).(plotrvec),title = "Local Plasma β",xlabel="r (m)",label=false)
        p5=plot(plotrvec,Jt.(plotrvec),title = "Toroidal current",xlabel="r (m)",ylabel="\$\\textrm{A/m}^{2}\$",label=false)
        p6=plot(plotrvec,Jp.(plotrvec),title = "Poloidal current",xlabel="r (m)",ylabel="\$\\textrm{A/m}^{2}\$",label=false)

        outerp6 = plot(p1,p2,p3,p4,p5,p6)
        display(outerp6)
    else
        outerp6=nothing
    end

    return Bp,Bt,q,dpdr,p,Jt,Jp,rb,outerp6
end
