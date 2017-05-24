# SplineSpace represents a Spline, right now piecewise constant HeavisideSpace is only implemented case
struct SplineSpace{order,T,R} <: Space{PiecewiseSegment{T},R}
    domain::PiecewiseSegment{T}
end

SplineSpace{m,T}(d::PiecewiseSegment{T}) where {m,T} = SplineSpace{m,T,real(eltype(T))}(d)
SplineSpace{m,T}(d::AbstractVector) where {m,T} = SplineSpace{m}(PiecewiseSegment(sort(d)))

SplineSpace{m}(d::PiecewiseSegment{T}) where {m,T} = SplineSpace{m,T,real(eltype(T))}(d)
SplineSpace{m}(d::AbstractVector) where {m} = SplineSpace{m}(PiecewiseSegment(sort(d)))

const HeavisideSpace{T,R} = SplineSpace{0,T,R}
dimension{λ}(h::SplineSpace{λ}) = length(h.domain.points)+λ-1

Base.convert(::Type{HeavisideSpace},d::PiecewiseSegment) = HeavisideSpace{eltype(d)}(d)

Base.convert(::Type{HeavisideSpace},d::AbstractVector) =
    HeavisideSpace(PiecewiseSegment(sort(d)))

spacescompatible{λ}(a::SplineSpace{λ},b::SplineSpace{λ}) = domainscompatible(a,b)
canonicalspace(sp::HeavisideSpace) = PiecewiseSpace(map(Chebyshev,components(domain(sp))))


function evaluate{T<:Real,R}(f::Fun{HeavisideSpace{T,R}},x::Real)
    p = domain(f).points
    c = f.coefficients
    for k=1:length(p)-1
        if p[k] ≤ x ≤ p[k+1]
            return c[k]
        end
    end
    return zero(T)
end


function evaluate{T<:Real,R}(f::Fun{SplineSpace{1,T,R}},x::Real)
    p = domain(f).points
    c = f.coefficients
    for k=1:length(p)-1
        if p[k] ≤ x ≤ p[k+1]
            return (x-p[k])*c[k+1]/(p[k+1]-p[k]) + (p[k+1]-x)*c[k]/(p[k+1]-p[k])
        end
    end
    return zero(T)
end


function points(sp::HeavisideSpace,n)
    x=sp.domain.points
    (x[1:end-1] + diff(x)/2)[1:n]
end

points(sp::SplineSpace{1},n) = sp.domain.points[1:n]

for λ = [0,1]
    @eval begin
        function transform(S::SplineSpace{$λ},vals::Vector,plan...)
            @assert length(vals) ≤ dimension(S)
            vals
        end
        itransform(S::SplineSpace{$λ},cfs::Vector,plan...) = pad(cfs,dimension(S))
    end
end

conversion_rule{k,PS<:PolynomialSpace}(sp::HeavisideSpace,sp2::PiecewiseSpace{NTuple{k,PS}}) = sp


Conversion(a::HeavisideSpace,b::PiecewiseSpace{NTuple{kk,CC},DD,RR}) where {kk,CC<:PolynomialSpace,DD<:UnivariateDomain,RR<:Real} =
    ConcreteConversion(a,b)
bandinds(::ConcreteConversion{HS,PiecewiseSpace{NTuple{kk,CC},DD,RR}}) where {HS<:HeavisideSpace,CC<:PolynomialSpace,DD<:UnivariateDomain,RR<:Real,kk} =
    0,0

getindex(C::ConcreteConversion{HS,PiecewiseSpace{NTuple{kk,CC},DD,RR}},k::Integer,j::Integer) where {HS<:HeavisideSpace,CC<:PolynomialSpace,DD<:UnivariateDomain,RR<:Real,kk} =
    k ≤ dimension(domainspace(C)) && j==k? one(eltype(C)) : zero(eltype(C))


bandinds{HS<:HeavisideSpace}(D::ConcreteDerivative{HS})=-1,0

rangespace{HS<:HeavisideSpace}(D::ConcreteDerivative{HS})=DiracSpace(domain(D).points)

function getindex{HS<:HeavisideSpace}(D::ConcreteDerivative{HS},k::Integer,j::Integer)
    n=ncomponents(domain(D))
    if k≤n && j==k
        one(eltype(D))
    elseif j≤n && j==k-1
        -one(eltype(D))
    else
        zero(eltype(D))
    end
end

Base.sum{HS<:HeavisideSpace}(f::Fun{HS}) = dotu(f.coefficients,diff(space(f).domain.points))
function Base.sum{T,R}(f::Fun{SplineSpace{1,T,R}})
    vals=pad(f.coefficients,dimension(space(f)))
    dfs=diff(space(f).domain.points)
    ret=vals[1]*dfs[1]/2
    for k=2:length(vals)-1
        ret+=vals[k]*(dfs[k]+dfs[k+1])/2
    end
    ret+=vals[end]*dfs[end]/2
    ret
end


differentiate{T,R}(f::Fun{SplineSpace{1,T,R}}) =
    Fun(HeavisideSpace(space(f).domain),
        diff(pad(f.coefficients,dimension(space(f))))./diff(space(f).domain.points))

integrate{T,R}(f::Fun{HeavisideSpace{T,R}}) =
    Fun(SplineSpace{1,T,R}(space(f).domain),
        [0;cumsum(f.coefficients).*diff(space(f).domain.points)])
