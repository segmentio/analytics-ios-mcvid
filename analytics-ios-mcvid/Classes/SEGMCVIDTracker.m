#import "SEGMCVIDTracker.h"
#import <Analytics/SEGAnalyticsUtils.h>

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

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *cachedMarketingCloudId = [defaults stringForKey:@"MarketingCloudId"];
    [defaults setObject:advertisingId forKey:@"AdvertisingId"];
    NSString *cachedAdvertisingId = [defaults stringForKey:@"AdvertisingId"];

    if (!cachedMarketingCloudId || (cachedAdvertisingId != SEGIDFA())) {
      NSString *advertisingId = SEGIDFA();
      [defaults setObject:advertisingId forKey:@"AdvertisingId"];
      dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        [self getMarketingCloudId:organizationId completion:^(NSString *marketingCloudId, NSError *error) {
          [defaults setObject:marketingCloudId forKey:@"MarketingCloudId"];
        }];

        [self syncMarketingCloudId:cachedAdvertisingId organizationId:organizationId marketingCloudId:cachedMarketingCloudId completion:^(NSError *error) {
          dispatch_semaphore_signal(sema);
        }];
      dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    } else if (cachedMarketingCloudId && (cachedAdvertisingId == SEGIDFA()) && cachedAdvertisingId) {
      dispatch_semaphore_t sema = dispatch_semaphore_create(0);
      [self syncMarketingCloudId:cachedAdvertisingId organizationId:organizationId marketingCloudId:cachedMarketingCloudId completion:^(NSError *error) {
        dispatch_semaphore_signal(sema);
      }];
      dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    }
    return self;
  }

- (void)getMarketingCloudId:(NSString *)organizationId completion:(void (^)(NSString *marketingCloudId, NSError *))completion {
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

    //Values to build URl components and query items
    NSMutableString *urlString = [NSMutableString stringWithFormat:@"%@://%@%@", protocol, host, path];
    NSURLComponents *components = [NSURLComponents componentsWithString:urlString];
    NSMutableArray *queryItems = [NSMutableArray array];

    //Error handling variables
    NSString *const MCVIDAdobeErrorKey = @"MCVIDAdobeErrorKey";
    NSString *errorResponseKey = @"error_msg";
    NSString *invalidMarketingCloudId = @"<null>";
    NSString *errorDomain = @"Segment-Adobe";
    NSString *serverErrorDomain = @"Segment-Adobe Server Response";

    [queryItems addObject:[NSURLQueryItem queryItemWithName:versionKey value:version]];
    [queryItems addObject:[NSURLQueryItem queryItemWithName:jsonFormatterKey value:jsonFormatter]];
    [queryItems addObject:[NSURLQueryItem queryItemWithName:regionKey value:region]];
    [queryItems addObject:[NSURLQueryItem queryItemWithName:organizationIdKey value:organizationId]];

    components.queryItems = queryItems;
    NSURL *url = components.URL;
    NSLog(@"URL, %@", url);

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];

    [[session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {

      void (^callbackWithCode)(MCVIDAdobeErrorCode code, NSString *message, NSError *error) = ^void(MCVIDAdobeErrorCode code, NSString *message, NSError *error) {
            MCVIDAdobeError *adobeError = [[MCVIDAdobeError alloc] initWithCode:code message:message error:error];
            NSError *compositeError = [NSError errorWithDomain:errorDomain code:adobeError.code userInfo:@{MCVIDAdobeErrorKey:adobeError}];
            completion(nil, compositeError);
        };

      if (error) {
        return callbackWithCode(MCVIDAdobeErrorCodeClientFailedRequestError, @"Request Failed", error);
      }

        NSDictionary *dictionary = nil;
        @try {
            dictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        } @catch (NSException *exception) {
            return callbackWithCode(MCVIDAdobeErrorCodeClientSerializationError, @"Deserializing the JSON response failed", nil);
            return (NSLog(@"error"));
        }

        NSDictionary *errorDictionary = dictionary[errorResponseKey];
        if (errorDictionary) {
            NSError *error = [NSError errorWithDomain:serverErrorDomain code:0 userInfo:errorDictionary];
            return callbackWithCode(MCVIDAdobeErrorCodeServerError, @"Server returned an error", error);
        }

        NSString *marketingCloudId = dictionary[marketingCloudIdKey];

        if ([marketingCloudId isEqualToString:invalidMarketingCloudId]){
          marketingCloudId =  nil;
        }
        completion(marketingCloudId, nil);
    }] resume];
}

