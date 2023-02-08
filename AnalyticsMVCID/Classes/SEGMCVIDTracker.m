#import "SEGMCVIDTracker.h"

#if defined(__has_include) && __has_include(<Analytics/SEGAnalytics.h>)
#import <Analytics/SEGAnalyticsUtils.h>
#import <Analytics/SEGState.h>
#import <Analytics/SEGAnalyticsConfiguration.h>
#elif SWIFT_PACKAGE
@import Segment;
#else
#import <Segment/SEGAnalyticsUtils.h>
#import <Segment/SEGState.h>
#import <Segment/SEGAnalyticsConfiguration.h>
#endif


#import <AdSupport/ASIdentifierManager.h>

#include <time.h>
#include <stdlib.h>
#include <math.h>

NSString *const MCVIDAdobeErrorKey = @"MCVIDAdobeErrorKey";
NSString *const cachedMarketingCloudIdKey = @"com.segment.mcvid.marketingCloudId";
NSString *const cachedAdvertisingIdKey = @"com.segment.mcvid.advertisingId";

// Request values taken from https://docs.adobe.com/content/help/en/audience-manager/user-guide/reference/visitor-authentication-states.html
NSString * MCVIDAuthStateRequestValue(MCVIDAuthState state) {
    switch (state) {
        case MCVIDAuthStateUnknown:
            return @"0";
            break;
        case MCVIDAuthStateAuthenticated:
            return @"1";
            break;
        case MCVIDAuthStateLoggedOut:
            return @"2";
            break;
    }
}

@interface MCVIDAdobeError ()

- (id)initWithCode:(MCVIDAdobeErrorCode)code message:(NSString *)message error:(NSError *)error;

@end

@implementation MCVIDAdobeError
- (id)initWithCode:(MCVIDAdobeErrorCode)code message:(NSString * _Nullable)message error:(NSError * _Nullable)error {
   self = [super  init];
   if (self) {
     _code = code;
     _message = message;
     _innerError = error;
   }
   return self;
}
@end

@interface SEGMCVIDTracker()
    @property(nonatomic) NSUInteger maxRetryCount;
    @property(nonatomic) NSUInteger currentRetryCount;
    @property(nonatomic, nonnull) NSString *cachedMarketingCloudId;
    @property(nonatomic, nonnull) NSString *cachedAdvertisingId;
    @property dispatch_queue_t _Nonnull backgroundQueue;
    @property(nonatomic, assign) MCVIDGenerationMode mcvidGenerationMode;
@end

@implementation SEGMCVIDTracker

+ (NSString *_Nullable)getCachedMarketingId{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [defaults stringForKey:cachedMarketingCloudIdKey];
}

- (id)initWithOrganizationId:(NSString *_Nonnull)organizationId region:(NSString *_Nonnull)region {
    return [self initWithOrganizationId:organizationId region:region advertisingIdProvider:nil mcvidGenerationMode: MCVIDGenerationModeRemote];
}

- (instancetype _Nonnull)initWithOrganizationId:(NSString *_Nonnull)organizationId region:(NSString *_Nonnull)region advertisingIdProvider:(SEGAdSupportBlock _Nullable)advertisingIdProvider {
    return [self initWithOrganizationId:organizationId region:region advertisingIdProvider:advertisingIdProvider mcvidGenerationMode: MCVIDGenerationModeRemote];
}
- (instancetype _Nonnull)initWithOrganizationId:(NSString *_Nonnull)organizationId region:(NSString *_Nonnull)region mcvidGenerationMode:(MCVIDGenerationMode)mcvidGenerationMode {
    return [self initWithOrganizationId:organizationId region:region advertisingIdProvider:nil mcvidGenerationMode:mcvidGenerationMode];
}

