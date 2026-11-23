import SwiftUI
import UniformTypeIdentifiers

/// ChangeSortingDialog.
struct ChangeSortingDialog: View {
    @Environment(Config.self) private var config
    @Environment(\.dismiss) private var dismiss
    let showCustomSorting: Bool
    @State private var field = Sort.firstName
    @State private var descending = false

    private var options: [(Int, String)] {
        var o = [(Sort.firstName, "First name"), (Sort.middleName, "Middle name"), (Sort.surname, "Surname"),
                 (Sort.fullName, "Full name"), (Sort.dateCreated, "Date created")]
        if showCustomSorting { o.append((Sort.custom, "Custom")) }
        return o
    }

    var body: some View {
        DialogFrame(title: "Sort by") {
            ForEach(options, id: \.0) { o in
                Button { field = o.0 } label: { RadioRow(title: o.1, on: field == o.0) }.buttonStyle(.plain)
            }
            if field != Sort.custom {
                Divider().padding(.vertical, 8)
                Button { descending = false } label: { RadioRow(title: "Ascending", on: !descending) }.buttonStyle(.plain)
                Button { descending = true } label: { RadioRow(title: "Descending", on: descending) }.buttonStyle(.plain)
            }
            DialogButtons {
                if field == Sort.custom {
                    config.isCustomOrderSelected = true
                } else {
                    if showCustomSorting { config.isCustomOrderSelected = false }
                    config.sorting = field | (descending ? Sort.descending : 0)
                }
                dismiss()
            }
        }
        .onAppear {
            let s = config.sorting
            field = [Sort.firstName, Sort.middleName, Sort.surname, Sort.fullName].first { s & $0 != 0 } ?? Sort.dateCreated
            if showCustomSorting && config.isCustomOrderSelected { field = Sort.custom }
            descending = s & Sort.descending != 0
        }
    }
}

/// FilterContactSourcesDialog: which contact sources (accounts) are shown.
struct FilterContactSourcesDialog: View {
    @Environment(ContactsStore.self) private var store
    @Environment(Config.self) private var config
    @Environment(\.dismiss) private var dismiss
    @State private var shown = Set<String>()

    var body: some View {
        DialogFrame(title: nil) {
            ForEach(store.sources) { s in
                let count = store.allContacts.filter { $0.source == s.id }.count
                CheckRow(title: "\(s.publicName) (\(count))", on: Binding(
                    get: { shown.contains(s.id) },
                    set: { if $0 { shown.insert(s.id) } else { shown.remove(s.id) } }))
            }
            DialogButtons {
                config.ignoredContactSources = Set(store.sources.map(\.id)).subtracting(shown)
                dismiss()
            }
        }
        .onAppear { shown = Set(store.sources.map(\.id)).subtracting(config.ignoredContactSources) }
    }
}

/// SelectContactsDialog (add/remove favorites).
struct SelectContactsDialog: View {
    @Environment(Config.self) private var config
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    let all: [Contact]
    let initiallySelected: Set<String>
    let onDone: (Set<String>, Set<String>) -> Void
    @State private var selected = Set<String>()
    @State private var query = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(palette.secondaryText)
                TextField("Search contacts", text: $query).autocorrectionDisabled()
            }
            .padding(12)
            .background(Capsule().fill(palette.backgroundColor))
            .padding(16)
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(all.filter { query.isEmpty || $0.matches(query, startWithSurname: config.startNameWithSurname) }) { c in
                        Button {
                            if selected.contains(c.id) { selected.remove(c.id) } else { selected.insert(c.id) }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: selected.contains(c.id) ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 20))
                                    .foregroundStyle(selected.contains(c.id) ? palette.primaryColor : palette.secondaryText)
                                ContactRow(contact: c)
                            }
                            .padding(.leading, 16)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            DialogButtons {
                onDone(selected.subtracting(initiallySelected), initiallySelected.subtracting(selected))
                dismiss()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .background(palette.surface.ignoresSafeArea())
        .presentationDetents([.large])
        .onAppear { selected = initiallySelected }
    }
}

