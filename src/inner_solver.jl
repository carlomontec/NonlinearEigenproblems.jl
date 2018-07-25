# Helper functions for methods based on inner-outer iterations

export inner_solve;
export InnerSolver;

abstract type InnerSolver end;
abstract type NewtonInnerSolver <: InnerSolver end;
abstract type PolyeigInnerSolver <: InnerSolver end;
abstract type DefaultInnerSolver <: InnerSolver end;
abstract type IARInnerSolver <: InnerSolver end;
abstract type IARChebInnerSolver <: InnerSolver end;
abstract type SGIterInnerSolver <: InnerSolver end;
abstract type ContourBeynInnerSolver <: InnerSolver end;

   """
  inner_solve(T,T_arit,nep;kwargs...)

Solves the projected linear problem with solver specied with T. This is to be used
as an inner solver in an inner-outer iteration. T specifies which method
to use. The most common choice is `DefaultInnersolver`. The function returns
`(λv,V)` where `λv` is an array of eigenvalues and `V` a matrix with corresponding
 vectors.
The type T_arit defines the arithmetics used in the outer iteration and should prefereably
also be used in the inner iteration.

Different inner_solve methods take different kwargs. The meaning of
the kwargs are the following

 Neig: Number of wanted eigenvalues (but less or more may be returned)
 σ: target specifying where eigenvalues
 λv, V: Vector/matrix of guesses to be used as starting values
 j: the jth eigenvalue in a min-max characterization
 tol: Termination tolarance for inner solver


"""
function inner_solve(TT::Type{DefaultInnerSolver},T_arit::DataType,nep::NEPTypes.Proj_NEP;kwargs...)
    if (typeof(nep.orgnep)==NEPTypes.PEP)
        return inner_solve(PolyeigInnerSolver,T_arit,nep;kwargs...);
    elseif (typeof(nep.orgnep)==NEPTypes.DEP)
        # Should be Cheb IAR
        return inner_solve(IARChebInnerSolver,T_arit,nep;kwargs...);
    elseif (typeof(nep.orgnep)==NEPTypes.SPMF_NEP) # Default to IAR for SPMF
        return inner_solve(IARInnerSolver,T_arit,nep;kwargs...);
    else
        return inner_solve(NewtonInnerSolver,T_arit,nep;kwargs...);
    end
end


function inner_solve(TT::Type{NewtonInnerSolver},T_arit::DataType,nep::NEPTypes.Proj_NEP;kwargs...)

    kvargsdict = Dict(kwargs);
    λv = kvargsdict[:λv];
    V = kvargsdict[:V];
    tol = kvargsdict[:tol];
    for k=1:size(λv,1)
        try
            v0=V[:,k]; # Starting vector for projected problem
            projerrmeasure=(λ,v) -> norm(compute_Mlincomb(nep,λ,v))/norm(compute_Mder(nep,λ));
            # Compute a solution to projected problem with Newton's method
            λ1,vproj=augnewton(T_arit,nep,displaylevel=0,λ=λv[k],
                               v=v0,maxit=50,tol=tol/10,
                               errmeasure=projerrmeasure);
            V[:,k]=vproj;
            λv[k]=λ1;
        catch e
            if (isa(e, NoConvergenceException))
                λ1=λv[k];
                vproj=V[:,k];
            else
                rethrow(e)
            end
        end
    end
    return λv,V
end

function inner_solve(TT::Type{PolyeigInnerSolver},T_arit::DataType,nep::NEPTypes.Proj_NEP;kwargs...)
    if (typeof(nep.orgnep)!=NEPTypes.PEP)
        error("Wrong type");
    end
    pep=NEPTypes.PEP(NEPTypes.get_Av(nep.nep_proj))
    return polyeig(T_arit,pep);
end


function inner_solve(TT::Type{IARInnerSolver},T_arit::DataType,nep::NEPTypes.Proj_NEP;σ=0,Neig=10,kwargs...)
    try
        λ,V=iar(T_arit,nep,σ=σ,Neig=Neig,tol=1e-13,maxit=50);
        return λ,V
    catch e
        if (isa(e, NoConvergenceException))
            # If we fail to find the wanted number of eigvals, we can still
            # return the ones we found
            return e.λ,e.v
        else
            rethrow(e)
        end
    end
end

function inner_solve(TT::Type{IARChebInnerSolver},T_arit::DataType,nep::NEPTypes.Proj_NEP;σ=0,Neig=10,kwargs...)
    if (typeof(nep.orgnep)==NEPTypes.DEP)
        AA=get_Av(nep);
        BB=Array{eltype(AA),1}(size(AA,1)-1);
        for i=1:(size(AA,1)-1)
            BB[i]=AA[1]\AA[1+i];
        end
        nep=DEP(BB,nep.orgnep.tauv)
    end

    try
        λ,V=iar_chebyshev(T_arit,nep,σ=σ,Neig=Neig,tol=1e-13,maxit=50);
        return λ,V
    catch e
        if (isa(e, NoConvergenceException))
            # If we fail to find the wanted number of eigvals, we can still
            # return the ones we found
            return e.λ,e.v
        else
            rethrow(e)
        end
    end
end


function inner_solve(TT::Type{SGIterInnerSolver},T_arit::DataType,nep::NEPTypes.Proj_NEP;λv=[0],j=0,kwargs...)
    λ,V=sgiter(T_arit,nep,j)
    return [λ],reshape(V,size(V,1),1);
end



function inner_solve(TT::Type{ContourBeynInnerSolver},T_arit::DataType,nep::NEPTypes.Proj_NEP;σ=0,λv=[0,1],Neig=10,kwargs...)
    # Radius  computed as the largest distance σ and λv and a litte more
    radius=maximum(abs.(σ .- λv))*1.5;
    Neig=min(Neig,size(nep,1));
    λ,V= contour_beyn(T_arit,nep,k=Neig,σ=σ,radius=radius);
    return λ,V;
end
