using SparseArrays

export SCSMatrix, SCSData, SCSSettings, SCSSolution, SCSInfo, SCSCone, SCSVecOrMatOrSparse

SCSVecOrMatOrSparse = Union{VecOrMat, SparseMatrixCSC{Float64,Int}}

struct SCSMatrix
    values::Ptr{Cdouble}
    rowval::Ptr{Int}
    colptr::Ptr{Int}
    m::Int
    n::Int
end

# Version where Julia manages the memory for the vectors.
struct ManagedSCSMatrix
    values::Vector{Cdouble}
    rowval::Vector{Int}
    colptr::Vector{Int}
    m::Int
    n::Int
end

function ManagedSCSMatrix(m::Int, n::Int, A::SCSVecOrMatOrSparse)
    A_sparse = sparse(A)

    values = copy(A_sparse.nzval)
    rowval = convert(Array{Int, 1}, A_sparse.rowval .- 1)
    colptr = convert(Array{Int, 1}, A_sparse.colptr .- 1)

    return ManagedSCSMatrix(values, rowval, colptr, m, n)
end

# Returns an SCSMatrix. The vectors are *not* GC tracked in the struct.
# Use this only when you know that the managed matrix will outlive the SCSMatrix.
SCSMatrix(m::ManagedSCSMatrix) =
    SCSMatrix(pointer(m.values), pointer(m.rowval), pointer(m.colptr), m.m, m.n)


struct SCSSettings
    normalize::Int # boolean, heuristic data rescaling
    scale::Cdouble # if normalized, rescales by this factor
    rho_x::Cdouble # x equality constraint scaling
    max_time_milliseconds::Cdouble #NEW
    max_iters::Int # maximum iterations to take
    previous_max_iters::Int #NEW
    eps::Cdouble # convergence tolerance
    alpha::Cdouble # relaxation parameter
    cg_rate::Cdouble # for indirect, tolerance goes down like (1/iter)^cg_rate
    verbose::Int # boolean, write out progress
    warm_start::Int # boolean, warm start (put initial guess in Sol struct)
    #acceleration_lookback::Int # acceleration memory parameter
    #write_data_filename::Cstring
    do_super_scs::Int #NEW /**< boolean: whether to use superscs or not */
    k0 ::Int #NEW
    c_bl::Cdouble #NEW
    k1::Int #NEW
    k2::Int #NEW
    c1::Cdouble #NEW
    sse::Cdouble #NEW
    ls::Int #NEW
    beta::Cdouble #NEW
    sigma::Cdouble #NEW
    #ScsDirectionType
    direction::UInt32#NEW
    thetabar::Cdouble #NEW
    memory::Int #NEW
    tRule::Int #NEW
    broyden_init_scaling::Int #NEW
    do_record_progress::Int #NEW
    do_override_streams::Int #NEW
    output_stream::Ptr{FILE} #cf lib_clangcommon.jl#105.

    SCSSettings() = new()
    SCSSettings(normalize, scale, rho_x,max_time_milliseconds,
     max_iters, previous_max_iters,eps, alpha, cg_rate, verbose, warm_start,
     do_super_scs,k0,c_dbl,k1,k2,c1,sse,ls,beta,sigma,direction,
     thetabar,memory,tRule, broyden_init_scaling,do_record_progress,
     do_override_streams,output_stream)= new(normalize, scale, rho_x,max_time_milliseconds,
     max_iters, previous_max_iters,eps, alpha, cg_rate, verbose, warm_start,
     do_super_scs,k0,c_dbl,k1,k2,c1,sse,ls,beta,sigma,direction,
     thetabar,memory,tRule, broyden_init_scaling,do_record_progress,
     do_override_streams,output_stream)
#     acceleration_lookback, write_data_filename)
end