/// CreateNewGroupDialog (with "Create group under account").
struct CreateNewGroupDialog: View {
    @Environment(ContactsStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var onCreated: (ContactGroup) -> Void = { _ in }
    @State private var title = ""
    @State private var source = ""

    var body: some View {
        DialogFrame(title: "Create a new group", scroll: false) {
            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)
                .padding(.bottom, 12)
            if store.sources.count > 1 {
                Text("Create group under account").font(.system(size: 14))
                ForEach(store.sources) { s in
                    Button { source = s.id } label: { RadioRow(title: s.publicName, on: source == s.id) }.buttonStyle(.plain)
                }
            }
            DialogButtons(okEnabled: !title.trimmingCharacters(in: .whitespaces).isEmpty) {
                if let g = store.createGroup(title.trimmingCharacters(in: .whitespaces), containerID: source.isEmpty ? nil : source) {
                    onCreated(g)
                }
                dismiss()
            }
        }
        .onAppear { source = store.defaultSourceID }
    }
}

struct RenameGroupDialog: View {
    @Environment(ContactsStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let group: ContactGroup
    @State private var title = ""

    var body: some View {
        DialogFrame(title: "Rename", scroll: false) {
            TextField("Title", text: $title).textFieldStyle(.roundedBorder)
            DialogButtons(okEnabled: !title.trimmingCharacters(in: .whitespaces).isEmpty) {
                store.renameGroup(group.id, to: title.trimmingCharacters(in: .whitespaces))
                dismiss()
            }
        }
        .onAppear { title = group.title }
    }
}

/// Single group picker used by "Add to group" (the action mode item).
struct SelectGroupDialog: View {
    @Environment(ContactsStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let onPick: (ContactGroup) -> Void
    @State private var creating = false

    var body: some View {
        DialogFrame(title: "Add to group") {
            ForEach(store.groups) { g in
                Button {
                    onPick(g)
                    dismiss()
                } label: { RadioRow(title: g.title, on: false) }.buttonStyle(.plain)
            }
            Button { creating = true } label: {
                Label("Create a new group", systemImage: "plus").padding(.vertical, 12)
            }
        }
        .sheet(isPresented: $creating) {
            CreateNewGroupDialog { g in
                onPick(g)
                dismiss()
            }
        }
    }
}

/// SelectGroupsDialog (edit screen): multi-select of groups.
struct SelectGroupsDialog: View {
    @Environment(ContactsStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Binding var groups: [ContactGroup]
    @State private var selected = Set<String>()
    @State private var creating = false

    var body: some View {
        DialogFrame(title: nil) {
            ForEach(store.groups) { g in
                CheckRow(title: g.title, on: Binding(
                    get: { selected.contains(g.id) },
                    set: { if $0 { selected.insert(g.id) } else { selected.remove(g.id) } }))
            }
            Button { creating = true } label: {
                Label("Create a new group", systemImage: "plus").padding(.vertical, 12)
            }
            DialogButtons {
                groups = store.groups.filter { selected.contains($0.id) }
                dismiss()
            }
        }
        .onAppear { selected = Set(groups.map(\.id)) }
        .sheet(isPresented: $creating) { CreateNewGroupDialog { g in selected.insert(g.id) } }
    }
}

/// ManageVisibleFieldsDialog.
struct ManageVisibleFieldsDialog: View {
    @Environment(Config.self) private var config
    @Environment(\.dismiss) private var dismiss
    @State private var fields = ShowField()

    var body: some View {
        DialogFrame(title: nil) {
            ForEach(ShowField.manageable, id: \.0.rawValue) { f in
                CheckRow(title: f.1, on: Binding(
                    get: { fields.contains(f.0) },
                    set: { if $0 { fields.insert(f.0) } else { fields.remove(f.0) } }))
            }
            DialogButtons {
                config.showContactFields = fields
                dismiss()
            }
        }
        .onAppear { fields = config.showContactFields }
    }
}

/// ManageVisibleTabsDialog.
struct ManageVisibleTabsDialog: View {
    @Environment(Config.self) private var config
    @Environment(\.dismiss) private var dismiss
    @State private var mask = 0

