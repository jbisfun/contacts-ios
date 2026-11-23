import SwiftUI

/// tryInitiateCall + CallConfirmationDialog + number chooser.
struct CallFlow: ViewModifier {
    @Environment(Config.self) private var config
    @Environment(\.palette) private var palette
    @Binding var contact: Contact?
    @State private var confirmNumber: String?
    @State private var choose: Contact?

    func body(content: Content) -> some View {
        content
            .onChange(of: contact) { _, c in
                guard let c else { return }
                contact = nil
                start(c)
            }
            .alert("Call \(confirmNumber ?? "")?", isPresented: Binding(get: { confirmNumber != nil }, set: { if !$0 { confirmNumber = nil } })) {
                Button("Cancel", role: .cancel) {}
                Button("Call") { if let n = confirmNumber { Launcher.call(n) } }
            }
            .sheet(item: $choose) { c in
                ChooseNumberDialog(contact: c) { number, remember in
                    if remember { config.defaultNumbers[c.id] = number }
                    call(number)
                }
                .environment(\.palette, palette)
            }
    }

    private func start(_ c: Contact) {
        if c.phoneNumbers.count == 1 {
            call(c.phoneNumbers[0].value)
        } else if let d = config.defaultNumbers[c.id], c.phoneNumbers.contains(where: { $0.value == d }) {
            call(d)
        } else if c.phoneNumbers.count > 1 {
            choose = c
        }
    }

    func call(_ number: String) {
        if config.showCallConfirmation { confirmNumber = number } else { Launcher.call(number) }
    }
}

