import FossifyCommons
import Contacts
import Foundation
import Observation
import UIKit

/// Port of Fossify's ContactsHelper on top of CNContactStore.
@MainActor
@Observable
final class ContactsStore {
    enum Access { case unknown, granted, denied }

    var access: Access = .unknown
    /// Every contact from every source (before filtering/merging).
    private(set) var allContacts: [Contact] = []
    private(set) var groups: [ContactGroup] = []
    private(set) var sources: [ContactSource] = []
    private(set) var loading = false
    var toast: String?

    @ObservationIgnored private let store = CNContactStore()
    @ObservationIgnored private let config = Config.shared
    @ObservationIgnored private var observer: NSObjectProtocol?
    @ObservationIgnored private var reloadPending = false

    nonisolated static let listKeys: [CNKeyDescriptor] = [
        CNContactIdentifierKey, CNContactNamePrefixKey, CNContactGivenNameKey, CNContactMiddleNameKey,
        CNContactFamilyNameKey, CNContactNameSuffixKey, CNContactNicknameKey, CNContactPhoneNumbersKey,
        CNContactEmailAddressesKey, CNContactPostalAddressesKey, CNContactBirthdayKey, CNContactDatesKey,
        CNContactInstantMessageAddressesKey, CNContactUrlAddressesKey, CNContactOrganizationNameKey,
        CNContactJobTitleKey, CNContactThumbnailImageDataKey, CNContactImageDataAvailableKey,
    ].map { $0 as CNKeyDescriptor }

    nonisolated static let fullKeys: [CNKeyDescriptor] = listKeys + [CNContactImageDataKey as CNKeyDescriptor]
    /// Kept separate from fullKeys so editing never depends on what vCard serialization asks for.
    nonisolated static let vcardKeys: [CNKeyDescriptor] = [CNContactVCardSerialization.descriptorForRequiredKeys()]

