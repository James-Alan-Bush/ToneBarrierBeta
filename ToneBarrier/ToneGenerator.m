//
//  ToneGenerator.m
//  ToneBarrierBeta
//
//  Created by James Alan Bush on 7/8/19.
//  Copyright © 2019 The Life of a Demoniac. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <GameKit/GameKit.h>

#import "ToneGenerator.h"
#import "ToneBarrierPlayer.h"
#import "ClicklessTones.h"
#import "SIMDTones.h"
#import "FrequenciesPairs.h"
#import "Frequencies.h"

#include "easing.h"

//static const float high_frequency = 6000.0;
//static const float low_frequency  = 1000.0;

@interface ToneGenerator ()

@property (nonatomic, readonly) AVAudioMixerNode * mixerNode;
@property (nonatomic, readonly) AVAudioPCMBuffer * pcmBufferOne;
@property (nonatomic, readonly) AVAudioPCMBuffer * pcmBufferTwo;
@property (nonatomic, readonly) AVAudioEnvironmentNode * environmentNode;
@property (nonatomic, readonly) AVAudioMixerNode *submixer;
@property (nonatomic, readonly) AVAudioUnitReverb *reverb;


@end

@implementation ToneGenerator

- (void)alarm {
    
}

- (NSUInteger)greatestCommonDivisor:(NSUInteger)firstValue secondValue:(NSUInteger)secondValue
{
    if (firstValue == 0 && secondValue == 0)
        return 1;
    
    NSUInteger r;
    while(secondValue)
    {
        r = firstValue % secondValue;
        firstValue = secondValue;
        secondValue = r;
    }
    return firstValue;
}

static ToneGenerator *sharedGenerator = NULL;
+ (nonnull ToneGenerator *)sharedGenerator
{
    static dispatch_once_t onceSecurePredicate;
    dispatch_once(&onceSecurePredicate,^
                  {
        if (!sharedGenerator)
        {
            sharedGenerator = [[self alloc] init];
        }
    });
    
    return sharedGenerator;
}

typedef typeof(void(^(^)(NSNotification *, void(^)(NSNotification *)))(void)) notification_observer;
typedef typeof(void(^)(void)) notification;
void(^(^(^notification_observation)(NSNotificationCenter *, NSOperationQueue *))(NSNotification *, void(^)(NSNotification *)))(void)  = ^ (NSNotificationCenter * notification_center, NSOperationQueue * operation_queue) {
    return ^ (NSNotification * observed_notification, typeof(void(^)(NSNotification *))notification_handler) {
        return ^{
            [notification_center addObserverForName:observed_notification.name object:observed_notification.object queue:operation_queue usingBlock:notification_handler];
        };
    };
};
static void (^observe_notifications)(NSArray<notification> *) = ^ (NSArray<notification> * notifications) {
    for (notification observed_notification in notifications) observed_notification();
};

// To-Do: Create an NSNotificationObserver block type that observes notifications when passed an object to observe
//        It should return another block that, when executed, removes the notification observer

static void (^setup_audio_session)(void) = ^{
    __block NSError *error = nil;
    static void (^throw_exception_with_error)(NSError ** error_t) = ^ (NSError ** error_t) {
        printf("Error configuring audio session:\n\t%s\n", [[*error_t localizedFailureReason] UTF8String]);
        NSException* exception = [NSException
                                  exceptionWithName:(*error_t).domain
                                  reason:(*error_t).localizedDescription
                                  userInfo:@{@"Error Code" : @((*error_t).code)}];
        @throw exception;
    };
    
    @try {
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord mode:AVAudioSessionModeDefault options:AVAudioSessionCategoryOptionAllowAirPlay | AVAudioSessionCategoryOptionDefaultToSpeaker error:&error];
//        !(error) ?: display_error(&error);
        [[AVAudioSession sharedInstance] setSupportsMultichannelContent:TRUE  error:&error];
//        !(error) ?: display_error(&error);
        [[AVAudioSession sharedInstance] setPreferredInputNumberOfChannels:2  error:&error];
//        !(error) ?: display_error(&error);
        [[AVAudioSession sharedInstance] setPreferredOutputNumberOfChannels:2 error:&error];
//        !(error) ?: display_error(&error);
        [[AVAudioSession sharedInstance] setPrefersNoInterruptionsFromSystemAlerts:TRUE error:&error]; // TO-DO: Make this a user-specified preference
//        !(error) ?: display_error(&error);
    } @catch (NSException *exception) {
        printf("Exception configuring audio session:\n\t%s\n\t%s\n\t%lu",
               [exception.name UTF8String],
               [exception.debugDescription UTF8String],
               ((NSNumber *)[exception.userInfo valueForKey:@"Error Code"]).unsignedIntegerValue);
    } @finally {
        // Setup notifications
        
        notification_observer audio_session_notification_observer = notification_observation([NSNotificationCenter defaultCenter], [NSOperationQueue mainQueue]);
        
        notification observe_audio_session_interruption_notification = audio_session_notification_observer([NSNotification notificationWithName:(NSNotificationName)AVAudioSessionInterruptionNotification object:[AVAudioSession sharedInstance]], ^(NSNotification * notification) {
            UInt8 theInterruptionType = [[notification.userInfo valueForKey:AVAudioSessionInterruptionTypeKey] intValue];
            NSLog(@"Session interrupted > --- %s ---\n", theInterruptionType == AVAudioSessionInterruptionTypeBegan ? "Begin Interruption" : "End Interruption");
//            static BOOL _isSessionInterrupted;
            switch (theInterruptionType) {
                case AVAudioSessionInterruptionTypeBegan: {
                    //                _isSessionInterrupted = [_engine isRunning];
                    //                !(_isSessionInterrupted) ?: [self toggleAudioEngineRunningStatus:((ViewController *)[[[[UIApplication sharedApplication] delegate] window] rootViewController]).playPauseButton];
                    break;
                }
                    
                case AVAudioSessionInterruptionTypeEnded: {
                    //                !(_isSessionInterrupted) ?: [self toggleAudioEngineRunningStatus:((ViewController *)[[[[UIApplication sharedApplication] delegate] window] rootViewController]).playPauseButton];
                    //                _isSessionInterrupted = FALSE;
                    break;
                }
                    
                default:
                    break;
            }
        });
        
        notification observe_audio_route_change_notification = audio_session_notification_observer([NSNotification notificationWithName:(NSNotificationName)AVAudioSessionRouteChangeNotification object:[AVAudioSession sharedInstance]], ^(NSNotification * notification) {
            UInt8 reasonValue = [[notification.userInfo valueForKey:AVAudioSessionRouteChangeReasonKey] intValue];
            AVAudioSessionRouteDescription *routeDescription = [notification.userInfo valueForKey:AVAudioSessionRouteChangePreviousRouteKey];
            
            NSLog(@"Route change:");
            switch (reasonValue) {
                case AVAudioSessionRouteChangeReasonNewDeviceAvailable:
                    NSLog(@"     NewDeviceAvailable");
                    break;
                case AVAudioSessionRouteChangeReasonOldDeviceUnavailable:
                    NSLog(@"     OldDeviceUnavailable");
                    break;
                case AVAudioSessionRouteChangeReasonCategoryChange:
                    NSLog(@"     CategoryChange");
                    NSLog(@"     New Category: %@", [[AVAudioSession sharedInstance] category]);
                    break;
                case AVAudioSessionRouteChangeReasonOverride:
                    NSLog(@"     Override");
                    break;
                case AVAudioSessionRouteChangeReasonWakeFromSleep:
                    NSLog(@"     WakeFromSleep");
                    break;
                case AVAudioSessionRouteChangeReasonNoSuitableRouteForCategory:
                    NSLog(@"     NoSuitableRouteForCategory");
                    break;
                default:
                    NSLog(@"     ReasonUnknown");
            }
            
            NSLog(@"Previous route:\n");
            NSLog(@"%@", routeDescription);
        });

        observe_notifications(@[observe_audio_session_interruption_notification, observe_audio_route_change_notification]);
        
    }
};