# struct SCSSettings
#     normalize::Int # boolean, heuristic data rescaling
#     scale::Cdouble # if normalized, rescales by this factor
#     rho_x::Cdouble # x equality constraint scaling
#     max_iters::Int # maximum iterations to take
#     eps::Cdouble # convergence tolerance
#     alpha::Cdouble # relaxation parameter
#     cg_rate::Cdouble # for indirect, tolerance goes down like (1/iter)^cg_rate
#     verbose::Int # boolean, write out progress
#     warm_start::Int # boolean, warm start (put initial guess in Sol struct)
#     acceleration_lookback::Int # acceleration memory parameter
#     write_data_filename::Cstring
#
#     SCSSettings() = new()
#     SCSSettings(normalize, scale, rho_x, max_iters, eps, alpha, cg_rate, verbose, warm_start, acceleration_lookback, write_data_filename) = new(normalize, scale, rho_x, max_iters, eps, alpha, cg_rate, verbose, warm_start, acceleration_lookback, write_data_filename)
# end

struct Direct end
struct Indirect end

function _SCS_user_settings(default_settings::SCSSettings;
        normalize=default_settings.normalize,
        scale=default_settings.scale,
        rho_x=default_settings.rho_x,
        max_iters=default_settings.max_iters,
        eps=default_settings.eps,
        alpha=default_settings.alpha,
        cg_rate=default_settings.cg_rate,
        verbose=default_settings.verbose,
        warm_start=default_settings.warm_start,

        do_super_scs=default_settings.do_super_scs #NEW /**< boolean: whether to use superscs or not */
        k0=default_settings.k0, #NEW
        c_bl=default_settings.c_bl, #NEW
        k1=default_settings.k1, #NEW
        k2=default_settings.k2, #NEW
        c1=default_settings.c1,#NEW
        sse=default_settings.sse, #NEW
        ls=default_settings.ls, #NEW
        beta=default_settings.beta, #NEW
        sigma=default_settings.sigma, #NEW
        direction=default_settings.direction,#NEW
        thetabar=default_settings.thetabar, #NEW
        memory=default_settings.memory, #NEW
        tRule=default_settings.tRule, #NEW
        broyden_init_scaling=default_settings.broyden_init_scaling, #NEW
        do_record_progress=default_settings.do_record_progress, #NEW
        do_override_streams=default_settings.do_override_streams, #NEW
        output_stream=default_settings.output_stream
        # acceleration_lookback=default_settings.acceleration_lookback,
        # write_data_filename=default_settings.write_data_filename
        )
    return SCSSettings(normalize, scale, rho_x,max_time_milliseconds,
     max_iters, previous_max_iters,eps, alpha, cg_rate, verbose, warm_start,
     do_super_scs,k0,c_dbl,k1,k2,c1,sse,ls,beta,sigma,direction,
     thetabar,memory,tRule, broyden_init_scaling,do_record_progress,
     do_override_streams,output_stream)
end

function SCSSettings(linear_solver::Union{Type{Direct}, Type{Indirect}}; options...)

    mmatrix = ManagedSCSMatrix(0,0,spzeros(1,1))
    matrix = Ref(SCSMatrix(mmatrix))
    default_settings = Ref(SCSSettings())
    #----------------REVOIR !!!!!
    dummy_data = Ref(SCSData(0,0, Base.unsafe_convert(Ptr{SCSMatrix}, matrix),
        pointer([0.0]), pointer([0.0]),
        Base.unsafe_convert(Ptr{SCSSettings}, default_settings)))
    SCS_set_default_settings(linear_solver, dummy_data)
    return _SCS_user_settings(default_settings[]; options...)
end

struct SCSData
    # A has m rows, n cols
    m::Int
    n::Int
    A::Ptr{SCSMatrix}
    # b is of size m, c is of size n
    b::Ptr{Cdouble}
    c::Ptr{Cdouble}
    stgs::Ptr{SCSSettings}
end

struct SCSSolution
    x::Ptr{Nothing}
    y::Ptr{Nothing}
    s::Ptr{Nothing}
end

struct SCSInfo
    iter::Int
    status::NTuple{32, Cchar} # char status[32]
    statusVal::Int
    history_length::Int /**< \brief how many history entries */
    cg_total_iters::Int /**< \brief total CG iterations (\c -1 if not defined) */

    pobj::Cdouble
    dobj::Cdouble
    resPri::Cdouble
    resDual::Cdouble
    resInfeas::Cdouble
    resUnbdd::Cdouble
    relGap::Cdouble
    setupTime::Cdouble
    solveTime::Cdouble
    linsys_total_solve_time_ms::Cdouble /**< \brief total linsys (e.g., CG) solve time in ms */
