import AppKit
import SwiftUI

struct APIKeySecureField: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSSecureTextField {
        let field = NSSecureTextField()
        field.bezelStyle = .roundedBezel
        // NSSecureTextField otherwise triggers Passwords heuristics even when completion is off.
        // An API token is credential-like but not a reusable login password.
        field.contentType = .oneTimeCode
        field.isAutomaticTextCompletionEnabled = false
        field.delegate = context.coordinator
        field.setAccessibilityLabel("API key")
        return field
    }

    func updateNSView(_ field: NSSecureTextField, context: Context) {
        if field.stringValue != text {
            field.stringValue = text
        }
        context.coordinator.text = $text
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSecureTextField else { return }
            text.wrappedValue = field.stringValue
        }
    }
}