    init() {
        observer = NotificationCenter.default.addObserver(forName: .CNContactStoreDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.reload() }
        }
    }

    // MARK: Permission

    func requestAccess() {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        switch status {
        case .authorized, .limited:
            access = .granted
            reload()
        case .notDetermined:
            store.requestAccess(for: .contacts) { ok, _ in
                Task { @MainActor in
                    self.access = ok ? .granted : .denied
                    if ok { self.reload() }
                }
            }
        default:
            access = .denied
        }
    }

    // MARK: Loading

    func reload() {
        guard access == .granted else { return }
        guard !loading else {
            reloadPending = true
            return
        }
        loading = true
        let store = self.store
        Task.detached(priority: .userInitiated) {
            let result = Self.fetchAll(store)
            await MainActor.run {
                self.sources = result.sources
                self.groups = result.groups
                self.allContacts = result.contacts
                self.loading = false
                if self.reloadPending {
                    self.reloadPending = false
                    self.reload()
                }
                self.config.favorites = self.config.favorites.intersection(Set(result.contacts.map(\.id)))
                BackupScheduler.runIfDue(self)
            }
        }
    }

    /// Raw (non-unified) contacts, matching Fossify's per-source raw contacts.
    nonisolated static func raw(_ store: CNContactStore, _ predicate: NSPredicate, _ keys: [CNKeyDescriptor]) -> [CNContact] {
        let req = CNContactFetchRequest(keysToFetch: keys)
        req.predicate = predicate
        req.unifyResults = false
        var out: [CNContact] = []
        try? store.enumerateContacts(with: req) { c, _ in out.append(c) }
        return out
    }

    private func raw(_ ids: [String], _ keys: [CNKeyDescriptor]) -> [CNContact] {
        Self.raw(store, CNContact.predicateForContacts(withIdentifiers: ids), keys)
    }

    private nonisolated static func fetchAll(_ store: CNContactStore) -> (contacts: [Contact], groups: [ContactGroup], sources: [ContactSource]) {
        let containers = (try? store.containers(matching: nil)) ?? []
        let sources = containers.map { ContactSource(id: $0.identifier, name: $0.name, type: $0.type) }

        var groups: [ContactGroup] = []
        var membership: [String: [ContactGroup]] = [:]
        for container in containers {
            let pred = CNGroup.predicateForGroupsInContainer(withIdentifier: container.identifier)
            for g in (try? store.groups(matching: pred)) ?? [] {
                var group = ContactGroup(id: g.identifier, title: g.name, containerID: container.identifier)
                let members = raw(store, CNContact.predicateForContactsInGroup(withIdentifier: g.identifier),
                                  [CNContactIdentifierKey as CNKeyDescriptor])
                group.contactsCount = members.count
                for m in members { membership[m.identifier, default: []].append(group) }
                groups.append(group)
            }
        }

        var contacts: [Contact] = []
        var seen = Set<String>()
        var order = 0
        for container in containers {
            let req = CNContactFetchRequest(keysToFetch: listKeys)
            req.predicate = CNContact.predicateForContactsInContainer(withIdentifier: container.identifier)
            req.unifyResults = false
            try? store.enumerateContacts(with: req) { cn, _ in
                guard seen.insert(cn.identifier).inserted else { return }
                var c = Contact(cn)
                c.source = container.identifier
                c.groups = membership[cn.identifier] ?? []
                c.created = order
                order += 1
                contacts.append(c)
            }
        }
        // Contacts the per-container predicate could not attribute (some account types).
        if containers.isEmpty {
            let req = CNContactFetchRequest(keysToFetch: listKeys)
            try? store.enumerateContacts(with: req) { cn, _ in
                var c = Contact(cn)
                c.created = order
                order += 1
                contacts.append(c)
            }
        }
        groups.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        return (contacts, groups, sources)
    }

    /// Visible contacts: ignored sources removed, duplicates merged, favorites marked.
    func contacts() -> [Contact] {
        var list = allContacts.filter { !config.ignoredContactSources.contains($0.source) }
        if config.showOnlyContactsWithNumbers {
            list = list.filter { !$0.phoneNumbers.isEmpty }
        }
        let favs = config.favorites
        for i in list.indices { list[i].starred = favs.contains(list[i].id) }
        if config.mergeDuplicateContacts {
            var firstIndex: [String: Int] = [:]
            var merged: [Contact] = []
            for c in list {
                let key = c.mergeKey(startWithSurname: config.startNameWithSurname)
                if let i = firstIndex[key] {
                    merged[i].starred = merged[i].starred || c.starred
                    if merged[i].thumbnail == nil { merged[i].thumbnail = c.thumbnail }
                } else {
                    firstIndex[key] = merged.count
                    merged.append(c)
                }
            }
            list = merged
        }
        return list
    }

    func contact(id: String) -> Contact? {
        guard var c = allContacts.first(where: { $0.id == id }) else { return nil }
        c.starred = config.favorites.contains(id)
        if let cn = raw([id], Self.fullKeys).first {
            c.photo = cn.imageData
        }
        return c
    }

    /// Other raw contacts that "Merge duplicate contacts" folds into `contact`.
    func duplicates(of contact: Contact) -> [Contact] {
        let key = contact.mergeKey(startWithSurname: false)
        return allContacts.filter { $0.id != contact.id && $0.mergeKey(startWithSurname: false) == key }
    }

    func sourceName(_ id: String) -> String {
        sources.first(where: { $0.id == id })?.publicName ?? "Phone storage"
    }

    var defaultSourceID: String { store.defaultContainerIdentifier() }

    // MARK: Saving

    @discardableResult
    func save(_ contact: Contact) -> Bool {
        let req = CNSaveRequest()
        let mutable: CNMutableContact
        let isNew = contact.id.isEmpty
        if isNew {
            mutable = CNMutableContact()
        } else {
            guard let existing = raw([contact.id], Self.fullKeys).first,
                  let m = existing.mutableCopy() as? CNMutableContact else { return fail() }
            mutable = m
        }
        contact.apply(to: mutable)
        if isNew {
            req.add(mutable, toContainerWithIdentifier: contact.source.isEmpty ? nil : contact.source)
        } else {
            req.update(mutable)
        }

        let before = Set(isNew ? [] : (allContacts.first(where: { $0.id == contact.id })?.groups.map(\.id) ?? []))
        let after = Set(contact.groups.map(\.id))
        let cnGroups = (try? store.groups(matching: nil)) ?? []
        for g in cnGroups where after.contains(g.identifier) && !before.contains(g.identifier) {
            req.addMember(mutable, to: g)
        }
        for g in cnGroups where before.contains(g.identifier) && !after.contains(g.identifier) {
            req.removeMember(mutable, from: g)
        }

        do {
            try store.execute(req)
        } catch {
            return fail(error)
        }
        if contact.starred { config.favorites.insert(mutable.identifier) } else { config.favorites.remove(mutable.identifier) }
        reload()
        return true
    }

    func delete(_ ids: [String]) {
        let req = CNSaveRequest()
        let keys = [CNContactIdentifierKey as CNKeyDescriptor]
        for c in raw(ids, keys) {
            if let m = c.mutableCopy() as? CNMutableContact { req.delete(m) }
        }
        do { try store.execute(req) } catch { fail(error) }
        config.favorites.subtract(ids)
        reload()
    }

    func addFavorites(_ ids: [String]) {
        config.favorites.formUnion(ids)
        for id in ids where !config.favoritesContactsOrder.contains(id) { config.favoritesContactsOrder.append(id) }
    }

    func removeFavorites(_ ids: [String]) {
        config.favorites.subtract(ids)
        config.favoritesContactsOrder.removeAll { ids.contains($0) }
    }

    // MARK: Groups

    @discardableResult
    func createGroup(_ title: String, containerID: String?) -> ContactGroup? {
        let g = CNMutableGroup()
        g.name = title
        let req = CNSaveRequest()
        req.add(g, toContainerWithIdentifier: containerID)
        do { try store.execute(req) } catch { fail(error); return nil }
        reload()
        return ContactGroup(id: g.identifier, title: title, containerID: containerID ?? defaultSourceID)
    }

    func renameGroup(_ id: String, to title: String) {
        guard let g = (try? store.groups(matching: CNGroup.predicateForGroups(withIdentifiers: [id])))?.first,
              let m = g.mutableCopy() as? CNMutableGroup else { return }
        m.name = title
        let req = CNSaveRequest()
        req.update(m)
        do { try store.execute(req) } catch { fail(error) }
        reload()
    }

    func deleteGroups(_ ids: [String]) {
        let req = CNSaveRequest()
        for g in (try? store.groups(matching: CNGroup.predicateForGroups(withIdentifiers: ids))) ?? [] {
            if let m = g.mutableCopy() as? CNMutableGroup { req.delete(m) }
        }
        do { try store.execute(req) } catch { fail(error) }
        reload()
    }

    func addContacts(_ ids: [String], toGroup groupID: String) {
        updateMembership(ids, groupID, add: true)
    }

    func removeContacts(_ ids: [String], fromGroup groupID: String) {
        updateMembership(ids, groupID, add: false)
    }

    private func updateMembership(_ ids: [String], _ groupID: String, add: Bool) {
        guard let g = (try? store.groups(matching: CNGroup.predicateForGroups(withIdentifiers: [groupID])))?.first else { return }
        let req = CNSaveRequest()
        let keys = [CNContactIdentifierKey as CNKeyDescriptor]
        for c in raw(ids, keys) {
            if add { req.addMember(c, to: g) } else { req.removeMember(c, from: g) }
        }
        do { try store.execute(req) } catch { fail(error) }
        reload()
    }

    func contacts(inGroup id: String) -> [Contact] {
        contacts().filter { $0.groups.contains(where: { $0.id == id }) }
    }

    // MARK: vCard

    func vcard(for ids: [String]) throws -> Data {
        let cns = raw(ids, Self.vcardKeys)
        return try CNContactVCardSerialization.data(with: cns)
    }

    func vcard(sources ignored: Set<String>) throws -> (Data, Int) {
        let ids = allContacts.filter { !ignored.contains($0.source) }.map(\.id)
        return (try vcard(for: ids), ids.count)
    }

    /// VcfImporter: returns (imported, failed).
    func importVCard(_ data: Data, into containerID: String?) -> (Int, Int) {
        guard let parsed = try? CNContactVCardSerialization.contacts(with: data), !parsed.isEmpty else { return (0, 1) }
        var ok = 0, failed = 0
        for cn in parsed {
            guard let m = cn.mutableCopy() as? CNMutableContact else { failed += 1; continue }
            let req = CNSaveRequest()
            req.add(m, toContainerWithIdentifier: containerID)
            do { try store.execute(req); ok += 1 } catch { failed += 1 }
        }
        reload()
        return (ok, failed)
    }

    @discardableResult
    private func fail(_ error: Error? = nil) -> Bool {
        toast = error.map { "An error occurred: \($0.localizedDescription)" } ?? "An unknown error occurred"
        return false
    }
}

