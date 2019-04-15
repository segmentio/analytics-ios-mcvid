#import <Foundation/Foundation.h>
#import <Analytics/SEGMiddleware.h>


@interface SEGMCVIDTracker : NSObject <SEGMiddleware>

+ (id<SEGMiddleware>)middleware;
-(id)initWithOrganizationId:(NSString *)organizationId region:(NSString *)region;

@property (nonatomic, strong) NSString *organizationId;
@property (nonatomic, strong) NSString *region;
@property(readonly, copy) NSString *stringByRemovingPercentEncoding;

- (void) sendRequestAdobeExperienceCloud:(NSString *)advertiserId organizationId:(NSString *)organizationId completion:(void (^)(NSString *marketingCloudIdKey, NSError *))completion;

@end

// Use this key to retrieve the MCVIDAdobeError object from the NSError's userInfo dictionary
extern NSString *const MCVIDAdobeErrorKey;

typedef NS_ENUM(NSInteger, MCVIDAdobeErrorCode) {
    // Network request failed
    MCVIDAdobeErrorCodeClientFailedRequestError,
    // Unable to deserialize JSON from response
    MCVIDAdobeErrorCodeClientSerializationError,
    // An error was provided by the server
    MCVIDAdobeErrorCodeServerError
};

@interface MCVIDAdobeError : NSObject

@property (nonatomic, assign) MCVIDAdobeErrorCode code;
@property (nonatomic) NSString *message;
@property (nonatomic) NSError *innerError;

@end