    var body: some View {
        DialogFrame(title: nil, scroll: false) {
            ForEach(Tab.allCases) { t in
                CheckRow(title: t.title, on: Binding(
                    get: { mask & t.rawValue != 0 },
                    set: { mask = $0 ? mask | t.rawValue : mask & ~t.rawValue }))
            }
            DialogButtons(okEnabled: mask != 0) {
                config.showTabs = mask
                if config.defaultTab != Tab.lastUsed && mask & config.defaultTab == 0 { config.defaultTab = Tab.lastUsed }
                dismiss()
            }
        }
        .onAppear { mask = config.showTabs }
    }
}

/// ImportContactsDialog: pick the target contact source for a .vcf.
struct ImportContactsDialog: View {
    @Environment(ContactsStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let url: URL
    @State private var target = ""

    var body: some View {
        DialogFrame(title: "Import contacts") {
            Text("Target contact source").font(.system(size: 14)).padding(.bottom, 4)
            ForEach(store.sources) { s in
                Button { target = s.id } label: { RadioRow(title: s.publicName, on: target == s.id) }.buttonStyle(.plain)
            }
            DialogButtons {
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                if let data = try? Data(contentsOf: url) {
                    let (ok, failed) = store.importVCard(data, into: target.isEmpty ? nil : target)
                    if ok == 0 {
                        store.toast = "No entries for importing have been found"
                    } else if failed > 0 {
                        store.toast = "Importing some entries failed"
                    } else {
                        store.toast = "Importing successful"
                    }
                } else {
                    store.toast = "An unknown error occurred"
                }
                dismiss()
            }
        }
        .onAppear { target = store.defaultSourceID }
    }
}

/// ExportContactsDialog: filename + included contact sources.
struct ExportContactsDialog: View {
    @Environment(ContactsStore.self) private var store
    @Environment(Config.self) private var config
    @Environment(\.dismiss) private var dismiss
    let onExport: (URL) -> Void
    @State private var filename = ""
    @State private var included = Set<String>()

    var body: some View {
        DialogFrame(title: "Export contacts") {
            Text("Filename (without .vcf)").font(.system(size: 14))
            TextField("", text: $filename).textFieldStyle(.roundedBorder).padding(.bottom, 12)
            Text("Include contact sources").font(.system(size: 14))
            ForEach(store.sources) { s in
                CheckRow(title: s.publicName, on: Binding(
                    get: { included.contains(s.id) },
                    set: { if $0 { included.insert(s.id) } else { included.remove(s.id) } }))
            }
            DialogButtons(okEnabled: !filename.isEmpty && !included.isEmpty) {
                let ignored = Set(store.sources.map(\.id)).subtracting(included)
                do {
                    let (data, count) = try store.vcard(sources: ignored)
                    if count == 0 {
                        store.toast = "No entries for exporting have been found"
                    } else {
                        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename + ".vcf")
                        try data.write(to: url, options: .atomic)
                        config.lastExportFilename = filename
                        onExport(url)
                    }
                } catch {
                    store.toast = "Exporting failed"
                }
                dismiss()
            }
        }
        .onAppear {
            filename = config.lastExportFilename.isEmpty ? "contacts_\(BackupScheduler.filename("%Y_%M_%D_%h_%m_%s"))" : config.lastExportFilename
            included = Set(store.sources.map(\.id))
        }
    }
}

/// ManageAutoBackupsDialog.
struct ManageAutoBackupsDialog: View {
    @Environment(ContactsStore.self) private var store
    @Environment(Config.self) private var config
    @Environment(\.dismiss) private var dismiss
    @State private var filename = ""
    @State private var included = Set<String>()

