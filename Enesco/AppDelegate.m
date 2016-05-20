//
//  AppDelegate.m
//  Enesco
//
//  Created by Aufree on 11/30/15.
//  Copyright © 2015 The EST Group. All rights reserved.
//

#import "AppDelegate.h"
#import "MusicListViewController.h"
#import <MediaPlayer/MediaPlayer.h>
#import "MusicViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "MBProgressHUD.h"

@interface AppDelegate ()
@property (nonatomic, strong) MusicListViewController *musicListVC;
@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    // Showing the App
    [self makeWindowVisible:launchOptions];
    
    // Basic setup
    [self basicSetup];
    
    return YES;
}

- (void)makeWindowVisible:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor whiteColor];
    
    [[UINavigationBar appearance] setBarTintColor:[UIColor whiteColor]];
    
    if (!_musicListVC){
        _musicListVC = [[UIStoryboard storyboardWithName:@"MusicList" bundle:[NSBundle mainBundle]] instantiateInitialViewController];
    }
    self.window.rootViewController = _musicListVC;
    
    [self.window makeKeyAndVisible];
}


- (void)basicSetup {
    // Remove control
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    [self becomeFirstResponder];
}

- (BOOL)canBecomeFirstResponder {
    return YES;
}

# pragma mark - Remote control

- (void)remoteControlReceivedWithEvent:(UIEvent *)receivedEvent {
    if (receivedEvent.type == UIEventTypeRemoteControl) {
        switch (receivedEvent.subtype) {
            case UIEventSubtypeRemoteControlPause:
                [[MusicViewController sharedInstance].streamer pause];
                break;
            case UIEventSubtypeRemoteControlStop:
                break;
            case UIEventSubtypeRemoteControlPlay:
                [[MusicViewController sharedInstance].streamer play];
                break;
            case UIEventSubtypeRemoteControlTogglePlayPause:
                break;
            case UIEventSubtypeRemoteControlNextTrack:
                [[MusicViewController sharedInstance] playNextMusic:nil];
                break;
            case UIEventSubtypeRemoteControlPreviousTrack:
                [[MusicViewController sharedInstance] playPreviousMusic:nil];
                break;
            default:
                break;
        }
    }
}


#if __IPHONE_OS_VERSION_MAX_ALLOWED < __IPHONE_9_0
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(nullable NSString *)sourceApplication annotation:(id)annotation
{
    NSString *fileName = [[url absoluteString] lastPathComponent];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *desMusicPath = [documentsPath stringByAppendingPathComponent:fileName];
    NSURL *desUrl = [NSURL fileURLWithPath:desMusicPath];
    
    NSError *error;
    if (![fileManager moveItemAtURL:url toURL:desUrl error:&error]) {
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.window animated:YES];
        [hud hideAnimated:YES afterDelay:0.5];
    }
    
    return YES;
}
#else
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url options:(nonnull NSDictionary<NSString *,id> *)options
{
//    UINavigationController *navigation = (UINavigationController *)application.keyWindow.rootViewController;
//    ViewController *displayController = (ViewController *)navigation.topViewController;
//    
//    [displayController.imageView setImage:[UIImage imageWithData:[NSData dataWithContentsOfURL:url]]];
//    [displayController.label setText:[options objectForKey:UIApplicationOpenURLOptionsSourceApplicationKey]];
    
    NSString *fileName = [[url absoluteString] lastPathComponent];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *desMusicPath = [documentsPath stringByAppendingPathComponent:fileName];
    NSURL *desUrl = [NSURL fileURLWithPath:desMusicPath];
    
    NSError *error;
    if (![fileManager moveItemAtURL:url toURL:desUrl error:&error]) {
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.window animated:YES];
        hud.label.text = @"copy失败!";
        [hud hideAnimated:YES afterDelay:0.5];
    }
    else
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"reloadLocalFiles" object:nil userInfo:nil];
    }
    
    return YES;
}
#endif

@end
