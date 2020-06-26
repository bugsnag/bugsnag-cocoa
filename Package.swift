// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "Bugsnag",
    platforms: [
        .macOS(.v10_11),
        .tvOS("9.2"),
        .iOS("9.3"),
    ],
    products: [
        .library(name: "Bugsnag", targets: ["Bugsnag"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Bugsnag",
            dependencies: [],
            path: "Bugsnag",
            sources: [
                ".",
                "Breadcrumbs",
                "Client",
                "Configuration",
                "Delivery",
                "Helpers",
                "KSCrash",
                "Metadata",
                "Payload",
                "Plugins",
                "KSCrash/Source/KSCrash/Reporting/Filters",
                "KSCrash/Source/KSCrash/Recording/Tools",
                "KSCrash/Source/KSCrash/Recording",
                "KSCrash/Source/KSCrash/Recording/Sentry",
            ],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("."),
                .headerSearchPath("include/Bugsnag"),
                .headerSearchPath("Breadcrumbs"),
                .headerSearchPath("Client"),
                .headerSearchPath("Configuration"),
                .headerSearchPath("Delivery"),
                .headerSearchPath("Helpers"),
                .headerSearchPath("KSCrash"),
                .headerSearchPath("Metadata"),
                .headerSearchPath("Payload"),
                .headerSearchPath("Plugins"),
                .headerSearchPath("Storage"),
                .headerSearchPath("KSCrash/Source/KSCrash/Reporting/Filters"),
                .headerSearchPath("KSCrash/Source/KSCrash/Recording/Tools"),
                .headerSearchPath("KSCrash/Source/KSCrash/Recording"),
                .headerSearchPath("KSCrash/Source/KSCrash/Recording/Sentry"),
            ],
            linkerSettings: [
                .linkedLibrary("z"),
                .linkedLibrary("c++"),
            ]
        ),
    ],
    cLanguageStandard: .gnu11,
    cxxLanguageStandard: .gnucxx14
)