    var body: some View {
        DialogFrame(title: "Manage automatic backups") {
            Text("Backups are stored in On My iPhone › Contacts › Backups.")
                .font(.system(size: 14)).padding(.bottom, 8)
            Text("Filename (without .vcf)").font(.system(size: 14))
            TextField("", text: $filename).textFieldStyle(.roundedBorder)
            Text("Example: \(BackupScheduler.filename(filename)).vcf").font(.system(size: 12)).padding(.vertical, 6)
            Text("Include contact sources").font(.system(size: 14))
            ForEach(store.sources) { s in
                CheckRow(title: s.publicName, on: Binding(
                    get: { included.contains(s.id) },
                    set: { if $0 { included.insert(s.id) } else { included.remove(s.id) } }))
            }
            DialogButtons(okEnabled: !filename.isEmpty && !included.isEmpty) {
                config.autoBackupFilename = filename
                config.autoBackupContactSources = included
                if !config.autoBackup {
                    // Like scheduleNextAutomaticBackup(): the first backup runs at the next 6 AM.
                    config.autoBackup = true
                    config.lastAutoBackupTime = Date().timeIntervalSince1970
                }
                dismiss()
            }
        }
        .onAppear {
            filename = config.autoBackupFilename
            included = config.autoBackupContactSources.isEmpty ? Set(store.sources.map(\.id)) : config.autoBackupContactSources
        }
    }
}

/// The dialpad (Fossify Contacts launches the Phone app's dialer).
struct DialpadView: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(Router.self) private var router
    @Environment(ContactsStore.self) private var store
    @Environment(Config.self) private var config
    @State private var number = ""

    private let keys: [(String, String)] = [
        ("1", ""), ("2", "ABC"), ("3", "DEF"), ("4", "GHI"), ("5", "JKL"), ("6", "MNO"),
        ("7", "PQRS"), ("8", "TUV"), ("9", "WXYZ"), ("*", ""), ("0", "+"), ("#", ""),
    ]

    var body: some View {
        let matches = number.isEmpty ? [] : store.contacts().filter { c in
            c.phoneNumbers.contains { $0.normalized.contains(number.normalizedPhoneNumber) }
        }.prefix(5)
        VStack(spacing: 12) {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(matches)) { c in
                        Button {
                            if let n = c.phoneNumbers.first(where: { $0.normalized.contains(number.normalizedPhoneNumber) }) { number = n.normalized }
                        } label: { ContactRow(contact: c, highlight: number) }
                        .buttonStyle(.plain)
                    }
                    if !number.isEmpty {
                        Button {
                            let n = number
                            dismiss()
                            router.push(.newContact(number: n))
                        } label: {
                            Label("Add number to contact", systemImage: "person.badge.plus")
                                .padding(.vertical, 12)
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)

            HStack {
                Text(config.formatPhoneNumbers ? number.formattedPhoneNumber : number)
                    .font(.system(size: 32))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: .infinity)
                if !number.isEmpty {
                    Button { number.removeLast() } label: { Image(systemName: "delete.left").font(.system(size: 22)) }
                        .simultaneousGesture(LongPressGesture().onEnded { _ in number = "" })
                }
            }
            .padding(.horizontal, 24)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(keys, id: \.0) { k in
                    Button { number += k.0 } label: {
                        VStack(spacing: 0) {
                            Text(k.0).font(.system(size: 30))
                            Text(k.1).font(.system(size: 11)).foregroundStyle(palette.secondaryText)
                        }
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(LongPressGesture().onEnded { _ in if k.0 == "0" { number += "+" } })
                }
            }
            .padding(.horizontal, 24)

            Button { Launcher.call(number) } label: {
                Image(systemName: "phone.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(Color(argb: 0xFF388E3C)))
            }
            .disabled(number.isEmpty)
            .padding(.bottom, 8)
        }
        .foregroundStyle(palette.textColor)
        .padding(.top, 16)
        .background(palette.backgroundColor.ignoresSafeArea())
        .presentationDetents([.large])
    }
}