// MARK: - Sorting (Contact.compareTo from Fossify Commons)

extension Contact {
    private func sortValue(_ sorting: Int, startWithSurname: Bool) -> String {
        let raw: String
        if sorting & Sort.firstName != 0 { raw = firstName }
        else if sorting & Sort.middleName != 0 { raw = middleName }
        else if sorting & Sort.surname != 0 { raw = surname }
        else { raw = nameToDisplay(startWithSurname: startWithSurname) }
        var v = raw.searchNormalized
        if v.isEmpty && firstName.isEmpty && middleName.isEmpty && surname.isEmpty {
            let company = fullCompany()
            if !company.isEmpty { v = company.searchNormalized } else if let e = emails.first { v = e.value }
        }
        return v
    }

    static func compare(_ a: Contact, _ b: Contact, sorting: Int, startWithSurname: Bool) -> Bool {
        var r: ComparisonResult
        if sorting & (Sort.firstName | Sort.middleName | Sort.surname | Sort.fullName) != 0 {
            let x = a.sortValue(sorting, startWithSurname: startWithSurname)
            let y = b.sortValue(sorting, startWithSurname: startWithSurname)
            let xl = x.first?.isLetter, yl = y.first?.isLetter
            if xl == true && yl == false { r = .orderedAscending }
            else if xl == false && yl == true { r = .orderedDescending }
            else if x.isEmpty && !y.isEmpty { r = .orderedDescending }
            else if !x.isEmpty && y.isEmpty { r = .orderedAscending }
            else if x.caseInsensitiveCompare(y) == .orderedSame {
                r = a.nameToDisplay(startWithSurname: startWithSurname)
                    .localizedCaseInsensitiveCompare(b.nameToDisplay(startWithSurname: startWithSurname))
            } else {
                r = x.localizedCaseInsensitiveCompare(y)
            }
        } else {
            r = a.created < b.created ? .orderedAscending : (a.created > b.created ? .orderedDescending : .orderedSame)
        }
        if sorting & Sort.descending != 0 {
            if r == .orderedAscending { r = .orderedDescending } else if r == .orderedDescending { r = .orderedAscending }
        }
        return r == .orderedAscending
    }

