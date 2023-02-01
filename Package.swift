// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

//See how ObjC sorces are declared in here for reference
https://github.com/segmentio/analytics-ios/blob/master/Package.swift

let package = Package(
    name: "analytics-ios-mcvid",
    platforms: [
        .macOS("10.15"),
        .iOS("13.0"),
        .tvOS("11.0"),
        .watchOS("7.1")
    ],
    products: [
        .library(
            name: "analytics-ios-mcvid",
            targets: ["analytics-ios-mcvid"]
        ),
    ],
    dependencies: [
        .package(
            name: "Segment",
            url: "https://github.com/segmentio/analytics-ios.git",
            from: "4.1.7"
        )
    ],
    targets: [
        .target(
            name: "analytics-ios-mcvid",
            dependencies: ["Segment"],
            path: "AnalyticsMVCID"
        ),
    ]
)
