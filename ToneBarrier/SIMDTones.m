//
//  SIMDTones.m
//  ToneBarrier
//
//  Created by Xcode Developer on 2/4/23.
//

#import "SIMDTones.h"

static const float high_frequency = 1750.0;
static const float low_frequency  = 500.0;
static const float min_duration   = 0.25;
static const float max_duration   = 1.75;

static __inline__ CGFloat random_float_between(CGFloat a, CGFloat b) {
    return a + (b - a) * ((CGFloat) random() / (CGFloat) RAND_MAX);
}

#define M_PI_SQR M_PI * 2.f

@implementation SIMDTones
{
    GKMersenneTwisterRandomSource * _Nullable randomizer;
    GKGaussianDistribution * _Nullable distributor;
    GKGaussianDistribution * _Nullable distributor_duration;
}

static SIMDTones * simdToneGenerator = NULL;
+ (nonnull SIMDTones *)simdToneGenerator
{
    static dispatch_once_t onceSecurePredicate;
    dispatch_once(&onceSecurePredicate, ^{
        if (!simdToneGenerator)
        {
            simdToneGenerator = [[self alloc] init];
        }
    });
    
    return simdToneGenerator;
}

- (instancetype)init
{
    self = [super init];
    
    if (self)
    {
        randomizer  = [[GKMersenneTwisterRandomSource alloc] initWithSeed:time(NULL)];
        distributor = [[GKGaussianDistribution alloc] initWithRandomSource:randomizer mean:(high_frequency / .75) deviation:low_frequency];
        distributor_duration = [[GKGaussianDistribution alloc] initWithRandomSource:randomizer mean:max_duration deviation:min_duration];
    }
    
    return self;
}

typedef NS_ENUM(NSUInteger, Fade) {
    FadeOut,
    FadeIn
};

float normalize(float unscaledNum, float minAllowed, float maxAllowed, float min, float max) {
    return (maxAllowed - minAllowed) * (unscaledNum - min) / (max - min) + minAllowed;
}

static unsigned int fade_bit = 1;
double (^fade)(Fade, double, double) = ^double(Fade fadeType, double x, double freq_amp)
{
    double fade_effect = freq_amp * ((fadeType == FadeIn) ? x : (1.0 - x));
    return fade_effect;
};

- (void)scheduleAudioBufferWithFormat:(AVAudioFormat *)audioFormat completionBlock:(CreateAudioBufferCompletionBlock)createAudioBufferCompletionBlock
{
    static unsigned int fade_bit = 1;
    static AVAudioPCMBuffer * (^createAudioBuffer)(Fade[2], simd_double2x2);
    static simd_double2x2 thetas, theta_increments, samples;

    AVAudioFramePosition frame = 0;
    AVAudioFramePosition * frame_t = &frame;
    AVAudioFrameCount frame_count = 44100;

    simd_double1 time;
    simd_double1 * time_t = &time;
    typedef simd_double1 normalized_time_ref[frame_count];
    typeof(normalized_time_ref) normalized_time;
    simd_double1 * normalized_time_ptr = &normalized_time[0];

    for (*frame_t = 0; *frame_t < frame_count; *frame_t += 1) {
        *(time_t) = 0.0 + ((((*frame_t - 0.0) * (1.0 - 0.0))) / (~-frame_count - 0.0));
        *(normalized_time_ptr + *frame_t) = *(time_t);
//        printf("%d\tframes == %f == frames_t == %f\n", *frame_t, *(time_t), *(normalized_time_ptr + *frame_t));
    }

//    for (*frame_t = 0; *frame_t < frame_count; *frame_t += 1) {
//        printf("time == %f\n", *(normalized_time_ptr + *frame_t));
//    }

    createAudioBuffer = ^ AVAudioPCMBuffer * (Fade fades[2], simd_double2x2 frequencies) {
        AVAudioFrameCount frameCount = (audioFormat.sampleRate * audioFormat.channelCount);
        AVAudioPCMBuffer * pcmBuffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:audioFormat frameCapacity:frameCount];
        pcmBuffer.frameLength = frameCount;
        simd_double1 split_frame = (simd_double1)(random_float_between(0.125f, 0.875f));
        simd_double1 phase_angular_unit = (simd_double1)(M_PI_SQR / frameCount);
        theta_increments = matrix_scale(phase_angular_unit, frequencies);

        // To-Do: - Merge tones via channel mixer
        //        - Transition using a balance mixer
        //        - Apply to transition between tones and between channels (that's two different things done the same way)

        for (*frame_t = 0; *frame_t < frame_count; *frame_t += 1) {
//            simd_double2x2 tone_transitions = simd_matrix_from_rows(simd_make_double2(*(normalized_time_ptr + *frame_t), 1.0 - *(normalized_time_ptr + *frame_t)),
//                                                                    simd_make_double2(1.0 - *(normalized_time_ptr + *frame_t), *(normalized_time_ptr + *frame_t)));
            samples = simd_matrix_from_rows(_simd_sin_d2(simd_make_double2((simd_double2)thetas.columns[0])),
                                            _simd_sin_d2(simd_make_double2((simd_double2)thetas.columns[1])));
//            samples = matrix_multiply(tone_transitions, samples);

//            simd_double2 a      = simd_make_double2((simd_double2)(samples.columns[0]) * simd_make_double2((simd_double2)durations.columns[0]));
//            simd_double2 b      = simd_make_double2((simd_double2)(samples.columns[1]) * simd_make_double2((simd_double2)durations.columns[1]));
//            simd_double2 ab_sum = _simd_sin_d2(a + b);
//            simd_double2 ab_sub = _simd_cos_d2(a - b);
//            simd_double2 ab_mul = ab_sum * ab_sub;
//            samples = simd_matrix_from_rows(simd_make_double2((simd_double2)((2.f * ab_mul) / 2.f) * simd_make_double2((simd_double2)durations.columns[1])),
//                                            simd_make_double2((simd_double2)((2.f * ab_mul) / 2.f) * simd_make_double2((simd_double2)durations.columns[0])));

            thetas  = simd_add(thetas, theta_increments);

            for (AVAudioChannelCount channel_count = 0; channel_count < audioFormat.channelCount; channel_count++) {
                pcmBuffer.floatChannelData[channel_count][*frame_t] = samples.columns[channel_count][*frame_t];
                !(thetas.columns[channel_count ^ 1][channel_count] > M_PI_SQR) && (thetas.columns[channel_count ^ 1][channel_count] -= M_PI_SQR); //0 = 1 0 //1 = 0 1
                !(thetas.columns[channel_count][channel_count ^ 1] > M_PI_SQR) && (thetas.columns[channel_count][channel_count ^ 1] -= M_PI_SQR); //0 = 0 1 //1 = 1 0
            }
        }

        return pcmBuffer;
    };

    static void (^block)(void);
    block = ^{
        Fade fades[2][2] = {{({ fade_bit ^= 1; }), fade_bit ^ 1}, {fade_bit, fade_bit ^ 1}};
        createAudioBufferCompletionBlock(createAudioBuffer(fades[0], simd_matrix_from_rows(simd_make_double2([distributor nextInt], [distributor nextInt]), simd_make_double2([distributor nextInt], [distributor nextInt]))), //RandomFloatBetween(4, 6), RandomFloatBetween(4, 6))),
                                         createAudioBuffer(fades[1], simd_matrix_from_rows(simd_make_double2([distributor nextInt], [distributor nextInt]), simd_make_double2([distributor nextInt], [distributor nextInt]))), //RandomFloatBetween(4, 6), RandomFloatBetween(4, 6))),
                                         ^{
            block();
        });
    };
    block();
}


@end