progress_relgap::Cdouble /**< \brief relative gap history */
progress_respri::Cdouble /**< \brief primal residual history */
progress_resdual::Cdouble /**< \brief dual residual history */
progress_pcost::Cdouble /**< \brief scaled primal cost history */
progress_dcost::Cdouble /**< \brief sclaed dual cost history */
progress_norm_fpr::Cdouble /**< \brief FPR history */
progress_time::Cdouble /**< \brief Timestamp of iteration */scs_int *RESTRICT progress_iter; /**< \brief iterations when residulas are recorded */
progress_mode::Int /**< \brief Mode of SuperSCS at each iteration */
progress_ls::Int /**< \brief Number of line search iterations */
allocated_memory::Culonglong /**< \brief Memory, in bytes, that was allocated to run the algorithm */

end

SCSInfo() = SCSInfo(0, ntuple(_ -> zero(Cchar), 32), 0, 0,0,
    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
    0,0,0,0
)

function raw_status(info::SCSInfo)
    s = collect(info.status)
    len = findfirst(iszero, s) - 1
    # There is no method String(::Vector{Cchar}) so we convert to `UInt8`.
    return String(UInt8[s[i] for i in 1:len])
end

# SCS solves a problem of the form
# minimize        c' * x
# subject to      A * x + s = b
#                 s in K
# where K is a product cone of
# zero cones,
# linear cones { x | x >= 0 },
# second-order cones { (t,x) | ||x||_2 <= t },
# semi-definite cones { X | X psd }, and
# exponential cones {(x,y,z) | y e^(x/y) <= z, y>0 }.
# dual exponential cones {(u,v,w) | −u e^(v/u) <= e w, u<0}
# power cones {(x,y,z) | x^a * y^(1-a) >= |z|, x>=0, y>=0}
# dual power cones {(u,v,w) | (u/a)^a * (v/(1-a))^(1-a) >= |w|, u>=0, v>=0}
struct SCSCone
    f::Int # number of linear equality constraints
    l::Int # length of LP cone
    q::Ptr{Int} # array of second-order cone constraints
    qsize::Int # length of SOC array
    s::Ptr{Int} # array of SD constraints
    ssize::Int # length of SD array
    ep::Int # number of primal exponential cone triples
    ed::Int # number of dual exponential cone triples
    p::Ptr{Cdouble} # array of power cone params, must be \in [-1, 1], negative values are interpreted as specifying the dual cone
    psize::Int # length of power cone array
end

# Returns an SCSCone. The q, s, and p arrays are *not* GC tracked in the
# struct. Use this only when you know that q, s, and p will outlive the struct.
function SCSCone(f::Int, l::Int, q::Vector{Int}, s::Vector{Int},
                 ep::Int, ed::Int, p::Vector{Cdouble})
    return SCSCone(f, l, pointer(q), length(q), pointer(s), length(s), ep, ed, pointer(p), length(p))
end


mutable struct Solution
    x::Array{Float64, 1}
    y::Array{Float64, 1}
    s::Array{Float64, 1}
    info::SCSInfo
    ret_val::Int
end

function sanitize_SCS_options(options)
    options = Dict(options)
    if haskey(options, :linear_solver)
        linear_solver = options[:linear_solver]
        if linear_solver == Direct || linear_solver == Indirect
            nothing
        else
            throw(ArgumentError("Unrecognized linear_solver passed to SCS: $linear_solver;\nRecognized options are: $Direct, $Indirect."))
        end
        delete!(options, :linear_solver)
    else
        linear_solver = Indirect # the default linear_solver
    end

    SCS_options = append!([:linear_solver], fieldnames(SCSSettings))
    unrecognized = setdiff(keys(options), SCS_options)
    if length(unrecognized) > 0
        plur = length(unrecognized) > 1 ? "s" : ""
        throw(ArgumentError("Unrecognized option$plur passed to SCS: $(join(unrecognized, ", "));\nRecognized options are: $(join(SCS_options, ", ", " and "))."))
    end
    return linear_solver, options
end