- (instancetype _Nonnull)initWithOrganizationId:(NSString *_Nonnull)organizationId region:(NSString *_Nonnull)region advertisingIdProvider:(SEGAdSupportBlock _Nullable)advertisingIdProvider mcvidGenerationMode:(MCVIDGenerationMode)mcvidGenerationMode {
    if ((self = [super init]))
    {
        self.organizationId = organizationId;
        self.region = region;
        self.mcvidGenerationMode = mcvidGenerationMode;
    }

    //Values for exponential backoff retry logic for API calls
    _maxRetryCount = 11;
    _currentRetryCount = 1;
    self.backgroundQueue = dispatch_queue_create("com.segment.mcvid", NULL);

    //Store advertisingId and marketingCloudId on local storage
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    NSString *advertisingId = nil;
    if (advertisingIdProvider != nil) {
        advertisingId = advertisingIdProvider();
    }
    _cachedAdvertisingId = [defaults stringForKey:cachedAdvertisingIdKey];
    if (_cachedAdvertisingId == NULL && advertisingId != nil) {
        [defaults setObject:advertisingId forKey:cachedAdvertisingIdKey];
        _cachedAdvertisingId = advertisingId;
    }

    _cachedMarketingCloudId = [defaults stringForKey:cachedMarketingCloudIdKey];
    [self generateMCVIDAndSync:advertisingId];
    return self;
}

- (void)generateMCVIDAndSync:(NSString *)advertisingId {
    if (self.cachedMarketingCloudId.length == 0) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        if (self.mcvidGenerationMode == MCVIDGenerationModeLocal) {
            NSString *mcvid = [self generateMCVID];
            [defaults setObject:mcvid forKey:cachedMarketingCloudIdKey];
            self.cachedMarketingCloudId = mcvid;
            if (advertisingId != nil) {
                [self syncAdvertisingIdentifier];
            }
        } else {
            [self getMarketingCloudId:self.organizationId completion:^(NSString * _Nullable marketingCloudId, NSError * _Nullable error) {
                [defaults setObject:marketingCloudId forKey:cachedMarketingCloudIdKey];
                self.cachedMarketingCloudId = marketingCloudId;
                if (advertisingId != nil) {
                    [self syncAdvertisingIdentifier];
                }
            }];
        }
    } else if (_cachedAdvertisingId != NULL &&
               advertisingId != nil &&
               ![_cachedAdvertisingId isEqualToString:advertisingId]) {
        [self syncAdvertisingIdentifier];
    }
}

- (void)syncAdvertisingIdentifier {
    //Default value for integration code which indicate ios
    NSString *integrationCode = @"DSID_20915";

    if (self.cachedAdvertisingId.length == 0) {
        return;
    }
    [self syncIntegrationCode:integrationCode userIdentifier:self.cachedAdvertisingId completion:^(NSError *error) {
        if (error) {
            return;
        }
    }];
}

- (void)getMarketingCloudId:(NSString *_Nonnull)organizationId completion:(void (^)(NSString * _Nullable marketingCloudId, NSError *_Nullable))completion {

    //Response and error handling variables
    NSString *errorResponseKey = @"errors";
    NSString *errorDomain = @"Segment-Adobe";
    NSString *marketingCloudIdKey = @"d_mid";

    NSURL *url = [self createURLWithAdditionalQueryItems:nil];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];

    [[session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        void (^callbackWithCode)(MCVIDAdobeErrorCode code, NSString *message, NSError *error) = ^void(MCVIDAdobeErrorCode code, NSString *message, NSError *error) {
            MCVIDAdobeError *adobeError = [[MCVIDAdobeError alloc] initWithCode:code message:message error:error];
            NSError *compositeError = [NSError errorWithDomain:errorDomain code:adobeError.code userInfo:@{MCVIDAdobeErrorKey:adobeError}];
            completion(nil, compositeError);
        };

        NSDictionary *dictionary = nil;
        @try {
            dictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        } @catch (NSException *exception) {
            return callbackWithCode(MCVIDAdobeErrorCodeClientSerializationError, @"Deserializing the JSON response failed", nil);
        }

        NSString *marketingCloudId = dictionary[marketingCloudIdKey];


        // or { ..., "errors": [{ "code": 2, "msg": "error" } ... ], ... }
        NSError *errorObject = dictionary[errorResponseKey][0];
        NSString *errorMessage = dictionary[@"errors"][0][@"msg"];

        NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
        NSInteger responseStatusCode = [httpResponse statusCode];

        //Logic for exponential backoff algorithm
        NSUInteger secondsToWait = pow(2, self.currentRetryCount);

        if ((self.currentRetryCount > self.maxRetryCount) && errorObject) {
            return callbackWithCode(MCVIDAdobeErrorCodeServerError, errorMessage, errorObject);
        }

        if (responseStatusCode == 200 && (!errorObject) ){
            self.currentRetryCount = 0;
            completion(marketingCloudId, nil);
        } else {
            dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * secondsToWait);
            dispatch_after(delay, self.backgroundQueue, ^(void){
                self.currentRetryCount = self.currentRetryCount + 1;
                [self getMarketingCloudId:organizationId completion:completion];
            });
        }
    }] resume];
}

