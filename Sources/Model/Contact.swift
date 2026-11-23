import FossifyCommons
import Contacts
import Foundation

/// A labeled value type choice shown in the type pickers of the edit screen.
struct LabelChoice: Hashable {
    let label: String   // CNLabel... constant or a custom string
    let title: String
}

enum Labels {
    static let phone: [LabelChoice] = [
        LabelChoice(label: CNLabelPhoneNumberMobile, title: "Mobile"),
        LabelChoice(label: CNLabelHome, title: "Home"),
        LabelChoice(label: CNLabelWork, title: "Work"),
        LabelChoice(label: CNLabelPhoneNumberMain, title: "Main number"),
        LabelChoice(label: CNLabelPhoneNumberWorkFax, title: "Work fax"),
        LabelChoice(label: CNLabelPhoneNumberHomeFax, title: "Home fax"),
        LabelChoice(label: CNLabelPhoneNumberPager, title: "Pager"),
        LabelChoice(label: CNLabelOther, title: "Other"),
    ]

    static let email: [LabelChoice] = [
        LabelChoice(label: CNLabelHome, title: "Home"),
        LabelChoice(label: CNLabelWork, title: "Work"),
        LabelChoice(label: CNLabelPhoneNumberMobile, title: "Mobile"),
        LabelChoice(label: CNLabelOther, title: "Other"),
    ]

    static let address: [LabelChoice] = [
        LabelChoice(label: CNLabelHome, title: "Home"),
        LabelChoice(label: CNLabelWork, title: "Work"),
        LabelChoice(label: CNLabelOther, title: "Other"),
    ]

    static let event: [LabelChoice] = [
        LabelChoice(label: Event.birthdayLabel, title: "Birthday"),
        LabelChoice(label: CNLabelDateAnniversary, title: "Anniversary"),
        LabelChoice(label: CNLabelOther, title: "Other"),
    ]

    static let website: [LabelChoice] = [
        LabelChoice(label: CNLabelURLAddressHomePage, title: "Homepage"),
        LabelChoice(label: CNLabelHome, title: "Home"),
        LabelChoice(label: CNLabelWork, title: "Work"),
        LabelChoice(label: CNLabelOther, title: "Other"),
    ]

    /// IM protocols (Fossify: AIM, Windows Live, Yahoo, Skype, QQ, Hangouts, ICQ, Jabber).
    static let im: [LabelChoice] = [
        LabelChoice(label: CNInstantMessageServiceAIM, title: "AIM"),
        LabelChoice(label: CNInstantMessageServiceMSN, title: "Windows Live"),
        LabelChoice(label: CNInstantMessageServiceYahoo, title: "Yahoo"),
        LabelChoice(label: CNInstantMessageServiceSkype, title: "Skype"),
        LabelChoice(label: CNInstantMessageServiceQQ, title: "QQ"),
        LabelChoice(label: CNInstantMessageServiceGoogleTalk, title: "Hangouts"),
        LabelChoice(label: CNInstantMessageServiceICQ, title: "ICQ"),
        LabelChoice(label: CNInstantMessageServiceJabber, title: "Jabber"),
    ]

    static func title(_ label: String, in choices: [LabelChoice]) -> String {
        if let c = choices.first(where: { $0.label == label }) { return c.title }
        if label.isEmpty { return choices.first?.title ?? "" }
        return CNLabeledValue<NSString>.localizedString(forLabel: label)
    }
}

struct PhoneNumber: Hashable, Identifiable {
    var id = UUID()
    var value: String
    var label: String = CNLabelPhoneNumberMobile

    var normalized: String { value.normalizedPhoneNumber }
    var comparable: String {
        let n = normalized
        return n.count >= comparablePhoneNumberLength ? String(n.suffix(comparablePhoneNumberLength)) : n
    }
}

struct Email: Hashable, Identifiable {
    var id = UUID()
    var value: String
    var label: String = CNLabelHome
}

struct Address: Hashable, Identifiable {
    var id = UUID()
    var street = ""
    var neighborhood = ""   // subLocality
    var city = ""
    var postcode = ""
    var region = ""
    var country = ""
    var label: String = CNLabelHome

    /// Single-line value as shown by Fossify (structured fields joined).
    var value: String {
        [street, neighborhood, city, region, postcode, country]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    var isEmpty: Bool { value.isEmpty }
}

struct Event: Hashable, Identifiable {
    static let birthdayLabel = "birthday"

    var id = UUID()
    var date: DateComponents
    var label: String = Event.birthdayLabel

