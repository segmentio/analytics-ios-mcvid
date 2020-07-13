/*
 * Copyright (c) 2015 Specta Team. All rights reserved.
 */
#import <Foundation/Foundation.h>

// This protocol was used for denying classes for global beforeEach and afterEach blocks.
// Now, instead, classes are allowed by implementing the SPTGlobalBeforeAfterEach protocol.
__deprecated_msg("Please allow classes instead with the SPTGlobalBeforeAfterEach protocol")
@protocol SPTExcludeGlobalBeforeAfterEach <NSObject>
@end
