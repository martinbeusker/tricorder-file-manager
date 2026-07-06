// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "LCARSOps",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "LCARSOps",
            path: "Sources/LCARSOps"
        )
    ]
)
