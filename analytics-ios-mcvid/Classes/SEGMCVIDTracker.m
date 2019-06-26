#import "SEGMCVIDTracker.h"
#import <Analytics/SEGAnalyticsUtils.h>
#import <AdSupport/ASIdentifierManager.h>
#include <time.h>
#include <stdlib.h>
#include <math.h>

NSString *const MCVIDAdobeErrorKey = @"MCVIDAdobeErrorKey";
NSString *const getCloudIdCallType = @"getMarketingCloudID";
NSString *const syncIntegrationCallType = @"syncIntegrationCode";

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
    @property(nonatomic) NSUInteger maxRetryTimeSecs;
    @property(nonatomic, nonnull) NSString *cachedMarketingCloudId;
    @property(nonatomic, nonnull) NSString *cachedAdvertisingId;
    @property dispatch_queue_t _Nonnull backgroundQueue;

@end

@implementation SEGMCVIDTracker

+ (id<SEGMiddleware>)middlewareWithOrganizationId:(NSString *_Nonnull)organizationId region:(NSString *_Nonnull)region {
    return [[SEGMCVIDTracker alloc] initWithOrganizationId: organizationId region:region ];
}

-(id)initWithOrganizationId:(NSString *_Nonnull)organizationId region:(NSString *_Nonnull)region
  {
    if (self = [super init])
    {
      self.organizationId = organizationId;
      self.region = region;
    }

    //Values for exponential backoff retry logic for API calls
    _maxRetryCount = 11;
    _currentRetryCount = 1;
    _maxRetryTimeSecs = 300;
    self.backgroundQueue = dispatch_queue_create("com.segment.mcvid", NULL);


    //Store advertisingId and marketingCloudId on local storage
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *segIdfa = SEGIDFA();
    _cachedMarketingCloudId = [defaults stringForKey:@"com.segment.mcvid.marketingCloudId"];
    if (_cachedAdvertisingId == NULL) {
        [defaults setObject:segIdfa forKey:@"com.segment.mcvid.advertisingId"];
        _cachedAdvertisingId = [defaults stringForKey:@"com.segment.mcvid.advertisingId"];
    }
    //Defaut value for integration code which indicate ios
    NSString *integrationCode = @"DSID_20915";

    if (self.cachedMarketingCloudId.length == 0) {
        [self getMarketingCloudId:organizationId completion:^(NSString  * _Nullable marketingCloudId, NSError * _Nullable error) {
          [defaults setObject:marketingCloudId forKey:@"com.segment.mcvid.marketingCloudId"];
            self.cachedMarketingCloudId = [defaults stringForKey:@"com.segment.mcvid.marketingCloudId"];
            [self syncIntegrationCode:integrationCode userIdentifier:self.cachedAdvertisingId completion:^(NSError *error) {
              if (error) {
                  return;
              }
          }];
        }];
    } else if (![_cachedAdvertisingId isEqualToString:segIdfa]) {
      [self syncIntegrationCode:integrationCode userIdentifier:self.cachedAdvertisingId completion:^(NSError * _Nullable error) {
          if (error) {
              return;
          }
      }];
    }

    [defaults synchronize];
    return self;
  }

- (void)getMarketingCloudId:(NSString *_Nonnull)organizationId completion:(void (^)(NSString * _Nullable marketingCloudId, NSError *_Nullable))completion {

    //Response and error handling variables
    NSString *errorResponseKey = @"errors";
    NSString *errorDomain = @"Segment-Adobe";
    NSString *marketingCloudIdKey = @"d_mid";

    NSURL *url = [self createURL:getCloudIdCallType integrationCode:@"DSID_20915"];

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
            completion(marketingCloudId, nil);
        } else {
            dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * secondsToWait);
            dispatch_after(delay, self.backgroundQueue, ^(void){
                self.currentRetryCount = self.currentRetryCount + 1;
                [self getMarketingCloudId:organizationId completion:^(NSString * _Nullable marketingCloudId, NSError * _Nullable error) {
                }];
            });
        }
    }] resume];
}

