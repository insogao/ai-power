// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AIPower",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "AIPowerCore", targets: ["AIPowerCore"]),
        .library(name: "AIPowerIPC", targets: ["AIPowerIPC"]),
        .library(name: "AIPowerSystem", targets: ["AIPowerSystem"]),
        .library(name: "AIPowerHelperSupport", targets: ["AIPowerHelperSupport"]),
        .executable(name: "AIPowerApp", targets: ["AIPowerApp"]),
        .executable(name: "AIPowerContinuityHelper", targets: ["AIPowerContinuityHelper"]),
    ],
    targets: [
        .target(
            name: "AIPowerCore"
        ),
        .target(
            name: "AIPowerIPC",
            dependencies: ["AIPowerCore"]
        ),
        .target(
            name: "AIPowerSystem",
            dependencies: ["AIPowerCore", "AIPowerHelperSupport", "AIPowerIPC"]
        ),
        .target(
            name: "AIPowerHelperSupport",
            dependencies: ["AIPowerCore", "AIPowerIPC"]
        ),
        .executableTarget(
            name: "AIPowerApp",
            dependencies: ["AIPowerCore", "AIPowerSystem"],
            sources: [
                "AI_PowerApp.swift",
                "AppModel.swift",
                "DebugLogStore.swift",
                "DiscoverFeed.swift",
                "MenuBarStatusController.swift",
                "MenuBarView.swift",
                "WakeTrackLayout.swift",
                "WarningOrbitArtwork.swift",
                "WaveformBadgeArtwork.swift",
            ]
        ),
        .executableTarget(
            name: "AIPowerContinuityHelper",
            dependencies: ["AIPowerCore", "AIPowerHelperSupport", "AIPowerIPC"]
        ),
        .testTarget(
            name: "AIPowerCoreTests",
            dependencies: ["AIPowerCore"]
        ),
        .testTarget(
            name: "AIPowerIPCTests",
            dependencies: ["AIPowerIPC"]
        ),
        .testTarget(
            name: "AIPowerHelperSupportTests",
            dependencies: ["AIPowerHelperSupport"]
        ),
        .testTarget(
            name: "AIPowerSystemTests",
            dependencies: ["AIPowerSystem"]
        ),
        .testTarget(
            name: "AIPowerAppTests",
            dependencies: ["AIPowerApp", "AIPowerCore", "AIPowerSystem"]
        ),
    ]
)
