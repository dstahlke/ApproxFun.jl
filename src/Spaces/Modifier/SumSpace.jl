export ⊕

## SumSpace{T,S,V} encodes a space that can be decoupled as f(x) = a(x) + b(x) where a is in S and b is in V


immutable PeriodicSumSpace{S<:PeriodicDomainSpace,V<:PeriodicDomainSpace,T<:Number} <: PeriodicDomainSpace{T}
    spaces::(S,V)
end


function PeriodicSumSpace{T<:Number}(A::(PeriodicDomainSpace{T},PeriodicDomainSpace{T}))
    @assert domain(A[1])==domain(A[2])
    PeriodicSumSpace{typeof(A[1]),typeof(A[2]),T}(A)
end

PeriodicSumSpace(A::PeriodicDomainSpace,B::PeriodicDomainSpace)=PeriodicSumSpace((A,B))



immutable IntervalSumSpace{S<:IntervalDomainSpace,V<:IntervalDomainSpace} <: IntervalDomainSpace
    spaces::(S,V)
end

function IntervalSumSpace(A::(IntervalDomainSpace,IntervalDomainSpace))
    @assert domain(A[1])==domain(A[2])
    IntervalSumSpace{typeof(A[1]),typeof(A[2])}(A)
end

IntervalSumSpace(A::IntervalDomainSpace,B::IntervalDomainSpace)=IntervalSumSpace((A,B))




⊕(A::IntervalDomainSpace,B::IntervalDomainSpace)=IntervalSumSpace(A,B)
⊕(A::PeriodicDomainSpace,B::PeriodicDomainSpace)=PeriodicSumSpace(A,B)

⊕(f::Fun,g::Fun)=Fun(interlace(coefficients(f),coefficients(g)),space(f)⊕space(g))


typealias SumSpace{S,V,T} Union(PeriodicSumSpace{S,V,T},IntervalSumSpace{S,V})


Base.getindex(S::SumSpace,k)=S.spaces[k]

domain(A::SumSpace)=domain(A[1])
evaluate{D<:SumSpace,T}(f::Fun{D,T},x)=evaluate(Fun(f.coefficients[1:2:end],space(f)[1]),x)+evaluate(Fun(f.coefficients[2:2:end],space(f)[2]),x)


spacescompatible{S,T}(A::SumSpace{S,T},B::SumSpace{S,T})=spacescompatible(A.spaces[1],B[1]) && spacescompatible(A.spaces[2],B[2])





## calculus

# assume first domain has ones

Base.ones{T<:Number}(::Type{T},S::SumSpace)=ones(T,S[1])⊕zeros(T,S[2])
Base.ones(S::SumSpace)=ones(S[1])⊕zeros(S[2])
