#import "SEGMiddlewareSpy.h"

@interface SEGMiddlewareSpy ()

@property (nonatomic, assign) SEGEventType lastEventType;

@end

@implementation SEGMiddlewareSpy

- (void)context:(SEGContext * _Nonnull)context next:(SEGMiddlewareNext _Nonnull)next {
    self.lastEventType = context.eventType;
    next(context);
}

@end