    var display: String {
        var dc = date
        dc.calendar = Calendar(identifier: .gregorian)
        guard let month = dc.month, let day = dc.day else { return "" }
        let f = DateFormatter()
        if let year = dc.year, year > 1 {
            f.dateStyle = .long
            f.timeStyle = .none
            let d = Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: day))
            return d.map { f.string(from: $0) } ?? ""
        }
        f.setLocalizedDateFormatFromTemplate("MMMMd")
        let d = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2000, month: month, day: day))
        return d.map { f.string(from: $0) } ?? ""
    }
}

struct IM: Hashable, Identifiable {
    var id = UUID()
    var value: String
    var service: String = CNInstantMessageServiceSkype
}

struct Website: Hashable, Identifiable {
    var id = UUID()
    var value: String
    var label: String = CNLabelURLAddressHomePage
}

struct Organization: Hashable {
    var company = ""
    var jobPosition = ""
    var isEmpty: Bool { company.isEmpty && jobPosition.isEmpty }
}

struct ContactGroup: Hashable, Identifiable {
    var id: String          // CNGroup.identifier
    var title: String
    var containerID: String
    var contactsCount = 0
}

struct ContactSource: Hashable, Identifiable {
    var id: String          // CNContainer.identifier
    var name: String
    var type: CNContainerType

    var publicName: String {
        switch type {
        case .local: return name.isEmpty ? "Phone storage" : name
        case .cardDAV: return name.isEmpty ? "CardDAV" : name
        case .exchange: return name.isEmpty ? "Exchange" : name
        default: return name
        }
    }
}

struct Contact: Hashable, Identifiable {
    var id: String                      // CNContact.identifier, "" for new
    var prefix = ""
    var firstName = ""
    var middleName = ""
    var surname = ""
    var suffix = ""
    var nickname = ""
    var phoneNumbers: [PhoneNumber] = []
    var emails: [Email] = []
    var addresses: [Address] = []
    var events: [Event] = []
    var ims: [IM] = []
    var websites: [Website] = []
    var organization = Organization()
    var groups: [ContactGroup] = []
    var source = ""                     // container identifier
    var thumbnail: Data?
    var photo: Data?
    var starred = false
    var created = 0                     // enumeration order, stands in for "date created"

    var isABusinessContact: Bool {
        prefix.isEmpty && firstName.isEmpty && middleName.isEmpty && surname.isEmpty && suffix.isEmpty && !organization.company.isEmpty
    }

    func fullCompany() -> String {
        var s = organization.company
        if !organization.company.isEmpty && !organization.jobPosition.isEmpty { s += ", " }
        s += organization.jobPosition
        return s.trimmingCharacters(in: .whitespaces)
    }

    /// Contact.getNameToDisplay() from Fossify Commons.
    func nameToDisplay(startWithSurname: Bool) -> String {
        let firstMiddle = "\(firstName) \(middleName)".trimmingCharacters(in: .whitespaces)
        let firstPart: String
        if startWithSurname {
            firstPart = (!surname.isEmpty && !firstMiddle.isEmpty) ? "\(surname)," : surname
        } else {
            firstPart = firstMiddle
        }
        let lastPart = startWithSurname ? firstMiddle : surname
        let suffixComma = suffix.isEmpty ? "" : ", \(suffix)"
        let fullName = "\(prefix) \(firstPart) \(lastPart)\(suffixComma)"
            .split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
        if !fullName.isEmpty { return fullName }
        let company = fullCompany()
        if !company.isEmpty { return company }
        if let e = emails.first?.value.trimmingCharacters(in: .whitespaces), !e.isEmpty { return e }
        if let p = phoneNumbers.first?.value, !p.isEmpty { return p }
        return ""
    }

    /// Key used by "Merge duplicate contacts": same name, same numbers and emails.
    func mergeKey(startWithSurname: Bool) -> String {
        let name = nameToDisplay(startWithSurname: false).lowercased()
        let numbers = Set(phoneNumbers.map(\.comparable)).sorted().joined(separator: ",")
        let mails = Set(emails.map { $0.value.lowercased() }).sorted().joined(separator: ",")
        return "\(name)|\(numbers)|\(mails)"
    }

    var isEmpty: Bool {
        prefix.isEmpty && firstName.isEmpty && middleName.isEmpty && surname.isEmpty && suffix.isEmpty
            && nickname.isEmpty && phoneNumbers.allSatisfy { $0.value.isEmpty } && emails.allSatisfy { $0.value.isEmpty }
            && addresses.allSatisfy(\.isEmpty) && organization.isEmpty && websites.allSatisfy { $0.value.isEmpty }
            && ims.allSatisfy { $0.value.isEmpty } && photo == nil
    }
}
