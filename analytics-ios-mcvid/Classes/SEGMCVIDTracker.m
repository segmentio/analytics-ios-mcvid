#import "SEGMCVIDTracker.h"
#import <Analytics/SEGAnalyticsUtils.h>
#import <AdSupport/ASIdentifierManager.h>
#include <time.h>
#include <stdlib.h>



@interface MCVIDAdobeError ()

- (id)initWithCode:(MCVIDAdobeErrorCode)code message:(NSString *)message error:(NSError *)error;

@end

@implementation MCVIDAdobeError
- (id)initWithCode:(MCVIDAdobeErrorCode)code message:(NSString *)message error:(NSError *)error {
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
    @property(nonatomic) NSString *cachedMarketingCloudId;
    @property(nonatomic) NSString *cachedAdvertisingId;
@end

@implementation SEGMCVIDTracker

+ (id<SEGMiddleware>)middlewareWithOrganizationId:(NSString *)organizationId region:(NSString *)region {
    return [[SEGMCVIDTracker alloc] initWithOrganizationId: organizationId region:region ];
}

-(id)initWithOrganizationId:(NSString *)organizationId region:(NSString *)region
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
    _cachedMarketingCloudId = [defaults stringForKey:@"MarketingCloudId"];
    
      [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString];
    //This is was SEGIDFA() is going under the hood. NSString *idfaString = [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString];
    NSString *segIdfa = SEGIDFA();
    if (![self.cachedAdvertisingId isEqualToString:segIdfa]) {
        [defaults setObject:segIdfa forKey:@"AdvertisingId"];
    }
    _cachedAdvertisingId = [defaults stringForKey:@"AdvertisingId"];
    
    //Defaut value for integration code which indicate ios
    NSString *integrationCode = @"DSID_20915";

    if (self.cachedMarketingCloudId.length == 0 || (segIdfa != self.cachedAdvertisingId)) {
        [self getMarketingCloudId:organizationId completion:^(NSString *marketingCloudId, NSError *error) {
          [defaults setObject:marketingCloudId forKey:@"MarketingCloudId"];
            [self syncIntegrationCode:integrationCode userIdentifier:self.cachedAdvertisingId completion:^(NSError *error) {
              if (error) {
                  return;
              }
          }];
        }];
    } else if (self.cachedMarketingCloudId.length != 0) {
      [self syncIntegrationCode:integrationCode userIdentifier:self.cachedAdvertisingId completion:^(NSError *error) {
          if (error) {
              return;
          }
      }];
    }
      
    [defaults synchronize];
    return self;
  }

- (void)getMarketingCloudId:(NSString *)organizationId completion:(void (^)(NSString *marketingCloudId, NSError *))completion {
    
    //Response and error handling variables
    NSString *const MCVIDAdobeErrorKey = @"MCVIDAdobeErrorKey";
    NSString *errorResponseKey = @"errors";
    NSString *errorDomain = @"Segment-Adobe";
    NSString *marketingCloudIdKey = @"d_mid";

    NSString *callType = @"getmMarketingCloudId";

    NSURL *url = [self createURL:callType integrationCode:@"DSID_20915"];

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
        NSUInteger milliSecondsToWait = self.currentRetryCount * self.currentRetryCount;
        NSUInteger milliSecondsWaited = self.currentRetryCount * (self.currentRetryCount + 1)  * ((2 * self.currentRetryCount) + 1)/6;

        if ((self.currentRetryCount > self.maxRetryCount) && errorObject) {
            return callbackWithCode(MCVIDAdobeErrorCodeServerError, errorMessage, errorObject);
        }

        if ((milliSecondsWaited / 1 >= self.maxRetryTimeSecs) && errorObject) {
            return callbackWithCode(MCVIDAdobeErrorCodeServerError, errorMessage, errorObject);
        }

        if (responseStatusCode == 200 && (!errorObject) ){
            completion(marketingCloudId, nil);
        } else {
            dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * milliSecondsToWait);
            dispatch_after(delay, self.backgroundQueue, ^(void){
                self.currentRetryCount = self.currentRetryCount + 1;
                [self getMarketingCloudId:organizationId completion:^(NSString *marketingCloudId, NSError *error) {
                }];
            });
        }
    }] resume];
}

