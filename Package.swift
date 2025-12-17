// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-file-system",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
    ],
    products: [
        .library(name: "File System", targets: ["File System"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-system", from: "1.4.0"),
        .package(url: "https://github.com/swift-standards/swift-standards", from: "0.16.1"),
        .package(url: "https://github.com/swift-standards/swift-incits-4-1986", from: "0.6.5"),
        .package(url: "https://github.com/swift-standards/swift-rfc-4648", from: "0.5.0"),
    ],
    targets: [
        .target(
            name: "File System",
            dependencies: [
                .product(name: "SystemPackage", package: "swift-system"),
                .product(name: "Binary", package: "swift-standards"),
                .product(name: "INCITS 4 1986", package: "swift-incits-4-1986"),
                .product(name: "RFC 4648", package: "swift-rfc-4648"),
            ],
            path: "Sources/File System"
        ),
        .testTarget(
            name: "File System Tests",
            dependencies: [
                "File System",
            ],
            path: "Tests/File System Tests"
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin].contains(target.type) {
    let existing = target.swiftSettings ?? []
    target.swiftSettings = existing + [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
    ]
}