    /// Letter shown by the fast scroller bubble (ContactsAdapter.onChange).
    func bubbleLetter(sorting: Int, startWithSurname: Bool) -> String {
        var name: String
        if isABusinessContact { name = fullCompany() }
        else if sorting & Sort.surname != 0 && !surname.isEmpty { name = surname }
        else if sorting & Sort.middleName != 0 && !middleName.isEmpty { name = middleName }
        else if sorting & Sort.firstName != 0 && !firstName.isEmpty { name = firstName }
        else if startWithSurname { name = surname }
        else { name = firstName }
        if name.isEmpty { name = nameToDisplay(startWithSurname: startWithSurname) }
        return name.folding(options: .diacriticInsensitive, locale: .current).nameLetter
    }

    /// ContactsFragment.onSearchQueryChanged matching.
    func matches(_ text: String, startWithSurname: Bool) -> Bool {
        let q = text.searchNormalized
        func has(_ s: String) -> Bool { s.searchNormalized.contains(q) }
        if has(nameToDisplay(startWithSurname: startWithSurname)) || has(nickname) { return true }
        let digits = text.normalizedPhoneNumber
        if !digits.isEmpty, digits == text.filter({ !$0.isWhitespace }), phoneNumbers.contains(where: { $0.normalized.contains(digits) }) {
            return true
        }
        return emails.contains { has($0.value) } || addresses.contains { has($0.value) } || ims.contains { has($0.value) }
            || has(organization.company) || has(organization.jobPosition) || websites.contains { has($0.value) }
    }
}

