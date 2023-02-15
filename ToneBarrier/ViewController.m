 //
//  ViewController.m
//  ToneBarrier
//
//  Created by James Alan Bush on 6/15/22.
//

#import "ViewController.h"
#import "ToneGenerator.h"
#import "AppDelegate.h"

#import "ViewController.h"
#import "ViewController+Signal.h"
#import "ViewController+AudioData.h"

#import <objc/runtime.h>


@import QuartzCore;
@import CoreGraphics;
@import AVKit;

@interface ViewController ()
{
    CAShapeLayer *pathLayerChannelR;
    CAShapeLayer *pathLayerChannelL;
    BOOL _wasPlaying;
}

@property (strong, nonatomic) MPNowPlayingInfoCenter * nowPlayingInfoCenter;
@property (strong, nonatomic) MPRemoteCommandCenter * remoteCommandCenter;

@property (weak, nonatomic) IBOutlet UIImageView *activationImageView;
@property (weak, nonatomic) IBOutlet UIImageView *reachabilityImageView;
@property (weak, nonatomic) IBOutlet UIImageView *thermometerImageView;
@property (weak, nonatomic) IBOutlet UIImageView *batteryImageView;
@property (weak, nonatomic) IBOutlet UIImageView *batteryLevelImageView;
//@property (weak, nonatomic) IBOutlet UIImageView *playButton;
@property (weak, nonatomic) IBOutlet AVRoutePickerView *routePickerVIew;

@property (weak, nonatomic) IBOutlet UIImageView *heartRateImage;

//@property (assign) id toneBarrierPlayingObserver;

@end

@implementation ViewController
{
    CAGradientLayer * gradient;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    const uintptr_t (^generate)(void) = generator(1, 1, 1);
    for (int i = 0; i < 10; i++) printf("i == %d\n", generate());
    
    [self.routePickerVIew setActiveTintColor:[UIColor systemBlueColor]];
    [self.routePickerVIew setDelegate:(id<AVRoutePickerViewDelegate> _Nullable)self];
    
    gradient = [CAGradientLayer new];
    gradient.frame = self.view.frame;
    [gradient setAllowsEdgeAntialiasing:TRUE];
    [gradient setColors:@[(id)[UIColor blackColor].CGColor, (id)[UIColor colorWithRed:0.f green:0.f blue:0.f alpha:0.f].CGColor, (id)[UIColor blackColor].CGColor]];
    [self.view.layer addSublayer:gradient];
    
    [self.play_button setImage:[UIImage systemImageNamed:@"stop"]  forState:UIControlStateSelected];
    [self.play_button setImage:[UIImage systemImageNamed:@"play"]  forState:UIControlStateNormal];
    [self.play_button setImage:[UIImage systemImageNamed:@"play.slash"] forState:UIControlStateDisabled];
    
//   condition_expr = ^ (UIButton * b) {
//       return ^{
//           return (unsigned long)(b.state ^ UIControlStateNormal);
//       };
//   }(self.play_button);
//
//    printf("condition == %s\n", (((condition_test = condition_eval((typeof(condition_expr) *)&condition_expr)))()) ? "TRUE" : "FALSE");
   
    
    NSMutableDictionary<NSString *, id> * nowPlayingInfo = [[NSMutableDictionary alloc] initWithCapacity:4];
    [nowPlayingInfo setObject:@"ToneBarrier" forKey:MPMediaItemPropertyTitle];
    [nowPlayingInfo setObject:(NSString *)@"James Alan Bush" forKey:MPMediaItemPropertyArtist];
    [nowPlayingInfo setObject:(NSString *)@"The Life of a Demoniac" forKey:MPMediaItemPropertyAlbumTitle];
    MPMediaItemArtwork *artwork = [[MPMediaItemArtwork alloc] initWithBoundsSize:CGSizeMake(180.0, 180.0) requestHandler:^ UIImage * _Nonnull (CGSize size) {
        static UIImage * image;
        image = [UIImage systemImageNamed:@"waveform.path"
                          withConfiguration:[[UIImageSymbolConfiguration configurationWithPointSize:size.height weight:UIImageSymbolWeightLight] configurationByApplyingConfiguration:[UIImageSymbolConfiguration configurationWithHierarchicalColor:[UIColor systemBlueColor]]]];
        return image;
    }];
    [nowPlayingInfo setObject:(MPMediaItemArtwork *)artwork forKey:MPMediaItemPropertyArtwork];
    
    [_nowPlayingInfoCenter = [MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:(NSDictionary<NSString *,id> * _Nullable)nowPlayingInfo];
    
    MPRemoteCommandHandlerStatus (^remote_command_handler)(MPRemoteCommandEvent * _Nonnull) = ^ MPRemoteCommandHandlerStatus (MPRemoteCommandEvent * _Nonnull event) {
        [self toggleToneGenerator:self->_play_button];
        return MPRemoteCommandHandlerStatusSuccess;
    };
    
    [[_remoteCommandCenter = [MPRemoteCommandCenter sharedCommandCenter] playCommand] addTargetWithHandler:remote_command_handler];
    [[_remoteCommandCenter stopCommand] addTargetWithHandler:remote_command_handler];
    [[_remoteCommandCenter pauseCommand] addTargetWithHandler:remote_command_handler];
    [[_remoteCommandCenter togglePlayPauseCommand] addTargetWithHandler:remote_command_handler];
    
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:UIDeviceBatteryLevelDidChangeNotification object:self];
    [self addStatusObservers];
    
    audio_engine_ref = audio_engine(audio_source(audio_renderer()));
    [audio_engine_ref startAndReturnError:nil];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [CATransaction begin];
    CGRect new_gradient_frame = CGRectMake(0.f, 0.f, size.width, size.height);
    [gradient setFrame:new_gradient_frame];
    [CATransaction commit];
}

