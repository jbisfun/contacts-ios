import SwiftUI

/// ViewContactActivity.
struct ViewContactView: View {
    @Environment(ContactsStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(Config.self) private var config
    @Environment(\.palette) private var palette
    let contactID: String

    @State private var contact: Contact?
    @State private var showBigPhoto = false
    @State private var confirmDelete = false
    @State private var manageFields = false
    @State private var share: ShareItem?
    @State private var callContact: Contact?
    @State private var confirmCall: String?

    var body: some View {
        ZStack(alignment: .top) {
            if let contact {
                let full = merged(contact)
                ScrollView {
                    VStack(spacing: 0) {
                        header(full)
                        details(full)
                    }
                    .padding(.bottom, 32)
                }
                if showBigPhoto, let data = full.photo ?? full.thumbnail, let ui = UIImage(data: data) {
                    Color.black.opacity(0.85).ignoresSafeArea()
                        .onTapGesture { withAnimation { showBigPhoto = false } }
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(16)
                        .frame(maxHeight: .infinity)
                        .onTapGesture { withAnimation { showBigPhoto = false } }
                        .transition(.opacity)
                }
            }
            TopBar(title: "", background: .clear, tint: hasPhoto ? .white : nil) {
                IconButton(icon: "pencil") { router.push(.edit(contactID)) }
                IconButton(icon: "square.and.arrow.up") { share = ShareItem.vcard(store, ids: shareIDs) }
                IconButton(icon: "trash") { confirmDelete = true }
                Menu {
                    Button("Manage shown contact fields") { manageFields = true }
                } label: {
                    Image(systemName: "ellipsis").rotationEffect(.degrees(90)).font(.system(size: 18)).frame(width: 40, height: 48)
                }
            }
        }
        .background(palette.backgroundColor.ignoresSafeArea())
        .onAppear(perform: load)
        .onChange(of: store.allContacts) { _, _ in load() }
        .callFlow($callContact)
        .sheet(isPresented: $manageFields) { ManageVisibleFieldsDialog() }
        .sheet(item: $share) { ShareSheet(items: [$0.url]) }
        .alert("Are you sure you want to delete \(contact?.nameToDisplay(startWithSurname: config.startNameWithSurname) ?? "")?", isPresented: $confirmDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                let ids = shareIDs
                router.pop()
                store.delete(ids)
            }
        } message: {
            if config.mergeDuplicateContacts && !store.duplicates(of: contact ?? Contact(id: "")).isEmpty {
                Text("The contact will be removed from all contact sources.")
            }
        }
        .alert("Call \(confirmCall ?? "")?", isPresented: Binding(get: { confirmCall != nil }, set: { if !$0 { confirmCall = nil } })) {
            Button("Cancel", role: .cancel) {}
            Button("Call") { if let n = confirmCall { Launcher.call(n) } }
        }
    }

    private var hasPhoto: Bool { !showBigPhoto && (contact?.photo ?? contact?.thumbnail) != nil }

    private var shareIDs: [String] {
        guard let contact else { return [] }
        return [contact.id] + (config.mergeDuplicateContacts ? store.duplicates(of: contact).map(\.id) : [])
    }

    private func load() {
        if let c = store.contact(id: contactID) {
            contact = c
        } else if store.access == .granted && !store.loading && router.path.last == .view(contactID) {
            router.pop()
        }
    }

