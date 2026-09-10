// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NotchOTP",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "NotchOTP", targets: ["NotchOTP"])],
    targets: [
        .target(name: "OTPCore"),
        .executableTarget(name: "NotchOTP", dependencies: ["OTPCore"]),
        .testTarget(name: "OTPCoreTests", dependencies: ["OTPCore"]),
        .testTarget(name: "AppTests", dependencies: ["NotchOTP", "OTPCore"])
    ]
)
