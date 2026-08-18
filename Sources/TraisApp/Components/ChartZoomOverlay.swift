import AppKit
import SwiftUI

struct ChartZoomOverlay: NSViewRepresentable {
    let onScroll: (CGFloat) -> Void

    func makeNSView(context: Context) -> ScrollCapturingView {
        let view = ScrollCapturingView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ view: ScrollCapturingView, context: Context) {
        view.onScroll = onScroll
    }
}

final class ScrollCapturingView: NSView {
    var onScroll: ((CGFloat) -> Void)?

    override var acceptsFirstResponder: Bool { false }
    override var isOpaque: Bool { false }

    override func scrollWheel(with event: NSEvent) {
        onScroll?(event.scrollingDeltaY)
    }
}

struct AxisBreakMark: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: 0, y: size.height))
            path.addLine(to: CGPoint(x: size.width * 0.4, y: 0))
            path.move(to: CGPoint(x: size.width * 0.6, y: size.height))
            path.addLine(to: CGPoint(x: size.width, y: 0))
            context.stroke(path, with: .color(.secondary), lineWidth: 1.5)
        }
        .frame(width: 10, height: 7)
        .accessibilityHidden(true)
    }
}