    /// fullContact: fields of duplicate contacts merged in (ViewContactActivity.setup*).
    private func merged(_ c: Contact) -> Contact {
        guard config.mergeDuplicateContacts else { return c }
        var full = c
        for d in store.duplicates(of: c) {
            full.phoneNumbers += d.phoneNumbers
            full.emails += d.emails
            full.addresses += d.addresses
            full.events += d.events
            full.ims += d.ims
            full.websites += d.websites
            full.groups += d.groups
            if full.organization.isEmpty { full.organization = d.organization }
            if full.photo == nil { full.photo = store.contact(id: d.id)?.photo }
        }
        var seen = Set<String>()
        full.phoneNumbers = full.phoneNumbers.filter { seen.insert($0.comparable).inserted }
        seen.removeAll()
        full.emails = full.emails.filter { seen.insert($0.value.lowercased()).inserted }
        seen.removeAll()
        full.addresses = full.addresses.filter { seen.insert($0.value.lowercased()).inserted }
        seen.removeAll()
        full.events = full.events.filter { seen.insert($0.display + $0.label).inserted }
        seen.removeAll()
        full.ims = full.ims.filter { seen.insert($0.value + $0.service).inserted }
        seen.removeAll()
        full.websites = full.websites.filter { seen.insert($0.value).inserted }
        seen.removeAll()
        full.groups = full.groups.filter { seen.insert($0.id).inserted }
        return full
    }

    // MARK: Header (photo, favorite, actions)

