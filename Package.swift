// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "Bugsnag",
    platforms: [
        .iOS(.v12),
        .tvOS(.v12),
        .macOS(.v10_14),
        .watchOS("6.3"),
    ],
    products: [
        .library(name: "Bugsnag", targets: ["Bugsnag"]),
        .library(name: "BugsnagNetworkRequestPlugin", targets: ["BugsnagNetworkRequestPlugin"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Bugsnag",
            dependencies: [],
            path: "Bugsnag",
            exclude: [
                "KSCrash/Package.swift",
                "KSCrash/Samples",
                "KSCrash/Tests",
                "KSCrash/Sources/KSCrashTestTools",
                "KSCrash/Sources/KSCrashSinks/include/KSCrashReportSinkConsole.h",
                "KSCrash/Sources/KSCrashSinks/include/KSCrashReportSinkEMail.h",
                "KSCrash/Sources/KSCrashSinks/KSCrashReportSinkConsole.m",
                "KSCrash/Sources/KSCrashSinks/KSCrashReportSinkEMail.m",
                "KSCrash/Sources/KSCrashInstallations/include/KSCrashInstallationEmail.h",
                "KSCrash/Sources/KSCrashInstallations/KSCrashInstallationEmail.m",
                "KSCrash/Sources/KSCrashInstallations/include/KSCrashInstallationConsole.h",
                "KSCrash/Sources/KSCrashInstallations/KSCrashInstallationConsole.m"
            ],
            resources: [
               .process("resources/PrivacyInfo.xcprivacy")
            ],
            publicHeadersPath: "include",
            cSettings: [
                .define("NS_BLOCK_ASSERTIONS", .when(configuration: .release)),
                .define("NDEBUG", .when(configuration: .release)),
                .headerSearchPath("."),
                .headerSearchPath("Breadcrumbs"),
                .headerSearchPath("Client"),
                .headerSearchPath("Configuration"),
                .headerSearchPath("Delivery"),
                .headerSearchPath("FeatureFlags"),
                .headerSearchPath("Helpers"),
                .headerSearchPath("include/Bugsnag"),
                .headerSearchPath("KSCrash/Sources/KSCrashReportingCore/include"),
                .headerSearchPath("KSCrash/Sources/KSCrashBootTimeMonitor/include"),
                .headerSearchPath("KSCrash/Sources/KSCrashCore/include"),
                .headerSearchPath("KSCrash/Sources/KSCrashDemangleFilter/include"),
                .headerSearchPath("KSCrash/Sources/KSCrashDiscSpaceMonitor/include"),
                .headerSearchPath("KSCrash/Sources/KSCrashFilters"),
                .headerSearchPath("KSCrash/Sources/KSCrashFilters/include"),
                .headerSearchPath("KSCrash/Sources/KSCrashRecording"),
                .headerSearchPath("KSCrash/Sources/KSCrashRecording/include"),
                .headerSearchPath("KSCrash/Sources/KSCrashRecording/Monitors"),
                .headerSearchPath("KSCrash/Sources/KSCrashRecordingCore/include"),
                .headerSearchPath("KSCrash/Sources/KSCrashDemangleFilter/swift"),
                .headerSearchPath("KSCrash/Sources/KSCrashDemangleFilter/swift/Basic"),
                .headerSearchPath("KSCrash/Sources/KSCrashDemangleFilter/llvm/ADT"),
                .headerSearchPath("KSCrash/Sources/KSCrashDemangleFilter/llvm/Config"),
                .headerSearchPath("KSCrash/Sources/KSCrashDemangleFilter/llvm/Support"),
                .headerSearchPath("KSCrash/Sources/KSCrashSinks/include"),
                .headerSearchPath("KSCrash/Sources/KSCrashInstallations"),
                .headerSearchPath("KSCrash/Sources/KSCrashInstallations/include"),
                .headerSearchPath("KSCrashLegacy"),
                .headerSearchPath("Metadata"),
                .headerSearchPath("Payload"),
                .headerSearchPath("Plugins"),
                .headerSearchPath("Storage"),
            ],
            linkerSettings: [
                .linkedLibrary("z"),
                .linkedLibrary("c++"),
            ]
        ),
        .target(
            name: "BugsnagNetworkRequestPlugin",
            dependencies: ["Bugsnag"],
            path: "BugsnagNetworkRequestPlugin/BugsnagNetworkRequestPlugin",
            publicHeadersPath: "include",
            cSettings: [
                .define("NS_BLOCK_ASSERTIONS", .when(configuration: .release)),
                .define("NDEBUG", .when(configuration: .release)),
                .headerSearchPath("."),
                .headerSearchPath("include/BugsnagNetworkRequestPlugin"),
            ]
        ),
    ],
    cLanguageStandard: .gnu11,
    cxxLanguageStandard: .gnucxx14
)