- (void)syncMarketingCloudId:(NSString *)advertisingId organizationId:(NSString *)organizationId marketingCloudId:(NSString *)marketingCloudId completion:(void (^)(NSError *))completion {
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
    NSString *deviceTypeKey = @"DSID_20915";//means ios
    NSString *separator = @"%01";
    NSString *advertisingIdKey = @"d_cid_ic";

    //Values to build URl components and query items
    NSMutableString *urlString = [NSMutableString stringWithFormat:@"%@://%@%@", protocol, host, path];
    NSURLComponents *components = [NSURLComponents componentsWithString:urlString];
    NSMutableArray *queryItems = [NSMutableArray array];

    //Error handling variables
    NSString *const MCVIDAdobeErrorKey = @"MCVIDAdobeErrorKey";
    NSString *errorResponseKey = @"error_msg";
    NSString *errorDomain = @"Segment-Adobe";
    NSString *serverErrorDomain = @"Segment-Adobe Server Response";

    NSString *encodedAdvertisingValue = [NSString stringWithFormat:@"%@%@%@", deviceTypeKey, separator, advertisingId];
    //removes %25 html encoding of '%'
    NSString *normalAdvertisingValue = [encodedAdvertisingValue stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    [queryItems addObject:[NSURLQueryItem queryItemWithName:advertisingIdKey value:normalAdvertisingValue]];

    [queryItems addObject:[NSURLQueryItem queryItemWithName:versionKey value:version]];
    [queryItems addObject:[NSURLQueryItem queryItemWithName:jsonFormatterKey value:jsonFormatter]];
    [queryItems addObject:[NSURLQueryItem queryItemWithName:regionKey value:region]];
    [queryItems addObject:[NSURLQueryItem queryItemWithName:organizationIdKey value:organizationId]];
    [queryItems addObject:[NSURLQueryItem queryItemWithName:marketingCloudIdKey value:marketingCloudId]];

    components.queryItems = queryItems;
    NSURL *url = components.URL;
    NSLog(@"URL, %@", url);

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];

    [[session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {

      void (^callbackWithCode)(MCVIDAdobeErrorCode code, NSString *message, NSError *error) = ^void(MCVIDAdobeErrorCode code, NSString *message, NSError *error) {
            MCVIDAdobeError *adobeError = [[MCVIDAdobeError alloc] initWithCode:code message:message error:error];
            NSError *compositeError = [NSError errorWithDomain:errorDomain code:adobeError.code userInfo:@{MCVIDAdobeErrorKey:adobeError}];
            completion(compositeError);
        };

      if (error) {
        return callbackWithCode(MCVIDAdobeErrorCodeClientFailedRequestError, @"Request Failed", error);
      }

        NSDictionary *dictionary = nil;
        @try {
            dictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        } @catch (NSException *exception) {
            return callbackWithCode(MCVIDAdobeErrorCodeClientSerializationError, @"Deserializing the JSON response failed", nil);
            return (NSLog(@"error"));
        }

        NSDictionary *errorDictionary = dictionary[errorResponseKey];
        if (errorDictionary) {
            NSError *error = [NSError errorWithDomain:serverErrorDomain code:0 userInfo:errorDictionary];
            return callbackWithCode(MCVIDAdobeErrorCodeServerError, @"Server returned an error", error);
        }

        completion(nil);
    }] resume];
}


- (void)context:(SEGContext *_Nonnull)context next:(SEGMiddlewareNext _Nonnull)next
{
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
    NSLog(@"mcidIntegrations %@", mcidIntegrations);
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

  if (!cachedMarketingCloudId) {
      next(context);
    return;
  }
}

@end
