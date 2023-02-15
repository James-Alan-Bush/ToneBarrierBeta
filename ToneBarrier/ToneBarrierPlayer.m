//
//  ToneBarrierPlayerContext.m
//  ToneBarrierBeta
//
//  Created by James Alan Bush on 12/17/19.
//  Copyright © 2019 The Life of a Demoniac. All rights reserved.
//

#import "ToneBarrierPlayer.h"

@implementation ToneBarrierPlayer

static ToneBarrierPlayer *context = NULL;
+ (nonnull ToneBarrierPlayer *)context
{
    static dispatch_once_t onceSecurePredicate;
    dispatch_once(&onceSecurePredicate,^
                  {
        if (!context)
        {
            context = [[self alloc] init];
        }
    });
    
    return context;
}

- (void)createAudioBufferWithFormat:(AVAudioFormat *)audioFormat completionBlock:(CreateAudioBufferCompletionBlock)createAudioBufferCompletionBlock
{
    [_player createAudioBufferWithFormat:audioFormat completionBlock:createAudioBufferCompletionBlock];
}

@end
