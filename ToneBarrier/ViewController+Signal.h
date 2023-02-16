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

static simd_double2x2 thetas, signal_samples;

static OSStatus (^generate_samples)(AVAudioFrameCount, AudioBufferList * _Nonnull);
static OSStatus (^(^sample_generator)(AVAudioFrameCount))(AVAudioFrameCount, AudioBufferList * _Nonnull) = ^ (AVAudioFrameCount samples) {
    static AVAudioFramePosition sample;
    static AVAudioFramePosition * sample_t = &sample;
    
    simd_double1 time;
    simd_double1 * time_t = &time;
    typedef simd_double1 normalized_time_ref[samples];
    typeof(normalized_time_ref) normalized_time;
    simd_double1 * normalized_time_ptr = &normalized_time[0];
    
    // Make room for a block that processes frame before and after it is normalized between one and zero (the old min/max, new min/max, and old value are assumed)
    for (*sample_t = 0; *sample_t < samples; *sample_t += 1) {
        *(time_t) = 0.f + ((((*sample_t - 0.f) * (1.f - 0.f))) / (samples - 0.f));
        *(normalized_time_ptr + *sample_t) = *(time_t);
        //        printf("%lld\tframes == %f == frames_t == %f\n", *sample_t, *(time_t), *(normalized_time_ptr + *sample_t));
    }
    
    *sample_t = 0;
    
    //    for (*sample_t = 0; *sample_t < samples; *sample_t += 1) {
    //        printf("time == %f\n", *(normalized_time_ptr + *sample_t));
    //    }
    
    GKMersenneTwisterRandomSource * randomizer = [[GKMersenneTwisterRandomSource alloc] initWithSeed:0];
    GKGaussianDistribution * distributor = [[GKGaussianDistribution alloc] initWithRandomSource:randomizer mean:(high_frequency / .75) deviation:low_frequency];
    __block simd_double2x2 frequencies = simd_matrix_from_rows(simd_make_double2([distributor nextInt], [distributor nextInt]), simd_make_double2([distributor nextInt], [distributor nextInt]));
    simd_double1 phase_angular_unit = (simd_double1)(M_PI_SQR / samples);
    __block simd_double2x2 theta_increments = matrix_scale(phase_angular_unit, frequencies);
    
    return ^ OSStatus (AVAudioFrameCount frames, AudioBufferList * _Nonnull outputData) {
        AVAudioFramePosition frame = 0;
        AVAudioFramePosition * frame_t = &frame;
        for (; *frame_t < frames; (*frame_t)++) {
            *time_t = 0.f + (((((*sample_t = -~(AVAudioFramePosition)((((*sample_t - samples) >> (WORD_BIT - 1)) & (*sample_t ^ (AVAudioFramePosition)nil)) ^ (AVAudioFramePosition)nil)) - 0.f) * (1.f - 0.f))) / (samples - 0.f));
            signal_samples = simd_matrix_from_rows(_simd_sin_d2(simd_make_double2((simd_double2)thetas.columns[0])),
                                                   _simd_sin_d2(simd_make_double2((simd_double2)thetas.columns[1])));
            thetas  = simd_add(thetas, theta_increments);
            
            simd_double2 ab_sum = _simd_sin_d2(signal_samples.columns[0][0] + signal_samples.columns[0][1]);
            simd_double2 ab_sub = _simd_cos_d2(signal_samples.columns[0][0] - signal_samples.columns[0][1]);
            simd_double2 ab_mul = ab_sum * ab_sub;
            *((Float32 *)((Float32 *)((outputData->mBuffers + 0))->mData) + *frame_t) = (ab_mul[0] * *time_t); //pcmBuffer.floatChannelData[channel_count][frame]
            *((Float32 *)((Float32 *)((outputData->mBuffers + 1))->mData) + *frame_t) = (ab_mul[1] * *time_t); //signal_samples.columns[1][0] + signal_samples.columns[1][1]; //pcmBuffer.floatChannelData[channel_count][frame]
        }
        return !(*sample_t < samples) && ({ (theta_increments = matrix_scale(phase_angular_unit, (frequencies = simd_matrix_from_rows(simd_make_double2([distributor nextInt], [distributor nextInt]), simd_make_double2([distributor nextInt], [distributor nextInt]))))); (OSStatus)noErr; });
    };
};
    
    
    static AVAudioSourceNodeRenderBlock (^audio_renderer)(void) = ^ AVAudioSourceNodeRenderBlock (void) {
        generate_samples = sample_generator(audio_format().sampleRate * audio_format().channelCount * 2);
        printf("--------\n\n\n");
        return ^OSStatus(BOOL * _Nonnull isSilence, const AudioTimeStamp * _Nonnull timestamp, AVAudioFrameCount frameCount, AudioBufferList * _Nonnull outputData) {
            return generate_samples(frameCount, outputData);
        };
    };
    
    
    
    static AVAudioSourceNode * (^audio_source)(AVAudioSourceNodeRenderBlock) = ^ AVAudioSourceNode * (AVAudioSourceNodeRenderBlock audio_renderer) {
        AVAudioSourceNode * source_node = [[AVAudioSourceNode alloc] initWithRenderBlock:audio_renderer];
        
        return source_node;
    };
    
    static AVAudioEngine * audio_engine_ref = nil;
    static AVAudioEngine * (^audio_engine)(void) = ^{
        AVAudioEngine * audio_engine = [[AVAudioEngine alloc] init];
        AVAudioSourceNode * audio_source_ref = audio_source(audio_renderer());
        [audio_engine attachNode:audio_source_ref];
        [audio_engine connect:audio_source_ref to:audio_engine.mainMixerNode format:audio_format()];
        [audio_engine prepare];
        [audio_engine startAndReturnError:nil];
        
        return (audio_engine_ref = audio_engine);
    };
    
    
    
    
    // (^ AVAudioFramePosition { printf("First...\n"); return 0; }())
    
    
    
    @interface ViewController ()
    
    @end
    
    NS_ASSUME_NONNULL_END
    
