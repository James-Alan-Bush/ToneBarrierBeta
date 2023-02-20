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

#define M_PI_DBL M_PI * 2.f
#define M_PI_HLF M_PI / 2.f

// a = (M_PI * *time_t)
// b = (M_PI_DBL * frequency * *time_t)
// c = sin(a * tremolo_coeff)
// d = sin(a ^ tremolo_exp)
// amplitude = sin(a);
// freq_sin = 2 * sin(b)
// freq_cos = cos(b)
// frequency = freq_sin * freq_cos
// tremolo = c * d
// envelope = amplitude * tremolo
// signal = envelope * frequency

static AVAudioSourceNodeRenderBlock (^audio_renderer)(AVAudioFrameCount) = ^ AVAudioSourceNodeRenderBlock (AVAudioFrameCount frame_count) {
    GKMersenneTwisterRandomSource * randomizer = [[GKMersenneTwisterRandomSource alloc] initWithSeed:(unsigned long)clock()];
    GKGaussianDistribution * distributor = [[GKGaussianDistribution alloc] initWithRandomSource:randomizer mean:(high_frequency / .75) deviation:low_frequency];
    __block simd_double2x2 frequencies = simd_matrix_from_rows(simd_make_double2([distributor nextInt], [distributor nextInt]), simd_make_double2([distributor nextInt], [distributor nextInt]));
    
    static AVAudioFramePosition   frame_position;
    static AVAudioFramePosition * frame_position_t = &frame_position;
    static simd_double1   time;
    static simd_double1 * time_t = &time;
    static simd_uint1 toggle;
    
    return ^ OSStatus (BOOL *isSilence, const AudioTimeStamp *timestamp, AVAudioFrameCount frameCount, AudioBufferList *outputData) {
        static simd_double2x2 signal_samples;
        AVAudioFramePosition split_frame = frame_count * 0.25;
        
        for (AVAudioFramePosition frame = 0; frame < frameCount; frame++) {
            (*frame_position_t ^ frame_count) && ^ AVAudioFramePosition {
                signal_samples = matrix_scale((*time_t = 0.f + ((*frame_position_t - 0.f) * (1.f - 0.f)) / (~-frame_count - 0.f)), frequencies);
                signal_samples = simd_matrix_from_rows(_simd_sinpi_d2(signal_samples.columns[0]),
                                                       _simd_sinpi_d2(signal_samples.columns[1]));
                !(*frame_position_t ^ split_frame) && (toggle ^= 1);
                *((Float32 *)((Float32 *)((outputData->mBuffers + 0))->mData) + frame) = signal_samples.columns[0][toggle];
                *((Float32 *)((Float32 *)((outputData->mBuffers + 1))->mData) + frame) = signal_samples.columns[1][toggle];
                
                return (*frame_position_t)++;
            }();

            !(*frame_position_t ^ frame_count) && ^ AVAudioFramePosition {
                frequencies = simd_matrix_from_rows(simd_make_double2([distributor nextInt], [distributor nextInt]), simd_make_double2([distributor nextInt], [distributor nextInt]));
                return (*frame_position_t = 0);
            }();
        }
        //        printf("*frame_position_t  == %lld\n", *frame_position_t);
        //        printf("*time_t == %f\n", *time_t);
        
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
    AVAudioSourceNode * audio_source_ref = audio_source(audio_renderer(audio_format().sampleRate * audio_format().channelCount));
    [audio_engine attachNode:audio_source_ref];
    [audio_engine connect:audio_source_ref to:audio_engine.mainMixerNode format:audio_format()];
    [audio_engine prepare];
    [[AVAudioSession sharedInstance] setActive:[audio_engine startAndReturnError:nil] error:nil];
    
    return (audio_engine_ref = audio_engine);
};

@interface ViewController ()

@end

NS_ASSUME_NONNULL_END

