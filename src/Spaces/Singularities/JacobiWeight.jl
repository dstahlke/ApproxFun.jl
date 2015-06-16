


export JacobiWeight

abstract WeightSpace <: IntervalSpace  #TODO: Why Interval?


domain(S::WeightSpace)=domain(S.space)

transform(sp::WeightSpace,vals::Vector)=transform(sp.space,vals./weight(sp,points(sp,length(vals))))
itransform(sp::WeightSpace,cfs::Vector)=itransform(sp.space,cfs).*weight(sp,points(sp,length(cfs)))
points(sp::WeightSpace,n)=points(sp.space,n)


function evaluate{WS<:WeightSpace,T}(f::Fun{WS,T},x)
    tol=1.0E-14
    fv=Fun(f.coefficients,space(f).space)[x]
    if isa(fv,Number)&&abs(fv)<tol
        #TODO: Why this special case??
        zero(T)
    else
        weight(space(f),x).*fv
    end
end


## JacobiWeight



immutable JacobiWeight{S<:IntervalSpace} <: WeightSpace
    α::Float64
    β::Float64
    space::S
    function JacobiWeight(α::Float64,β::Float64,space::S)
        if isa(space,JacobiWeight)
            JacobiWeight(α+space.α,β+space.β,space.space)
        else
            new(α,β,space)
        end
    end
end

JacobiWeight{S<:IntervalSpace}(a::Number,b::Number,d::S)=JacobiWeight{S}(@compat(Float64(a)),@compat(Float64(b)),d)
JacobiWeight(a::Number,b::Number,d::IntervalDomain)=JacobiWeight(@compat(Float64(a)),@compat(Float64(b)),Space(d))
JacobiWeight(a::Number,b::Number,d::Vector)=JacobiWeight(@compat(Float64(a)),@compat(Float64(b)),Space(d))
JacobiWeight(a::Number,b::Number)=JacobiWeight(a,b,Chebyshev())

JacobiWeight{S<:IntervalSpace}(a::Number,b::Number,s::Vector{S}) = map(s->JacobiWeight(a,b,s),s)
JacobiWeight{S<:IntervalSpace,T}(a::Number,b::Number,s::PiecewiseSpace{S,T}) = PiecewiseSpace(JacobiWeight(a,b,vec(s)))

identity_fun(S::JacobiWeight)=isapproxinteger(S.α)&&isapproxinteger(S.β)?Fun(x->x,S):Fun(identity,domain(S))



spacescompatible(A::JacobiWeight,B::JacobiWeight)=A.α==B.α && A.β == B.β && spacescompatible(A.space,B.space)
spacescompatible(A::JacobiWeight,B::IntervalSpace)=spacescompatible(A,JacobiWeight(0,0,B))
spacescompatible(B::IntervalSpace,A::JacobiWeight)=spacescompatible(A,JacobiWeight(0,0,B))

transformtimes{S,V}(f::Fun{JacobiWeight{S}},g::Fun{JacobiWeight{V}}) = Fun(coefficients(transformtimes(Fun(f.coefficients,f.space.space),Fun(g.coefficients,g.space.space))),JacobiWeight(f.space.α+g.space.α,f.space.β+g.space.β,f.space.space))
transformtimes{S}(f::Fun{JacobiWeight{S}},g::Fun) = Fun(coefficients(transformtimes(Fun(f.coefficients,f.space.space),g)),f.space)
transformtimes{S}(f::Fun,g::Fun{JacobiWeight{S}}) = Fun(coefficients(transformtimes(Fun(g.coefficients,g.space.space),f)),g.space)

## In this package, α and β are opposite the convention. Here, α is the left algebraic singularity and β is the right algebraic singularity.

jacobiweight(α,β,x)=(1+x).^α.*(1-x).^β
weight(sp::JacobiWeight,x)=jacobiweight(sp.α,sp.β,tocanonical(sp,x))


## Use 1st kind points to avoid singularities
points(sp::JacobiWeight,n)=fromcanonical(sp,chebyshevpoints(n;kind=1))

# These are meant for Jacobi
plan_itransform(S::JacobiWeight,n::Integer)=points(S,n)
itransform(S::JacobiWeight,cfs::Vector)=itransform(S,cfs,plan_itransform(S,length(cfs)))
itransform(S::JacobiWeight,cfs::Vector,pts::Vector)=weight(S,pts).*itransform(S.space,cfs)

