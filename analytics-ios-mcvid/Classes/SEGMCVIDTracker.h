#import <Foundation/Foundation.h>
#import <Analytics/SEGMiddleware.h>


@interface SEGMCVIDTracker : NSObject <SEGMiddleware>

+ (id<SEGMiddleware>)middleware;
@property (nonatomic) NSString *organizationId;

- (void) sendRequestAdobeExperienceCloud:(NSString *)advertiserId organizationId:(NSString *)organizationId completion:(void (^)(NSString *marketingCloudIdKey, NSError *))completion;

@end

// @interface MCVIDAdobeError : NSObject
//
// @property (nonatomic, assign) MCVIDAdobeError *code;
// @property (nonatomic) NSString *message;
// @property (nonatomic) NSError *error;
//
// @end
