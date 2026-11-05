// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DDCMenuBar",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "DDCMenuBar", targets: ["DDCMenuBar"]),
    ],
    targets: [
        .executableTarget(name: "DDCMenuBar"),
    ]
)
