// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "HoopsTicker",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "HoopsTicker",
            path: "Sources/HoopsTicker"
        )
    ]
)
