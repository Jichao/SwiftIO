// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "SwiftIO",
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "SwiftIO",
            targets: ["SwiftIO","SwiftIOSupport"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Esri/SwiftUtilities.git", .branch("develop"))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "SwiftIO",
            dependencies: ["SwiftIOSupport", "SwiftUtilities"]),
        .target(
            name: "SwiftIOSupport",
            dependencies: []
        )
    ]
)
