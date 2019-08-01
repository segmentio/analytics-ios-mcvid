//
//  SEGMiddlewareSpy.m
//  analytics-ios-mcvid_Tests
//
//  Created by Xavier Jurado on 01/08/2019.
//  Copyright © 2019 Brie. All rights reserved.
//

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