struct ChooseNumberDialog: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    let contact: Contact
    let onPick: (String, Bool) -> Void
    @State private var remember = false

    var body: some View {
        DialogFrame(title: "Select a number") {
            ForEach(contact.phoneNumbers) { n in
                Button {
                    onPick(n.value, remember)
                    dismiss()
                } label: {
                    HStack {
                        Text(n.value).foregroundStyle(palette.textColor)
                        Spacer()
                        Text(Labels.title(n.label, in: Labels.phone)).foregroundStyle(palette.secondaryText)
                    }
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            CheckRow(title: "Remember this choice (set as default)", on: $remember)
        }
    }
}

extension View {
    func callFlow(_ contact: Binding<Contact?>) -> some View { modifier(CallFlow(contact: contact)) }
}

struct MainView: View {
    @Environment(ContactsStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(Config.self) private var config
    @Environment(\.palette) private var palette

    @State private var tab: Tab = .contacts
    @State private var didPickTab = false
    @State private var query = ""
    @State private var searching = false
    @FocusState private var searchFocused: Bool
    @State private var selectedContacts = Set<String>()
    @State private var selectedGroups = Set<String>()
    @State private var callContact: Contact?

    @State private var showSorting = false
    @State private var showFilter = false
    @State private var showDialpad = false
    @State private var showAddFavorites = false
    @State private var showCreateGroup = false
    @State private var showAddToGroup = false
    @State private var showColumnCount = false
    @State private var confirmDelete = false
    @State private var renameGroup: ContactGroup?
    @State private var share: ShareItem?

    private var visibleTabs: [Tab] { Tab.allCases.filter { config.isTabVisible($0) } }

    var body: some View {
        let contacts = sortedContacts()
        let favorites = favoriteContacts(contacts)
        VStack(spacing: 0) {
            if !selectedContacts.isEmpty || !selectedGroups.isEmpty {
                selectionBar(contacts)
            } else {
                searchBar
            }
            TabView(selection: $tab) {
                ForEach(visibleTabs) { t in
                    page(t, contacts: contacts, favorites: favorites)
                        .tag(t)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .overlay(alignment: .bottom) {
                if config.showDialpadButton && selectedContacts.isEmpty {
                    Button { showDialpad = true } label: {
                        Image(systemName: "circle.grid.3x3.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(palette.onPrimary)
                            .frame(width: 56, height: 56)
                            .background(Circle().fill(palette.primaryColor))
                            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                    }
                    .padding(.bottom, 16)
                }
            }
            if visibleTabs.count > 1 { bottomTabs }
        }
        .background(palette.backgroundColor.ignoresSafeArea())
        .onAppear(perform: pickDefaultTab)
        .onChange(of: tab) { _, t in
            config.lastUsedViewPagerPage = t.rawValue
            selectedContacts.removeAll()
            selectedGroups.removeAll()
        }
        .onChange(of: config.showTabs) { _, _ in if !visibleTabs.contains(tab) { tab = visibleTabs.first ?? .contacts } }
        .callFlow($callContact)
        .sheet(isPresented: $showSorting) {
            ChangeSortingDialog(showCustomSorting: tab == .favorites)
        }
        .sheet(isPresented: $showFilter) { FilterContactSourcesDialog() }
        .sheet(isPresented: $showDialpad) { DialpadView() }
        .sheet(isPresented: $showAddFavorites) {
            SelectContactsDialog(all: contacts, initiallySelected: Set(favorites.map(\.id))) { added, removed in
                store.addFavorites(Array(added))
                store.removeFavorites(Array(removed))
            }
        }
        .sheet(isPresented: $showCreateGroup) { CreateNewGroupDialog() }
        .sheet(isPresented: $showAddToGroup) {
            SelectGroupDialog { group in
                store.addContacts(Array(selectedContacts), toGroup: group.id)
                selectedContacts.removeAll()
            }
        }
        .sheet(isPresented: $showColumnCount) {
            RadioDialog(title: nil, items: (1...10).map { ($0, "\($0) column\($0 == 1 ? "" : "s")") }, selected: config.contactsGridColumnCount) {
                config.contactsGridColumnCount = $0
            }
        }
        .sheet(item: $renameGroup) { g in RenameGroupDialog(group: g) }
        .sheet(item: $share) { item in ShareSheet(items: [item.url]) }
        .alert(deleteQuestion, isPresented: $confirmDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if tab == .groups {
                    store.deleteGroups(Array(selectedGroups))
                    selectedGroups.removeAll()
                } else {
                    store.delete(Array(selectedContacts))
                    selectedContacts.removeAll()
                }
            }
        } message: {
            if tab != .groups && config.mergeDuplicateContacts { Text("The contact will be removed from all contact sources.") }
        }
    }

    // MARK: Pages

    @ViewBuilder
    private func page(_ t: Tab, contacts: [Contact], favorites: [Contact]) -> some View {
        let q = query.trimmingCharacters(in: .whitespaces)
        ZStack(alignment: .bottomTrailing) {
            switch t {
            case .contacts:
                let list = filtered(contacts, q)
                if list.isEmpty {
                    if q.isEmpty {
                        Placeholder(text: "No contacts found", action: "Change filter") { showFilter = true }
                    } else {
                        Placeholder(text: "No contacts found")
                    }
                } else {
                    ContactsList(contacts: list, location: .contacts, highlight: q, selection: $selectedContacts,
                                 onClick: click, onAvatar: { router.push(.view($0.id)) })
                }
            case .favorites:
                let list = filtered(favorites, q)
                if list.isEmpty {
                    if q.isEmpty {
                        Placeholder(text: "Seems like you haven't added any favorite contacts yet.", action: "Add favorites") { showAddFavorites = true }
                    } else {
                        Placeholder(text: "No contacts found")
                    }
                } else {
                    ContactsList(contacts: list, location: .favorites, highlight: q, selection: $selectedContacts,
                                 onClick: click, onAvatar: { router.push(.view($0.id)) },
                                 onMove: config.isCustomOrderSelected ? { from, to in moveFavorite(list, from, to) } : nil)
                }
            case .groups:
                let groups = store.groups.filter { q.isEmpty || $0.title.localizedCaseInsensitiveContains(q) }
                if groups.isEmpty {
                    if q.isEmpty {
                        Placeholder(text: "There are no contact groups on the device", action: "Create group") { showCreateGroup = true }
                    } else {
                        Placeholder(text: "No items found")
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(groups) { g in
                                GroupRow(group: g, highlight: q, selected: selectedGroups.contains(g.id))
                                    .onTapGesture {
                                        if selectedGroups.isEmpty { router.push(.group(g.id)) } else { toggleGroup(g) }
                                    }
                                    .onLongPressGesture { toggleGroup(g) }
                            }
                        }
                        .padding(.bottom, 90)
                    }
                }
            }

            if selectedContacts.isEmpty && selectedGroups.isEmpty {
                Fab {
                    switch t {
                    case .contacts: router.push(.newContact(number: nil))
                    case .favorites: showAddFavorites = true
                    case .groups: showCreateGroup = true
                    }
                }
                .padding(16)
            }
        }
        .background(palette.backgroundColor)
    }

    // MARK: Search menu (MySearchMenu)

    private var searchBar: some View {
        HStack(spacing: 0) {
            Button {
                if searching {
                    query = ""
                    searching = false
                    searchFocused = false
                } else {
                    searching = true
                    searchFocused = true
                }
            } label: {
                Image(systemName: searching ? "arrow.left" : "magnifyingglass")
                    .font(.system(size: 18))
                    .frame(width: 48, height: 48)
            }
            TextField("", text: $query, prompt: Text(searchHint).foregroundStyle(palette.secondaryText))
                .focused($searchFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .onChange(of: searchFocused) { _, f in if f { searching = true } }
            if !query.isEmpty {
                IconButton(icon: "xmark") { query = "" }
            }
            Menu {
                if tab != .groups {
                    Button { showSorting = true } label: { Label("Sort by", systemImage: "arrow.up.arrow.down") }
                    Button { showFilter = true } label: { Label("Filter", systemImage: "line.3.horizontal.decrease") }
                }
                if !config.showDialpadButton {
                    Button { showDialpad = true } label: { Label("Dialpad", systemImage: "circle.grid.3x3") }
                }
                if tab == .favorites {
                    Button {
                        config.favoritesViewType = config.favoritesViewType == .grid ? .list : .grid
                    } label: { Label("Change view type", systemImage: config.favoritesViewType == .grid ? "list.bullet" : "square.grid.2x2") }
                    if config.favoritesViewType == .grid {
                        Button { showColumnCount = true } label: { Label("Column count", systemImage: "rectangle.split.3x1") }
                    }
                }
                Button { router.push(.settings) } label: { Label("Settings", systemImage: "gearshape") }
                Button { router.push(.about) } label: { Label("About", systemImage: "info.circle") }
            } label: {
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
                    .font(.system(size: 18))
                    .frame(width: 48, height: 48)
            }
        }
        .foregroundStyle(palette.textColor)
        .background(Capsule().fill(palette.surface))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var searchHint: String {
        switch tab {
        case .contacts: return "Search contacts"
        case .favorites: return "Search favorites"
        case .groups: return "Search groups"
        }
    }

    // MARK: Action mode (cab.xml / cab_groups.xml)

    private func selectionBar(_ contacts: [Contact]) -> some View {
        let isGroups = !selectedGroups.isEmpty
        let count = isGroups ? selectedGroups.count : selectedContacts.count
        return HStack(spacing: 0) {
            IconButton(icon: "xmark") {
                selectedContacts.removeAll()
                selectedGroups.removeAll()
            }
            Text("\(count)").font(.system(size: 20, weight: .medium)).padding(.leading, 8)
            Spacer()
            if isGroups {
                if count == 1 {
                    IconButton(icon: "pencil") { renameGroup = store.groups.first { selectedGroups.contains($0.id) } }
                }
                IconButton(icon: "checklist") { selectedGroups = Set(store.groups.map(\.id)) }
                IconButton(icon: "trash") { confirmDelete = true }
            } else {
                if count == 1 {
                    IconButton(icon: "pencil") { if let id = selectedContacts.first { selectedContacts.removeAll(); router.push(.edit(id)) } }
                }
                if tab == .contacts {
                    IconButton(icon: "star") {
                        store.addFavorites(Array(selectedContacts))
                        selectedContacts.removeAll()
                    }
                } else {
                    IconButton(icon: "minus.circle") {
                        store.removeFavorites(Array(selectedContacts))
                        selectedContacts.removeAll()
                    }
                }
                IconButton(icon: "person.2.badge.plus") { showAddToGroup = true }
                Menu {
                    Button { shareSelected() } label: { Label("Share", systemImage: "square.and.arrow.up") }
                    Button { smsSelected(contacts) } label: { Label("Send SMS to contacts", systemImage: "message") }
                    Button { emailSelected(contacts) } label: { Label("Send email to contacts", systemImage: "envelope") }
                    Button { selectAll(contacts) } label: { Label("Select all", systemImage: "checklist") }
                    if tab == .contacts {
                        Button(role: .destructive) { confirmDelete = true } label: { Label("Delete", systemImage: "trash") }
                    }
                } label: {
                    Image(systemName: "ellipsis").rotationEffect(.degrees(90)).font(.system(size: 18)).frame(width: 44, height: 48)
                }
            }
        }
        .foregroundStyle(palette.onPrimary)
        .padding(.horizontal, 4)
        .frame(height: 64)
        .background(palette.primaryColor.ignoresSafeArea(edges: .top))
    }

    private var deleteQuestion: String {
        if tab == .groups {
            let n = selectedGroups.count
            return "Are you sure you want to delete \(n) group\(n == 1 ? "" : "s")?"
        }
        let n = selectedContacts.count
        return "Are you sure you want to delete \(n) contact\(n == 1 ? "" : "s")?"
    }

    // MARK: Tabs

    private var bottomTabs: some View {
        HStack(spacing: 0) {
            ForEach(visibleTabs) { t in
                Button {
                    withAnimation { tab = t }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: t.icon(selected: t == tab)).font(.system(size: 20))
                        Text(t.title).font(.system(size: 13, weight: t == tab ? .semibold : .regular))
                    }
                    .foregroundStyle(t == tab ? palette.primaryColor : palette.textColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(palette.surface.ignoresSafeArea(edges: .bottom))
    }

    // MARK: Helpers

    private func pickDefaultTab() {
        guard !didPickTab else { return }
        didPickTab = true
        let wanted = config.defaultTab == Tab.lastUsed ? config.lastUsedViewPagerPage : config.defaultTab
        tab = visibleTabs.first { $0.rawValue == wanted } ?? visibleTabs.first ?? .contacts
    }

    private func sortedContacts() -> [Contact] {
        let sorting = config.sorting
        let surname = config.startNameWithSurname
        return store.contacts().sorted { Contact.compare($0, $1, sorting: sorting, startWithSurname: surname) }
    }

    private func favoriteContacts(_ contacts: [Contact]) -> [Contact] {
        let favs = contacts.filter(\.starred)
        guard config.isCustomOrderSelected else { return favs }
        let order = Dictionary(config.favoritesContactsOrder.enumerated().map { ($1, $0) }, uniquingKeysWith: { a, _ in a })
        return favs.sorted { (order[$0.id] ?? Int.max) < (order[$1.id] ?? Int.max) }
    }

    private func filtered(_ list: [Contact], _ q: String) -> [Contact] {
        guard !q.isEmpty else { return list }
        let surname = config.startNameWithSurname
        let text = q.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
        let matching = list.filter { $0.matches(text, startWithSurname: surname) }
        // Name matches first, like ContactsFragment.onSearchQueryChanged.
        let first = matching.filter { $0.nameToDisplay(startWithSurname: surname).searchNormalized.contains(text.searchNormalized) }
        let rest = matching.filter { !$0.nameToDisplay(startWithSurname: surname).searchNormalized.contains(text.searchNormalized) }
        return first + rest
    }

    private func moveFavorite(_ list: [Contact], _ from: IndexSet, _ to: Int) {
        var ids = list.map(\.id)
        ids.move(fromOffsets: from, toOffset: to)
        config.favoritesContactsOrder = ids
    }

    private func click(_ c: Contact) {
        switch config.onContactClick {
        case .call: callContact = c
        case .view: router.push(.view(c.id))
        case .edit: router.push(.edit(c.id))
        }
    }

    private func toggleGroup(_ g: ContactGroup) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if selectedGroups.contains(g.id) { selectedGroups.remove(g.id) } else { selectedGroups.insert(g.id) }
    }

    private func selectAll(_ contacts: [Contact]) {
        selectedContacts = Set((tab == .favorites ? contacts.filter(\.starred) : contacts).map(\.id))
    }

    private func shareSelected() {
        share = ShareItem.vcard(store, ids: Array(selectedContacts))
        selectedContacts.removeAll()
    }

    private func smsSelected(_ contacts: [Contact]) {
        Launcher.sms(contacts.filter { selectedContacts.contains($0.id) }.compactMap { $0.phoneNumbers.first?.value })
        selectedContacts.removeAll()
    }

    private func emailSelected(_ contacts: [Contact]) {
        Launcher.email(contacts.filter { selectedContacts.contains($0.id) }.compactMap { $0.emails.first?.value })
        selectedContacts.removeAll()
    }
}

struct ShareItem: Identifiable {
    let url: URL
    var id: URL { url }

    /// shareContacts(): writes a .vcf to the temp dir and shares it.
    @MainActor
    static func vcard(_ store: ContactsStore, ids: [String], name: String? = nil) -> ShareItem? {
        guard let data = try? store.vcard(for: ids) else { return nil }
        let base = name ?? (ids.count == 1 ? store.contact(id: ids[0])?.nameToDisplay(startWithSurname: false) : nil) ?? "contacts"
        let safe = base.replacingOccurrences(of: "/", with: "_")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent((safe.isEmpty ? "contacts" : safe) + ".vcf")
        try? data.write(to: url, options: .atomic)
        return ShareItem(url: url)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
