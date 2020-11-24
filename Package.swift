// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "SwiftIO",
    dependencies: [
        .package(url: "https://github.com/Esri/SwiftUtilities.git", .branch("develop"))
    ]
)
