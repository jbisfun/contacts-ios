import FossifyCommons
import SwiftUI
import UIKit

/// Round contact image or letter placeholder (SimpleContactsHelper.getContactLetterIcon).
struct Avatar: View {
    let name: String
    var image: Data?
    var size: CGFloat = 44
    var isGroup = false

    var body: some View {
        if let image, let ui = UIImage(data: image) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            let colors = letterBackgroundColors
            let idx = Int(abs(Int64(name.javaHashCode)) % Int64(colors.count))
            ZStack {
                Circle().fill(Color(argb: colors[idx]))
                if isGroup {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: size * 0.36))
                        .foregroundStyle(.white)
                } else {
                    Text(name.nameLetter)
                        .font(.system(size: size * 0.45))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: size, height: size)
        }
    }
}

/// MyFloatingActionButton.
struct Fab: View {
    @Environment(\.palette) private var palette
    var icon = "plus"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(palette.onPrimary)
                .frame(width: 56, height: 56)
                .background(Circle().fill(palette.primaryColor))
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}

/// Two-line placeholder shown when a tab has nothing to show.
struct Placeholder: View {
    @Environment(\.palette) private var palette
    let text: String
    var action: String?
    var onAction: () -> Void = {}

    var body: some View {
        VStack(spacing: 16) {
            Text(text)
                .font(.system(size: 17, weight: .regular).italic())
                .foregroundStyle(palette.textColor)
                .multilineTextAlignment(.center)
            if let action {
                Button(action: onAction) {
                    Text(action)
                        .font(.system(size: 17))
                        .underline()
                        .foregroundStyle(palette.primaryColor)
                }
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// com.reddit.indicatorfastscroll: a column of letters along the right edge with
/// a thumb bubble showing the letter currently being scrolled to.
struct LetterFastScroller: View {
    @Environment(\.palette) private var palette
    let letters: [String]
    let onSelect: (String) -> Void
    @State private var active: String?
    @State private var activeY: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let rowH = min(18, geo.size.height / CGFloat(max(letters.count, 1)))
            let total = rowH * CGFloat(letters.count)
            let top = (geo.size.height - total) / 2
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 0) {
                    ForEach(letters, id: \.self) { l in
                        Text(l)
                            .font(.system(size: min(12, rowH * 0.8), weight: .medium))
                            .foregroundStyle(l == active ? palette.primaryColor : palette.textColor)
                            .frame(width: 24, height: rowH)
                    }
                }
                .frame(width: 24)
                .padding(.top, top)
                .overlay {
                    // UIKit touch strip: a SwiftUI DragGesture here gets cancelled by the
                    // tab pager's UIScrollView pan as soon as the finger moves.
                    TouchStrip { y in
                        guard let y else { active = nil; return }
                        let idx = min(max(Int((y - top) / rowH), 0), letters.count - 1)
                        guard letters.indices.contains(idx) else { return }
                        activeY = top + CGFloat(idx) * rowH + rowH / 2
                        if active != letters[idx] {
                            active = letters[idx]
                            UISelectionFeedbackGenerator().selectionChanged()
                            onSelect(letters[idx])
                        }
                    }
                }

                if let active {
                    Text(active)
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(palette.onPrimary)
                        .frame(width: 64, height: 64)
                        .background(
                            UnevenRoundedRectangle(topLeadingRadius: 32, bottomLeadingRadius: 32, bottomTrailingRadius: 4, topTrailingRadius: 32)
                                .fill(palette.primaryColor)
                        )
                        .offset(x: -40, y: activeY - 32)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topTrailing)
        }
        .frame(width: 110)
    }
}

/// Reports the finger's y position (nil when lifted) from touch-down on, and makes
/// every enclosing scroll view (list, tab pager) wait until the finger is lifted.
struct TouchStrip: UIViewRepresentable {
    let onTouch: (CGFloat?) -> Void

    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.backgroundColor = .clear
        let g = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handle(_:)))
        g.minimumPressDuration = 0
        g.allowableMovement = .greatestFiniteMagnitude
        g.delegate = context.coordinator
        v.addGestureRecognizer(g)
        return v
    }

    func updateUIView(_ v: UIView, context: Context) { context.coordinator.onTouch = onTouch }
    func makeCoordinator() -> Coordinator { Coordinator(onTouch: onTouch) }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onTouch: (CGFloat?) -> Void
        init(onTouch: @escaping (CGFloat?) -> Void) { self.onTouch = onTouch }

        @objc func handle(_ g: UILongPressGestureRecognizer) {
            switch g.state {
            case .began, .changed: onTouch(g.location(in: g.view).y)
            default: onTouch(nil)
            }
        }

        func gestureRecognizer(_ g: UIGestureRecognizer, shouldBeRequiredToFailBy other: UIGestureRecognizer) -> Bool {
            other.view is UIScrollView
        }

        func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            false
        }
    }
}
