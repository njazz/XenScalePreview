// iOS app: the viewer (ViewerUI) in a window. It also carries the Quick Look extension (Files, Mail, Messages and AirDrop
// previews of .scl files). Files handed over from Files or the share sheet ("Open in…") arrive through onOpenURL.
import SwiftUI
import ViewerUI

@main
struct XenScalePreviewApp: App {
    var body: some Scene {
        WindowGroup {
            ViewerView()
                .onOpenURL { url in Task { @MainActor in ViewerModel.shared.open(url) } }
        }
    }
}
