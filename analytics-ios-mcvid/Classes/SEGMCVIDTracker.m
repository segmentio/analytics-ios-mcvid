#import "SEGMCVIDTracker.h"
#import <Analytics/SEGAnalyticsUtils.h>

@implementation SEGMCVIDTracker

+ (id<SEGMiddleware>)middleware
{
    return [[SEGMCVIDTracker alloc] init];
}

- (void)context:(SEGContext *_Nonnull)context next:(SEGMiddlewareNext _Nonnull)next
{
    NSString *advertisingId = context.device[@"advertisingId"];
    NSString *organizationId = context.settings[@"marketingCloudOrgId"]; //can retrieve from settings
    SEGIdentifyPayload *identify =(SEGIdentifyPayload *)context.payload;

    if (context.eventType != SEGEventTypeIdentify) {
        next(context);
        return;
    }

    if (![context.payload isKindOfClass:[SEGIdentifyPayload class]]) {
        next(context);
        return;
    }

    if (!organizationId) {
        next(context);
        return;
    }

    [sendRequestAdobeExperienceCloud:advertisingId organizationId:organizationId completion:(void (^)(NSString *marketingCloudId, NSError *))completion {
      if (marketingCloudId.length) {
        SEGContext *newContext = [context modify:^(id<SEGMutableContext> _Nonnull ctx) {
            ctx.payload = [[SEGIdentifyPayload alloc] initWithEvent:identify.event
                                                      properties:identify.properties
                                                         context:identify.context
                                                    integrations:identify.integrations.["Adobe Anlytics"].marketingCloudId ];

          //somewhere here append marketingCloudId to newContext?????

        }];
        next(newContext);
      }
    }]

}

- (void)sendRequestAdobeExperienceCloud:(NSString *)advertisingId organizationId:(NSString *)organizationId completion:(void (^)(NSString *marketingCloudId, NSError *))completion {
  //Variables to build URL for GET request
  NSString *protocol = @"https";
  NSString *host = @"dpm.demdex.net";
  NSString *path = @"/id?";

  //Defaulted values for request
  NSString *versionKey = @"d_ver"; //d_ver defaults to 2
  NSString *version = @"2"; //d_ver defaults to 2
  NSString *jsonFormatterKey = @"&d_rtbd" //&d_rtbd and defaults to = json
  NSString *jsonFormatter = @"json" //&d_rtbd and defaults to = json
  NSString *regionKey = @"dcs_region"; //dcs_region key defaults to = 6
  NSString *region = @"6"; //dcs_region key defaults to = 6
  NSString *marketingCloudIdKey =@"d_mid"
  NSString *organizationIdKey = @"d_orgid"; //can retrieve from settings

  //Variables for when advertising Id is present
  NSString *deviceTypeKey = @"DSID_20915" //means ios
  NSString *separator = @"%01";
  NSString *advertisingIdKey = @"d_cid_ic";

  //Error messaging
  NSString *errorResponseKey = @"error_msg";
  NSString *errorMessageKey = @"msg";
  NSString *errorCodeKey = @"code";

  //Values to build URl components and quuery items
  NSMutableString *urlString = [NSMutableString stringWithFormat:@"%@://%@%@", protocol, host, path];
  NSURLComponents *components = [NSURLComponents componentsWithString:urlString];
  NSMutableArray *queryItems = [NSMutableArray array];

  if (advertisingId) {
      [queryItems addObject:[NSURLQueryItem queryItemWithName:advertisingIdKey value:[NSString stringWithFormat:@"%@%@%@", deviceTypeKey, separator, advertisingId]]];
  }

  [queryItems addObject:[NSURLQueryItem queryItemWithName:versionKey value:version]];
  [queryItems addObject:[NSURLQueryItem queryItemWithName:jsonFormatterKey value:jsonFormatter]];
  [queryItems addObject:[NSURLQueryItem queryItemWithName:regionKey value:region]];
  [queryItems addObject:[NSURLQueryItem queryItemWithName:organizationIdKey value:organizationId]];

  components.queryItems = queryItems;
  NSURL *url = components.URL;

  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
  NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
  NSURLSession *session = [NSURLSession sessionWithConfiguration:config];

  [[session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
    NSDictionary = nil;
    @try {
      dictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    } @catch (NSException *exception) {
      return callbackWithCode(MPIAdobeErrorCodeClientSerializationError, @"Deserializing the response failed", nil);
    }

    NSString *marketingCloudId = dictionary[marketingCloudIdKey]
    completion(marketingCloudOrgId, nil);
  }] resume];
}

@end
