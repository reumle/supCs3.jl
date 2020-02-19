@testset "Test the MathProgBase wrapper with linprog" begin
    include("mpb_linear.jl")
end

import MathProgBase
for T in [supCs3.Direct, supCs3.Indirect]
    @testset "MathProgBase $T" begin
        include(joinpath(dirname(dirname(pathof(MathProgBase))), "test", "conicinterface.jl"))
        coniclineartest(supCs3.SCSSolver(linear_solver=T, eps=1e-6, verbose=0),
                        duals=true, tol=1e-5)
        conicSOCtest(supCs3.SCSSolver(linear_solver=T, eps=1e-6, verbose=0),
                     duals=true, tol=1e-5)
        conicEXPtest(supCs3.SCSSolver(linear_solver=T, eps=1e-6, verbose=0),
                     duals=true, tol=1e-5)
        conicSDPtest(supCs3.SCSSolver(linear_solver=T, eps=1e-6, verbose=0),
                     duals=true, tol=1e-5)
    end
end
