// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "STMURLAsset",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "STMURLAsset",
            targets: ["STMURLAsset"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.9.1"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "STMURLAsset",
            dependencies: [
                .product(name: "Alamofire", package: "Alamofire")
            ],
            path: "STMURLAsset"),
        .testTarget(
            name: "STMURLAssetTests",
            dependencies: ["STMURLAsset"], 
            path: "STMURLAssetTests"),
    ],
    swiftLanguageVersions: [.version("6")]
)