typedef NS_ENUM(NSUInteger, HeartRateMonitorStatus) {
    HeartRateMonitorPermissionDenied,
    HeartRateMonitorPermissionGranted,
    HeartRateMonitorDataUnavailable,
    HeartRateMonitorDataAvailable
    
};

- (void)updateHeartRateMonitorStatus:(HeartRateMonitorStatus)heartRateMonitorStatus
{
    dispatch_async(dispatch_get_main_queue(), ^{
        switch (heartRateMonitorStatus) {
            case HeartRateMonitorPermissionDenied:
            {
                [self.heartRateImage setImage:[UIImage imageNamed:@"heart.fill"]];
                [self.heartRateImage setTintColor:[UIColor darkGrayColor]];
                break;
            }
                
            case HeartRateMonitorPermissionGranted:
            {
                [self.heartRateImage setImage:[UIImage imageNamed:@"heart.fill"]];
                [self.heartRateImage setTintColor:[UIColor redColor]];
                break;
            }
                
            case HeartRateMonitorDataUnavailable:
            {
                [self.heartRateImage setImage:[UIImage imageNamed:@"heart.slash"]];
                [self.heartRateImage setTintColor:[UIColor greenColor]];
                break;
            }
                
            case HeartRateMonitorDataAvailable:
            {
                [self.heartRateImage setImage:[UIImage imageNamed:@"heart.fill"]];
                [self.heartRateImage setTintColor:[UIColor greenColor]];
                break;
            }
                
            default:
                break;
        }
    });
}

//float scaleBetween(float unscaledNum, float minAllowed, float maxAllowed, float min, float max) {
//    return (maxAllowed - minAllowed) * (unscaledNum - min) / (max - min) + minAllowed;
//}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

- (void)setupDeviceMonitoring
{
    self->_device = [UIDevice currentDevice];
    [self->_device setBatteryMonitoringEnabled:TRUE];
    [self->_device setProximityMonitoringEnabled:TRUE];
}

- (void)addStatusObservers
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleInterruption:) name:AVAudioSessionInterruptionNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateDeviceStatus) name:NSProcessInfoThermalStateDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateDeviceStatus) name:UIDeviceBatteryLevelDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateDeviceStatus) name:UIDeviceBatteryStateDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateDeviceStatus) name:NSProcessInfoPowerStateDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateDeviceStatus) name:AVAudioSessionRouteChangeNotification object:nil];
//    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(toggleToneGenerator:) name:@"ToneBarrierPlayingNotification" object:nil];
    
}

static NSProcessInfoThermalState(^thermalState)(void) = ^NSProcessInfoThermalState(void)
{
    NSProcessInfoThermalState thermalState = [[NSProcessInfo processInfo] thermalState];
    return thermalState;
};

static UIDeviceBatteryState(^batteryState)(UIDevice *) = ^UIDeviceBatteryState(UIDevice * device)
{
    UIDeviceBatteryState batteryState = [device batteryState];
    return batteryState;
};

static float(^batteryLevel)(UIDevice *) = ^float(UIDevice * device)
{
    float batteryLevel = [device batteryLevel];
    return batteryLevel;
};

static bool(^powerState)(void) = ^bool(void)
{
    return [[NSProcessInfo processInfo] isLowPowerModeEnabled];
};

static bool(^audioRoute)(void) = ^bool(void)
{
    // NOT DONE
    return [[NSProcessInfo processInfo] isLowPowerModeEnabled];
};

static NSDictionary<NSString *, id> * (^deviceStatus)(UIDevice *) = ^NSDictionary<NSString *, id> * (UIDevice * device)
{
    NSDictionary<NSString *, id> * status =
    @{@"NSProcessInfoThermalStateDidChangeNotification" : @(thermalState()),
      @"UIDeviceBatteryLevelDidChangeNotification"      : @(batteryLevel(device)),
      @"UIDeviceBatteryStateDidChangeNotification"      : @(batteryState(device)),
      @"NSProcessInfoPowerStateDidChangeNotification"   : @(powerState()),
      @"AVAudioSessionRouteChangeNotification"          : @(audioRoute())};
//      @"ToneBarrierPlayingNotification"                 : @([ToneGenerator.sharedGenerator.audioEngine isRunning])};
    
    return status;
};