- (void)syncIntegrationCode:(NSString *)integrationCode userIdentifier:(NSString *)userIdentifier completion:(void (^)(NSError *))completion {
    
    //Response and error handling variables
    NSString *const MCVIDAdobeErrorKey = @"MCVIDAdobeErrorKey";
    NSString *errorResponseKey = @"errors";
    NSString *errorDomain = @"Segment-Adobe";
    NSString *callType =@"syncIntegrationCode";

    NSURL *url = [self createURL:callType integrationCode:integrationCode];
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
        NSUInteger milliSecondsToWait = self.currentRetryCount * self.currentRetryCount;
        NSUInteger milliSecondsWaited = self.currentRetryCount * (self.currentRetryCount + 1)  * ((2 * self.currentRetryCount) + 1)/6;
        
        if ((self.currentRetryCount > self.maxRetryCount) && (errorObject)) {
            return callbackWithCode(MCVIDAdobeErrorCodeServerError, errorMessage, errorObject);

        }
        
        if (milliSecondsWaited / 1 >= self.maxRetryTimeSecs && (errorObject)) {
            return callbackWithCode(MCVIDAdobeErrorCodeServerError, errorMessage, errorObject);
        }
        
        if ((responseStatusCode == 200) && (!errorObject)){
            completion(nil);
        } else {
            dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * milliSecondsToWait);
            dispatch_after(delay, self.backgroundQueue, ^(void){
                self.currentRetryCount = self.currentRetryCount + 1;
                [self syncIntegrationCode:integrationCode userIdentifier:self.cachedAdvertisingId completion:^(NSError *error){
                }];
            });
        }
    }] resume];
}

- (NSURL *)createURL:callType integrationCode:(NSString *)integrationCode {
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
        NSString *encodedAdvertisingValue = [NSString stringWithFormat:@"%@%@%@", integrationCode, separator, self.cachedAdvertisingId];
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

  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *cachedMarketingCloudId = [defaults stringForKey:@"MarketingCloudId"];

  if (!cachedMarketingCloudId) {
    next(context);
    return;
  }

  if (!_organizationId) {
     next(context);
     return;
  }

  SEGIdentifyPayload *identify =(SEGIdentifyPayload *)context.payload;
  SEGTrackPayload *track =(SEGTrackPayload *)context.payload;
  SEGScreenPayload *screen =(SEGScreenPayload *)context.payload;
  SEGGroupPayload *group =(SEGGroupPayload *)context.payload;

  if (cachedMarketingCloudId.length) {
    NSMutableDictionary *mergedIntegrations = [NSMutableDictionary dictionaryWithCapacity:100];
    NSDictionary *mcidIntegrations = @{@"Adobe Analytics" : @{ @"marketingCloudVisitorId": cachedMarketingCloudId } };
    [mergedIntegrations addEntriesFromDictionary:mcidIntegrations];

    if ([context.payload isKindOfClass:[SEGIdentifyPayload class]]){
      [mergedIntegrations addEntriesFromDictionary:identify.integrations];
      SEGContext *newIdentifyContext = [context modify:^(id<SEGMutableContext> _Nonnull ctx) {
          ctx.payload = [[SEGIdentifyPayload alloc] initWithUserId:identify.userId
                                                    anonymousId:identify.anonymousId
                                                    traits: identify.traits
                                                    context:identify.context
                                                    integrations: mergedIntegrations];
                                                  }];

      next(newIdentifyContext);
    }

    if ([context.payload isKindOfClass:[SEGTrackPayload class]]){
      [mergedIntegrations addEntriesFromDictionary:track.integrations];
      SEGContext *newTrackContext = [context modify:^(id<SEGMutableContext> _Nonnull ctx) {
          ctx.payload = [[SEGTrackPayload alloc] initWithEvent:track.event
                                                    properties:track.properties
                                                    context:track.context
                                                    integrations: mergedIntegrations];
                                                  }];
      next(newTrackContext);
    }

    if ([context.payload isKindOfClass:[SEGScreenPayload class]]){
      [mergedIntegrations addEntriesFromDictionary:screen.integrations];
      SEGContext *newScreenContext = [context modify:^(id<SEGMutableContext> _Nonnull ctx) {
          ctx.payload = [[SEGScreenPayload alloc] initWithName:screen.name
                                                  properties:screen.properties
                                                  context:screen.context
                                                  integrations: mergedIntegrations];
                                                }];
      next(newScreenContext);
    }

    if ([context.payload isKindOfClass:[SEGGroupPayload class]]){
      [mergedIntegrations addEntriesFromDictionary:group.integrations];
      SEGContext *newGroupContext = [context modify:^(id<SEGMutableContext> _Nonnull ctx) {
          ctx.payload = [[SEGGroupPayload alloc] initWithGroupId:group.groupId
                                                  traits: group.traits
                                                  context:group.context
                                                  integrations: mergedIntegrations];
                                                }];
      next(newGroupContext);
    }
    return;
  }
}

@end
