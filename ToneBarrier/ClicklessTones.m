//
//  ClicklessTones.m
//  ToneBarrierBeta
//
//  Created by James Alan Bush on 12/17/19.
//  Copyright © 2019 The Life of a Demoniac. All rights reserved.
//

#import "ClicklessTones.h"
#include "easing.h"


static const float high_frequency = 1750.0;
static const float low_frequency  = 500.0;
static const float min_duration   = 0.25;
static const float max_duration   = 1.75;

@interface ClicklessTones ()
{
    double frequency[2];
    NSInteger alternate_channel_flag;
    double duration_bifurcate;
}

@property (nonatomic, readonly) GKMersenneTwisterRandomSource * _Nullable randomizer;
@property (nonatomic, readonly) GKGaussianDistribution * _Nullable distributor;

// Randomizes duration
@property (nonatomic, readonly) GKGaussianDistribution * _Nullable distributor_duration;

@end


@implementation ClicklessTones

- (instancetype)init
{
    self = [super init];
    
    if (self)
    {
        _randomizer  = [[GKMersenneTwisterRandomSource alloc] initWithSeed:time(NULL)];
        _distributor = [[GKGaussianDistribution alloc] initWithRandomSource:_randomizer mean:(high_frequency / .75) deviation:low_frequency];
        _distributor_duration = [[GKGaussianDistribution alloc] initWithRandomSource:_randomizer mean:max_duration deviation:min_duration];
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

double (^fade)(Fade, double, double) = ^double(Fade fadeType, double x, double freq_amp)
{
    double fade_effect = freq_amp * ((fadeType == FadeIn) ? x : (1.0 - x));
    
    return fade_effect;
};

static __inline__ CGFloat random_float_between(CGFloat a, CGFloat b) {
    return a + (b - a) * ((CGFloat) random() / (CGFloat) RAND_MAX);
}

//- (float)generateRandomNumberBetweenMin:(int)min Max:(int)max
//{
//    return ( (arc4random() % (max-min+1)) + min );
//}

#define M_PI_SQR M_PI * 2.f

- (void)createAudioBufferWithFormat:(AVAudioFormat *)audioFormat completionBlock:(CreateAudioBufferCompletionBlock)createAudioBufferCompletionBlock
{
    static unsigned int fade_bit = 1;
    static AVAudioPCMBuffer * (^createAudioBuffer)(Fade[2], simd_double2x2);
    createAudioBuffer = ^ AVAudioPCMBuffer * (Fade fades[2], simd_double2x2 frequencies) {
        static simd_double2x2 thetas, theta_increments, samples;
        AVAudioFrameCount frameCount = audioFormat.sampleRate;
        AVAudioPCMBuffer * pcmBuffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:audioFormat frameCapacity:frameCount];
        pcmBuffer.frameLength = frameCount;
        
        simd_double1 phase_angular_unit = (simd_double1)(M_PI_SQR / frameCount);
        theta_increments = matrix_scale(phase_angular_unit, frequencies);
        simd_double1 split_frame = (simd_double1)(random_float_between(0.125f, 0.875f));
        
        simd_double2 durations = simd_make_double2(split_frame, 1.0 - split_frame);
        for (AVAudioFrameCount frame = 0; frame < frameCount; frame++) {
            samples = simd_matrix_from_rows(_simd_sin_d2(simd_make_double2((simd_double2)thetas.columns[0])), _simd_sin_d2(simd_make_double2((simd_double2)thetas.columns[1])));
            samples = simd_matrix_from_rows(simd_make_double2((simd_double2)(samples.columns[0] * durations)), simd_make_double2((simd_double2)(samples.columns[1] * durations)));
            
            // TO-DO: Mix channels here
            
            thetas = simd_add(thetas, theta_increments);
            for (AVAudioChannelCount channel_count = 0; channel_count < audioFormat.channelCount; channel_count++) {
                pcmBuffer.floatChannelData[channel_count][frame] = samples.columns[channel_count][frame];
            }
        }

        /*
         double channel_swap = RandomFloatBetween(0.125f, 0.875f);
         double * channel_swap_t = &channel_swap;
         double a = sinf(left_channel_theta) * (1.0 - *channel_swap_t);
         double b = sinf(right_channel_theta) * *channel_swap_t;
         buffer_left[frame]  = (2.f * (sinf(a + b) * cosf(a - b))) / 2.f * (1.0 - *channel_swap_t);;
         buffer_right[frame] = (2.f * (sinf(a + b) * cosf(a - b))) / 2.f * *channel_swap_t;;
         */
        
        
//        theta_increments = frequencies;
//        for (AVAudioFrameCount frame = 0; frame < frameCount; frame++)
//        {
//            samples = simd_make_float4(_simd_sin_f4(thetas));
//            thetas += theta_increments;
//            for (AVAudioChannelCount channel_count = 0; channel_count < audioFormat.channelCount; channel_count++) {
//                pcmBuffer.floatChannelData[channel_count][frame] = samples[channel_count] * samples[channel_count + 2];
//                !(thetas[channel_count] > M_PI_SQR) && (thetas[channel_count] -= M_PI_SQR);
//                !(thetas[channel_count + 2] > M_PI_SQR) && (thetas[channel_count + 2] -= M_PI_SQR);
//            }
//        }
        
        //        for (int index = 0; index < frameCount; index++)
        //        {
        //            double normalized_index = LinearInterpolation(index, frameCount);
//            double amplitude = NormalizedSineEaseInOut(normalized_index, amplitude_frequency);
//            left_channel[index]  = fade(fade_bit, normalized_index, NormalizedSineEaseInOut(normalized_index, frequencyLeft)  * amplitude);
//            right_channel[index] = fade((fade_bit ^ 1), normalized_index, NormalizedSineEaseInOut(normalized_index, frequencyRight) * amplitude); // fade((leading_fade == FadeOut) ? FadeIn : leading_fade, normalized_index, (SineEaseInOutFrequency(normalized_index, frequencyRight) * NormalizedSineEaseInOutAmplitude((1.0 - normalized_index), 1)));
//        }
//
        return pcmBuffer;
    };
    
    static void (^block)(void);
    block = ^{
        Fade fades[2][2] = {{({fade_bit ^= 1; }), fade_bit ^ 1}, {fade_bit, fade_bit ^ 1}};
        createAudioBufferCompletionBlock(createAudioBuffer(fades[0], simd_matrix_from_rows(simd_make_double2([self->_distributor nextInt], [self->_distributor nextInt]), simd_make_double2([self->_distributor nextInt], [self->_distributor nextInt]))), //RandomFloatBetween(4, 6), RandomFloatBetween(4, 6))),
                                         createAudioBuffer(fades[1], simd_matrix_from_rows(simd_make_double2([self->_distributor nextInt], [self->_distributor nextInt]), simd_make_double2([self->_distributor nextInt], [self->_distributor nextInt]))), //RandomFloatBetween(4, 6), RandomFloatBetween(4, 6))),
                                         ^{
            printf("fade_bit == %u\t\tfade_bit ^ 1 == %u\n", fade_bit, fade_bit ^ 1);
            block();
        });
    };
    block();
}

@end
