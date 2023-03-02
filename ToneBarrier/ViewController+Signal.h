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

static __inline__ simd_double1 random_float_between(simd_double1 a, simd_double1 b) {
    return a + (b - a) * ((simd_double1) random() / (simd_double1) RAND_MAX);
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

typeof(simd_double1(^)(simd_double1)) rescale_random;
typeof(simd_double1(^(* restrict))(simd_double1)) _Nullable rescale_random_t = &rescale_random;
static __inline__ typeof(simd_double1(^)(simd_double1)) random_rescaler (simd_double1 old_min, simd_double1 old_max, simd_double1 new_min, simd_double1 new_max) {
    return ^ simd_double1 (simd_double1 value) {
        return (simd_double1)(value = (new_max - new_min) * (value - old_min) / (old_max - old_min) + new_min);
    };
}

typeof(simd_double1(^)(simd_double1)) distribute_random;
typeof(simd_double1(^(* restrict))(simd_double1)) _Nullable distribute_random_t = &distribute_random;
static __inline__ typeof(simd_double1(^)(simd_double1)) gaussian_distributor (simd_double1 mean, simd_double1 standard_deviation) {
    simd_double1 variance = (1.f / M_PI) * asin(sin(M_PI_HLF * mean));
    simd_double1 offset = (variance * 0.5f) * standard_deviation;
    __block typeof(simd_double1(^)(simd_double1)) normalize = random_rescaler((mean - offset), (mean + offset), 0.f, 1.f);
    return ^ (simd_double1 * offset_t, typeof(simd_double1(^(* restrict))(simd_double1)) normalize_t) {
        return ^ simd_double1 (simd_double1 time) {
            return time; //(simd_double1)(time = ((*normalize_t)(time)));
        };
    }(&offset, (typeof(simd_double1(^(* restrict))(simd_double1)))(&normalize));
}

typeof(simd_double1(^)(void)) generate_randomd48;
typeof(simd_double1(^(* restrict))(void)) _Nullable generate_randomd48_t = &generate_randomd48;
static __inline__ typeof(simd_double1(^)(void)) randomizerd48_generator (void) {
    srand48((unsigned long)clock());
    static simd_double1 random;
    return ^ (simd_double1 * random_t) {
        return ^ simd_double1 {
            return (simd_double1)(*random_t = (drand48()));
        };
    }(&random);
}

typedef typeof(simd_double1(^)(void)) random_generator;
typedef typeof(simd_double1(^(* restrict))(void)) _Nullable random_generator_t;
static simd_double1 (^(^(^(^randomizer_generator)(simd_double1(^)(void)))(simd_double1(^)(simd_double1)))(simd_double1(^)(simd_double1)))(void) = ^ (simd_double1(^randomize)(void)) {
    return ^ (simd_double1(^distribute)(simd_double1)) {
        return ^ (simd_double1(^rescale)(simd_double1)) {
            return ^ simd_double1 {
                return rescale(distribute(randomize()));
            };
        };
    };
};

static AVAudioSourceNodeRenderBlock (^audio_renderer)(unsigned long) = ^ AVAudioSourceNodeRenderBlock (unsigned long frame_count) {
    GKMersenneTwisterRandomSource * randomizer = [[GKMersenneTwisterRandomSource alloc] initWithSeed:(unsigned long)clock()];
    GKGaussianDistribution * distributor = [[GKGaussianDistribution alloc] initWithRandomSource:randomizer mean:(high_frequency / .75f) deviation:low_frequency];
    
    generate_randomd48   = randomizerd48_generator();
    distribute_random    = gaussian_distributor(0.75f, 0.125f);
    rescale_random       = random_rescaler(0.f, 1.f, low_frequency, high_frequency);
    random_generator randomize_frequency = ((randomizer_generator(generate_randomd48))(distribute_random))(rescale_random);
                         
    
    static simd_double1 frequency_random[4];
    static simd_double2x2 frequencies, theta_increments;
    simd_double1 phase_angular_unit = (simd_double1)(M_PI_DBL / frame_count);
    static simd_double2x2 signal_samples, thetas;
    
    static unsigned long   frame_position;
    static unsigned long * frame_position_t = &frame_position;

    static simd_double1 split_frame, distributed_split_frame;
    static unsigned long split_frames[2];
    
    //    static simd_double1   time;
    //    static simd_double1 * time_t = &time;
    //
    
    
    return ^ OSStatus (BOOL *isSilence, const AudioTimeStamp *timestamp, AVAudioFrameCount frameCount, AudioBufferList *outputData) {
        for (AVAudioFramePosition frame = 0; frame < frameCount; frame++) {
            ({
                !(*frame_position_t ^ frame_count) && ^ AVAudioFramePosition {
                    frequency_random[0] = randomize_frequency();
                    frequency_random[1] = randomize_frequency();//(simd_double1)random_float_between(low_frequency, high_frequency);
                    frequency_random[2] = randomize_frequency();//(simd_double1)random_float_between(low_frequency, high_frequency);
                    frequency_random[3] = randomize_frequency();//(simd_double1)random_float_between(low_frequency, high_frequency);
                    frequencies = simd_matrix_from_rows(simd_make_double2(frequency_random[0],
                                                                          frequency_random[1]),
                                                        simd_make_double2(frequency_random[2],
                                                                          frequency_random[3]));
                    theta_increments = matrix_scale(phase_angular_unit, frequencies);
                    thetas = theta_increments;
                    split_frame = randomize_frequency();
                    split_frames[0] = frame_count * 0.25;//(frame_count * split_frame);
                    split_frames[1] = frame_count * 0.75;//(frame_count * distributed_split_frame);
                    return (*frame_position_t = 0);
                }();
                
                (*frame_position_t ^ frame_count) &&
                ^ AVAudioFramePosition {
                    signal_samples = simd_matrix_from_rows(_simd_sin_d2(simd_make_double2((simd_double2)thetas.columns[0])),
                                                           _simd_sin_d2(simd_make_double2((simd_double2)thetas.columns[1])));
                    
                    // Transition combinations:
                    // - transition from one tone to another on the same channel
                    //      - mix the two tones
                    //      - balance over time weighted by duration coefficient [balancer would be an equal trade-off, which may be limiting)
                    // - transition from one tone to another from one channel to another
                    //      - mix the two tones
                    //      - add mix to both channels
                    //      - balance over time in opposite directions in each channel
                    
                    // Ease-in/out combinations:
                    // - the envelope between tone pairs
                    //      - applied at the end
                    // - the envelope between tones in a pair
                    //      - applied to the duration coefficient only
                    
                    
                    //                  signal_samples = matrix_scale(1.0 - (*time_t = 0.f + ((*frame_position_t - 0.f) * (1.f - 0.f)) / (~-frame_count - 0.f)), frequencies);
                    //                  simd_double1   tone_pair_amplitude_envelope = (simd_double1)sinf(*time_t * M_PI);
                    //                  signal_samples = matrix_scale(tone_pair_amplitude_envelope, (simd_matrix_from_rows(_simd_sinpi_d2(signal_samples.columns[0]),
                    //                                                                                                     _simd_sinpi_d2(signal_samples.columns[1]))));
                    
                    
                    //                    (*frame_position - split_frame) && (toggle ^= 1);
                    *((Float32 *)((Float32 *)((outputData->mBuffers + 0))->mData) + frame) = simd_mix(signal_samples.columns[0][0], signal_samples.columns[0][1], (*frame_position_t < split_frames[0]));
                    *((Float32 *)((Float32 *)((outputData->mBuffers + 1))->mData) + frame) = simd_mix(signal_samples.columns[1][0], signal_samples.columns[1][1], (*frame_position_t < split_frames[1]));
                    
                    //                    *((Float32 *)((Float32 *)((outputData->mBuffers + 1))->mData) + frame) = signal_samples.columns[1][(*frame_position_t < split_frame)];
                    
                    thetas  = simd_add(thetas, theta_increments);
                    
                    return (*frame_position_t)++;
                }();
            });
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

