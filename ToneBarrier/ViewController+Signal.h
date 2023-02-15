//
//  ViewController+Signal.h
//  ToneBarrier
//
//  Created by Xcode Developer on 1/20/23.
//

#import "ViewController.h"
#import "ToneGenerator.h"

@import simd;
@import GameKit;

NS_ASSUME_NONNULL_BEGIN

static const float high_frequency = 1750.f;
static const float low_frequency  = 500.f;

static __inline__ CGFloat random_float_between(CGFloat a, CGFloat b) {
    return a + (b - a) * ((CGFloat) random() / (CGFloat) RAND_MAX);
}

#define M_PI_SQR M_PI * 2.f

static AVAudioFormat * (^audio_format)(void) = ^ AVAudioFormat * {
    static AVAudioFormat * audio_format_ref = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        audio_format_ref = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:(simd_double1)50.f channels:(AVAudioChannelCount)2];
    });
    
    return audio_format_ref;
};

static AVAudioEngine * audio_engine_ref = nil;
static AVAudioEngine * (^audio_engine)(AVAudioSourceNode *) = ^(AVAudioSourceNode * audio_source) {
    AVAudioEngine * audio_engine = [[AVAudioEngine alloc] init];
    [audio_engine attachNode:audio_source];
    [audio_engine connect:audio_source to:audio_engine.mainMixerNode format:audio_format()];
    [audio_engine prepare];
    
    return audio_engine;
};

static AVAudioSourceNode * (^audio_source)(AVAudioSourceNodeRenderBlock) = ^ AVAudioSourceNode * (AVAudioSourceNodeRenderBlock audio_renderer) {
    AVAudioSourceNode * source_node = [[AVAudioSourceNode alloc] initWithRenderBlock:audio_renderer];
    
    return source_node;
};

static int counter = 0;
static void (^(^distributor)(GKMersenneTwisterRandomSource *))(simd_double2x2 *) = ^ (GKMersenneTwisterRandomSource * randomizer) {
    static GKGaussianDistribution * distributor_ref = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        distributor_ref = [[GKGaussianDistribution alloc] initWithRandomSource:randomizer mean:(high_frequency / .75) deviation:low_frequency];
    });
    return ^ (simd_double2x2 * frequencies_t) {
        printf("Distributed %d times\n", counter++);
        (*frequencies_t) = simd_matrix_from_rows(simd_make_double2([distributor_ref nextInt], [distributor_ref nextInt]), simd_make_double2([distributor_ref nextInt], [distributor_ref nextInt]));
    };
};

static simd_double2x2 frequencies, thetas, theta_increments, samples;

static OSStatus (^generate_samples)(const AVAudioFrameCount);
static OSStatus (^(^sample_generator)(const AVAudioFrameCount))(const AVAudioFrameCount) = ^ (const AVAudioFrameCount samples) {
    void (^distribute)(simd_double2x2 *) = distributor([[GKMersenneTwisterRandomSource alloc] initWithSeed:time(nil)]);
    static AVAudioFramePosition sample;
    static AVAudioFramePosition * sample_t = &sample;
    return ^ OSStatus (const AVAudioFrameCount frames) {
        AVAudioFramePosition frame = 0;
        AVAudioFramePosition * frame_t = &frame;
        for (; *frame_t < frames; (*frame_t)++) {
            (*sample_t = -~(AVAudioFramePosition)((((*sample_t - samples) >> (WORD_BIT - 1)) & (*sample_t ^ (AVAudioFramePosition)nil)) ^ (AVAudioFramePosition)nil));
            printf("\t\tSampled %lld out of %u samples\n\n", *sample_t, samples);
            (*sample_t < samples) ? 0 : distribute(&frequencies);
//            printf("Frame %lld out of %u frames\n", -~frame, frames);
        }
//        printf("\t\tSampled %lld out of %u samples\n\n", *sample_t, samples);
        return (OSStatus)noErr;
        
    };
};


// (^ AVAudioFramePosition { printf("First...\n"); return 0; }())

static AVAudioSourceNodeRenderBlock (^audio_renderer)(void) = ^ AVAudioSourceNodeRenderBlock {
//    GKMersenneTwisterRandomSource * randomizer = [[GKMersenneTwisterRandomSource alloc] initWithSeed:time(nil)];
//    GKGaussianDistribution * distributor = [[GKGaussianDistribution alloc] initWithRandomSource:randomizer mean:(high_frequency / .75) deviation:low_frequency];
//    frequencies = simd_matrix_from_rows(simd_make_double2([distributor nextInt], [distributor nextInt]), simd_make_double2([distributor nextInt], [distributor nextInt]));
//    simd_double1 phase_angular_unit = (simd_double1)(M_PI_SQR / audio_format().sampleRate);
//    theta_increments = matrix_scale(phase_angular_unit, frequencies);
//    simd_double1 split_frame = (simd_double1)(random_float_between(0.125f, 0.875f));
//    
//    simd_double2x2 durations = simd_matrix_from_rows(simd_make_double2(split_frame, 1.0 - split_frame),
//                                                     simd_make_double2(1.0 - split_frame, split_frame));
//    

    generate_samples = sample_generator(audio_format().sampleRate);
    printf("--------\n\n\n");
    return ^OSStatus(BOOL * _Nonnull isSilence, const AudioTimeStamp * _Nonnull timestamp, AVAudioFrameCount frameCount, AudioBufferList * _Nonnull outputData) {
        
        
        //        printf("frameCount == %d\n", frameCount);
//        for (AVAudioFrameCount frame = 0; frame < frameCount; frame++) {
//                samples = simd_matrix_from_rows(_simd_sin_d2(simd_make_double2((simd_double2)thetas.columns[0])),
//                                                _simd_sin_d2(simd_make_double2((simd_double2)thetas.columns[1])));
//
//                simd_double2 a      = simd_make_double2((simd_double2)(samples.columns[0]) * simd_make_double2((simd_double2)durations.columns[0]));
//                simd_double2 b      = simd_make_double2((simd_double2)(samples.columns[1]) * simd_make_double2((simd_double2)durations.columns[1]));
//                simd_double2 ab_sum = _simd_sin_d2(a + b);
//                simd_double2 ab_sub = _simd_cos_d2(a - b);
//                simd_double2 ab_mul = ab_sum * ab_sub;
//                samples = simd_matrix_from_rows(simd_make_double2((simd_double2)((2.f * ab_mul) / 2.f) * simd_make_double2((simd_double2)durations.columns[1])),
//                                                simd_make_double2((simd_double2)((2.f * ab_mul) / 2.f) * simd_make_double2((simd_double2)durations.columns[0])));
//                thetas  = simd_add(thetas, theta_increments);
//                for (AVAudioChannelCount channel_count = 0; channel_count < audio_format().channelCount; channel_count++) {
//                    *((Float32 *)((Float32 *)((outputData->mBuffers + channel_count))->mData) + frame) = samples.columns[channel_count][frame]; //pcmBuffer.floatChannelData[channel_count][frame]
//                    !(thetas.columns[channel_count ^ 1][channel_count] > M_PI_SQR) && (thetas.columns[channel_count ^ 1][channel_count] -= M_PI_SQR); //0 = 1 0 //1 = 0 1
//                    !(thetas.columns[channel_count][channel_count ^ 1] > M_PI_SQR) && (thetas.columns[channel_count][channel_count ^ 1] -= M_PI_SQR); //0 = 0 1 //1 = 1 0
//                }
//            }
        return generate_samples(5);
    };
};



@interface ViewController ()

@end

NS_ASSUME_NONNULL_END