- (void)setAdvertisingIdProvider:(SEGAdSupportBlock _Nullable)advertisingIdProvider {
    NSString *advertisingId = advertisingIdProvider();
    if (_cachedAdvertisingId == NULL) {
        _cachedAdvertisingId = advertisingId;
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:advertisingId forKey:cachedAdvertisingIdKey];
        [self syncAdvertisingIdentifier];
    }
}

- (void)syncIntegrationCode:(NSString * _Nonnull)integrationCode userIdentifier:(NSString * _Nonnull)userIdentifier completion:(void (^)(NSError * _Nullable))completion {
    // According to Adobe, Unknown is applied by default when AuthState is not used with a visitor ID or not explicitly set on each page or app context.
    [self syncIntegrationCode:integrationCode userIdentifier:userIdentifier authentication:MCVIDAuthStateUnknown completion:completion];
}

- (void)syncIntegrationCode:(NSString *_Nonnull)integrationCode userIdentifier:(NSString *_Nonnull)userIdentifier authentication:(MCVIDAuthState)state completion:(void (^_Nonnull)(NSError *_Nullable))completion {
    //Response and error handling variables
    NSString *errorResponseKey = @"errors";
    NSString *errorDomain = @"Segment-Adobe";

    // We cannot perform an idsync if we don't have a MCVID.
    if (self.cachedMarketingCloudId.length == 0) {
        NSString *message = @"A MCVID is not yet available. Please, retry the operation later.";
        MCVIDAdobeError *adobeError = [[MCVIDAdobeError alloc] initWithCode:MCVIDAdobeErrorCodeUnavailable message:message error:nil];
        NSError *compositeError = [NSError errorWithDomain:errorDomain code:adobeError.code userInfo:@{MCVIDAdobeErrorKey:adobeError}];
        completion(compositeError);
        return;
    }

    NSArray<NSURLQueryItem *>* syncQueryItems = [self URLQueryItemsForIntegrationCode:integrationCode userIdentifier:userIdentifier authentication:state];
    NSURL *url = [self createURLWithAdditionalQueryItems:syncQueryItems];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];

    [[session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        void (^callbackWithCode)(MCVIDAdobeErrorCode code, NSString *message, NSError *error) = ^void(MCVIDAdobeErrorCode code, NSString *message, NSError *error) {
            MCVIDAdobeError *adobeError = [[MCVIDAdobeError alloc] initWithCode:code message:message error:error];
            NSError *compositeError = [NSError errorWithDomain:errorDomain code:adobeError.code userInfo:@{MCVIDAdobeErrorKey:adobeError}];
            completion(compositeError);
        };


        NSDictionary *dictionary = nil;
        @try {
            dictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        } @catch (NSException *exception) {
            return callbackWithCode(MCVIDAdobeErrorCodeClientSerializationError, @"Deserializing the JSON response failed", nil);
        }

        // or { ..., "errors": [{ "code": 2, "msg": "error" } ... ], ... }
        NSError *errorObject = dictionary[errorResponseKey][0];
        NSString *errorMessage = dictionary[@"errors"][0][@"msg"];


        NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
        NSInteger responseStatusCode = [httpResponse statusCode];
        NSUInteger secondsToWait = pow(2, self.currentRetryCount);

        if ((self.currentRetryCount > self.maxRetryCount) && (errorObject)) {
            return callbackWithCode(MCVIDAdobeErrorCodeServerError, errorMessage, errorObject);
        }

        if ((responseStatusCode == 200) && (!errorObject)){
            self.currentRetryCount = 0;
            completion(nil);
        } else {
            dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * secondsToWait);
            dispatch_after(delay, self.backgroundQueue, ^(void){
                self.currentRetryCount = self.currentRetryCount + 1;
                [self syncIntegrationCode:integrationCode userIdentifier:self.cachedAdvertisingId completion:completion];
            });
        }
    }] resume];
}

