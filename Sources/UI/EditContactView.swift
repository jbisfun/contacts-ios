import FossifyCommons
import Contacts
import PhotosUI
import _PhotosUI_SwiftUI
import SwiftUI

/// EditContactActivity.
struct EditContactView: View {
    @Environment(ContactsStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(Config.self) private var config
    @Environment(\.palette) private var palette
    let contactID: String?
    let prefillNumber: String?

    @State private var contact = Contact(id: "")
    @State private var original = Contact(id: "")
    @State private var loaded = false
    @State private var photoItem: PhotosPickerItem?
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var photoMenu = false
    @State private var unsavedPrompt = false
    @State private var confirmDelete = false
    @State private var manageFields = false
    @State private var selectGroups = false
    @State private var selectSource = false
    @State private var share: ShareItem?
    @State private var customLabel: CustomLabelTarget?
    @State private var customLabelText = ""
    @State private var eventEditing: Int?

    private var isNew: Bool { contactID == nil }

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: isNew ? "New contact" : "Edit contact", onBack: back) {
                IconButton(icon: "checkmark", action: save)
                if !isNew {
                    IconButton(icon: "square.and.arrow.up") { share = ShareItem.vcard(store, ids: [contact.id]) }
                    IconButton(icon: "trash") { confirmDelete = true }
                }
                Menu {
                    Button("Manage shown contact fields") { manageFields = true }
                } label: {
                    Image(systemName: "ellipsis").rotationEffect(.degrees(90)).font(.system(size: 18)).frame(width: 40, height: 48)
                }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    photoHeader
                    fields
                }
                .padding(.bottom, 48)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(palette.backgroundColor.ignoresSafeArea())
        .onAppear(perform: load)
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self), let ui = UIImage(data: data) {
                    contact.photo = ui.squareCropped(720).jpegData(compressionQuality: 0.85)
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { ui in contact.photo = ui.squareCropped(720).jpegData(compressionQuality: 0.85) }.ignoresSafeArea()
        }
        .confirmationDialog("", isPresented: $photoMenu) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) { Button("Take photo") { showCamera = true } }
            Button("Choose photo") { showPhotoPicker = true }
            if contact.photo != nil { Button("Remove photo", role: .destructive) {
                contact.photo = nil
                contact.thumbnail = nil
            } }
        }
        .alert("You have unsaved changes. Save before exiting?", isPresented: $unsavedPrompt) {
            Button("Save", action: save)
            Button("Discard", role: .destructive) { router.pop() }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Are you sure you want to delete \(contact.nameToDisplay(startWithSurname: config.startNameWithSurname))?", isPresented: $confirmDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                store.delete([contact.id])
                router.path.removeAll { $0 == .view(contact.id) || $0 == .edit(contact.id) }
            }
        }
        .alert("Custom label", isPresented: Binding(get: { customLabel != nil }, set: { if !$0 { customLabel = nil } })) {
            TextField("Label", text: $customLabelText)
            Button("Cancel", role: .cancel) {}
            Button("OK") {
                if let t = customLabel, !customLabelText.isEmpty { applyCustomLabel(t, customLabelText) }
            }
        }
        .sheet(isPresented: $manageFields) { ManageVisibleFieldsDialog() }
        .sheet(isPresented: $selectGroups) { SelectGroupsDialog(groups: $contact.groups) }
        .sheet(isPresented: $selectSource) {
            RadioDialog(title: "Select account", items: store.sources.map { ($0.id, $0.publicName) }, selected: contact.source) {
                contact.source = $0
                // Groups belong to a container; drop the ones from another source.
                let source = $0
                contact.groups.removeAll { g in g.containerID != source }
            }
        }
        .sheet(item: Binding(get: { eventEditing.map(EventIndex.init) }, set: { eventEditing = $0?.index })) { e in
            if contact.events.indices.contains(e.index) {
                EventDatePicker(date: $contact.events[e.index].date)
            }
        }
        .sheet(item: $share) { ShareSheet(items: [$0.url]) }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let contactID, let c = store.contact(id: contactID) {
            contact = c
        } else {
            contact = Contact(id: "")
            contact.source = store.defaultSourceID
            if let prefillNumber { contact.phoneNumbers = [PhoneNumber(value: prefillNumber)] }
        }
        // Edit screens always show one empty row per shown list field (setupNewContact).
        if contact.phoneNumbers.isEmpty { contact.phoneNumbers = [PhoneNumber(value: "")] }
        if contact.emails.isEmpty { contact.emails = [Email(value: "")] }
        if contact.addresses.isEmpty { contact.addresses = [Address()] }
        if contact.ims.isEmpty { contact.ims = [IM(value: "")] }
        if contact.websites.isEmpty { contact.websites = [Website(value: "")] }
        original = contact
    }

    // MARK: Photo + favorite

    private var photoHeader: some View {
        let name = contact.nameToDisplay(startWithSurname: config.startNameWithSurname)
        return ZStack(alignment: .bottomLeading) {
            Button { photoMenu = true } label: {
                ZStack {
                    if let data = contact.photo ?? contact.thumbnail, let ui = UIImage(data: data) {
                        Image(uiImage: ui).resizable().scaledToFill().frame(width: 180, height: 180).clipShape(Circle())
                    } else {
                        ZStack {
                            Avatar(name: name.isEmpty ? " " : name, size: 180)
                            Image(systemName: "camera.fill").font(.system(size: 28)).foregroundStyle(.white.opacity(0.9)).offset(y: 50)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }
            .buttonStyle(.plain)
            Button { contact.starred.toggle() } label: {
                Image(systemName: contact.starred ? "star.fill" : "star")
                    .font(.system(size: 22))
                    .foregroundStyle(contact.starred ? palette.primaryColor : palette.textColor)
                    .frame(width: 48, height: 48)
            }
            .padding(.leading, 8)
        }
    }

    // MARK: Fields

    @ViewBuilder
    private var fields: some View {
        let show = config.showContactFields
        if !show.intersection(ShowField.names.union(.nickname)).isEmpty {
            group("person") {
                if show.contains(.prefix) { field("Prefix", $contact.prefix) }
                if show.contains(.firstName) { field("First name", $contact.firstName, content: .givenName) }
                if show.contains(.middleName) { field("Middle name", $contact.middleName, content: .middleName) }
                if show.contains(.surname) { field("Surname", $contact.surname, content: .familyName) }
                if show.contains(.suffix) { field("Suffix", $contact.suffix) }
                if show.contains(.nickname) { field("Nickname", $contact.nickname, content: .nickname) }
            }
        }
        if show.contains(.phoneNumbers) {
            group("phone") {
                ForEach($contact.phoneNumbers) { $p in
                    HStack(spacing: 4) {
                        field("Number", $p.value, keyboard: .phonePad, content: .telephoneNumber)
                        if contact.phoneNumbers.count > 1 {
                            let isDefault = config.defaultNumbers[contact.id] == p.value && !p.value.isEmpty
                            Button {
                                if isDefault { config.defaultNumbers[contact.id] = nil } else { config.defaultNumbers[contact.id] = p.value }
                            } label: {
                                Image(systemName: isDefault ? "star.fill" : "star")
                                    .foregroundStyle(isDefault ? palette.primaryColor : palette.secondaryText)
                            }
                            .disabled(contact.id.isEmpty)
                        }
                        typePicker(p.label, Labels.phone) { label in
                            if let label { p.label = label } else { customLabel = .phone(p.id) }
                        }
                        removeButton { contact.phoneNumbers.removeAll { $0.id == p.id } }
                    }
                }
                addButton { contact.phoneNumbers.append(PhoneNumber(value: "")) }
            }
        }
        if show.contains(.emails) {
            group("envelope") {
                ForEach($contact.emails) { $e in
                    HStack(spacing: 4) {
                        field("Email", $e.value, keyboard: .emailAddress, content: .emailAddress)
                        typePicker(e.label, Labels.email) { label in
                            if let label { e.label = label } else { customLabel = .email(e.id) }
                        }
                        removeButton { contact.emails.removeAll { $0.id == e.id } }
                    }
                }
                addButton { contact.emails.append(Email(value: "")) }
            }
        }
        if show.contains(.addresses) {
            group("mappin.and.ellipse") {
                ForEach($contact.addresses) { $a in
                    HStack(alignment: .top, spacing: 4) {
                        VStack(spacing: 0) {
                            if show.contains(.structuredAddresses) {
                                field("Street", $a.street, content: .streetAddressLine1)
                                field("Appartment or suite number", $a.neighborhood)
                                field("City", $a.city, content: .addressCity)
                                field("Postal code", $a.postcode, content: .postalCode)
                                field("State", $a.region, content: .addressState)
                                field("Country", $a.country, content: .countryName)
                            } else {
                                field("Address", $a.street, content: .fullStreetAddress, multiline: true)
                            }
                        }
                        typePicker(a.label, Labels.address) { label in
                            if let label { a.label = label } else { customLabel = .address(a.id) }
                        }
                        removeButton { contact.addresses.removeAll { $0.id == a.id } }
                    }
                }
                addButton { contact.addresses.append(Address()) }
            }
        }
        if show.contains(.ims) {
            group("bubble.left.and.bubble.right") {
                ForEach($contact.ims) { $im in
                    HStack(spacing: 4) {
                        field("Instant messaging (IM)", $im.value)
                        typePicker(im.service, Labels.im) { label in
                            if let label { im.service = label } else { customLabel = .im(im.id) }
                        }
                        removeButton { contact.ims.removeAll { $0.id == im.id } }
                    }
                }
                addButton { contact.ims.append(IM(value: "")) }
            }
        }
        if show.contains(.events) {
            group("birthday.cake") {
                ForEach(Array(contact.events.enumerated()), id: \.element.id) { i, e in
                    HStack(spacing: 4) {
                        Button { eventEditing = i } label: {
                            Text(e.display.isEmpty ? "Date" : e.display)
                                .foregroundStyle(e.display.isEmpty ? palette.secondaryText : palette.textColor)
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        typePicker(e.label, Labels.event) { label in
                            if let label {
                                if label == Event.birthdayLabel { for j in contact.events.indices where contact.events[j].label == label { contact.events[j].label = CNLabelOther } }
                                contact.events[i].label = label
                            } else { customLabel = .event(e.id) }
                        }
                        removeButton { contact.events.removeAll { $0.id == e.id } }
                    }
                }
                addButton {
                    let hasBirthday = contact.events.contains { $0.label == Event.birthdayLabel }
                    let today = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                    contact.events.append(Event(date: today, label: hasBirthday ? CNLabelDateAnniversary : Event.birthdayLabel))
                    eventEditing = contact.events.count - 1
                }
            }
        }
        if show.contains(.organization) {
            group("building.2") {
                field("Company", $contact.organization.company, content: .organizationName)
                field("Job position", $contact.organization.jobPosition, content: .jobTitle)
            }
        }
        if show.contains(.websites) {
            group("link") {
                ForEach($contact.websites) { $w in
                    HStack(spacing: 4) {
                        field("Website", $w.value, keyboard: .URL, content: .URL)
                        removeButton { contact.websites.removeAll { $0.id == w.id } }
                    }
                }
                addButton { contact.websites.append(Website(value: "")) }
            }
        }
        if show.contains(.groups) {
            group("person.3") {
                ForEach(contact.groups) { g in
                    HStack {
                        Button { selectGroups = true } label: {
                            Text(g.title).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        removeButton { contact.groups.removeAll { $0.id == g.id } }
                    }
                }
                Button { selectGroups = true } label: {
                    Text(contact.groups.isEmpty ? "No groups" : "Add to group")
                        .foregroundStyle(contact.groups.isEmpty ? palette.secondaryText : palette.primaryColor)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
        if show.contains(.contactSource) {
            group("person.crop.square") {
                Button { if isNew { selectSource = true } } label: {
                    Text(store.sourceName(contact.source)).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func group<Content: View>(_ icon: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .frame(width: 56, height: 52)
            VStack(alignment: .leading, spacing: 0) { content() }
        }
        .padding(.trailing, 8)
        .padding(.vertical, 6)
    }

    private func field(_ hint: String, _ text: Binding<String>, keyboard: UIKeyboardType = .default,
                       content: UITextContentType? = nil, multiline: Bool = false) -> some View {
        VStack(spacing: 0) {
            TextField(hint, text: text, axis: multiline ? .vertical : .horizontal)
                .keyboardType(keyboard)
                .textContentType(content)
                .textInputAutocapitalization(keyboard == .default ? .words : .never)
                .autocorrectionDisabled(keyboard != .default)
                .font(.system(size: 16))
                .padding(.vertical, 10)
            Rectangle().fill(palette.divider).frame(height: 1)
        }
        .padding(.vertical, 2)
    }

    private func typePicker(_ label: String, _ choices: [LabelChoice], onPick: @escaping (String?) -> Void) -> some View {
        Menu {
            ForEach(choices, id: \.self) { c in Button(c.title) { onPick(c.label) } }
            Button("Custom") { onPick(nil) }
        } label: {
            Text(Labels.title(label, in: choices))
                .font(.system(size: 15))
                .foregroundStyle(palette.textColor)
                .lineLimit(1)
                .frame(minWidth: 70, alignment: .trailing)
                .padding(.vertical, 12)
        }
    }

    private func removeButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "xmark").font(.system(size: 14)).foregroundStyle(palette.secondaryText).frame(width: 32, height: 44)
        }
    }

    private func addButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "plus.circle").font(.system(size: 20)).foregroundStyle(palette.primaryColor).frame(width: 44, height: 44)
        }
    }

    // MARK: Actions

    private func applyCustomLabel(_ t: CustomLabelTarget, _ label: String) {
        switch t {
        case .phone(let id): if let i = contact.phoneNumbers.firstIndex(where: { $0.id == id }) { contact.phoneNumbers[i].label = label }
        case .email(let id): if let i = contact.emails.firstIndex(where: { $0.id == id }) { contact.emails[i].label = label }
        case .address(let id): if let i = contact.addresses.firstIndex(where: { $0.id == id }) { contact.addresses[i].label = label }
        case .im(let id): if let i = contact.ims.firstIndex(where: { $0.id == id }) { contact.ims[i].service = label }
        case .event(let id): if let i = contact.events.firstIndex(where: { $0.id == id }) { contact.events[i].label = label }
        }
        customLabelText = ""
    }

    private func back() {
        if contact != original { unsavedPrompt = true } else { router.pop() }
    }

    private func save() {
        var c = contact
        c.phoneNumbers.removeAll { $0.value.trimmingCharacters(in: .whitespaces).isEmpty }
        c.emails.removeAll { $0.value.trimmingCharacters(in: .whitespaces).isEmpty }
        c.addresses.removeAll(where: \.isEmpty)
        c.ims.removeAll { $0.value.trimmingCharacters(in: .whitespaces).isEmpty }
        c.websites.removeAll { $0.value.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !c.isEmpty else {
            store.toast = "At least 1 field has to be filled out"
            return
        }
        if store.save(c) { router.pop() }
    }
}

enum CustomLabelTarget: Equatable {
    case phone(UUID), email(UUID), address(UUID), im(UUID), event(UUID)
}

struct EventIndex: Identifiable {
    let index: Int
    var id: Int { index }
}

/// MyDatePickerDialog: day/month with an optional year.
struct EventDatePicker: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var date: DateComponents
    @State private var picked = Date()
    @State private var hideYear = false

    var body: some View {
        DialogFrame(title: nil, scroll: false) {
            DatePicker("", selection: $picked, displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
            CheckRow(title: "Hide year", on: $hideYear)
            DialogButtons {
                let c = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: picked)
                date = hideYear ? DateComponents(month: c.month, day: c.day) : c
                dismiss()
            }
        }
        .onAppear {
            var c = date
            hideYear = c.year == nil
            if c.year == nil { c.year = Calendar.current.component(.year, from: Date()) }
            picked = Calendar(identifier: .gregorian).date(from: c) ?? Date()
        }
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        p.sourceType = .camera
        p.delegate = context.coordinator
        return p
    }

    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ p: CameraPicker) { parent = p }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage { parent.onImage(img) }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}

extension UIImage {
    /// Center square crop + downscale (Fossify crops contact photos to a square).
    func squareCropped(_ size: CGFloat) -> UIImage {
        let side = min(self.size.width, self.size.height)
        let target = min(size, side)
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: target, height: target), format: fmt).image { _ in
            let scale = target / side
            let w = self.size.width * scale, h = self.size.height * scale
            draw(in: CGRect(x: (target - w) / 2, y: (target - h) / 2, width: w, height: h))
        }
    }
}