- (instancetype)init
{
    self = [super init];
    
    if (self)
    {
        //        semaphore = dispatch_semaphore_create(1);
        _audioEngine = [[AVAudioEngine alloc] init];
        _mixerNode = _audioEngine.mainMixerNode;
        
//        _environmentNode = [[AVAudioEnvironmentNode alloc] init];
//        [_environmentNode setOutputType:AVAudioEnvironmentOutputTypeHeadphones];
//        [_environmentNode setOutputVolume:1.0];
//        [_audioEngine attachNode:_environmentNode];
        
        _submixer = [[AVAudioMixerNode alloc] init];
        [_audioEngine attachNode:_submixer];
        
        _reverb = [[AVAudioUnitReverb alloc] init];
        [_reverb loadFactoryPreset:AVAudioUnitReverbPresetLargeHall];
        [_reverb setWetDryMix:50];
        [_audioEngine attachNode:_reverb];
        
        _playerOneNode = [[AVAudioPlayerNode alloc] init];
        [_playerOneNode setRenderingAlgorithm:AVAudio3DMixingRenderingAlgorithmAuto];
        [_playerOneNode setSourceMode:AVAudio3DMixingSourceModeAmbienceBed];
        [_audioEngine attachNode:_playerOneNode];
        [_audioEngine connect:_playerOneNode to:_submixer format:[_playerOneNode outputFormatForBus:0]];
        
        _playerTwoNode = [[AVAudioPlayerNode alloc] init];
        [_playerTwoNode setRenderingAlgorithm:AVAudio3DMixingRenderingAlgorithmAuto];
        [_playerTwoNode setSourceMode:AVAudio3DMixingSourceModeAmbienceBed];
        [_audioEngine attachNode:_playerTwoNode];
        [_audioEngine connect:_playerTwoNode to:_submixer format:[_playerTwoNode outputFormatForBus:0]];
        
        [_audioEngine connect:_submixer to:_reverb format:[_mixerNode outputFormatForBus:0]];
        [_audioEngine connect:_reverb to:_mixerNode format:[_mixerNode outputFormatForBus:0]];
        
        
        setup_audio_session();
        
//        __autoreleasing NSError *error = nil;
//        [_audioEngine startAndReturnError:&error];
        
//        [[AVAudioSession sharedInstance] setActive:YES error:&error];
    }
    
    return self;
}



//- (AVAudioPCMBuffer *)createAudioBufferWithLoopableSineWaveFrequency:(NSUInteger)frequency
//{
//    AVAudioFormat *mixerFormat = [_mixerNode outputFormatForBus:0];
//    NSUInteger randomNum = [self generateRandomNumberBetweenMin:1 Max:4];
//    double frameLength = mixerFormat.sampleRate / randomNum;
//    AVAudioPCMBuffer *pcmBuffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:mixerFormat frameCapacity:frameLength];
//    pcmBuffer.frameLength = frameLength;
//
//    float *leftChannel = pcmBuffer.floatChannelData[0];
//    float *rightChannel = mixerFormat.channelCount == 2 ? pcmBuffer.floatChannelData[1] : nil;
//
//    NSUInteger r = arc4random_uniform(2);
//    double amplitude_step  = (1.0 / frameLength > 0.000100) ? (((double)arc4random() / 0x100000000) * (0.000100 - 0.000021) + 0.000021) : 1.0 / frameLength;
//    double amplitude_value = 0.0;
//    for (int i_sample = 0; i_sample < pcmBuffer.frameCapacity; i_sample++)
//    {
//        amplitude_value += amplitude_step;
//        double amplitude = pow(((r == 1) ? ((amplitude_value < 1.0) ? (amplitude_value) : 1.0) : ((1.0 - amplitude_value > 0.0) ? 1.0 - (amplitude_value) : 0.0)), ((r == 1) ? randomNum : 1.0/randomNum));
//        amplitude = ((amplitude < 0.000001) ? 0.000001 : amplitude);
//        double value = sinf((frequency*i_sample*2*M_PI) / mixerFormat.sampleRate);
//        if (leftChannel)  leftChannel[i_sample]  = value * amplitude;
//        if (rightChannel) rightChannel[i_sample] = value * (1.0 - amplitude);
//    }
//
//    return pcmBuffer;
//}

//

