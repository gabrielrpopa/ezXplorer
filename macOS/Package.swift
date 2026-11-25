// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ezXplorer",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ezXplorer", targets: ["ezXplorer"])
    ],
    targets: [
        .executableTarget(
            name: "ezXplorer",
            path: "ezXplorer",
            exclude: [
                "Info.plist",
                "ezXplorer.entitlements",
                "Assets.xcassets"
            ]
        )
    ]
)
