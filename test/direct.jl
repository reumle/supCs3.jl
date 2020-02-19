# Solve a trivial problem
A = reshape([1.0],(1,1))
solution = SCS_solve(supCs3.Direct, 1, 1, A, [1.0], [1.0], 1, 0, Int[], Int[], 0, 0, Float64[]);
@test solution.ret_val == 1

feasible_basic_conic(supCs3.Direct)

feasible_exponential_conic(supCs3.Direct)

feasible_sdp_conic(supCs3.Direct)

feasible_pow_conic(supCs3.Direct)
