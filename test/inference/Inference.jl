using Turing, Random, Test
using DynamicPPL: getlogp
import MCMCChains

dir = splitdir(splitdir(pathof(Turing))[1])[1]
include(dir*"/test/test_utils/AllUtils.jl")

@testset "io.jl" begin
    # Only test threading if 1.3+.
    if VERSION > v"1.2"
        @testset "threaded sampling" begin
            # Test that chains with the same seed will sample identically.
            chain1 = sample(Random.seed!(5), gdemo_default, HMC(0.1, 7), MCMCThreads(),
                            1000, 4)
            chain2 = sample(Random.seed!(5), gdemo_default, HMC(0.1, 7), MCMCThreads(),
                            1000, 4)
            @test all(chain1.value .== chain2.value)
            check_gdemo(chain1)

            # Smoke test for default sample call.
            chain = sample(gdemo_default, HMC(0.1, 7), MCMCThreads(), 1000, 4)
            check_gdemo(chain)

            # run sampler: progress logging should be disabled and
            # it should return a Chains object
            sampler = Sampler(HMC(0.1, 7), gdemo_default)
            chains = sample(gdemo_default, sampler, MCMCThreads(), 1000, 4)
            @test chains isa MCMCChains.Chains
        end
    end
    @testset "chain save/resume" begin
        Random.seed!(1234)

        alg1 = HMCDA(1000, 0.65, 0.15)
        alg2 = PG(20)
        alg3 = Gibbs(PG(30, :s), HMCDA(500, 0.65, 0.05, :m))

        chn1 = sample(gdemo_default, alg1, 3000; save_state=true)
        check_gdemo(chn1)

        chn1_resumed = Turing.Inference.resume(chn1, 1000)
        check_gdemo(chn1_resumed)

        chn1_contd = sample(gdemo_default, alg1, 1000; resume_from=chn1)
        check_gdemo(chn1_contd)

        chn1_contd2 = sample(gdemo_default, alg1, 1000; resume_from=chn1, reuse_spl_n=1000)
        check_gdemo(chn1_contd2)

        chn2 = sample(gdemo_default, alg2, 1000; save_state=true)
        check_gdemo(chn2)

        chn2_contd = sample(gdemo_default, alg2, 1000; resume_from=chn2)
        check_gdemo(chn2_contd)

        chn3 = sample(gdemo_default, alg3, 1000; save_state=true)
        check_gdemo(chn3)

        chn3_contd = sample(gdemo_default, alg3, 1000; resume_from=chn3)
        check_gdemo(chn3_contd)
    end
    @testset "Contexts" begin
        # Test LikelihoodContext
        @model testmodel(x) = begin
            a ~ Beta()
            lp1 = getlogp(_varinfo)
            x[1] ~ Bernoulli(a)
            global loglike = getlogp(_varinfo) - lp1
        end
        model = testmodel([1.0])
        varinfo = Turing.VarInfo(model)
        model(varinfo, Turing.SampleFromPrior(), Turing.LikelihoodContext())
        @test getlogp(varinfo) == loglike

        # Test MiniBatchContext
        @model testmodel(x) = begin
            a ~ Beta()
            x[1] ~ Bernoulli(a)
        end
        model = testmodel([1.0])
        varinfo1 = Turing.VarInfo(model)
        varinfo2 = deepcopy(varinfo1)
        model(varinfo1, Turing.SampleFromPrior(), Turing.LikelihoodContext())
        model(varinfo2, Turing.SampleFromPrior(), Turing.MiniBatchContext(Turing.LikelihoodContext(), 10))
        @test isapprox(getlogp(varinfo2) / getlogp(varinfo1), 10)
    end
end
