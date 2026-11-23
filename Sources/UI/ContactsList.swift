import SwiftUI

enum ListLocation { case contacts, favorites, groupContacts }

/// item_contact_with_number / item_contact_without_number (+ grid variants).
struct ContactRow: View {
    @Environment(Config.self) private var config
    @Environment(\.palette) private var palette
    let contact: Contact
    var highlight = ""
    var selected = false
    var grid = false
    var onAvatarTap: (() -> Void)?

    var body: some View {
        let name = contact.nameToDisplay(startWithSurname: config.startNameWithSurname)
        let size = palette.fontSize
        let number = contact.phoneNumbers.first.map { config.formatPhoneNumbers ? $0.value.formattedPhoneNumber : $0.value }
        if grid {
            VStack(spacing: 6) {
                avatar(name, size: 72)
                Text(highlighted(name, highlight, color: palette.primaryColor))
                    .font(.system(size: size * 0.85))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                if config.showPhoneNumbers, let number {
                    Text(highlighted(number, highlight, color: palette.primaryColor))
                        .font(.system(size: size * 0.7))
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(1)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(selected ? palette.primaryColor.opacity(0.25) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
        } else {
            HStack(spacing: 16) {
                if config.showContactThumbnails {
                    avatar(name, size: 44)
                        .onTapGesture { onAvatarTap?() }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(highlighted(name, highlight, color: palette.primaryColor))
                        .font(.system(size: size))
                        .lineLimit(1)
                    if config.showPhoneNumbers, let number {
                        Text(highlighted(number, highlight, color: palette.primaryColor))
                            .font(.system(size: size * 0.8))
                            .foregroundStyle(palette.secondaryText)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, config.showPhoneNumbers ? 8 : 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? palette.primaryColor.opacity(0.25) : .clear)
            .contentShape(Rectangle())
        }
    }

    @ViewBuilder private func avatar(_ name: String, size: CGFloat) -> some View {
        ZStack(alignment: .bottomTrailing) {
            Avatar(name: name, image: contact.thumbnail, size: size)
            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(palette.onPrimary, palette.primaryColor)
                    .background(Circle().fill(palette.backgroundColor).padding(2))
            }
        }
    }
}

/// The list of a contacts fragment: rows, letter fast scroller, selection.
struct ContactsList: View {
    @Environment(Config.self) private var config
    @Environment(\.palette) private var palette
    let contacts: [Contact]
    let location: ListLocation
    var highlight = ""
    @Binding var selection: Set<String>
    let onClick: (Contact) -> Void
    let onAvatar: (Contact) -> Void
    var onMove: ((IndexSet, Int) -> Void)?
    @State private var scrolledID: String?

    private var grid: Bool { location == .favorites && config.favoritesViewType == .grid }

    var body: some View {
        let sorting = config.sorting
        let surnameFirst = config.startNameWithSurname
        let letters = contacts.map { $0.bubbleLetter(sorting: sorting, startWithSurname: surnameFirst) }
        ZStack(alignment: .trailing) {
                if grid {
                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: max(1, config.contactsGridColumnCount)), spacing: 4) {
                            ForEach(contacts) { c in
                                ContactRow(contact: c, highlight: highlight, selected: selection.contains(c.id), grid: true)
                                    .onTapGesture { tap(c) }
                                    .onLongPressGesture { toggle(c) }
                            }
                        }
                        .padding(8)
                        .padding(.bottom, 90)
                    }
                    .scrollDismissesKeyboard(.immediately)
                } else if let onMove, highlight.isEmpty {
                    // Custom favorites order: drag handles in action mode (enableDrag in ContactsAdapter).
                    List {
                        ForEach(contacts) { c in
                            row(c).listRowInsets(EdgeInsets()).listRowSeparator(.hidden).listRowBackground(palette.backgroundColor)
                        }
                        .onMove(perform: onMove)
                        Color.clear.frame(height: 80).listRowBackground(palette.backgroundColor).listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .environment(\.editMode, .constant(selection.isEmpty ? .inactive : .active))
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(contacts) { c in row(c) }
                        }
                        .scrollTargetLayout()
                        .padding(.bottom, 90)
                        .padding(.trailing, 24)
                    }
                    .scrollPosition(id: $scrolledID, anchor: .top)
                    .scrollDismissesKeyboard(.immediately)
                }

                if !grid && contacts.count > 0 && (onMove == nil || !highlight.isEmpty) {
                    let firsts = Self.firstIDs(contacts, letters)
                    LetterFastScroller(letters: firsts.map(\.0)) { l in
                        if let id = firsts.first(where: { $0.0 == l })?.1 { scrolledID = id }
                    }
                    .padding(.vertical, 8)
                }
        }
    }

    /// (letter, id of the first contact with that letter), in list order.
    private static func firstIDs(_ contacts: [Contact], _ letters: [String]) -> [(String, String)] {
        var seen = Set<String>()
        var out: [(String, String)] = []
        for (c, l) in zip(contacts, letters) where seen.insert(l).inserted { out.append((l, c.id)) }
        return out
    }

    private func row(_ c: Contact) -> some View {
        ContactRow(contact: c, highlight: highlight, selected: selection.contains(c.id), onAvatarTap: {
            if selection.isEmpty { onAvatar(c) } else { toggle(c) }
        })
        .onTapGesture { tap(c) }
        .onLongPressGesture { toggle(c) }
    }

    private func tap(_ c: Contact) {
        if selection.isEmpty { onClick(c) } else { toggle(c) }
    }

    private func toggle(_ c: Contact) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if selection.contains(c.id) { selection.remove(c.id) } else { selection.insert(c.id) }
    }
}

/// item_group: group icon + "Title (count)".
struct GroupRow: View {
    @Environment(\.palette) private var palette
    let group: ContactGroup
    var highlight = ""
    var selected = false

    var body: some View {
        HStack(spacing: 16) {
            Avatar(name: group.title, size: 44, isGroup: true)
            Text(highlighted("\(group.title) (\(group.contactsCount))", highlight, color: palette.primaryColor))
                .font(.system(size: palette.fontSize))
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(selected ? palette.primaryColor.opacity(0.25) : .clear)
        .contentShape(Rectangle())
    }
}
