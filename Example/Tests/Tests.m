//
//  analytics-ios-mcvidTests.m
//  analytics-ios-mcvidTests
//
//  Created by Brie on 04/08/2019.
//  Copyright (c) 2019 Brie. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Specta/Specta.h>
#import "Expecta.h"
#import "SEGMCVIDTracker.h"
#import <Analytics/SEGAnalytics.h>
#import "SEGAppDelegate.h"
#import "SEGPayload.h"

// https://github.com/Specta/Specta
@interface SEGMCVIDTracker (Testing)

- (NSURL * _Nonnull)createURL:callType integrationCode:(NSString * _Nonnull)integrationCode;
- (NSMutableDictionary * _Nonnull)buildIntegrationsObject:(SEGPayload *_Nonnull)payload;
@property(nonatomic, nonnull) NSString *cachedMarketingCloudId;
@property(nonatomic, nonnull) NSString *cachedAdvertisingId;
@property(nonatomic) NSUInteger currentRetryCount;


@end

SpecBegin(SEGMCVIDTracker)

describe(@"SEGMCVID", ^{
    __block NSString *organizationId;
    __block NSString *region;
    __block SEGAnalyticsConfiguration *configuration;
    __block SEGMCVIDTracker *instance;
    
    beforeEach(^{
        configuration =  [SEGAnalyticsConfiguration configurationWithWriteKey:@"some_write_key"];
        organizationId = @"B3CB46FC57C6C8F77F000101@AdobeOrg";
        region = @"6";
        configuration.middlewares = @[[[SEGMCVIDTracker alloc] initWithOrganizationId:organizationId region:region]];
        configuration.trackApplicationLifecycleEvents = YES;
        [SEGAnalytics setupWithConfiguration:configuration];
        instance = [[SEGMCVIDTracker alloc] initWithOrganizationId:organizationId region:region];
        
    });
    
    it(@"should properly update the cachedAdvertisingId", ^{
        NSString *cachedAdvertisingId = instance.cachedAdvertisingId;
        expect(cachedAdvertisingId).willNot.beNil();
    });
    
    it(@"should properly store the cachedAdvertisingId in NSUserDefaults", ^{
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *storedAdvertisingId = [defaults stringForKey:@"com.segment.mcvid.advertisingId"];
        expect(storedAdvertisingId).willNot.beNil();
    });
    
    it(@"can make basic identify calls", ^{
        [[SEGAnalytics sharedAnalytics] identify:@"user12345"
                                          traits:@{ @"email": @"test@test.com" }];
    });
    
    it(@"can make basic track calls", ^{
        [[SEGAnalytics sharedAnalytics] track:@"Item Purchased"
                                   properties:@{ @"item": @"Sword of Heracles", @"revenue": @2.95 }];
    });
    
    it(@"can make track calls with integration options", ^{
        [[SEGAnalytics sharedAnalytics] track:@"Product Rated"
                                   properties:nil
                                      options:@{ @"integrations": @{ @"All": @YES, @"Mixpanel": @NO }}];
    });
    
    it(@"can properly append marketingCloudId to track calls pre-existing AA integration options", ^{
        [[SEGAnalytics sharedAnalytics] track:@"Product Removed"
                                   properties:nil
                                      options:@{ @"integrations": @{ @"All": @YES, @"Mixpanel": @NO, @"Adobe Analytics":@{ @"prop1":@"Hello World"} }}];
    });
    
});

describe(@"createURL function", ^{
    __block NSString *organizationId;
    __block NSString *region;
    __block SEGAnalyticsConfiguration *configuration;
    __block SEGMCVIDTracker *instance;
    
    beforeEach(^{
        configuration =  [SEGAnalyticsConfiguration configurationWithWriteKey:@"some_write_key"];
        organizationId = @"B3CB46FC57C6C8F77F000101@AdobeOrg";
        region = @"6";
        configuration.middlewares = @[[[SEGMCVIDTracker alloc] initWithOrganizationId:organizationId region:region]];
        configuration.trackApplicationLifecycleEvents = YES;
        [SEGAnalytics setupWithConfiguration:configuration];
        instance = [[SEGMCVIDTracker alloc] initWithOrganizationId:organizationId region:region];
        
    });

    it(@"can properly create the synIntegrationCode url", ^{
        NSString const *syncIntegrationCallType = @"syncIntegrationCode";
        NSURL *url = [instance createURL:syncIntegrationCallType integrationCode:@"DSID_20915"];
        NSString *urlString = url.absoluteString;
        NSString *expected = [NSString stringWithFormat:@"%@%@", @"01", instance.cachedAdvertisingId];
        NSString *actual = [[urlString componentsSeparatedByString:@"%"] objectAtIndex:1];
        
        expect(actual).to.equal(expected);
    });

    it(@"can properly create the getMarketingCloudId url", ^{
        NSString const *getCloudIdCallType = @"getMarketingCloudID";
        NSURL *url = [instance createURL:getCloudIdCallType integrationCode:@"DSID_20915"];
        NSString *urlString = url.absoluteString;
        
        NSString *expected = @"https://dpm.demdex.net/id?d_ver=2&d_rtbd=json&dcs_region=6&d_orgid=B3CB46FC57C6C8F77F000101@AdobeOrg";
        expect(urlString).to.equal(expected);
    });
});