- (void)syncIntegrationCode:(NSString * _Nonnull)integrationCode userIdentifier:(NSString * _Nonnull)userIdentifier completion:(void (^)(NSError * _Nullable))completion {

    //Response and error handling variables
    NSString *errorResponseKey = @"errors";
    NSString *errorDomain = @"Segment-Adobe";

    NSURL *url = [self createURL:syncIntegrationCallType integrationCode:integrationCode];
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

- (NSURL * _Nonnull)createURL:callType integrationCode:(NSString * _Nonnull)integrationCode {
    return [self createURL:callType integrationCode:integrationCode userIdentifier:self.cachedAdvertisingId];
}

- (NSURL * _Nonnull)createURL:(NSString *_Nonnull)callType integrationCode:(NSString * _Nonnull)integrationCode userIdentifier:(NSString* _Nullable)userIdentifier {
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
    NSString *marketingCloudIdKey = @"d_mid";
    NSString *organizationIdKey = @"d_orgid"; //can retrieve from settings

    //Variables for when advertising Id is present
    NSString *separator = @"%01";
    NSString *advertisingIdKey = @"d_cid_ic";

    //Values to build URl components and query items
    NSMutableString *urlString = [NSMutableString stringWithFormat:@"%@://%@%@", protocol, host, path];
    NSURLComponents *components = [NSURLComponents componentsWithString:urlString];
    NSMutableArray *queryItems = [NSMutableArray array];

    [queryItems addObject:[NSURLQueryItem queryItemWithName:versionKey value:version]];
    [queryItems addObject:[NSURLQueryItem queryItemWithName:jsonFormatterKey value:jsonFormatter]];
    [queryItems addObject:[NSURLQueryItem queryItemWithName:regionKey value:region]];
    [queryItems addObject:[NSURLQueryItem queryItemWithName:organizationIdKey value:self.organizationId]];

    if ([callType isEqualToString:@"syncIntegrationCode"]) {
        [queryItems addObject:[NSURLQueryItem queryItemWithName:marketingCloudIdKey value:self.cachedMarketingCloudId]];
        NSString *encodedAdvertisingValue = [NSString stringWithFormat:@"%@%@%@", integrationCode, separator, userIdentifier];
        //removes %25 html encoding of '%'
        NSString *normalAdvertisingValue = [encodedAdvertisingValue stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        [queryItems addObject:[NSURLQueryItem queryItemWithName:advertisingIdKey value:normalAdvertisingValue]];
    }
    components.queryItems = queryItems;
    NSURL *url = components.URL;

    return url;
}


- (void)context:(SEGContext *_Nonnull)context next:(SEGMiddlewareNext _Nonnull)next {
    if ([context.payload isKindOfClass:[SEGAliasPayload class]]) {
      next(context);
      return;
    }

  if (!self.cachedMarketingCloudId) {
    next(context);
    return;
  }

  SEGIdentifyPayload *identify =(SEGIdentifyPayload *)context.payload;
  SEGTrackPayload *track =(SEGTrackPayload *)context.payload;
  SEGScreenPayload *screen =(SEGScreenPayload *)context.payload;
  SEGGroupPayload *group =(SEGGroupPayload *)context.payload;

  if (self.cachedMarketingCloudId.length) {
    NSMutableDictionary *adobeOptions = [NSMutableDictionary new];

    if ([context.payload isKindOfClass:[SEGIdentifyPayload class]]){
        if ((identify.integrations != NULL) && ([identify.integrations objectForKey:@"Adobe Analytics"])){
            NSDictionary *existingAAOptions = identify.integrations[@"Adobe Analytics"];
            [adobeOptions addEntriesFromDictionary:existingAAOptions];
            [adobeOptions setObject:self.cachedMarketingCloudId forKey:@"marketingCloudVisitorId"];
        }
        
        NSMutableDictionary *integrations = [NSMutableDictionary new];
        if (identify.integrations != NULL) {
            NSMutableDictionary *existingIntegrations = [NSMutableDictionary new];
            [existingIntegrations addEntriesFromDictionary:identify.integrations];
            [existingIntegrations removeObjectForKey:@"Adobe Analytics"];
            [integrations addEntriesFromDictionary:existingIntegrations];
            [integrations setObject:adobeOptions forKey:@"Adobe Analytics"];
        }
        SEGContext *newIdentifyContext = [context modify:^(id<SEGMutableContext> _Nonnull ctx) {
            ctx.payload = [[SEGIdentifyPayload alloc] initWithUserId:identify.userId
                                                    anonymousId:identify.anonymousId
                                                    traits: identify.traits
                                                    context:identify.context
                                                    integrations: integrations];
                                                  }];

        next(newIdentifyContext);
    }

    if ([context.payload isKindOfClass:[SEGTrackPayload class]]){
        if ((track.integrations != NULL) && ([track.integrations objectForKey:@"Adobe Analytics"])){
            NSDictionary *existingAAOptions = track.integrations[@"Adobe Analytics"];
            [adobeOptions addEntriesFromDictionary:existingAAOptions];
            [adobeOptions setObject:self.cachedMarketingCloudId forKey:@"marketingCloudVisitorId"];
        }
        
        NSMutableDictionary *integrations = [NSMutableDictionary new];
        if (track.integrations != NULL) {
            NSMutableDictionary *existingIntegrations = [NSMutableDictionary new];
            [existingIntegrations addEntriesFromDictionary:track.integrations];
            [existingIntegrations removeObjectForKey:@"Adobe Analytics"];
            [integrations addEntriesFromDictionary:existingIntegrations];
            [integrations setObject:adobeOptions forKey:@"Adobe Analytics"];
        }

        SEGContext *newTrackContext = [context modify:^(id<SEGMutableContext> _Nonnull ctx) {
          ctx.payload = [[SEGTrackPayload alloc] initWithEvent:track.event
                                                    properties:track.properties
                                                    context:track.context
                                                    integrations: integrations];
                                                  }];
        next(newTrackContext);
    }

    if ([context.payload isKindOfClass:[SEGScreenPayload class]]){
        if ((screen.integrations != NULL) && ([screen.integrations objectForKey:@"Adobe Analytics"])){
            NSDictionary *existingAAOptions = screen.integrations[@"Adobe Analytics"];
            [adobeOptions addEntriesFromDictionary:existingAAOptions];
            [adobeOptions setObject:self.cachedMarketingCloudId forKey:@"marketingCloudVisitorId"];
        }
        
        NSMutableDictionary *integrations = [NSMutableDictionary new];
        if (screen.integrations != NULL) {
            NSMutableDictionary *existingIntegrations = [NSMutableDictionary new];
            [existingIntegrations addEntriesFromDictionary:screen.integrations];
            [existingIntegrations removeObjectForKey:@"Adobe Analytics"];
            [integrations addEntriesFromDictionary:existingIntegrations];
            [integrations setObject:adobeOptions forKey:@"Adobe Analytics"];
        }
        
        SEGContext *newScreenContext = [context modify:^(id<SEGMutableContext> _Nonnull ctx) {
          ctx.payload = [[SEGScreenPayload alloc] initWithName:screen.name
                                                  properties:screen.properties
                                                  context:screen.context
                                                  integrations: integrations];
                                                }];
        next(newScreenContext);
    }

    if ([context.payload isKindOfClass:[SEGGroupPayload class]]){
        if ((group.integrations != NULL) && ([group.integrations objectForKey:@"Adobe Analytics"])){
            NSDictionary *existingAAOptions = group.integrations[@"Adobe Analytics"];
            [adobeOptions addEntriesFromDictionary:existingAAOptions];
            [adobeOptions setObject:self.cachedMarketingCloudId forKey:@"marketingCloudVisitorId"];
        }
        
        NSMutableDictionary *integrations = [NSMutableDictionary new];
        if (group.integrations != NULL) {
            NSMutableDictionary *existingIntegrations = [NSMutableDictionary new];
            [existingIntegrations addEntriesFromDictionary:group.integrations];
            [existingIntegrations removeObjectForKey:@"Adobe Analytics"];
            [integrations addEntriesFromDictionary:existingIntegrations];
            [integrations setObject:adobeOptions forKey:@"Adobe Analytics"];
        }
        
        SEGContext *newGroupContext = [context modify:^(id<SEGMutableContext> _Nonnull ctx) {
          ctx.payload = [[SEGGroupPayload alloc] initWithGroupId:group.groupId
                                                  traits: group.traits
                                                  context:group.context
                                                  integrations: integrations];
                                                }];
        next(newGroupContext);
    }
    return;
  }
}

@end