- (void)updateDeviceStatus
{
    dispatch_async(dispatch_get_main_queue(), ^{
        switch (thermalState()) {
            case NSProcessInfoThermalStateNominal:
            {
                [self.thermometerImageView setTintColor:[UIColor greenColor]];
                break;
            }
                
            case NSProcessInfoThermalStateFair:
            {
                [self.thermometerImageView setTintColor:[UIColor yellowColor]];
                break;
            }
                
            case NSProcessInfoThermalStateSerious:
            {
                [self.thermometerImageView setTintColor:[UIColor redColor]];
                break;
            }
                
            case NSProcessInfoThermalStateCritical:
            {
                [self.thermometerImageView setTintColor:[UIColor whiteColor]];
                break;
            }
                
            default:
            {
                [self.thermometerImageView setTintColor:[UIColor grayColor]];
            }
                break;
        }
        
        switch (batteryState(self->_device)) {
            case UIDeviceBatteryStateUnknown:
            {
                [self.batteryImageView setImage:[UIImage systemImageNamed:@"bolt.slash"]];
                [self.batteryImageView setTintColor:[UIColor grayColor]];
                break;
            }
                
            case UIDeviceBatteryStateUnplugged:
            {
                [self.batteryImageView setImage:[UIImage systemImageNamed:@"bolt.slash.fill"]];
                [self.batteryImageView setTintColor:[UIColor redColor]];
                break;
            }
                
            case UIDeviceBatteryStateCharging:
            {
                [self.batteryImageView setImage:[UIImage systemImageNamed:@"bolt"]];
                [self.batteryImageView setTintColor:[UIColor greenColor]];
                break;
            }
                
            case UIDeviceBatteryStateFull:
            {
                [self.batteryImageView setImage:[UIImage systemImageNamed:@"bolt.fill"]];
                [self.batteryImageView setTintColor:[UIColor greenColor]];
                break;
            }
                
            default:
            {
                [self.batteryImageView setImage:[UIImage systemImageNamed:@"bolt.slash"]];
                [self.batteryImageView setTintColor:[UIColor grayColor]];
                break;
            }
        }
        
        float level = batteryLevel(self->_device);
        if (level <= 1.0 || level > .66)
        {
            [self.batteryLevelImageView setImage:[UIImage systemImageNamed:@"battery.100"]];
            [self.batteryLevelImageView setTintColor:[UIColor greenColor]];
        } else
            if (level <= .66 || level > .33)
            {
                [self.batteryLevelImageView setImage:[UIImage systemImageNamed:@"battery.25"]];
                [self.batteryLevelImageView setTintColor:[UIColor yellowColor]];
            } else
                if (level <= .33)
                {
                    [self.batteryLevelImageView setImage:[UIImage systemImageNamed:@"battery.0"]];
                    [self.batteryLevelImageView setTintColor:[UIColor redColor]];
                } else
                    if (level <= .125)
                    {
                        [self.batteryLevelImageView setImage:[UIImage systemImageNamed:@"battery.0"]];
                        [self.batteryLevelImageView setTintColor:[UIColor redColor]];
                        //                        [ToneGenerator.sharedGenerator alarm];
                    }
    });
}

- (IBAction)toggleToneGenerator:(UIButton *)sender
{
    [sender setSelected:^ BOOL { return ((![ToneGenerator.sharedGenerator.audioEngine isRunning] && [ToneGenerator.sharedGenerator start]) || [ToneGenerator.sharedGenerator stop]); }()];
//    printf("condition == %s\n", (condition_test()) ? "TRUE" : "FALSE");
}

- (void)handleInterruption:(NSNotification *)notification
{
    _wasPlaying = ([ToneGenerator.sharedGenerator.audioEngine isRunning])
    ? TRUE : FALSE;
    
    NSDictionary *userInfo = [notification userInfo];
    
    if ([ToneGenerator.sharedGenerator.audioEngine isRunning])
    {
        NSInteger typeValue = [[userInfo objectForKey:AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
        AVAudioSessionInterruptionType type = (AVAudioSessionInterruptionType)typeValue;
        if (type)
        {
            if (type == AVAudioSessionInterruptionTypeBegan)
            {
                if (_wasPlaying)
                {
                    [ToneGenerator.sharedGenerator stop];
                    [self.play_button setImage:[UIImage systemImageNamed:@"pause"] forState:UIControlStateNormal];
                }
            } else if (type == AVAudioSessionInterruptionTypeEnded)
            {
//                NSInteger optionsValue = [[userInfo objectForKey:AVAudioSessionInterruptionOptionKey] unsignedIntegerValue];
//                AVAudioSessionInterruptionOptions options = (AVAudioSessionInterruptionOptions)optionsValue;
//                if (options == AVAudioSessionInterruptionOptionShouldResume)
//                {
                if (_wasPlaying)
                {
                    [ToneGenerator.sharedGenerator start];
                    [self.play_button setImage:[UIImage systemImageNamed:@"play"] forState:UIControlStateNormal];
                }
//                }
            }
        }
    }
    
   
    [self updateDeviceStatus];
}

@end