##TODO: paradigm for same space
function coefficients(f::Vector,sp1::JacobiWeight,sp2::JacobiWeight)
    α,β=sp1.α,sp1.β
    c,d=sp2.α,sp2.β

    if isapprox(c,α) && isapprox(d,β)
        coefficients(f,sp1.space,sp2.space)
    else
        (Conversion(sp1,sp2)*f)
    end
end
coefficients{S,n,st}(f::Vector,sp::JacobiWeight,S2::SliceSpace{n,st,S,RealBasis})=error("Implement")
coefficients{S,n,st}(f::Vector,S2::SliceSpace{n,st,S,RealBasis},sp::JacobiWeight)=error("Implement")
coefficients(f::Vector,sp::JacobiWeight,S2::IntervalSpace)=coefficients(f,sp,JacobiWeight(0,0,S2))
coefficients(f::Vector,S2::IntervalSpace,sp::JacobiWeight)=coefficients(f,JacobiWeight(0,0,S2),sp)

increase_jacobi_parameter(f)=Fun(f,JacobiWeight(f.space.α+1,f.space.β+1,space(f).space))
increase_jacobi_parameter(s,f)=s==-1?Fun(f,JacobiWeight(f.space.α+1,f.space.β,space(f).space)):Fun(f,JacobiWeight(f.space.α,f.space.β+1,space(f).space))



function canonicalspace(S::JacobiWeight)
    if S.α==0 && S.β==0
        canonicalspace(S.space)
    else
        #TODO: promote singularities?
        JacobiWeight(S.α,S.β,canonicalspace(S.space))
    end
end

## Algebra

for op in (:/,:./)
    @eval begin
        ($op){S}(c::Number,f::Fun{JacobiWeight{S}})=Fun(($op)(c,Fun(f.coefficients,space(f).space)).coefficients,
                                                        JacobiWeight(-f.space.α,-f.space.β,space(f).space))
    end
end

function .^{J<:JacobiWeight}(f::Fun{J},k::Float64)
    S=space(f)
    g=Fun(coefficients(f),S.space)^k
    Fun(coefficients(g),JacobiWeight(k*S.α,k*S.β,space(g)))
end

function .*{S,V}(f::Fun{JacobiWeight{S}},g::Fun{JacobiWeight{V}})
    @assert domainscompatible(f,g)
    fα,fβ=f.space.α,f.space.β
    gα,gβ=g.space.α,g.space.β
    m=(Fun(f.coefficients,space(f).space).*Fun(g.coefficients,space(g).space))
    if isapprox(fα+gα,0)&&isapprox(fβ+gβ,0)
        m
    else
        Fun(m.coefficients,JacobiWeight(fα+gα,fβ+gβ,space(m)))
    end
end


./{T,N}(f::Fun{JacobiWeight{T}},g::Fun{JacobiWeight{N}})=f*(1/g)

function Base.dot(f::Fun{JacobiWeight{Chebyshev}},g::Fun{Chebyshev})
    @assert domain(f) == domain(g)
    if f.space.α == f.space.β == -0.5
        mn = min(length(f),length(g))
        return complexlength(domain(f))*(conj(f.coefficients[1])*g.coefficients[1]+dot(f.coefficients[1:mn],g.coefficients[1:mn]))*π/4
    else
        return generaldot(f,g)
    end
end

function Base.dot(f::Fun{Chebyshev},g::Fun{JacobiWeight{Chebyshev}})
    @assert domain(f) == domain(g)
    if g.space.α == g.space.β == -0.5
        mn = min(length(f),length(g))
        return complexlength(domain(f))*(conj(f.coefficients[1])*g.coefficients[1]+dot(f.coefficients[1:mn],g.coefficients[1:mn]))*π/4
    else
        return generaldot(f,g)
    end
end

function Base.dot(f::Fun{JacobiWeight{Chebyshev}},g::Fun{JacobiWeight{Chebyshev}})
    @assert domain(f) == domain(g)
    if f.space.α+g.space.α == f.space.β+g.space.β == -0.5
        mn = min(length(f),length(g))
        return complexlength(domain(f))*(conj(f.coefficients[1])*g.coefficients[1]+dot(f.coefficients[1:mn],g.coefficients[1:mn]))*π/4
    else
        return generaldot(f,g)
    end
end


## Project
#TODO: Where is this used?
project{S}(f::Fun{JacobiWeight{S}})=Fun(f.coefficients,JacobiWeight(space(f).α,space(f).β,canonicaldomain(f)))

