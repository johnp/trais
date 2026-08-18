// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "trais",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(name: "TraisCore", targets: ["TraisCore"]),
        .executable(name: "trais", targets: ["TraisApp"]),
        .executable(name: "trais-core-checks", targets: ["TraisCoreChecks"]),
    ],
    targets: [
        .target(name: "TraisCore"),
        .executableTarget(
            name: "TraisApp",
            dependencies: ["TraisCore"]
        ),
        .executableTarget(
            name: "TraisCoreChecks",
            dependencies: ["TraisCore"],
            path: "Checks/TraisCoreChecks"
        ),
    ],
    swiftLanguageModes: [.v6]
)