//- (void)start
//{
//    static void (^recursive_block)(double, AudioBufferCompletionBlock);
//    recursive_block = ^(double first_frequency, AudioBufferCompletionBlock audioBufferCompletionBlock)
//    {
//        // create audio buffer with first_frequency
//        // generate second frequency
//        // generate third frequency
//        // create audio buffer with interstitial frequency by averaging first and second frequency
//        // create audio buffer with second frequency
//        // create audio buffer with interstitial frequency by averaging second and third frequency
//        // return audio buffers with CreateAudioBufferCompletionBlock
//        // pass third frequency to recursive_block as first_frequency when PlayToneCompletionBlock is called
//        audioBufferCompletionBlock([AVAudioPCMBuffer new], ^{
//
//        });
//    };
//
//    recursive_block((((double)arc4random() / 0x100000000) * (high_frequency - low_frequency) + low_frequency), ^(AVAudioPCMBuffer *buffer, ToneCompletionBlock toneCompletionBlock)
//    {
//        [self->_playerOneNode scheduleBuffer:buffer atTime:nil options:AVAudioPlayerNodeBufferInterruptsAtLoop completionCallbackType:AVAudioPlayerNodeCompletionDataPlayedBack completionHandler:^(AVAudioPlayerNodeCompletionCallbackType callbackType) {
//            if (callbackType == AVAudioPlayerNodeCompletionDataPlayedBack)
//                toneCompletionBlock();
//            NSLog(@"Calling playToneCompletionBlock 2...");
//        }];
//    });
//}

/// / To-Do: Use dispatch_io to read buffers instead

static const float high_frequency = 6000.0;
static const float low_frequency  = 1000.0;

NSArray<NSDictionary<NSString *, id> *> *(^tonesDictionary)(void) = ^NSArray<NSDictionary<NSString *, id> *> *(void)
{
    NSMutableArray *tones = [NSMutableArray arrayWithCapacity:90];
    for (int i = 0; i < 180; i++)
    {
        AVAudioTime *time = [[AVAudioTime alloc] initWithHostTime:CMClockConvertHostTimeToSystemUnits(CMClockGetTime(CMClockGetHostTimeClock()))];
        NSDictionary *td = @{@"time" : time,
                             @"frequency_right" : @((((double)arc4random() / 0x100000000) * (high_frequency - low_frequency) + low_frequency)),
                             @"frequency_left" : @((((double)arc4random() / 0x100000000) * (high_frequency - low_frequency) + low_frequency))};
        [tones addObject:td];
        
        float randomNum = (((double)arc4random() / 0x100000000) * (1.0 - 0.0) + 0.0);
        CMTime current_cmtime = CMTimeAdd(CMClockGetTime(CMClockGetHostTimeClock()), CMTimeMakeWithSeconds(randomNum, NSEC_PER_SEC));
        time = [[AVAudioTime alloc] initWithHostTime:CMClockConvertHostTimeToSystemUnits(current_cmtime)];
        td = @{@"time" : time,
               @"frequency_right" : @((((double)arc4random() / 0x100000000) * (high_frequency - low_frequency) + low_frequency)),
               @"frequency_left" : @((((double)arc4random() / 0x100000000) * (high_frequency - low_frequency) + low_frequency))};
        [tones addObject:td];
    }
    
    return tones;
};

- (BOOL)start
{
    NSError *error = nil;
    if (self.audioEngine.isRunning == NO && [_audioEngine startAndReturnError:&error])
    {
        printf("\n%s\nerror: %s\n", __PRETTY_FUNCTION__, error.localizedFailureReason.UTF8String);
        
        if (![self->_playerOneNode isPlaying] || ![self->_playerTwoNode isPlaying])
        {
            [self->_playerOneNode play];
            [self->_playerTwoNode play];
            NSError *error = nil;
            [[AVAudioSession sharedInstance] setActive:TRUE error:&error];
            NSLog(@"error: %@", error.localizedFailureReason);
        }

        if (self->_playerOneNode)
        {
//            ClicklessTones *tones = [[ClicklessTones alloc] init];
            SIMDTones * tones = [[SIMDTones alloc] init];
            [ToneBarrierPlayer.context setPlayer:(id<ToneBarrierPlayerDelegate> _Nonnull)tones];
            [ToneBarrierPlayer.context createAudioBufferWithFormat:[self->_mixerNode outputFormatForBus:0] completionBlock:^(AVAudioPCMBuffer * _Nonnull buffer1, AVAudioPCMBuffer * _Nonnull buffer2, PlayToneCompletionBlock playToneCompletionBlock) {
                [self->_playerOneNode scheduleBuffer:buffer1 atTime:nil options:AVAudioPlayerNodeBufferInterruptsAtLoop completionCallbackType:AVAudioPlayerNodeCompletionDataPlayedBack completionHandler:^(AVAudioPlayerNodeCompletionCallbackType callbackType) {
                    playToneCompletionBlock();
                }];
//                [self->_playerTwoNode scheduleBuffer:buffer2 atTime:nil options:AVAudioPlayerNodeBufferInterruptsAtLoop completionCallbackType:AVAudioPlayerNodeCompletionDataConsumed completionHandler:^(AVAudioPlayerNodeCompletionCallbackType callbackType) {
//                    playToneCompletionBlock();
//                }];

                
                
            }];
        }
    }
    return [ToneGenerator.sharedGenerator.audioEngine isRunning];
}

