#import <Foundation/Foundation.h>
#import <Analytics/SEGMiddleware.h>


@interface SEGMCVIDTracker : NSObject <SEGMiddleware>

+ (id<SEGMiddleware>)middleware;
-(id)initWithOrganizationId:(NSString *)organizationId;
@property (nonatomic, strong) NSString *organizationId;

- (void) sendRequestAdobeExperienceCloud:(NSString *)advertiserId organizationId:(NSString *)organizationId completion:(void (^)(NSString *marketingCloudIdKey, NSError *))completion;

@end
