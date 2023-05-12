#import <Foundation/Foundation.h>

#if defined(__has_include) && __has_include(<Analytics/SEGAnalytics.h>)
#import <Analytics/SEGMiddleware.h>
#import <Analytics/SEGAnalyticsConfiguration.h>
#elif SWIFT_PACKAGE
@import Segment;
#else
#import <Segment/SEGMiddleware.h>
#import <Segment/SEGAnalyticsConfiguration.h>
#endif

// Visitor Authentication States in Audience Manager
// @see https://docs.adobe.com/content/help/en/id-service/using/reference/authenticated-state.html
typedef NS_ENUM(NSInteger, MCVIDAuthState) {
    // Unknown or never authenticated
    MCVIDAuthStateUnknown,
    // Authenticated for a particular instance, page, or app
    MCVIDAuthStateAuthenticated,
    // Logged out
    MCVIDAuthStateLoggedOut,
};

typedef NS_ENUM(NSInteger, MCVIDGenerationMode) {
    // Locally generates a UUID
    MCVIDGenerationModeLocal,
    // Delegate its generation to the server side
    MCVIDGenerationModeRemote,
};

@interface SEGMCVIDTracker : NSObject <SEGMiddleware>

- (instancetype _Nonnull)init NS_UNAVAILABLE;
- (instancetype _Nonnull)initWithOrganizationId:(NSString *_Nonnull)organizationId region:(NSString *_Nonnull)region;
- (instancetype _Nonnull)initWithOrganizationId:(NSString *_Nonnull)organizationId region:(NSString *_Nonnull)region advertisingIdProvider:(SEGAdSupportBlock _Nullable)advertisingIdProvider;
- (instancetype _Nonnull)initWithOrganizationId:(NSString *_Nonnull)organizationId region:(NSString *_Nonnull)region mcvidGenerationMode:(MCVIDGenerationMode)mcvidGenerationMode;
- (instancetype _Nonnull)initWithOrganizationId:(NSString *_Nonnull)organizationId region:(NSString *_Nonnull)region advertisingIdProvider:(SEGAdSupportBlock _Nullable)advertisingIdProvider mcvidGenerationMode:(MCVIDGenerationMode)mcvidGenerationMode NS_DESIGNATED_INITIALIZER;
+ (NSString *_Nullable)getCachedMarketingId;

@property (nonatomic, strong, nonnull) NSString *organizationId;
@property (nonatomic, strong, nonnull) NSString *region;

- (void)setAdvertisingIdProvider:(SEGAdSupportBlock _Nullable)advertisingIdProvider;
- (void)syncIntegrationCode:(NSString *_Nonnull)integrationCode userIdentifier:(NSString *_Nonnull)userIdentifier completion:(void (^_Nonnull)(NSError *_Nullable))completion;
- (void)syncIntegrationCode:(NSString *_Nonnull)integrationCode userIdentifier:(NSString *_Nonnull)userIdentifier authentication:(MCVIDAuthState)state completion:(void (^_Nonnull)(NSError *_Nullable))completion;

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
