#import <Foundation/Foundation.h>
#import <Analytics/SEGMiddleware.h>

NS_ASSUME_NONNULL_BEGIN

@interface SEGMiddlewareSpy : NSObject <SEGMiddleware>

@property (nonatomic, assign, readonly) SEGEventType lastEventType;

@end

NS_ASSUME_NONNULL_END
