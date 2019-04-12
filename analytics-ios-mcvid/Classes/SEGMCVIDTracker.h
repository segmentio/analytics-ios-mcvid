#import <Foundation/Foundation.h>
#import <Analytics/SEGMiddleware.h>


@interface SEGMCVIDTracker : NSObject <SEGMiddleware>

+ (id<SEGMiddleware>)middleware;
@property (nonatomic) NSString *organizationId;

- (void) sendRequestAdobeExperienceCloud:(NSString *)advertiserId organizationId:(NSString *)organizationId completion:(void (^)(NSString *marketingCloudIdKey, NSError *))completion;

@end
