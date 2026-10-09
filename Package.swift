// swift-tools-version:5.9
// SwiftPM builds the macOS app via build_macos.sh (it can't produce .app/.appex bundles itself, so the script
// wraps the executables). iOS and Xcode builds use project.yml (XcodeGen), which compiles Sources/SclCore into its own static library targets.
import PackageDescription

let package = Package(
    name: "XenScalePreview",
    platforms: [.macOS(.v14), .iOS(.v17)], // keep in step with project.yml
    products: [
        .library(name: "SclCore", targets: ["SclCore"]),
        .library(name: "ViewerUI", targets: ["ViewerUI"]),
    ],
    targets: [
        // .scl text -> HTML (wheel, keyboard, table, source). No Quick Look dependency, so it's testable via the CLI.
        .target(name: "SclCore"),
        // The app window shared by the iOS and macOS apps: folder sidebar, web view with the synth page, open/close.
        .target(name: "ViewerUI", dependencies: ["SclCore"]),
        // Quick Look preview extension (becomes XenScalePreviewExtension.appex). macOS only here; Xcode builds
        // compile the same PreviewProvider.swift for iOS too.
        .executableTarget(name: "XenScalePreviewExtension", dependencies: ["SclCore"]),
        // macOS host app that carries the extension and declares the .scl type (becomes XenScalePreview.app).
        .executableTarget(name: "XenScalePreview", dependencies: ["ViewerUI"]),
        // Dev tool: `swift run scl2html file.scl > out.html`
        .executableTarget(name: "scl2html", dependencies: ["SclCore"]),
    ]
)