NSArray<Frequencies *> * (^pairFrequencies)(NSArray<Frequencies *> *, AVAudioTime *) = ^NSArray<Frequencies *> * (NSArray<Frequencies *> * frequenciesPair, AVAudioTime *time)
{
    NSMutableArray<Frequencies *> *pairs = [NSMutableArray new];
    [pairs addObject:[[Frequencies alloc] initWithFrequency1:frequenciesPair.lastObject.frequency1.doubleValue
                                                  frequency2:frequenciesPair.lastObject.frequency2.doubleValue
                                               stereoChannel:(StereoChannel)frequenciesPair.lastObject.channel.unsignedIntValue
                                                        time:time]];
    [pairs addObject:[[Frequencies alloc] initWithFrequency1:(((double)arc4random() / 0x100000000) * (high_frequency - low_frequency) + low_frequency)
                                                  frequency2:(((double)arc4random() / 0x100000000) * (high_frequency - low_frequency) + low_frequency)
                                               stereoChannel:((StereoChannel)frequenciesPair.lastObject.channel.unsignedIntValue == StereoChannelRight) ? StereoChannelLeft : StereoChannelRight
                                                        time:time]];
    
    NSLog(@"Return frequencies (1st): %f\t%f", pairs.firstObject.frequency1.doubleValue, pairs.firstObject.frequency2.doubleValue);
    NSLog(@"Return frequencies (2nd): %f\t%f", pairs.lastObject.frequency1.doubleValue, pairs.lastObject.frequency2.doubleValue);
    NSLog(@"Time: %f", [AVAudioTime secondsForHostTime:[pairs.firstObject.time hostTime]]);
    
    return (NSArray<Frequencies *> *)pairs;
};

AVAudioTime *(^bufferSchedule)(CMTime, NSUInteger) = ^AVAudioTime *(CMTime current_time, NSUInteger count)
{
    CMTime scheduled_time = CMTimeAdd(current_time, CMTimeMakeWithSeconds(count, NSEC_PER_SEC));
    AVAudioTime *time = [[AVAudioTime alloc] initWithHostTime:CMClockConvertHostTimeToSystemUnits(scheduled_time)];
    
    return time;
};

NSArray<NSArray<Frequencies *> *> *(^scoreFrequenciesPairs)(void) = ^NSArray<NSArray<Frequencies *> *> *(void)
{
    __block NSMutableArray *score = [NSMutableArray new];
    CMTime current_time = CMClockGetTime(CMClockGetHostTimeClock());
    __block NSUInteger count = 0;
    static void (^block)(Frequencies *);
    block = ^void(Frequencies *returnFrequencies)
    {
        NSArray<Frequencies *> *frequenciesPair = pairFrequencies(returnFrequencies, bufferSchedule(current_time, count++));
        [score addObject:frequenciesPair];
        if (score.count < 90) block([frequenciesPair lastObject]);
        //        if ([ToneGenerator.sharedGenerator.audioEngine isRunning]) block([frequenciesPair lastObject]); // Can't do this without a completion block that returns every frequenciesPair array
    };
    block(nil);
    
    return score;
};

double Normalize(double a, double b)
{
    return (double)(a / b);
}

#define max_frequency      1500.0
#define min_frequency       100.0
#define max_trill_interval    4.0
#define min_trill_interval    2.0
#define duration_interval     5.0
#define duration_maximum      2.0


// Elements of an effective tone:
// High-pitched
// Modulating amplitude
// Alternating channel output
// Loud
// Non-natural (no spatialization)
//
// Elements of an effective score:
// Random frequencies
// Random duration
// Random tonality

// To-Do: Multiply the frequency by a random number between 1.01 and 1.1)

typedef NS_ENUM(NSUInteger, TonalHarmony) {
    TonalHarmonyConsonance,
    TonalHarmonyDissonance,
    TonalHarmonyRandom
};

typedef NS_ENUM(NSUInteger, TonalInterval) {
    TonalIntervalUnison,
    TonalIntervalOctave,
    TonalIntervalMajorSixth,
    TonalIntervalPerfectFifth,
    TonalIntervalPerfectFourth,
    TonalIntervalMajorThird,
    TonalIntervalMinorThird,
    TonalIntervalRandom
};

typedef NS_ENUM(NSUInteger, TonalEnvelope) {
    TonalEnvelopeAverageSustain,
    TonalEnvelopeLongSustain,
    TonalEnvelopeShortSustain
};

double Tonality(double frequency, TonalInterval interval, TonalHarmony harmony)
{
    double new_frequency = frequency;
    switch (harmony) {
        case TonalHarmonyDissonance:
            new_frequency *= (1.1 + drand48());
            break;
            
        case TonalHarmonyConsonance:
            new_frequency = ToneGenerator.Interval(frequency, interval);
            break;
            
        case TonalHarmonyRandom:
            new_frequency = Tonality(frequency, interval, (TonalHarmony)arc4random_uniform(2));
            break;
            
        default:
            break;
    }
    
    return new_frequency;
}

double Envelope(double x, TonalEnvelope envelope)
{
    double x_envelope = 1.0;
    switch (envelope) {
        case TonalEnvelopeAverageSustain:
            x_envelope = sinf(x * M_PI) * (sinf((2 * x * M_PI) / 2));
            break;
            
        case TonalEnvelopeLongSustain:
            x_envelope = sinf(x * M_PI) * -sinf(
                               ((Envelope(x, TonalEnvelopeAverageSustain) - (2.0 * Envelope(x, TonalEnvelopeAverageSustain)))) / 2.0)
            * (M_PI / 2.0) * 2.0;
            break;
            
        case TonalEnvelopeShortSustain:
            x_envelope = sinf(x * M_PI) * -sinf(
                               ((Envelope(x, TonalEnvelopeAverageSustain) - (-2.0 * Envelope(x, TonalEnvelopeAverageSustain)))) / 2.0)
            * (M_PI / 2.0) * 2.0;
            break;
    
        default:
            break;
    }
    
    return x_envelope;
}

typedef NS_ENUM(NSUInteger, Trill) {
    TonalTrillUnsigned,
    TonalTrillInverse
};

+ (double(^)(double, double))Frequency
{
    return ^double(double time, double frequency)
    {
        return pow(sinf(M_PI * time * frequency), 2.0);
    };
}

+ (double(^)(double))TrillInterval
{
    return ^double(double frequency)
    {
        return ((frequency / (max_frequency - min_frequency) * (max_trill_interval - min_trill_interval)) + min_trill_interval);
    };
}

+ (double(^)(double, double))Trill
{
    return ^double(double time, double trill)
    {
        return pow(2.0 * pow(sinf(M_PI * time * trill), 2.0) * 0.5, 4.0);
    };
}

+ (double(^)(double, double))TrillInverse
{
    return ^double(double time, double trill)
    {
        return pow(-(2.0 * pow(sinf(M_PI * time * trill), 2.0) * 0.5) + 1.0, 4.0);
    };
}

