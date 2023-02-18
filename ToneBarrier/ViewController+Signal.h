//
//  ViewController+Signal.h
//  ToneBarrier
//
//  Created by James Alan Bush on 1/20/23.
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

static simd_double1 (^scale)(simd_double1, simd_double1, simd_double1, simd_double1, simd_double1) = ^ simd_double1 (simd_double1 val_old, simd_double1 min_new, simd_double1 max_new, simd_double1 min_old, simd_double1 max_old) {
    simd_double1 val_new = min_new + ((((val_old - min_old) * (max_new - min_new))) / (max_old - min_old));
    return val_new;
};

static AVAudioFormat * (^audio_format)(void) = ^ AVAudioFormat * {
    static AVAudioFormat * audio_format_ref = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        audio_format_ref = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:(simd_double1)48000.f channels:(AVAudioChannelCount)2];
    });
    
    return audio_format_ref;
};

#define M_PI_SQR M_PI * 2.f
#define M_PI_MID M_PI / 2.f

static AVAudioSourceNodeRenderBlock (^audio_renderer)(void) = ^ AVAudioSourceNodeRenderBlock {
    static AVAudioFramePosition sample;
    static AVAudioFramePosition * sample_t = &sample;
    static unsigned long (^sample_conditional)(void) = ^ unsigned long {
        return (*sample_t - (int)(audio_format().sampleRate * audio_format().channelCount)) >> (WORD_BIT - 1);
    };
    
    GKMersenneTwisterRandomSource * randomizer = [[GKMersenneTwisterRandomSource alloc] initWithSeed:(unsigned long)clock()];
    GKGaussianDistribution * distributor = [[GKGaussianDistribution alloc] initWithRandomSource:randomizer mean:(high_frequency / .75) deviation:low_frequency];
    // frequencies[0][0] & [1][0] = signal; frequencies[-][1] & [1][1] =  amplitude
    // Add tremolo effect to signal and triol effect to amplitude
    __block simd_double2x2 frequencies = simd_matrix_from_rows(simd_make_double2([distributor nextInt] * M_PI_SQR, M_PI), simd_make_double2([distributor nextInt] * M_PI_SQR, M_PI));
    static simd_double2x2 thetas, signal_samples;
    
    return ^ OSStatus (BOOL * _Nonnull isSilence, const AudioTimeStamp * _Nonnull timestamp, AVAudioFrameCount frames, AudioBufferList * _Nonnull outputData) {
        AVAudioFramePosition frame = 0;
        AVAudioFramePosition * frame_t = &frame;
        static simd_double1 time;
        static simd_double1 * time_t = &time;
        
        for (; *frame_t < frames; (*frame_t)++) {
            signal_samples = matrix_scale(({
                // TO-DO: Use sample_t before incrementing for both the time and frequencies calculations
                *time_t = 0.f + (((((*sample_t = -~(AVAudioFramePosition)(((sample_conditional()) & (*sample_t ^ (AVAudioFramePosition)0)) ^ (AVAudioFramePosition)0)) - 0.f) * (1.f - 0.f))) / ((int)(audio_format().sampleRate * audio_format().channelCount * 2.f) - 0.f));
                (!sample_conditional()) && ({ (frequencies = simd_matrix_from_rows(simd_make_double2([distributor nextInt] * M_PI_SQR, M_PI), simd_make_double2([distributor nextInt] * M_PI_SQR, M_PI))); *time_t; });
                *time_t;
            }), frequencies);
            signal_samples = simd_matrix_from_rows(_simd_sin_d2(signal_samples.columns[0]),
                                                   _simd_sin_d2(signal_samples.columns[1]));
            *((Float32 *)((Float32 *)((outputData->mBuffers + 0))->mData) + *frame_t) = signal_samples.columns[0][0] * signal_samples.columns[0][1];
            *((Float32 *)((Float32 *)((outputData->mBuffers + 1))->mData) + *frame_t) = signal_samples.columns[1][0] * signal_samples.columns[1][1];
        }
        
        return (OSStatus)noErr;
    };
};

static AVAudioSourceNode * (^audio_source)(AVAudioSourceNodeRenderBlock) = ^ AVAudioSourceNode * (AVAudioSourceNodeRenderBlock audio_renderer) {
    AVAudioSourceNode * source_node = [[AVAudioSourceNode alloc] initWithRenderBlock:audio_renderer];
    [source_node setRenderingAlgorithm:AVAudio3DMixingRenderingAlgorithmAuto];
    [source_node setSourceMode:AVAudio3DMixingSourceModeAmbienceBed];
    return source_node;
};

static AVAudioEngine * audio_engine_ref = nil;
static AVAudioEngine * (^audio_engine)(void) = ^{
    AVAudioEngine * audio_engine = [[AVAudioEngine alloc] init];
    AVAudioSourceNode * audio_source_ref = audio_source(audio_renderer());
    [audio_engine attachNode:audio_source_ref];
    [audio_engine connect:audio_source_ref to:audio_engine.mainMixerNode format:audio_format()];
    [audio_engine prepare];
    [[AVAudioSession sharedInstance] setActive:[audio_engine startAndReturnError:nil] error:nil];
    
    return (audio_engine_ref = audio_engine);
};

@interface ViewController ()

@end

NS_ASSUME_NONNULL_END

