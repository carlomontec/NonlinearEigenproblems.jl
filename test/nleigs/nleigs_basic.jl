# Solves a few basic eigenvalue problems to test various aspects of NLEIGS

# Intended to be run from nep-pack/ directory or nep-pack/test directory
push!(LOAD_PATH, string(@__DIR__, "/../../src"))

using NEPCore
using NEPTypes
using LinSolvers
using NEPSolver
using Gallery
using IterativeSolvers
using Test

include("nleigs_test_utils.jl")
include(normpath(string(@__DIR__), "..", "..", "src", "nleigs", "inpolygon.jl"))

function nleigs_basic()
    n = 2
    B = Vector{Matrix{Float64}}([[1 3; 5 6], [3 4; 6 6], [1 0; 0 1]])
    pep = PEP(B)

    Σ = [-10.0-2im, 10-2im, 10+2im, -10+2im]

    @testset "Polynomial only" begin
        @time lambda, X = nleigs(pep, Σ, maxit=10, v=ones(n).+0im, blksize=5)
        nleigs_verify_lambdas(4, pep, X, lambda)
    end

    @testset "Non-convergent linearization" begin
        @test_logs (:warn, r".*Linearization not converged.*") begin
            @time lambda, X = nleigs(pep, Σ, maxit=10, v=ones(n).+0im, maxdgr=5, blksize=5)
            nleigs_verify_lambdas(4, pep, X, lambda)
        end
    end

    @testset "Non-convergent linearization (static)" begin
        @test_logs (:warn, r".*Linearization not converged.*") begin
            @time lambda, X = nleigs(pep, Σ, maxit=10, v=ones(n).+0im, maxdgr=5, blksize=5, static=true)
            nleigs_verify_lambdas(4, pep, X, lambda)
        end
    end

    @testset "Non-convergent linearization (return_details)" begin
        @test_logs (:warn, r".*Linearization not converged.*") begin
            @time lambda, X, _ = nleigs(pep, Σ, maxit=5, v=ones(n).+0im, blksize=5, return_details=true)
            nleigs_verify_lambdas(0, pep, X, lambda)
        end
    end

    @testset "Complex-valued matrices" begin
        complex_B = map(X -> X + im*I, B)
        complex_pep = PEP(complex_B)
        @time lambda, X, _ = nleigs(complex_pep, Σ, maxit=10, v=ones(n).+0im, blksize=5, return_details=true)
        nleigs_verify_lambdas(3, complex_pep, X, lambda)
    end

    @testset "Complex-valued start vector" begin
        @time lambda, X, _ = nleigs(pep, Σ, maxit=10, v=ones(n) * (1+0.1im), blksize=5, return_details=true)
        nleigs_verify_lambdas(4, pep, X, lambda)
    end

    @testset "return_details" begin
        @time lambda, X, res, details = nleigs(pep, Σ, maxit=10, v=ones(n).+0im, blksize=5, return_details=true)
        nleigs_verify_lambdas(4, pep, X, lambda)

        info_λ = details.Lam[:,end]
        local in_Σ = map(p -> inpolygon(real(p), imag(p), real(Σ), imag(Σ)), info_λ)
        info_λ = info_λ[in_Σ]

        # test that eigenvalues in the info are the same as those returned by nleigs
        @test length(info_λ) == 4
        @test length(union(lambda, info_λ)) == 4

        # test that the residuals are near 0
        info_res = details.Res[in_Σ,end]
        @test all(r -> r < 1e-12, info_res)
    end
end

@testset "NLEIGS: Basic functionality" begin
    nleigs_basic()
end
