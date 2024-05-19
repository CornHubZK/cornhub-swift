// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-project",
    platforms: [ .macOS(.v10_15), .iOS(.v14) ],
    dependencies: [
        .package(url: "https://github.com/Swoir/Swoir.git", exact: "0.19.4-2")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(name: "swift-project", dependencies: ["Swoir"])
    ]
)
