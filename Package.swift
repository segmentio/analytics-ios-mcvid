// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

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
        .package(url: "https://github.com/sch-devios/analytics-ios", branch: "master")
    ],
    targets: [
        .target(
            name: "analytics-ios-mcvid",
            dependencies: [
                .product(name: "Segment", package: "analytics-ios")
            ],
            path: "AnalyticsMVCID"
        ),
    ]
)
