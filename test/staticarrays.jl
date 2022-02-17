using StaticArrays, ThreadingUtilities
struct MulStaticArray{P} end
function (::MulStaticArray{P})(p::Ptr{UInt}) where {P}
  _, (ptry,ptrx) = ThreadingUtilities.load(p, P, 2*sizeof(UInt))
  unsafe_store!(ptry, unsafe_load(ptrx) * 2.7)
  ThreadingUtilities._atomic_store!(p, ThreadingUtilities.SPIN)
  nothing
end
@generated function mul_staticarray_ptr(::A, ::B) where {A,B}
    c = MulStaticArray{Tuple{A,B}}()
    :(@cfunction($c, Cvoid, (Ptr{UInt},)))
end

@inline function setup_mul_svector!(p, y::Base.RefValue{T}, x::Base.RefValue{T}) where {T}
    py = Base.unsafe_convert(Ptr{T}, y)
    px = Base.unsafe_convert(Ptr{T}, x)
    fptr = mul_staticarray_ptr(py, px)
    offset = ThreadingUtilities.store!(p, fptr, sizeof(UInt))
    ThreadingUtilities.store!(p, (py,px), offset)
end

@inline function launch_thread_mul_svector(tid, y, x)
    ThreadingUtilities.launch(setup_mul_svector!, tid, y, x)
end

function waste_time(a, b)
  s = a * b'
  for i ∈ 1:0
    s += a * b'
  end
  s
end

function mul_svector_threads(a::T, b::T, c::T) where {T}
    ra = Ref(a)
    rb = Ref(b)
    rc = Ref(c)
    rx = Ref{T}()
    ry = Ref{T}()
    rz = Ref{T}()
    GC.@preserve ra rb rc rx ry rz begin
        launch_thread_mul_svector(1, rx, ra)
        launch_thread_mul_svector(2, ry, rb)
        launch_thread_mul_svector(3, rz, rc)
        w = waste_time(a, b)
        ThreadingUtilities.wait(1)
        ThreadingUtilities.wait(2)
        ThreadingUtilities.wait(3)
    end
    rx[], ry[], rz[], w
end
function count_allocated(a, b, c)
  @allocated(mul_svector_threads(a,b,c))
end


@testset "SVector Test" begin
  a = @SVector rand(16);
  b = @SVector rand(16);
  c = @SVector rand(16);
  w,x,y,z = mul_svector_threads(a, b, c)
  if Sys.iswindows()
    # if VERSION < v"1.6" && Sys.WORD_SIZE == 32
    if Sys.WORD_SIZE == 32
      @show count_allocated(a, b, c)
      @test count_allocated(a, b, c) == 0
    else
      @test_broken count_allocated(a, b, c) == 0
    end
  else
    @test count_allocated(a, b, c) == 0
  end
  @test w == a*2.7
  @test x == b*2.7
  @test y == c*2.7
  @test z ≈ waste_time(a, b)
  A = @SMatrix rand(7,9);
  B = @SMatrix rand(7,9);
  C = @SMatrix rand(7,9);
  Wans = A*2.7; Xans = B*2.7; Yans = C*2.7;
  for i ∈ 1:100 # repeat rapdily
    C, A, B = A, B, C
    W,X,Y,Z = mul_svector_threads(A, B, C)
    iseven(i) && ThreadingUtilities.sleep_all_tasks()
    (Yans, Wans, Xans) = Wans, Xans, Yans
    @test W == Wans
    @test X == Xans
    @test Y == Yans
    @test Z ≈ waste_time(A, B)
  end
end