- (NSURL * _Nonnull)createURLWithAdditionalQueryItems:(NSArray<NSURLQueryItem *>* _Nullable)extraQueryItems {
    //Variables to build URL for GET request
    NSString *protocol = @"https";
    NSString *host = @"dpm.demdex.net";
    NSString *path = @"/id?";

    //Defaulted values for request
    NSString *versionKey = @"d_ver"; //d_ver defaults to 2
    NSString *version = @"2"; //d_ver defaults to 2
    NSString *jsonFormatterKey = @"d_rtbd";//&d_rtbd and defaults to = json
    NSString *jsonFormatter = @"json";//&d_rtbd and defaults to = json
    NSString *regionKey = @"dcs_region"; //dcs_region key defaults to = 6
    NSString *region = _region; //dcs_region
    NSString *organizationIdKey = @"d_orgid"; //can retrieve from settings

    //Values to build URl components and query items
    NSMutableString *urlString = [NSMutableString stringWithFormat:@"%@://%@%@", protocol, host, path];
    NSURLComponents *components = [NSURLComponents componentsWithString:urlString];
    NSMutableArray *queryItems = [NSMutableArray array];

    [queryItems addObject:[NSURLQueryItem queryItemWithName:versionKey value:version]];
    [queryItems addObject:[NSURLQueryItem queryItemWithName:jsonFormatterKey value:jsonFormatter]];
    [queryItems addObject:[NSURLQueryItem queryItemWithName:regionKey value:region]];
    [queryItems addObject:[NSURLQueryItem queryItemWithName:organizationIdKey value:self.organizationId]];

    if (extraQueryItems.count > 0) {
        [queryItems addObjectsFromArray:extraQueryItems];
    }
    components.queryItems = queryItems;
    NSURL *url = components.URL;

    return url;
}

- (NSArray<NSURLQueryItem *>* _Nonnull)URLQueryItemsForIntegrationCode:(NSString * _Nonnull)integrationCode userIdentifier:(NSString* _Nonnull)userIdentifier authentication:(MCVIDAuthState)state {
    NSString *marketingCloudIdKey = @"d_mid";
    NSString *advertisingIdKey = @"d_cid_ic";
    NSString *separator = @"%01";

    NSMutableArray *queryItems = [NSMutableArray array];

    // d_mid=<marketing_cloud_visitor_id>
    [queryItems addObject:[NSURLQueryItem queryItemWithName:marketingCloudIdKey value:self.cachedMarketingCloudId]];

    // d_cid_ic=<integration_code>%01<user_identifier>
    NSString *encodedAdvertisingValue = [NSString stringWithFormat:@"%@%@%@%@%@", integrationCode, separator, userIdentifier, separator, MCVIDAuthStateRequestValue(state)];
    //removes %25 html encoding of '%'
    NSString *normalAdvertisingValue = [encodedAdvertisingValue stringByRemovingPercentEncoding];
    [queryItems addObject:[NSURLQueryItem queryItemWithName:advertisingIdKey value:normalAdvertisingValue]];

    return queryItems;
}