+ (double(^)(double))Amplitude
{
    return ^double(double time)
    {
        return pow(sinf(time * M_PI), 3.0) * 0.5;
    };
}

+ (double(^)(double, TonalInterval))Interval
{
    return ^double(double frequency, TonalInterval interval)
    {
        double new_frequency = frequency;
        switch (interval)
        {
            case TonalIntervalUnison:
                new_frequency *= 1.0;
                break;
                
            case TonalIntervalOctave:
                new_frequency *= 2.0;
                break;
                
            case TonalIntervalMajorSixth:
                new_frequency *= 5.0/3.0;
                break;
                
            case TonalIntervalPerfectFifth:
                new_frequency *= 4.0/3.0;
                break;
                
            case TonalIntervalMajorThird:
                new_frequency *= 5.0/4.0;
                break;
                
            case TonalIntervalMinorThird:
                new_frequency *= 6.0/5.0;
                break;
                
            case TonalIntervalRandom:
                new_frequency = ToneGenerator.Interval(frequency, (TonalInterval)arc4random_uniform(7));
                
            default:
                break;
        }
        
        return new_frequency;
    };
};

AVAudioPCMBuffer * (^audioBufferFromFrequencies)(Frequencies *, AVAudioFormat *) = ^AVAudioPCMBuffer *(Frequencies *frequencies, AVAudioFormat *audioFormat)
{
    AVAudioFrameCount frameCount = audioFormat.sampleRate;
    AVAudioPCMBuffer *pcmBuffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:audioFormat frameCapacity:frameCount];
    pcmBuffer.frameLength = frameCount;
    float *left_channel  = pcmBuffer.floatChannelData[0];
    float *right_channel = (audioFormat.channelCount == 2) ? pcmBuffer.floatChannelData[1] : nil;
    
    
    double harmonized_frequency = Tonality(frequencies.frequency1.doubleValue, TonalIntervalRandom, TonalHarmonyRandom);
    double trill_interval       = ToneGenerator.TrillInterval(frequencies.frequency1.doubleValue);
    for (int index = 0; index < frameCount; index++)
    {
        double normalized_index = Normalize(index, frameCount);
        double trill            = ToneGenerator.Trill(normalized_index, trill_interval);
        double trill_inverse    = ToneGenerator.TrillInverse(normalized_index, trill_interval);
        double amplitude        = ToneGenerator.Amplitude(normalized_index);
        
//    int amplitude_frequency = arc4random_uniform(8) + 4;
        if (left_channel) left_channel[index] = ToneGenerator.Frequency(normalized_index, frequencies.frequency1.doubleValue) * amplitude * trill;
        if (right_channel) right_channel[index] = ToneGenerator.Frequency(normalized_index, harmonized_frequency) * amplitude * trill_inverse;
        
//        if (left_channel)  left_channel[index]  = (NormalizedSineEaseInOut(normalized_index, frequencies.frequency1.doubleValue) * NormalizedSineEaseInOut(normalized_index, amplitude_frequency));
//        if (right_channel) right_channel[index] = (NormalizedSineEaseInOut(normalized_index, frequencies.frequency2.doubleValue) * NormalizedSineEaseInOut(normalized_index, amplitude_frequency)); // fade((leading_fade == FadeOut) ? FadeIn : leading_fade, normalized_index, (SineEaseInOutFrequency(normalized_index, frequencyRight) * NormalizedSineEaseInOutAmplitude((1.0 - normalized_index), 1)));
    }
    
    return pcmBuffer;
};

void (^scheduleBuffers)(AVAudioPlayerNode *, AVAudioPlayerNode *, AVAudioFormat *) = ^void(AVAudioPlayerNode *playerNode1, AVAudioPlayerNode *playerNode2, AVAudioFormat *audioFormat)
{
    // TO-DO:
    // Create a new frequency object
    // Pass it to the audio buffer block
    // Use
    
//    AVAudioTime *time = [[AVAudioTime alloc] initWithHostTime:CMClockConvertHostTimeToSystemUnits(CMClockGetTime(CMClockGetHostTimeClock()))];
    NSArray<NSArray<Frequencies *> *> *score = (NSArray<NSArray<Frequencies *> *> *)[NSArray arrayWithArray:scoreFrequenciesPairs()];
    for (NSUInteger index = 0; index < score.count; index++)  // (NSArray<Frequencies *> *frequencyPair in score)
    {
        NSArray<Frequencies *> *frequencyPair = (NSArray<Frequencies *> *)[score objectAtIndex:index];
        [playerNode1 scheduleBuffer:audioBufferFromFrequencies([frequencyPair firstObject], audioFormat) atTime:[[frequencyPair firstObject] time] options:AVAudioPlayerNodeBufferInterruptsAtLoop completionCallbackType:AVAudioPlayerNodeCompletionDataPlayedBack completionHandler:^(AVAudioPlayerNodeCompletionCallbackType callbackType) {
            NSLog(@"%lu Played frequencies (1st): %f\t%f\t%f", index, frequencyPair.firstObject.frequency1.doubleValue, frequencyPair.firstObject.frequency2.doubleValue, [AVAudioTime secondsForHostTime:[frequencyPair.firstObject.time hostTime]]);
        }];
        [playerNode2 scheduleBuffer:audioBufferFromFrequencies([frequencyPair lastObject], audioFormat) atTime:[[frequencyPair lastObject] time] options:AVAudioPlayerNodeBufferInterruptsAtLoop completionCallbackType:AVAudioPlayerNodeCompletionDataPlayedBack completionHandler:^(AVAudioPlayerNodeCompletionCallbackType callbackType) {
           NSLog(@"%lu Played frequencies (2nd): %f\t%f\t%f", index, frequencyPair.lastObject.frequency1.doubleValue, frequencyPair.lastObject.frequency2.doubleValue, [AVAudioTime secondsForHostTime:[frequencyPair.lastObject.time hostTime]]);
        }];
    }
};

typedef void (^DataPlayedBackCompletionBlock)(void);
typedef void (^DataRenderedCompletionBlock)(NSArray<Frequencies *> * frequencyPair, DataPlayedBackCompletionBlock dataPlayedBackCompletionBlock);

