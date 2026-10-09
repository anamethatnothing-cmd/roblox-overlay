// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RobloxOverlay",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "RobloxOverlay", targets: ["RobloxOverlay"])],
    targets: [.executableTarget(name: "RobloxOverlay")]
)
