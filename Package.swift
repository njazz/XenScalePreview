// swift-tools-version:5.9
// SwiftPM builds the macOS app via build_macos.sh (it can't produce .app/.appex bundles itself, so the script
// wraps the executables). iOS and Xcode builds use project.yml (XcodeGen), which compiles Sources/SclCore into its own static library targets.
import PackageDescription

let package = Package(
    name: "XenScalePreview",
    platforms: [.macOS(.v12), .iOS(.v16)], // data-based QLPreviewProvider needs macOS 12 / iOS 15
    products: [
        .library(name: "SclCore", targets: ["SclCore"]),
    ],
    targets: [
        // .scl text -> HTML (wheel, keyboard, table, source). No Quick Look dependency, so it's testable via the CLI.
        .target(name: "SclCore"),
        // Quick Look preview extension (becomes XenScalePreviewExtension.appex). macOS only here; Xcode builds
        // compile the same PreviewProvider.swift for iOS too.
        .executableTarget(name: "XenScalePreviewExtension", dependencies: ["SclCore"]),
        // macOS host app that carries the extension and declares the .scl type (becomes XenScalePreview.app).
        .executableTarget(name: "XenScalePreview"),
        // Dev tool: `swift run scl2html file.scl > out.html`
        .executableTarget(name: "scl2html", dependencies: ["SclCore"]),
    ]
)