describe(@"buildIntegrationObject Function", ^{
    __block NSString *organizationId;
    __block NSString *region;
    __block SEGAnalyticsConfiguration *configuration;
    __block SEGMCVIDTracker *instance;


    beforeAll(^{
        configuration =  [SEGAnalyticsConfiguration configurationWithWriteKey:@"some_write_key"];
        organizationId = @"B3CB46FC57C6C8F77F000101@AdobeOrg";
        region = @"6";
        configuration.middlewares = @[[[SEGMCVIDTracker alloc] initWithOrganizationId:organizationId region:region]];
        configuration.trackApplicationLifecycleEvents = YES;
        [SEGAnalytics setupWithConfiguration:configuration];
        instance = [[SEGMCVIDTracker alloc] initWithOrganizationId:organizationId region:region];
        instance.cachedMarketingCloudId = @"12345678910";
    });

    it(@"properly updates an empty integrations object with the marketingCloudId", ^{
        NSDictionary *context = [[NSDictionary alloc] initWithObjectsAndKeys:
                                 @"Item Purchased", @"event", @{ @"item": @"Sword of Heracles", @"revenue": @2.95 }, @"properties", nil];
        NSDictionary *exisintgIntegrations = [NSDictionary new];
        SEGPayload *payload = [[SEGPayload alloc] initWithContext:context integrations:exisintgIntegrations];
        NSMutableDictionary *integrations = [instance buildIntegrationsObject:payload];
        NSString *marketingCloudId = integrations[@"Adobe Analytics"][@"marketingCloudVisitorId"];
        expect(marketingCloudId).to.equal(instance.cachedMarketingCloudId);
    });

    it(@"updates an empty integrations object with one k/v pair", ^{
        NSDictionary *context = [[NSDictionary alloc] initWithObjectsAndKeys:
                                 @"Item Purchased", @"event", @{ @"item": @"Sword of Heracles", @"revenue": @2.95 }, @"properties", nil];
        NSDictionary *exisintgIntegrations = [NSDictionary new];
        SEGPayload *payload = [[SEGPayload alloc] initWithContext:context integrations:exisintgIntegrations];
        NSMutableDictionary *integrations = [instance buildIntegrationsObject:payload];
        NSInteger count = [integrations count];
        expect(count).to.equal(1);
    });

    it(@"properly updates an integrations object with other integration specific options with the marketingCloudId", ^{
        NSDictionary *context = [[NSDictionary alloc] initWithObjectsAndKeys:
                                 @"Item Purchased", @"event", @{ @"item": @"Sword of Heracles", @"revenue": @2.95 }, @"properties", nil];
        NSDictionary *exisintgIntegrations = [[NSDictionary alloc] initWithObjectsAndKeys: @NO, @"Mixpanel", nil];
        SEGPayload *payload = [[SEGPayload alloc] initWithContext:context integrations:exisintgIntegrations];
        NSMutableDictionary *integrations = [instance buildIntegrationsObject:payload];
        NSString *marketingCloudId = integrations[@"Adobe Analytics"][@"marketingCloudVisitorId"];
        expect(marketingCloudId).to.equal(instance.cachedMarketingCloudId);
    });

    it(@"properly updates an integrations object with other integration specific options with the marketingCloudId", ^{
        NSDictionary *context = [[NSDictionary alloc] initWithObjectsAndKeys:
                                 @"Item Purchased", @"event", @{ @"item": @"Sword of Heracles", @"revenue": @2.95 }, @"properties", nil];
        NSDictionary *exisintgIntegrations = [[NSDictionary alloc] initWithObjectsAndKeys: @NO, @"Mixpanel", nil];
        SEGPayload *payload = [[SEGPayload alloc] initWithContext:context integrations:exisintgIntegrations];
        NSMutableDictionary *integrations = [instance buildIntegrationsObject:payload];
        NSInteger count = [integrations count];
        expect(count).to.equal(2);
    });

    it(@"properly updates the AA integrations object with the marketingCloudId without overriding existing options", ^{
        NSDictionary *context = [[NSDictionary alloc] initWithObjectsAndKeys:
                                 @"Item Purchased", @"event", @{ @"item": @"Sword of Heracles", @"revenue": @2.95 }, @"properties", nil];
        NSDictionary *exisintgIntegrations = [[NSDictionary alloc] initWithObjectsAndKeys: @NO, @"Mixpanel", @{ @"prop1": @"hello world"}, @"Adobe Analytics", nil];
        SEGPayload *payload = [[SEGPayload alloc] initWithContext:context integrations:exisintgIntegrations];
        NSMutableDictionary *integrations = [instance buildIntegrationsObject:payload];
        NSString *marketingCloudId = integrations[@"Adobe Analytics"][@"marketingCloudVisitorId"];
        expect(marketingCloudId).to.equal(instance.cachedMarketingCloudId);
    });

    it(@"properly updates the AA integrations object with the marketingCloudId without overriding existing options", ^{
        NSDictionary *context = [[NSDictionary alloc] initWithObjectsAndKeys:
                                 @"Item Purchased", @"event", @{ @"item": @"Sword of Heracles", @"revenue": @2.95 }, @"properties", nil];
        NSDictionary *exisintgIntegrations = [[NSDictionary alloc] initWithObjectsAndKeys: @NO, @"Mixpanel", @{ @"prop1": @"hello world"}, @"Adobe Analytics", nil];
        SEGPayload *payload = [[SEGPayload alloc] initWithContext:context integrations:exisintgIntegrations];
        NSMutableDictionary *integrations = [instance buildIntegrationsObject:payload];
        NSInteger count = [integrations count];
        expect(count).to.equal(2);
    });
});
SpecEnd
