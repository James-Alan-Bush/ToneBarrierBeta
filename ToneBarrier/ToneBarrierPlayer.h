//
//  ToneBarrierPlayerContext.h
//  ToneBarrierBeta
//
//  Created by James Alan Bush on 12/17/19.
//  Copyright © 2019 The Life of a Demoniac. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ToneGenerator.h"

NS_ASSUME_NONNULL_BEGIN

@interface ToneBarrierPlayer : NSObject

+ (nonnull ToneBarrierPlayer *)context;

@property (assign) id<ToneBarrierPlayerDelegate> player;

- (void)createAudioBufferWithFormat:(AVAudioFormat *)audioFormat completionBlock:(CreateAudioBufferCompletionBlock)createAudioBufferCompletionBlock;;

@end

NS_ASSUME_NONNULL_END