//- (void)start
//{
//    [audio_session() setActive:YES error:nil];
//
//    if (self.audioEngine.isRunning == NO)
//    {
//        NSError *error = nil;
//        [_audioEngine startAndReturnError:&error];
//        NSLog(@"error: %@", error);
//        [[NSNotificationCenter defaultCenter] postNotificationName:@"ToneBarrierPlayingNotification" object:nil userInfo:nil];
//
//        if (![self->_playerOneNode isPlaying] || ![self->_playerTwoNode isPlaying])
//        {
//            [self->_playerOneNode play];
//            [self->_playerTwoNode play];
//        }
//
//        if (self->_playerOneNode && self->_playerTwoNode)
//        {
//            scheduleBuffers(self->_playerOneNode, self->_playerTwoNode, [self->_mixerNode outputFormatForBus:0]);
//        }
//    }
//}

/*
 BARRIER ONE
 */

//- (void)start
//{
//    if (self.audioEngine.isRunning == NO)
//    {
//        NSError *error = nil;
//        [_audioEngine startAndReturnError:&error];
//        NSLog(@"error: %@", error);
//    }
//
//
//    if (self->_timer != nil) [self stop];
//    self.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
//    dispatch_source_set_timer(self->_timer, DISPATCH_TIME_NOW, 2.0 * NSEC_PER_SEC, 0.0 * NSEC_PER_SEC);
//    dispatch_source_set_event_handler(self->_timer, ^{
//        if ([self->_playerOneNode isPlaying] || [self->_playerTwoNode isPlaying])
//        {
//            [self->_playerOneNode stop];
//            [self->_playerTwoNode stop];
//        }
//
//        if (self->_playerOneNode)
//        {
//            AVAudioTime *start_time_one = [[AVAudioTime alloc] initWithHostTime:CMClockConvertHostTimeToSystemUnits(CMClockGetTime(CMClockGetHostTimeClock()))];
//
//            [self->_playerOneNode scheduleBuffer:[self createAudioBufferWithLoopableSineWaveFrequency:(((double)arc4random() / 0x100000000) * (high_frequency - low_frequency) + low_frequency)] atTime:start_time_one options:AVAudioPlayerNodeBufferLoops completionHandler:^{
//
//            }];
//
//            [self->_playerOneNode scheduleBuffer:[self createAudioBufferWithLoopableSineWaveFrequency:(((double)arc4random() / 0x100000000) * (high_frequency - low_frequency) + low_frequency)] atTime:start_time_one options:AVAudioPlayerNodeBufferLoops completionHandler:^{
//
//            }];
//
//            [self->_playerOneNode play];
//        }
//    });
//    dispatch_resume(self.timer);
//}

/*
 BARRIER TWO
 */

// - (void)start
// {
//     if (self.audioEngine.isRunning == NO)
//     {
//         NSError *error = nil;
//         [_audioEngine startAndReturnError:&error];
//         NSLog(@"error: %@", error);
//     }
//
//     if (self->_timer != nil) [self stop];
//
//     self.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
//     dispatch_source_set_timer(self->_timer, DISPATCH_TIME_NOW, 2.0 * NSEC_PER_SEC, 0.0 * NSEC_PER_SEC);
//     dispatch_source_set_event_handler(self->_timer, ^{
//         if (![self->_playerOneNode isPlaying] || ![self->_playerTwoNode isPlaying])
//         {
//             [self->_playerOneNode play];
//             [self->_playerTwoNode play];
//         }
//
//         if (self->_playerOneNode && self->_playerTwoNode)
//         {
//             AVAudioTime *start_time_one = [[AVAudioTime alloc] initWithHostTime:CMClockConvertHostTimeToSystemUnits(CMClockGetTime(CMClockGetHostTimeClock()))];
//             double frequencyOne = (((double)arc4random() / 0x100000000) * (high_frequency - low_frequency) + low_frequency);
//             [self->_playerOneNode scheduleBuffer:[self createAudioBufferWithLoopableSineWaveFrequency:frequencyOne] atTime:start_time_one options:AVAudioPlayerNodeBufferLoops completionHandler:^{
////                 [self.toneWaveRendererDelegate drawFrequency:frequencyOne amplitude:1.0 channel:StereoChannelR];
//             }];
//
//             float randomNum = (((double)arc4random() / 0x100000000) * (1.0 - 0.0) + 0.0); //((float)rand() / RAND_MAX) * 1;
//             CMTime current_cmtime = CMTimeAdd(CMClockGetTime(CMClockGetHostTimeClock()), CMTimeMakeWithSeconds(randomNum, NSEC_PER_SEC));
//             AVAudioTime *start_time_two = [[AVAudioTime alloc] initWithHostTime:CMClockConvertHostTimeToSystemUnits(current_cmtime)];
////
//             double frequencyTwo = (((double)arc4random() / 0x100000000) * (high_frequency - low_frequency) + low_frequency);
//             [self->_playerTwoNode scheduleBuffer:[self createAudioBufferWithLoopableSineWaveFrequency:frequencyTwo] atTime:start_time_two options:AVAudioPlayerNodeBufferLoops completionHandler:^{
////                 [self.toneWaveRendererDelegate drawFrequency:frequencyTwo amplitude:1.0/2.0 channel:StereoChannelL];
//             }];
////         }
////
////
////          if (self->_playerOneNode && self->_playerTwoNode)
////          {
////              float randomNum = ((float)rand() / RAND_MAX) * 1;
////              CMTime current_cmtime = CMTimeAdd(CMClockGetTime(CMClockGetHostTimeClock()), CMTimeMakeWithSeconds(randomNum, NSEC_PER_SEC));
////              AVAudioTime *start_time_three = [[AVAudioTime alloc] initWithHostTime:CMClockConvertHostTimeToSystemUnits(current_cmtime)];
////              double frequencyOne = (((double)arc4random() / 0x100000000) * (high_frequency - low_frequency) + low_frequency);
////              [self->_playerOneNode scheduleBuffer:[self createAudioBufferWithLoopableSineWaveFrequency:frequencyOne] atTime:start_time_three options:AVAudioPlayerNodeBufferLoops completionHandler:^{
//////                  [self.toneWaveRendererDelegate drawFrequency:frequencyOne amplitude:1.0 channel:StereoChannelR];
////              }];
////
////              randomNum = ((float)rand() / RAND_MAX) * 1;
////              current_cmtime = CMTimeAdd(CMClockGetTime(CMClockGetHostTimeClock()), CMTimeMakeWithSeconds(randomNum, NSEC_PER_SEC));
////              AVAudioTime *start_time_four = [[AVAudioTime alloc] initWithHostTime:CMClockConvertHostTimeToSystemUnits(current_cmtime)];
////
////              double frequencyTwo = (((double)arc4random() / 0x100000000) * (high_frequency - low_frequency) + low_frequency);
////              [self->_playerTwoNode scheduleBuffer:[self createAudioBufferWithLoopableSineWaveFrequency:frequencyTwo] atTime:start_time_four options:AVAudioPlayerNodeBufferLoops completionHandler:^{
//////                  [self.toneWaveRendererDelegate drawFrequency:frequencyTwo amplitude:1.0/3.0 channel:StereoChannelL];
////              }];
//          }
//     });
//     dispatch_resume(self.timer);
// }

