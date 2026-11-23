import FossifyCommons
import SwiftUI

/// GroupContactsActivity.
struct GroupContactsView: View {
    @Environment(ContactsStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(Config.self) private var config
    @Environment(\.palette) private var palette
    let groupID: String

    @State private var selection = Set<String>()
    @State private var addContacts = false
    @State private var confirmDelete = false
    @State private var callContact: Contact?
    @State private var share: ShareItem?

    var body: some View {
        let group = store.groups.first { $0.id == groupID }
        let members = store.contacts(inGroup: groupID)
            .sorted { Contact.compare($0, $1, sorting: config.sorting, startWithSurname: config.startNameWithSurname) }
        VStack(spacing: 0) {
            if selection.isEmpty {
                TopBar(title: group?.title ?? "") {
                    IconButton(icon: "message") { Launcher.sms(members.compactMap { $0.phoneNumbers.first?.value }) }
                    IconButton(icon: "envelope") { Launcher.email(members.compactMap { $0.emails.first?.value }) }
                }
            } else {
                selectionBar(members)
            }
            ZStack(alignment: .bottomTrailing) {
                if members.isEmpty {
                    Placeholder(text: "This group is empty", action: "Add contacts") { addContacts = true }
                } else {
                    ContactsList(contacts: members, location: .groupContacts, selection: $selection, onClick: click,
                                 onAvatar: { router.push(.view($0.id)) })
                }
                if selection.isEmpty {
                    Fab(icon: "person.badge.plus") { addContacts = true }.padding(16)
                }
            }
        }
        .background(palette.backgroundColor.ignoresSafeArea())
        .callFlow($callContact)
        .sheet(isPresented: $addContacts) {
            let all = store.contacts().sorted { Contact.compare($0, $1, sorting: config.sorting, startWithSurname: config.startNameWithSurname) }
            SelectContactsDialog(all: all, initiallySelected: Set(members.map(\.id))) { added, removed in
                if !added.isEmpty { store.addContacts(Array(added), toGroup: groupID) }
                if !removed.isEmpty { store.removeContacts(Array(removed), fromGroup: groupID) }
            }
        }
        .sheet(item: $share) { ShareSheet(items: [$0.url]) }
        .alert("Are you sure you want to delete \(selection.count) contact\(selection.count == 1 ? "" : "s")?", isPresented: $confirmDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                store.delete(Array(selection))
                selection.removeAll()
            }
        }
    }

    private func selectionBar(_ members: [Contact]) -> some View {
        HStack(spacing: 0) {
            IconButton(icon: "xmark") { selection.removeAll() }
            Text("\(selection.count)").font(.system(size: 20, weight: .medium)).padding(.leading, 8)
            Spacer()
            if selection.count == 1 {
                IconButton(icon: "pencil") { if let id = selection.first { selection.removeAll(); router.push(.edit(id)) } }
            }
            IconButton(icon: "minus.circle") {
                store.removeContacts(Array(selection), fromGroup: groupID)
                selection.removeAll()
            }
            Menu {
                Button { share = ShareItem.vcard(store, ids: Array(selection)); selection.removeAll() } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                Button {
                    Launcher.sms(members.filter { selection.contains($0.id) }.compactMap { $0.phoneNumbers.first?.value })
                } label: { Label("Send SMS to contacts", systemImage: "message") }
                Button {
                    Launcher.email(members.filter { selection.contains($0.id) }.compactMap { $0.emails.first?.value })
                } label: { Label("Send email to contacts", systemImage: "envelope") }
                Button { selection = Set(members.map(\.id)) } label: { Label("Select all", systemImage: "checklist") }
                Button(role: .destructive) { confirmDelete = true } label: { Label("Delete", systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis").rotationEffect(.degrees(90)).font(.system(size: 18)).frame(width: 44, height: 48)
            }
        }
        .foregroundStyle(palette.onPrimary)
        .padding(.horizontal, 4)
        .frame(height: 56)
        .background(palette.primaryColor.ignoresSafeArea(edges: .top))
    }

    private func click(_ c: Contact) {
        switch config.onContactClick {
        case .call: callContact = c
        case .view: router.push(.view(c.id))
        case .edit: router.push(.edit(c.id))
        }
    }
}