- (NSMutableDictionary * _Nonnull)buildIntegrationsObject:(SEGPayload *_Nonnull)payload {
    NSMutableDictionary *integrations = [NSMutableDictionary new];

    NSMutableDictionary *adobeOptions = [payload.integrations[@"Adobe Analytics"] mutableCopy];
    if (!adobeOptions) {
        adobeOptions = [NSMutableDictionary new];
    }
    [adobeOptions setObject:self.cachedMarketingCloudId forKey:@"marketingCloudVisitorId"];

    if (payload.integrations != nil) {
        NSMutableDictionary *existingIntegrations = [payload.integrations mutableCopy];
        [existingIntegrations removeObjectForKey:@"AdobeAnalytics"];
        [integrations addEntriesFromDictionary:existingIntegrations];
    }
    [integrations setObject:adobeOptions forKey:@"Adobe Analytics"];

    return integrations;
}


- (void)context:(SEGContext *_Nonnull)context next:(SEGMiddlewareNext _Nonnull)next {
    // If we still don't have a marketing cloud visitor ID we can't inject it
    if (self.cachedMarketingCloudId.length == 0) {
        next(context);
        return;
    }

    SEGContext *updatedContext = context;

    if ([context.payload isKindOfClass:[SEGTrackPayload class]]) {
        SEGTrackPayload *track = (SEGTrackPayload *)context.payload;
        NSMutableDictionary *integrations = [self buildIntegrationsObject:track];

        SEGContext *newTrackContext = [context modify:^(id<SEGMutableContext> _Nonnull ctx) {
          ctx.payload = [[SEGTrackPayload alloc] initWithEvent:track.event
                                                    properties:track.properties
                                                    context:track.context
                                                    integrations: integrations];
                                                  }];
        updatedContext = newTrackContext;
    }
    
    if ([context.payload isKindOfClass:[SEGIdentifyPayload class]]){
        SEGIdentifyPayload *identify= (SEGIdentifyPayload *)context.payload;
        NSMutableDictionary *integrations = [self buildIntegrationsObject:identify];
        
        SEGContext *newIdentifyContext = [context modify:^(id<SEGMutableContext> _Nonnull ctx) {
            ctx.payload = [[SEGIdentifyPayload alloc] initWithUserId:identify.userId
                                                         anonymousId:identify.anonymousId
                                                              traits: identify.traits
                                                             context:identify.context
                                                        integrations: integrations];
        }];
        
        updatedContext = newIdentifyContext;
    }

    if ([context.payload isKindOfClass:[SEGScreenPayload class]]) {
        SEGScreenPayload *screen = (SEGScreenPayload *)context.payload;
        NSMutableDictionary *integrations = [self buildIntegrationsObject:screen];

        SEGContext *newScreenContext = [context modify:^(id<SEGMutableContext> _Nonnull ctx) {
          ctx.payload = [[SEGScreenPayload alloc] initWithName:screen.name
                                                  category: screen.category
                                                  properties:screen.properties
                                                  context:screen.context
                                                  integrations: integrations];
                                                }];
        updatedContext = newScreenContext;
    }
    
    if ([context.payload isKindOfClass:[SEGGroupPayload class]]){
        SEGGroupPayload *group = (SEGGroupPayload *)context.payload;
        NSMutableDictionary *integrations = [self buildIntegrationsObject:group];
        
        SEGContext *newGroupContext = [context modify:^(id<SEGMutableContext> _Nonnull ctx) {
            ctx.payload = [[SEGGroupPayload alloc] initWithGroupId:group.groupId
                                                            traits: group.traits
                                                           context:group.context
                                                      integrations: integrations];
        }];
        
        updatedContext = newGroupContext;
    }

    next(updatedContext);
    return;
}

- (NSString *)generateMCVID {
    NSMutableString *mcvid = [[NSMutableString alloc] init];
    for (int i = 0; i < 38; i++) {
        [mcvid appendFormat:@"%d", arc4random_uniform(10)];
    }
    return mcvid;
}

@end
