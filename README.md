# analytics-ios-mcvid

[![CI Status](https://img.shields.io/travis/Brie/analytics-ios-mcvid.svg?style=flat)](https://travis-ci.org/Brie/analytics-ios-mcvid)
[![Version](https://img.shields.io/cocoapods/v/analytics-ios-mcvid.svg?style=flat)](https://cocoapods.org/pods/analytics-ios-mcvid)
[![License](https://img.shields.io/cocoapods/l/analytics-ios-mcvid.svg?style=flat)](https://cocoapods.org/pods/analytics-ios-mcvid)
[![Platform](https://img.shields.io/cocoapods/p/analytics-ios-mcvid.svg?style=flat)](https://cocoapods.org/pods/analytics-ios-mcvid)

A middleware to inject an Adobe Marketing Cloud Visitor IDs to your identify events. Customer's initialize the middleware with their Adobe Organization ID and DCS Region. A list of DCS Regions can be found [here](https://marketing.adobe.com/resources/help/en_US/aam/dcs-regions.html). The middleware makes a call to Adobe's Experience Cloud ID Service to retrieve the Marketing Cloud ID. Documentation on the HTTP request can be found [here](https://marketing.adobe.com/resources/help/en_US/mcvid/mcvid-direct-integration.html). If there is an advertisingId present on the device we will sync that ID to the Adobe Marketing Cloud ID.

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

## Installation

analytics-ios-mcvid is available through [CocoaPods](https://cocoapods.org). This pod requires version 3.6.0 or higher of the `Analytics` pod. To install
it, simply add the following line to your Podfile:

```ruby
pod 'Analytics'
pod 'analytics-ios-mcvid'
```

```obj-c
#import <analytics-ios-mcvid/SEGMCVIDTracker.h>

// Initialize the configuration as you would normally.
SEGAnalyticsConfiguration *configuration = [SEGAnalyticsConfiguration configurationWithWriteKey:@"YOUR_WRITE_KEY"];

// Configure the client with the MCVID middleware to attach Adobe 'marketingCloudId' to your 'identify' payload. Initialize the middleware with your Adobe OrganizationId and Adobe Region (ie. dcs_region key).  
configuration.middlewares = @[ [[SEGMCVIDTracker alloc]  initWithOrganizationId:@"YOUR_ADOBE_ORGID@AdobeOrg" region:@"YOUR_REGION_HERE"] ];

[SEGAnalytics setupWithConfiguration:configuration];
```

## Author

Segment.io, Inc., friends@segment.com

## License

analytics-ios-mcvid is available under the MIT license. See the LICENSE file for more info.
