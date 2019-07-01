#
# Be sure to run `pod lib lint analytics-ios-mcvid.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'analytics-ios-mcvid'
  s.version          = '1.0.1'
  s.summary          = 'Append marketingCloudId to identify calls with analytics-ios-mcvid.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
Analytics-ios-mcvid requests the marketingCloudId from Adobe and appends it to identify calls in the integration specific object.
                       DESC

  s.homepage         = 'https://github.com/segmentio/analytics-ios-mcvid.git'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'briemcnally' => 'brienne.mcnally@segment.com' }
  s.source           = { :git => 'https://github.com/segmentio/analytics-ios-mcvid.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/SegmentEng'

  s.ios.deployment_target = '8.0'

  s.source_files = 'analytics-ios-mcvid/Classes/**/*'

  s.dependency 'Analytics', '~> 3.6.0'
end
