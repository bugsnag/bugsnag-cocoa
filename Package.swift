// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "Bugsnag",
    platforms: [
        .macOS(.v10_11),
        .tvOS("9.2"),
        .iOS("9.0"),
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
                .headerSearchPath("KSCrash"),
                .headerSearchPath("KSCrash/Source/KSCrash/Recording"),
                .headerSearchPath("KSCrash/Source/KSCrash/Recording/Sentry"),
                .headerSearchPath("KSCrash/Source/KSCrash/Recording/Tools"),
                .headerSearchPath("KSCrash/Source/KSCrash/Reporting/Filters"),
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
