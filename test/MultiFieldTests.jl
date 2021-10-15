module MultiFieldTests

using Gridap
using Gridap.FESpaces
using GridapDistributed
using PartitionedArrays
using Test

function main(parts)

  output = mkpath(joinpath(@__DIR__,"output"))

  domain = (0,4,0,4)
  cells = (4,4)
  model = CartesianDiscreteModel(parts,domain,cells)
  Ω = Triangulation(model)

  k = 2
  reffe_u = ReferenceFE(lagrangian,VectorValue{2,Float64},k)
  reffe_p = ReferenceFE(lagrangian,Float64,k-1,space=:P)

  u((x,y)) = VectorValue((x+y)^2,(x-y)^2)
  p((x,y)) = x+y
  f(x) = - Δ(u,x) + ∇(p,x)
  g(x) = tr(∇(u,x))

  V = TestFESpace(model,reffe_u,dirichlet_tags="boundary")
  Q = TestFESpace(model,reffe_p,constraint=:zeromean)
  U = TrialFESpace(V,u)
  P = TrialFESpace(Q,p)

  VxQ = MultiFieldFESpace([V,Q])
  UxP = MultiFieldFESpace([U,P]) # This generates again the global numbering
  UxP = TrialFESpace(VxQ,[u,p]) # This reuses the one computed

  zh = zero(UxP)
  du,dp = get_trial_fe_basis(UxP)
  dv,dq = get_fe_basis(VxQ)

  dΩ = Measure(Ω,2*k)

  a((u,p),(v,q)) = ∫( ∇(v)⊙∇(u) - q*(∇⋅u) - (∇⋅v)*p )*dΩ
  l((v,q)) = ∫( v⋅f - q*g )*dΩ

  assem = SparseMatrixAssembler(UxP,VxQ)
  data = collect_cell_matrix_and_vector(UxP,VxQ,a((du,dp),(dv,dq)),l((dv,dq)),zh)
  A,b = assemble_matrix_and_vector(assem,data)
  x = A\b
  r = A*x -b
  uh, ph = FEFunction(UxP,x)

  eu = u - uh
  ep = p - ph

  writevtk(Ω,"Ω",nsubcells=10,cellfields=["uh"=>uh,"ph"=>ph])

  @test sqrt(sum(∫( eu⋅eu )dΩ)) < 1.0e-9
  @test sqrt(sum(∫( eu⋅eu )dΩ)) < 1.0e-9

end

end # module
