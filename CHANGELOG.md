Change Log
==========

Version 1.2.2 *(25th February, 2020)*
-------------------------------------
* Added Carthage support.
* Added ability to get cached marketing id externally.

Version 1.2.1 *(8th January, 2020)*
-------------------------------------
* Modified analytics dependency version number such that 3.6 or greater will be used.

Version 1.2.0 *(1st July, 2019)*
-------------------------------------
* Ensures middleware doesn't break chain of events by always calling next.
* Fixes `syncIntegrationCode` method to make useable outside of framework.
* Ensures SEGMCVIDTracker is property initialized.
* Avoids performing an idsync if no MCVID is available. 

Version 1.0.2 *(1st July, 2019)*
-------------------------------------
* Adds additional unit tests for buildIntegrationsObject.

Version 1.0.1 *(1st July, 2019)*
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
