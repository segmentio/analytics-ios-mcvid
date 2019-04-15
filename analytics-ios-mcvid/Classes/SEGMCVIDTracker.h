#import <Foundation/Foundation.h>
#import <Analytics/SEGMiddleware.h>


@interface SEGMCVIDTracker : NSObject <SEGMiddleware>

+ (id<SEGMiddleware>)middleware;
-(id)initWithOrganizationId:(NSString *)organizationId;
@property (nonatomic, strong) NSString *organizationId;

- (void) sendRequestAdobeExperienceCloud:(NSString *)advertiserId organizationId:(NSString *)organizationId completion:(void (^)(NSString *marketingCloudIdKey, NSError *))completion;
- (NSString *)stringByReplacingPercentEscapesUsingEncoding:(NSStringEncoding)encoding;


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
