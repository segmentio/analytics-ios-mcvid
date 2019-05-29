//
//  SEGAppDelegate.m
//  analytics-ios-mcvid
//
//  Created by Brie on 04/08/2019.
//  Copyright (c) 2019 Brie. All rights reserved.
//

#import "SEGAppDelegate.h"
#import <Analytics/SEGAnalytics.h>
#import <analytics-ios-mcvid/SEGMCVIDTracker.h>

@implementation SEGAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Initialize the analytics client as you would normally.
    // https://segment.com/segment-mobile/sources/ios/settings/keys
    SEGAnalyticsConfiguration *configuration = [SEGAnalyticsConfiguration configurationWithWriteKey:@"YOUR_WRITE_KEY"];

    // Configure the client with the MCVID middleware. Intiliaze with your Adobe OrgId and Adobe Region (ie. dcs_region key)
    configuration.middlewares = @[ [[SEGMCVIDTracker alloc]  initWithOrganizationId:@"YOUR_ADOBE_ORGID@AdobeOrg" region:@"YOUR_REGION_HERE"] ];
    configuration.trackApplicationLifecycleEvents = YES; // Enable this to record certain application events automatically!
    configuration.recordScreenViews = YES; // Enable this to record screen views automatically!
    configuration.flushAt = 1; // Flush events to Segment every 1 event
    [SEGAnalytics setupWithConfiguration:configuration];
    [SEGAnalytics debug:YES];
    // Override point for customization after application launch.
    [[SEGAnalytics sharedAnalytics] identify:@"user12345"
                               traits:@{ @"email": @"test@test.com" }];

   [[SEGAnalytics sharedAnalytics] track:@"Item Purchased"
                              properties:@{ @"item": @"Sword of Heracles", @"revenue": @2.95 }];

    [[SEGAnalytics sharedAnalytics] identify:@"Testing Adobe Analytics"];

    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
