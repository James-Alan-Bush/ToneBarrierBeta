//
//  SIMDTones.h
//  ToneBarrier
//
//  Created by Xcode Developer on 2/4/23.
//

#import <Foundation/Foundation.h>
#import <GameKit/GameKit.h>
#import "ToneGenerator.h"

NS_ASSUME_NONNULL_BEGIN

@interface SIMDTones : NSObject <ToneBarrierPlayerDelegate>

+ (nonnull SIMDTones *)simdToneGenerator;
- (instancetype)init;
- (void)createAudioBufferWithFormat:(AVAudioFormat *)audioFormat completionBlock:(CreateAudioBufferCompletionBlock)createAudioBufferCompletionBlock;

@end

NS_ASSUME_NONNULL_END
