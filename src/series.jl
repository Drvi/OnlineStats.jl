"""
AbstractSeries:  Managers for a group or single OnlineStat

Subtypes should:
- Have fields `weight::Weight`, `nobs::Int`, and `nups::Int`
"""
abstract type AbstractSeries end
#----------------------------------------------------------------# AbstractSeries methods
nobs(o::AbstractSeries) = o.nobs
nups(o::AbstractSeries) = o.nups
weight!(o::AbstractSeries, n2::Int = 1) = (updatecounter!(o, n2); weight(o, n2))
updatecounter!(o::AbstractSeries, n2::Int = 1) = (o.nups += 1; o.nobs += n2)
weight(o::AbstractSeries, n2::Int = 1) = weight(o.weight, o.nobs, n2, o.nups)
nextweight(o::AbstractSeries, n2::Int = 1) = nextweight(o.weight, o.nobs, n2, o.nups)
Base.copy(o::AbstractSeries) = deepcopy(o)
function Base.show(io::IO, o::AbstractSeries)
    header(io, "$(name(o))\n")
    subheader(io, "nobs = $(o.nobs)\n")
    show_series(io, o)
end
show_series(io::IO, o::AbstractSeries) = print(io)
const _label = :unlabeled

#----------------------------------------------------------------# Series
mutable struct Series{I, OS <: Union{Tuple, OnlineStat{I}}, W <: Weight} <: AbstractSeries
    weight::W
    nobs::Int
    nups::Int
    stats::OS
end
function Series(wt::Weight, S::Union{Tuple, OnlineStat})
    Series{input(S), typeof(S), typeof(wt)}(wt, 0, 0, S)
end
Series(wt::Weight, s...) = Series(wt, s)
Series(wt::Weight, s) = Series(wt, s)

Series(s...) = Series(default(Weight, s), s)
Series(s) = Series(default(Weight, s), s)

Series(t::Tuple,      wt::Weight = default(Weight, t)) = Series(wt, t)
Series(o::OnlineStat, wt::Weight = default(Weight, o)) = Series(wt, o)

Series(y::AA, s...) = (o = Series(default(Weight, s), s); fit!(o, y))
Series(y::AA, s) = (o = Series(default(Weight, s), s); fit!(o, y))

Series(y::AA, wt::Weight, s...) = (o = Series(wt, s); fit!(o, y))
Series(y::AA, wt::Weight, s) = (o = Series(wt, s); fit!(o, y))


show_series(io::IO, s::Series) = print_item.(io, name.(s.stats), value.(s.stats))

value(s::Series) = map(value, s.stats)
value(s::Series, i::Integer) = value(s.stats[i])
stats(s::Series) = s.stats
stats(s::Series, i::Integer) = s.stats[i]


Base.map(f::Function, o::OnlineStat) = f(o)
#-----------------------------------------------------------------------# Series{0}
function fit!(s::Series{0}, y::Real, γ::Float64 = nextweight(s))
    updatecounter!(s)
    map(s -> fit!(s, y, γ), s.stats)
    s
end
function fit!(s::Series{0}, y::AVec)
    for yi in y
        fit!(s, yi)
    end
    s
end
function fit!(s::Series{0}, y::AVec, γ::Float64)
    for yi in y
        fit!(s, yi, γ)
    end
    s
end
function fit!(s::Series{0}, y::AVec, γ::AVecF)
    length(y) == length(γ) || throw(DimensionMismatch())
    for (yi, γi) in zip(y, γ)
        fit!(s, yi, γi)
    end
    s
end
function fit!(s::Series{0}, y::AVec, b::Integer)
    maprows(b, y) do yi
        bi = length(yi)
        γ = weight!(s, bi)
        map(o -> fitbatch!(o, yi, γ), s.stats)
    end
    s
end

#-----------------------------------------------------------------------# Series{1}
function fit!(s::Series{1}, y::AVec, γ::Float64 = nextweight(s))
    updatecounter!(s)
    map(s -> fit!(s, y, γ), s.stats)
    s
end
function fit!(s::Series{1}, y::AMat)
    for i in 1:size(y, 1)
        fit!(s, view(y, i, :))
    end
    s
end
function fit!(s::Series{1}, y::AMat, γ::Float64)
    for i in 1:size(y, 1)
        fit!(s, view(y, i, :), γ)
    end
    s
end
function fit!(s::Series{1}, y::AMat, γ::AVecF)
    for i in 1:size(y, 1)
        fit!(s, view(y, i, :), γ[i])
    end
    s
end
function fit!(s::Series{1}, y::AMat, b::Integer)
    maprows(b, y) do yi
        bi = size(yi, 1)
        γ = weight!(s, bi)
        map(o -> fitbatch!(o, yi, γ), s.stats)
    end
    s
end

#-------------------------------------------------------------------------# merge
Base.merge{T <: Series}(s1::T, s2::T, method::Symbol = :append) = merge!(copy(s1), s2, method)

function Base.merge!{T <: Series}(s1::T, s2::T, method::Symbol = :append)
    n2 = nobs(s2)
    n2 == 0 && return s1
    updatecounter!(s1, n2)
    for (o1, o2) in zip(s1.stats, s2.stats)
        if method == :append
            merge!(o1, o2, nextweight(s1, n2))
        elseif method == :mean
            merge!(o1, o2, (weight(s1) + weight(s2)))
        elseif method == :singleton
            merge!(o1, o2, nextweight(s1))
        else
            throw(ArgumentError("method must be :append, :mean, or :singleton"))
        end
    end
    s1
end
