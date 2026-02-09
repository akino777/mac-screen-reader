// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MacScreenReader",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .executable(
            name: "MacScreenReader",
            targets: ["MacScreenReader"]
        )
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "MacScreenReader",
            swiftSettings: [
                // Allow use of APIs that are deprecated in newer macOS versions
                // but required for compatibility with macOS 10.15-14.x
                .unsafeFlags(["-Xfrontend", "-disable-availability-checking"])
            ]
        )
    ]
)
