// SwiftPM has no app-extension product type. Xcode links extensions with `-e _NSExtensionMain`;
// we get the same result by handing control to Foundation's NSExtensionMain from main.
import Foundation

@_silgen_name("NSExtensionMain")
private func NSExtensionMain(_ argc: Int32, _ argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) -> Int32

exit(NSExtensionMain(CommandLine.argc, CommandLine.unsafeArgv))