/*
 BARRIER THREE
 */

//- (void)start
//{
//    if (self.audioEngine.isRunning == NO)
//    {
//        NSError *error = nil;
//        [_audioEngine startAndReturnError:&error];
//        NSLog(@"error: %@", error);
//    }
//
//    if (self->_timer != nil) [self stop];
//
//    self.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
//    dispatch_source_set_timer(self->_timer, DISPATCH_TIME_NOW, 2.0 * NSEC_PER_SEC, 0.0 * NSEC_PER_SEC);
//    dispatch_source_set_event_handler(self->_timer, ^{
//        if (![self->_playerOneNode isPlaying] || ![self->_playerTwoNode isPlaying])
//        {
//            [self->_playerOneNode play];
//            [self->_playerTwoNode play];
//        }
//
//        NSUInteger r = arc4random_uniform(2);
//        switch (r) {
//            case 1: {
//                CMTime ctime = CMClockGetTime(CMClockGetHostTimeClock());
//                uint64_t htime = CMClockConvertHostTimeToSystemUnits(ctime);
//                if (self->_playerOneNode && self->_playerTwoNode)
//                {
//                    double freq = (((double)arc4random() / 0x100000000) * (high_frequency - low_frequency) + low_frequency);
//                    [self->_playerOneNode scheduleBuffer:[self createAudioBufferWithLoopableSineWaveFrequency:freq]
//                                                  atTime:[[AVAudioTime alloc] initWithHostTime:htime]
//                                                 options:AVAudioPlayerNodeBufferLoops completionHandler:^{
//                    }];
//
//                    [self->_playerTwoNode scheduleBuffer:[self createAudioBufferWithLoopableSineWaveFrequency:freq]
//                                                  atTime:[[AVAudioTime alloc] initWithHostTime:htime]
//                                                 options:AVAudioPlayerNodeBufferLoops completionHandler:^{
//                    }];
//
//                    freq = (((double)arc4random() / 0x100000000) * (high_frequency - low_frequency) + low_frequency);
//                    float randomNum = ((float)rand() / RAND_MAX) * 1;
//                    [self->_playerOneNode scheduleBuffer:[self createAudioBufferWithLoopableSineWaveFrequency:freq]
//                                                  atTime:[[AVAudioTime alloc] initWithHostTime:CMClockConvertHostTimeToSystemUnits(CMTimeAdd(ctime, CMTimeMakeWithSeconds(randomNum, NSEC_PER_SEC)))]
//                                                 options:AVAudioPlayerNodeBufferLoops completionHandler:^{
//                    }];
//
//                    [self->_playerTwoNode scheduleBuffer:[self createAudioBufferWithLoopableSineWaveFrequency:freq]
//                                                  atTime:[[AVAudioTime alloc] initWithHostTime:CMClockConvertHostTimeToSystemUnits(CMTimeAdd(ctime, CMTimeMakeWithSeconds(randomNum, NSEC_PER_SEC)))]
//                                                 options:AVAudioPlayerNodeBufferLoops completionHandler:^{
//                    }];
//
//                    freq = (((double)arc4random() / 0x100000000) * (high_frequency - low_frequency) + low_frequency);
//                    randomNum += ((float)rand() / RAND_MAX) * 1;
//                    [self->_playerOneNode scheduleBuffer:[self createAudioBufferWithLoopableSineWaveFrequency:freq]
//                                                  atTime:[[AVAudioTime alloc] initWithHostTime:CMClockConvertHostTimeToSystemUnits(CMTimeAdd(ctime, CMTimeMakeWithSeconds(randomNum, NSEC_PER_SEC)))]
//                                                 options:AVAudioPlayerNodeBufferLoops completionHandler:^{
//                    }];
//
//                    [self->_playerTwoNode scheduleBuffer:[self createAudioBufferWithLoopableSineWaveFrequency:freq]
//                                                  atTime:[[AVAudioTime alloc] initWithHostTime:CMClockConvertHostTimeToSystemUnits(CMTimeAdd(ctime, CMTimeMakeWithSeconds(randomNum, NSEC_PER_SEC)))]
//                                                 options:AVAudioPlayerNodeBufferLoops completionHandler:^{
//                    }];
//
//                    freq = (((double)arc4random() / 0x100000000) * (high_frequency - low_frequency) + low_frequency);
//                    randomNum += ((float)rand() / RAND_MAX) * 1;
//                    [self->_playerOneNode scheduleBuffer:[self createAudioBufferWithLoopableSineWaveFrequency:freq]
//                                                  atTime:[[AVAudioTime alloc] initWithHostTime:CMClockConvertHostTimeToSystemUnits(CMTimeAdd(ctime, CMTimeMakeWithSeconds(randomNum, NSEC_PER_SEC)))]
//                                                 options:AVAudioPlayerNodeBufferLoops completionHandler:^{
//                    }];
//
//                    [self->_playerTwoNode scheduleBuffer:[self createAudioBufferWithLoopableSineWaveFrequency:freq]
//                                                  atTime:[[AVAudioTime alloc] initWithHostTime:CMClockConvertHostTimeToSystemUnits(CMTimeAdd(ctime, CMTimeMakeWithSeconds(randomNum, NSEC_PER_SEC)))]
//                                                 options:AVAudioPlayerNodeBufferLoops completionHandler:^{
//                    }];
//                 }
//                break;
//            }
//
//            default: {
//                AVAudioTime *start_time_one = [[AVAudioTime alloc] initWithHostTime:CMClockConvertHostTimeToSystemUnits(CMClockGetTime(CMClockGetHostTimeClock()))];
//                if (self->_playerOneNode && self->_playerTwoNode)
//                {
//                    double frequencyOne = (((double)arc4random() / 0x100000000) * (high_frequency - low_frequency) + low_frequency);
//                    double frequencyTwo = (((double)arc4random() / 0x100000000) * (high_frequency - low_frequency) + low_frequency);
//                    [self->_playerOneNode scheduleBuffer:[self createAudioBufferWithLoopableSineWaveFrequency:frequencyOne] atTime:start_time_one options:AVAudioPlayerNodeBufferLoops completionHandler:^{
//                    //                         [self.toneWaveRendererDelegate drawFrequency:frequencyOne amplitude:1.0 channel:StereoChannelR];
//                    }];
//
//
//                    [self->_playerTwoNode scheduleBuffer:[self createAudioBufferWithLoopableSineWaveFrequency:frequencyTwo] atTime:start_time_one options:AVAudioPlayerNodeBufferLoops completionHandler:^{
//                    //                         [self.toneWaveRendererDelegate drawFrequency:frequencyTwo amplitude:1.0 channel:StereoChannelL];
//                    }];
//                }
//
//                float randomNum = ((float)rand() / RAND_MAX) * 1;
//                CMTime current_cmtime = CMTimeAdd(CMClockGetTime(CMClockGetHostTimeClock()), CMTimeMakeWithSeconds(randomNum, NSEC_PER_SEC));
//                AVAudioTime *start_time_two = [[AVAudioTime alloc] initWithHostTime:CMClockConvertHostTimeToSystemUnits(current_cmtime)];
//                if (self->_playerOneNode && self->_playerTwoNode)
//                {
//                    double frequencyOne = (((double)arc4random() / 0x100000000) * (high_frequency - low_frequency) + low_frequency);
//                    [self->_playerOneNode scheduleBuffer:[self createAudioBufferWithLoopableSineWaveFrequency:frequencyOne] atTime:start_time_two options:AVAudioPlayerNodeBufferLoops completionHandler:^{
//                    //                          [self.toneWaveRendererDelegate drawFrequency:frequencyOne amplitude:1.0 channel:StereoChannelR];
//                    }];
//
//                    double frequencyTwo = (((double)arc4random() / 0x100000000) * (high_frequency - low_frequency) + low_frequency);
//                    [self->_playerTwoNode scheduleBuffer:[self createAudioBufferWithLoopableSineWaveFrequency:frequencyTwo] atTime:start_time_two options:AVAudioPlayerNodeBufferLoops completionHandler:^{
//                    //                          [self.toneWaveRendererDelegate drawFrequency:frequencyTwo amplitude:1.0 channel:StereoChannelL];
//                    }];
//                }
//                }
//                break;
//        }
//
//
//    });
//    dispatch_resume(self.timer);
//}

