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

/// RadioGroupDialog from Fossify Commons.
struct RadioDialog<T: Hashable>: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    let title: String?
    let items: [(T, String)]
    let selected: T
    let onPick: (T) -> Void

    var body: some View {
        DialogFrame(title: title) {
            ForEach(items, id: \.0) { item in
                Button {
                    onPick(item.0)
                    dismiss()
                } label: {
                    RadioRow(title: item.1, on: item.0 == selected)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct RadioRow: View {
    @Environment(\.palette) private var palette
    let title: String
    let on: Bool

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: on ? "largecircle.fill.circle" : "circle")
                .font(.system(size: 20))
                .foregroundStyle(on ? palette.primaryColor : palette.secondaryText)
            Text(title).foregroundStyle(palette.textColor)
            Spacer()
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

struct CheckRow: View {
    @Environment(\.palette) private var palette
    let title: String
    @Binding var on: Bool

    var body: some View {
        Button { on.toggle() } label: {
            HStack(spacing: 16) {
                Image(systemName: on ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20))
                    .foregroundStyle(on ? palette.primaryColor : palette.secondaryText)
                Text(title).foregroundStyle(palette.textColor).multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Material-style dialog body presented as a sheet.
struct DialogFrame<Content: View>: View {
    @Environment(\.palette) private var palette
    let title: String?
    var scroll = true
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(palette.textColor)
                    .padding(.bottom, 8)
            }
            if scroll {
                ScrollView { VStack(alignment: .leading, spacing: 0, content: content) }
            } else {
                VStack(alignment: .leading, spacing: 0, content: content)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

struct DialogButtons: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    var ok = "OK"
    var okEnabled = true
    let onOK: () -> Void

    var body: some View {
        HStack(spacing: 24) {
            Spacer()
            Button("Cancel") { dismiss() }
            Button(ok) { onOK() }.disabled(!okEnabled)
        }
        .font(.system(size: 16, weight: .medium))
        .foregroundStyle(palette.primaryColor)
        .padding(.top, 16)
    }
}

/// Toast replacement (Android Toast -> transient capsule).
struct ToastModifier: ViewModifier {
    @Binding var text: String?

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let text {
                Text(text)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.black.opacity(0.8)))
                    .padding(.bottom, 100)
                    .transition(.opacity)
                    .task(id: text) {
                        try? await Task.sleep(for: .seconds(2.5))
                        withAnimation { self.text = nil }
                    }
            }
        }
        .animation(.default, value: text)
    }
}

extension View {
    func toast(_ text: Binding<String?>) -> some View { modifier(ToastModifier(text: text)) }

    /// Fossify settings section header ("Color customization", "General", ...).
    func sectionHeader(_ palette: Palette) -> some View {
        self.font(.system(size: 14, weight: .bold))
            .foregroundStyle(palette.primaryColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 8)
    }
}

/// Wraps a View in a NavigationStack-less themed screen with a top app bar.
struct TopBar<Trailing: View>: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    let title: String
    var onBack: (() -> Void)?
    var background: Color?
    var tint: Color?
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 4) {
            Button {
                if let onBack { onBack() } else { dismiss() }
            } label: {
                Image(systemName: "arrow.left").font(.system(size: 20)).frame(width: 48, height: 48)
            }
            Text(title)
                .font(.system(size: 21, weight: .medium))
                .lineLimit(1)
            Spacer()
            trailing()
        }
        .foregroundStyle(tint ?? palette.textColor)
        .padding(.horizontal, 4)
        .frame(height: 56)
        .background(background ?? palette.backgroundColor)
    }
}

extension TopBar where Trailing == EmptyView {
    init(title: String, onBack: (() -> Void)? = nil) {
        self.init(title: title, onBack: onBack, background: nil, tint: nil, trailing: { EmptyView() })
    }
}

struct IconButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 19)).frame(width: 44, height: 48)
        }
    }
}
