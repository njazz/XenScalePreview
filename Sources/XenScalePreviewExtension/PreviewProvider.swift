// One Quick Look data-based preview extension for macOS and iOS: both use QLPreviewProvider and
// QLPreviewReply (iOS 15+ in QuickLook, macOS 12+ in QuickLookUI), so the source is shared.
import Foundation
import UniformTypeIdentifiers
import SclCore
#if os(macOS)
import Quartz
#else
import QuickLook
#endif

// Stable Objective-C name so Info.plist can say NSExtensionPrincipalClass = PreviewProvider.
@objc(PreviewProvider)
final class PreviewProvider: QLPreviewProvider, QLPreviewingController {
    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let url = request.fileURL
        let data = try Data(contentsOf: url)
        let html = Scl.html(from: data, fileName: url.lastPathComponent)
        return QLPreviewReply(dataOfContentType: .html, contentSize: CGSize(width: 1100, height: 720)) { reply in
            reply.stringEncoding = .utf8
            return Data(html.utf8)
        }
    }
}
