@testset "THREADPOOL" begin
    @test isconst(ThreadingUtilities, :THREADPOOL) # test that ThreadingUtilities.THREADPOOL is a constant
    @test ThreadingUtilities.THREADPOOL isa Vector{UInt}
    @test eltype(ThreadingUtilities.THREADPOOL) === UInt
    @test length(ThreadingUtilities.THREADPOOL) == ThreadingUtilities.THREADBUFFERSIZE * (min(Threads.nthreads(),(Sys.CPU_THREADS)::Int) - 1) + (VectorizationBase.cacheline_size() ÷ sizeof(UInt)) - 1
end
