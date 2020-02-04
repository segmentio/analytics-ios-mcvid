#import <Foundation/Foundation.h>
#import <Analytics/SEGMiddleware.h>

@interface SEGMCVIDTracker : NSObject <SEGMiddleware>

- (instancetype _Nonnull)init NS_UNAVAILABLE;
- (instancetype _Nonnull)initWithOrganizationId:(NSString *_Nonnull)organizationId region:(NSString *_Nonnull)region NS_DESIGNATED_INITIALIZER;
+ (NSString *_Nullable)getCachedMarketingId;

@property (nonatomic, strong, nonnull) NSString *organizationId;
@property (nonatomic, strong, nonnull) NSString *region;

- (void)syncIntegrationCode:(NSString *_Nonnull)integrationCode userIdentifier:(NSString *_Nonnull)userIdentifier completion:(void (^_Nonnull)(NSError *_Nullable))completion;

@end

// Use this key to retrieve the MCVIDAdobeError object from the NSError's userInfo dictionary
extern NSString * _Nonnull const MCVIDAdobeErrorKey;

typedef NS_ENUM(NSInteger, MCVIDAdobeErrorCode) {
    // Unable to deserialize JSON from response
    MCVIDAdobeErrorCodeClientSerializationError,
    // An error was provided by the server
    MCVIDAdobeErrorCodeServerError,
    // The MCVID is not yet available
    MCVIDAdobeErrorCodeUnavailable
};

@interface MCVIDAdobeError : NSObject

@property (nonatomic, assign) MCVIDAdobeErrorCode code;
@property (nonatomic, nullable) NSString *message;
@property (nonatomic, nullable) NSError *innerError;

@end