    private func header(_ c: Contact) -> some View {
        let name = c.nameToDisplay(startWithSurname: config.startNameWithSurname)
        return VStack(spacing: 0) {
            ZStack {
                if let data = c.photo ?? c.thumbnail, let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 300)
                        .clipped()
                        .overlay(alignment: .top) {
                            LinearGradient(colors: [.black.opacity(0.5), .clear], startPoint: .top, endPoint: .bottom).frame(height: 100)
                        }
                        .onTapGesture { withAnimation { showBigPhoto = true } }
                } else {
                    Avatar(name: name, size: 200)
                        .frame(maxWidth: .infinity)
                        .frame(height: 300)
                        .padding(.top, 40)
                }
            }
            HStack(spacing: 0) {
                Button {
                    var updated = c
                    updated.starred.toggle()
                    if updated.starred { store.addFavorites([c.id]) } else { store.removeFavorites([c.id]) }
                    contact?.starred = updated.starred
                } label: {
                    Image(systemName: c.starred ? "star.fill" : "star")
                        .font(.system(size: 22))
                        .foregroundStyle(c.starred ? palette.primaryColor : palette.textColor)
                        .frame(width: 48, height: 48)
                }
                Spacer()
                if !c.emails.isEmpty {
                    IconButton(icon: "envelope") { trySendEmail(c) }
                }
                if !c.phoneNumbers.isEmpty {
                    IconButton(icon: "phone") { callContact = c }
                    IconButton(icon: "message") { trySendSMS(c) }
                }
            }
            .foregroundStyle(palette.textColor)
            .padding(.horizontal, 8)
        }
    }

    // MARK: Details

    @ViewBuilder
    private func details(_ c: Contact) -> some View {
        let show = config.showContactFields
        let name = c.nameToDisplay(startWithSurname: config.startNameWithSurname)
        VStack(alignment: .leading, spacing: 0) {
            if !name.isEmpty && !c.isABusinessContact && !show.intersection(ShowField.names).isEmpty {
                section("person") {
                    DetailRow(text: c.nickname.isEmpty || !show.contains(.nickname) ? name : "\(name) (\(c.nickname))",
                              copy: name)
                }
            }
            if show.contains(.phoneNumbers) && !c.phoneNumbers.isEmpty {
                section("phone") {
                    ForEach(c.phoneNumbers) { p in
                        DetailRow(text: config.formatPhoneNumbers ? p.value.formattedPhoneNumber : p.value,
                                  type: Labels.title(p.label, in: Labels.phone),
                                  isDefault: config.defaultNumbers[c.id] == p.value && c.phoneNumbers.count > 1,
                                  copy: p.value) {
                            if config.showCallConfirmation { confirmCall = p.value } else { Launcher.call(p.value) }
                        }
                    }
                }
            }
            if show.contains(.emails) && !c.emails.isEmpty {
                section("envelope") {
                    ForEach(c.emails) { e in
                        DetailRow(text: e.value, type: Labels.title(e.label, in: Labels.email), copy: e.value) { Launcher.email([e.value]) }
                    }
                }
            }
            if show.contains(.addresses) && !c.addresses.isEmpty {
                section("mappin.and.ellipse") {
                    ForEach(c.addresses) { a in
                        DetailRow(text: a.value, type: Labels.title(a.label, in: Labels.address), copy: a.value, multiline: true) {
                            Launcher.map(a.value)
                        }
                    }
                }
            }
            if show.contains(.ims) && !c.ims.isEmpty {
                section("bubble.left.and.bubble.right") {
                    ForEach(c.ims) { im in
                        DetailRow(text: im.value, type: Labels.title(im.service, in: Labels.im), copy: im.value)
                    }
                }
            }
            if show.contains(.events) && !c.events.isEmpty {
                section("birthday.cake") {
                    ForEach(c.events) { e in
                        DetailRow(text: e.display, type: Labels.title(e.label, in: Labels.event), copy: e.display)
                    }
                }
            }
            if show.contains(.organization) && !c.organization.isEmpty {
                section("building.2") {
                    if !c.organization.company.isEmpty { DetailRow(text: c.organization.company, copy: c.organization.company) }
                    if !c.organization.jobPosition.isEmpty { DetailRow(text: c.organization.jobPosition, copy: c.organization.jobPosition) }
                }
            }
            if show.contains(.websites) && !c.websites.isEmpty {
                section("link") {
                    ForEach(c.websites) { w in
                        DetailRow(text: w.value, copy: w.value) { Launcher.website(w.value) }
                    }
                }
            }
            if show.contains(.groups) && !c.groups.isEmpty {
                section("person.3") {
                    ForEach(c.groups) { g in
                        DetailRow(text: g.title, copy: g.title) { router.push(.group(g.id)) }
                    }
                }
            }
            if show.contains(.contactSource) {
                section("person.crop.square") {
                    let ids = [c.id] + (config.mergeDuplicateContacts ? store.duplicates(of: c).map(\.id) : [])
                    ForEach(ids, id: \.self) { id in
                        let src = store.allContacts.first { $0.id == id }?.source ?? ""
                        DetailRow(text: store.sourceName(src)) {
                            router.push(.edit(id))
                        }
                    }
                }
            }
        }
        .padding(.top, 8)
    }

    private func section<Content: View>(_ icon: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(palette.textColor)
                .frame(width: 56, height: 46)
            VStack(alignment: .leading, spacing: 0) { content() }
        }
        .padding(.trailing, 12)
        .padding(.vertical, 4)
    }

    private func trySendSMS(_ c: Contact) {
        if c.phoneNumbers.count == 1 { Launcher.sms([c.phoneNumbers[0].value]); return }
        let d = config.defaultNumbers[c.id]
        Launcher.sms([d ?? c.phoneNumbers[0].value])
    }

    private func trySendEmail(_ c: Contact) {
        Launcher.email([c.emails[0].value])
    }
}

/// item_view_phone_number / item_view_email / ...: value on the left, type on the right.
struct DetailRow: View {
    @Environment(\.palette) private var palette
    let text: String
    var type: String?
    var isDefault = false
    var copy: String?
    var multiline = false
    var action: (() -> Void)?

    var body: some View {
        Button { action?() } label: {
            HStack(spacing: 8) {
                Text(text)
                    .font(.system(size: 16))
                    .foregroundStyle(palette.textColor)
                    .lineLimit(multiline ? nil : 1)
                    .multilineTextAlignment(.leading)
                if isDefault {
                    Image(systemName: "star.fill").font(.system(size: 13)).foregroundStyle(palette.primaryColor)
                }
                Spacer(minLength: 8)
                if let type {
                    Text(type)
                        .font(.system(size: 16))
                        .foregroundStyle(palette.textColor)
                        .frame(minWidth: 70, alignment: .trailing)
                }
            }
            .frame(minHeight: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let copy {
                Button { UIPasteboard.general.string = copy } label: { Label("Copy", systemImage: "doc.on.doc") }
            }
        }
    }
}
