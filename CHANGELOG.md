Change Log
==========

Version 1.0.1 *(18th April, 2019)*
-------------------------------------
* Adds ID and Sync calls to the constructor of the middleware. Note: it will getMarketingCloudId and then syncIntegrationCode if we don't have a cachedMarketingCloudId. Otherwise it will syncIntegrationCode with the cachedMarketingCloudId if the advertisingId has changed.
* Stores the advertisingID and marketingCloudId in iOS local storage (NSUserDefaults)
* De-couples the API calls to Adobe Experience Cloud ID Service into two API calls getMarketingCloudId and syncIntegrationCode.
* Implements exponential backoff algorithm on API calls. The API calls will continue to retry if the call returns an error or if the responseStatusCode != 200. It will retry up to 10 times.
* Adds improved error handling and incorporated into exponential backoff algorithm. An error will not be returned until the retry logic has exited.
* Is non-blocking. If there is no cachedMarketingCloudId events will continue to be sent to Segment without modification to payloads.

Version 1.0.0 *(18th April, 2019)*
-------------------------------------
Initial release.
