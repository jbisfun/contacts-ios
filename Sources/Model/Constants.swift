import Foundation

// Port of org.fossify.commons.helpers / org.fossify.contacts.helpers constants.

enum Sort {
    static let firstName = 128
    static let middleName = 256
    static let surname = 512
    static let descending = 1024
    static let fullName = 65536
    static let custom = 131072
    static let dateCreated = 262144
}

enum Tab: Int, CaseIterable, Identifiable {
    case contacts = 1
    case favorites = 2
    case groups = 8

    static let lastUsed = 0
    static let allMask = Tab.contacts.rawValue | Tab.favorites.rawValue | Tab.groups.rawValue

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .contacts: return "Contacts"
        case .favorites: return "Favorites"
        case .groups: return "Groups"
        }
    }

    func icon(selected: Bool) -> String {
        switch self {
        case .contacts: return selected ? "person.fill" : "person"
        case .favorites: return selected ? "star.fill" : "star"
        case .groups: return selected ? "person.3.fill" : "person.3"
        }
    }
}

enum FontSize: Int, CaseIterable {
    case small = 0, medium, large, extraLarge

    var title: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        case .extraLarge: return "Extra large"
        }
    }

    /// Context.getTextSize(): smaller/normal/big/extra_big text sizes.
    var points: CGFloat {
        switch self {
        case .small: return 12
        case .medium: return 14
        case .large: return 18
        case .extraLarge: return 22
        }
    }
}

enum OnContactClick: Int, CaseIterable {
    case call = 1, view, edit

    var title: String {
        switch self {
        case .call: return "Call contact"
        case .view: return "View contact"
        case .edit: return "Edit contact"
        }
    }
}

enum ViewType: Int { case grid = 1, list = 2 }

struct ShowField: OptionSet, Hashable {
    let rawValue: Int
    static let prefix = ShowField(rawValue: 1)
    static let firstName = ShowField(rawValue: 2)
    static let middleName = ShowField(rawValue: 4)
    static let surname = ShowField(rawValue: 8)
    static let suffix = ShowField(rawValue: 16)
    static let phoneNumbers = ShowField(rawValue: 32)
    static let emails = ShowField(rawValue: 64)
    static let addresses = ShowField(rawValue: 128)
    static let events = ShowField(rawValue: 256)
    static let notes = ShowField(rawValue: 512)
    static let organization = ShowField(rawValue: 1024)
    static let groups = ShowField(rawValue: 2048)
    static let contactSource = ShowField(rawValue: 4096)
    static let websites = ShowField(rawValue: 8192)
    static let nickname = ShowField(rawValue: 16384)
    static let ims = ShowField(rawValue: 32768)
    static let structuredAddresses = ShowField(rawValue: 131072)

    static let defaults: ShowField = [.firstName, .surname, .phoneNumbers, .emails, .addresses, .events, .notes, .groups, .contactSource]
    static let names: ShowField = [.prefix, .firstName, .middleName, .surname, .suffix]

    /// ManageVisibleFieldsDialog order. Ringtone and notes are omitted: iOS has no
    /// public per-contact ringtone API and contact notes need a restricted entitlement.
    static let manageable: [(ShowField, String)] = [
        (.prefix, "Prefix"),
        (.firstName, "First name"),
        (.middleName, "Middle name"),
        (.surname, "Surname"),
        (.suffix, "Suffix"),
        (.nickname, "Nickname"),
        (.phoneNumbers, "Phone numbers"),
        (.emails, "Emails"),
        (.addresses, "Addresses"),
        (.structuredAddresses, "Structured addresses (edit mode)"),
        (.ims, "Instant messaging (IM)"),
        (.events, "Events (birthdays, anniversaries)"),
        (.organization, "Organization"),
        (.websites, "Websites"),
        (.groups, "Groups"),
        (.contactSource, "Contact source"),
    ]
}

/// org.fossify.commons.helpers.letterBackgroundColors (ARGB).
let letterBackgroundColors: [UInt32] = [
    0xCCD32F2F, 0xCCC2185B, 0xCC1976D2, 0xCC0288D1, 0xCC0097A7,
    0xCC00796B, 0xCC388E3C, 0xCC689F38, 0xCCF57C00, 0xCCE64A19,
]

/// Last digits compared when deduplicating phone numbers (ViewContactActivity).
let comparablePhoneNumberLength = 9
