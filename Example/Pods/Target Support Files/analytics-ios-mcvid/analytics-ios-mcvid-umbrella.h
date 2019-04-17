#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "SEGMCVIDTracker.h"

FOUNDATION_EXPORT double analytics_ios_mcvidVersionNumber;
FOUNDATION_EXPORT const unsigned char analytics_ios_mcvidVersionString[];

