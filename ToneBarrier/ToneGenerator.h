//
//  ToneGenerator.h
//  ToneBarrierBeta
//
//  Created by James Alan Bush on 7/8/19.
//  Copyright © 2019 The Life of a Demoniac. All rights reserved.
//

//
//  ToneGenerator.h
//  ToneBarrierBeta
//
//  Created by James Alan Bush on 7/8/19.
//  Copyright © 2019 The Life of a Demoniac. All rights reserved.
//
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <AVFoundation/AVFoundation.h>

typedef void (^PlayToneCompletionBlock)(void);
typedef void (^CreateAudioBufferCompletionBlock)(AVAudioPCMBuffer * _Nonnull buffer1, AVAudioPCMBuffer * _Nonnull buffer2, PlayToneCompletionBlock _Nonnull playToneCompletionBlock);

@protocol ToneBarrierPlayerDelegate <NSObject>

- (void)createAudioBufferWithFormat:(AVAudioFormat *)audioFormat completionBlock:(CreateAudioBufferCompletionBlock)createAudioBufferCompletionBlock;

@end

@protocol ToneWaveRendererDelegate <NSObject>

//- (void)drawFrequency:(double)frequency amplitude:(double)amplitude channel:(StereoChannels)channel;

// Since the draw layer frame size is needed from the delegate-view to create a path, this method must return a block that requires the parameters from the delegate-view before executing it
// The problem with that is you lose the advantage of calculating the path at the same time you create the buffer (those are now split into two separate for-loops, when they could conceivably be combined into one)
// Solution: get the required information before/when creating the buffer from the delegate
// That means the delegate-view protocol method will return a block that draws the path provided by the caller;
// the delegate-view will provide the layer frame size; the caller will construct a block that adds the path
// The method-caller will provide a completion block to its caller that provides both the buffer and the jointly constructed block

//- (void)drawFrequency:(dispatch_block_t)block
//- (void)drawFrequency:(double)frequency amplitude:(double)amplitude channel:(StereoChannels)channel path:(CGPathRef _Nullable )path;

@end

@interface ToneGenerator : NSObject

@property (nonatomic, readonly) AVAudioEngine * _Nonnull audioEngine;

+ (nonnull ToneGenerator *)sharedGenerator;

@property (nonatomic, weak) id<ToneWaveRendererDelegate> _Nullable toneWaveRendererDelegate;
@property (nonatomic, strong) dispatch_source_t _Nullable timer;

@property (nonatomic, readonly) AVAudioPlayerNode * _Nullable playerOneNode;
@property (nonatomic, readonly) AVAudioPlayerNode * _Nullable playerTwoNode;
@property (copy) void (^ _Nonnull block)(void);
//@property (strong, nonatomic) dispatch_queue_t tone_serial_queue;



- (BOOL)start;
- (BOOL)stop;
- (void)alarm;

@end