// MARK: - CNContact mapping

extension Contact {
    init(_ cn: CNContact) {
        self.init(id: cn.identifier)
        prefix = cn.namePrefix
        firstName = cn.givenName
        middleName = cn.middleName
        surname = cn.familyName
        suffix = cn.nameSuffix
        nickname = cn.nickname
        phoneNumbers = cn.phoneNumbers.map { PhoneNumber(value: $0.value.stringValue, label: $0.label ?? CNLabelOther) }
        emails = cn.emailAddresses.map { Email(value: $0.value as String, label: $0.label ?? CNLabelOther) }
        addresses = cn.postalAddresses.map {
            let a = $0.value
            return Address(street: a.street, neighborhood: a.subLocality, city: a.city, postcode: a.postalCode,
                           region: a.state, country: a.country, label: $0.label ?? CNLabelOther)
        }
        if let b = cn.birthday { events.append(Event(date: b, label: Event.birthdayLabel)) }
        events += cn.dates.map { Event(date: $0.value as DateComponents, label: $0.label ?? CNLabelOther) }
        ims = cn.instantMessageAddresses.map { IM(value: $0.value.username, service: $0.value.service) }
        websites = cn.urlAddresses.map { Website(value: $0.value as String, label: $0.label ?? CNLabelURLAddressHomePage) }
        organization = Organization(company: cn.organizationName, jobPosition: cn.jobTitle)
        thumbnail = cn.isKeyAvailable(CNContactThumbnailImageDataKey) ? cn.thumbnailImageData : nil
    }

    func apply(to m: CNMutableContact) {
        m.namePrefix = prefix
        m.givenName = firstName
        m.middleName = middleName
        m.familyName = surname
        m.nameSuffix = suffix
        m.nickname = nickname
        m.phoneNumbers = phoneNumbers.filter { !$0.value.isEmpty }
            .map { CNLabeledValue(label: $0.label, value: CNPhoneNumber(stringValue: $0.value)) }
        m.emailAddresses = emails.filter { !$0.value.isEmpty }.map { CNLabeledValue(label: $0.label, value: $0.value as NSString) }
        m.postalAddresses = addresses.filter { !$0.isEmpty }.map {
            let a = CNMutablePostalAddress()
            a.street = $0.street
            a.subLocality = $0.neighborhood
            a.city = $0.city
            a.postalCode = $0.postcode
            a.state = $0.region
            a.country = $0.country
            return CNLabeledValue(label: $0.label, value: a.copy() as! CNPostalAddress)
        }
        m.birthday = events.first(where: { $0.label == Event.birthdayLabel })?.date
        m.dates = events.filter { $0.label != Event.birthdayLabel }
            .map { CNLabeledValue(label: $0.label, value: $0.date as NSDateComponents) }
        m.instantMessageAddresses = ims.filter { !$0.value.isEmpty }
            .map { CNLabeledValue(label: nil, value: CNInstantMessageAddress(username: $0.value, service: $0.service)) }
        m.urlAddresses = websites.filter { !$0.value.isEmpty }.map { CNLabeledValue(label: $0.label, value: $0.value as NSString) }
        m.organizationName = organization.company
        m.jobTitle = organization.jobPosition
        m.imageData = photo
    }
}