//
//typedef NS_OPTIONS(NSUInteger, Texture) {
//    Monophonic = 1 << 0,
//    Heterophonic = 1 << 1
//};
//
//// Phonaesthesia: the study of aesthetic properties of sounds
//typedef NS_OPTIONS(NSUInteger, Phonaesthetic) {
//    Cacophonic = 1 << 0,
//    Euphonic = 1 << 1
//};
//
//typedef NS_ENUM(NSUInteger, Rhythm) {
//    Monody,
//    Heterodony
//};
//
//
//static void (^generateTone)(AVAudioPlayerNode *) = ^(AVAudioPlayerNode *playerNode) {
//    // Loop the number of stereoChannels
//    AVAudioTime *start_time_one = [[AVAudioTime alloc] initWithHostTime:CMClockConvertHostTimeToSystemUnits(CMClockGetTime(CMClockGetHostTimeClock()))];
//        double frequencyOne = (((double)arc4random() / 0x100000000) * (high_frequency - low_frequency) + low_frequency);
//        [self->_playerOneNode scheduleBuffer:[self createAudioBufferWithLoopableSineWaveFrequency:frequencyOne] atTime:start_time_one options:AVAudioPlayerNodeBufferLoops completionHandler:^{
//            if ([self->_playerOneNode isPlaying] && [self->_playerTwoNode isPlaying])
//                generateTones(stereoChannels);
//        }];
//};
//
//- (void)play:(StereoChannels)stereoChannels
//{
//    if (self.audioEngine.isRunning == NO)
//    {
//        NSError *error = nil;
//        [_audioEngine startAndReturnError:&error];
//        NSLog(@"error: %@", error);
//    }
//
//    if ((stereoChannels & StereoChannelRight) && self->_playerOneNode)
//    {
//        if (![self->_playerOneNode isPlaying])
//            [self->_playerOneNode play];
//
//        generateTones(self->_playerOneNode);
//
//    }
//
//    if ((stereoChannels & StereoChannelLeft) && self->_playerTwoNode)
//    {
//        if (![self->_playerTwoNode isPlaying])
//            [self->_playerTwoNode play];
//
//        generateTones(self->_playerTwoNode);
//    }
//}

- (BOOL)stop
{
    //    dispatch_source_cancel(self->_timer);
    //    self->_timer = nil;
    //    dispatch_async(dispatch_get_main_queue(), ^{
    //    [self->_playerOneNode stop];
    //    [self->_playerTwoNode stop];
    if ([ToneGenerator.sharedGenerator.audioEngine isRunning]) [self->_audioEngine pause];
    //        [self.playerOneNode reset];
    //        [self.playerTwoNode reset];
    
    
//    [[NSNotificationCenter defaultCenter] postNotificationName:@"ToneBarrierPlayingNotification" object:self.audioEngine userInfo:nil];
    
    return [ToneGenerator.sharedGenerator.audioEngine isRunning];
    //    });
}

@end
