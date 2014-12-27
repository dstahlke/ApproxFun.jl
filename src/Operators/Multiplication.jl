abstract AbstractMultiplication{T} <:BandedOperator{T}

immutable Multiplication{D<:FunctionSpace,S<:FunctionSpace,T<:Number} <: AbstractMultiplication{T}
    f::Fun{D,T}
    space::S
    
    Multiplication(f::Fun{D,T},sp::S)=new(f,sp)
end

Multiplication{D,T,S}(f::Fun{D,T},sp::S)=Multiplication{D,S,T}(f,sp)

Multiplication(f::Fun)=Multiplication(f,AnySpace())

Multiplication(c::Number)=ConstantOperator(c)




domainspace{D,S,T}(M::Multiplication{D,S,T})=M.space
domain(T::Multiplication)=domain(T.f)


## Default implementation: try converting to space of M.f

rangespace{F,T}(D::Multiplication{F,AnySpace,T})=AnySpace()
bandinds{F,T}(D::Multiplication{F,AnySpace,T})=error("No range space attached to Multiplication")
addentries!{F,T}(D::Multiplication{F,AnySpace,T},A,kr)=error("No range space attached to Multiplication")


function addentries!{F,S,T}(D::Multiplication{F,S,T},A,kr)   
    # Default is to convert to space of f
    sp=domainspace(D)
    csp=space(D.f)
    if csp==sp
        error("Override Multiplication(::Fun{"*string(typeof(space(D.f)))*",T},"*string(typeof(sp))*")")
    end
    addentries!(TimesOperator([Multiplication(D.f,csp),Conversion(sp,csp)]),A,kr)
end
        
function bandinds{F,S,T}(D::Multiplication{F,S,T})
    sp=domainspace(D)
    csp=space(D.f)
    if csp==sp
        error("Override bandinds for Multiplication(::Fun{"*string(typeof(space(D.f)))*",T},"*string(typeof(sp))*")")
    end     
    bandinds(TimesOperator([Multiplication(D.f,csp),Conversion(sp,csp)]))
end

# corresponds to default implementation        
function rangespace{F,S,T}(D::Multiplication{F,S,T})
    sp=domainspace(D)
    csp=space(D.f)
    if csp==sp
        error("Override rangespace for Multiplication(::Fun{"*string(typeof(space(D.f)))*",T},"*string(typeof(sp))*")")
    end      
    rangespace(TimesOperator([Multiplication(D.f,csp),Conversion(sp,csp)]))
end






##multiplication can always be promoted, range space is allowed to change
promotedomainspace(D::AbstractMultiplication,sp::AnySpace)=D
promotedomainspace(D::AbstractMultiplication,sp::FunctionSpace)=Multiplication(D.f,sp)


Base.diagm(a::Fun)=Multiplication(a)


immutable MultiplicationWrapper{D<:FunctionSpace,O<:BandedOperator,T<:Number} <: AbstractMultiplication{T}
    f::Fun{D,T}
    op::O
end

MultiplicationWrapper{D<:FunctionSpace,T<:Number}(f::Fun{D,T},op::BandedOperator{T})=MultiplicationWrapper{D,typeof(op),T}(f,op)

addentries!(D::MultiplicationWrapper,A,k::Range)=addentries!(D.op,A,k)
for func in (:rangespace,:domainspace,:bandinds,:domain,:(Base.stride))
    @eval $func(D::MultiplicationWrapper)=$func(D.op)
end





## Multiplication operators allowus to multiply two spaces

# Overrideable
# This should be overriden whenever the multiplication space is different
function .*{T,N,S,V}(f::Fun{S,T},g::Fun{V,N})
    # When the spaces differ we promote and multiply   
    if domainscompatible(space(f),space(g))
        # THe bandwidth of Mutliplication is
        # usually the length of the function
        if length(f)≤length(g)
            Multiplication(f,space(g))*g
        else
            Multiplication(g,space(f))*f
        end        
    else         
        sp=union(space(f),space(g))
        Fun(f,sp).*Fun(g,sp)
    end
end


function transformtimes(f::Fun,g::Fun,n)
    @assert spacescompatible(space(f),space(g))
    f2 = pad(f,n); g2 = pad(g,n)
    
    sp=space(f)
    chop!(Fun(transform(sp,values(f2).*values(g2)),sp),10eps())    
end
transformtimes(f::Fun,g::Fun)=transformtimes(f,g,length(f) + length(g) - 1)