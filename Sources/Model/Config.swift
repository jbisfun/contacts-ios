import Observation
import SwiftUI

/// Port of Fossify's BaseConfig + contacts Config (SharedPreferences -> UserDefaults).
@Observable
final class Config {
    static let shared = Config()

    @ObservationIgnored private let d = UserDefaults.standard

    // Colors
    var theme: ThemeKind { didSet { d.set(theme.rawValue, forKey: "theme") } }
    var customTextColor: UInt32 { didSet { d.set(Int(customTextColor), forKey: "text_color") } }
    var customBackgroundColor: UInt32 { didSet { d.set(Int(customBackgroundColor), forKey: "background_color") } }
    var customPrimaryColor: UInt32 { didSet { d.set(Int(customPrimaryColor), forKey: "primary_color") } }

    // General
    var fontSize: FontSize { didSet { d.set(fontSize.rawValue, forKey: "font_size") } }
    var showContactFields: ShowField { didSet { d.set(showContactFields.rawValue, forKey: "show_contact_fields") } }
    var mergeDuplicateContacts: Bool { didSet { d.set(mergeDuplicateContacts, forKey: "merge_duplicate_contacts") } }
    var showCallConfirmation: Bool { didSet { d.set(showCallConfirmation, forKey: "show_call_confirmation") } }

    // Main screen
    var showTabs: Int { didSet { d.set(showTabs, forKey: "show_tabs") } }
    var defaultTab: Int { didSet { d.set(defaultTab, forKey: "default_tab") } }
    var lastUsedViewPagerPage: Int { didSet { d.set(lastUsedViewPagerPage, forKey: "last_used_view_pager_page") } }
    var onContactClick: OnContactClick { didSet { d.set(onContactClick.rawValue, forKey: "on_contact_click") } }
    var showDialpadButton: Bool { didSet { d.set(showDialpadButton, forKey: "show_dialpad_button") } }
    var showOnlyContactsWithNumbers: Bool { didSet { d.set(showOnlyContactsWithNumbers, forKey: "show_only_contacts_with_numbers") } }

    // List view
    var showContactThumbnails: Bool { didSet { d.set(showContactThumbnails, forKey: "show_contact_thumbnails") } }
    var showPhoneNumbers: Bool { didSet { d.set(showPhoneNumbers, forKey: "show_phone_numbers") } }
    var formatPhoneNumbers: Bool { didSet { d.set(formatPhoneNumbers, forKey: "format_phone_numbers") } }
    var startNameWithSurname: Bool { didSet { d.set(startNameWithSurname, forKey: "start_name_with_surname") } }

    // Sorting / filtering
    var sorting: Int { didSet { d.set(sorting, forKey: "sort_order") } }
    var isCustomOrderSelected: Bool { didSet { d.set(isCustomOrderSelected, forKey: "is_custom_order_selected") } }
    var favoritesContactsOrder: [String] { didSet { d.set(favoritesContactsOrder, forKey: "favorites_contacts_order") } }
    var ignoredContactSources: Set<String> { didSet { d.set(Array(ignoredContactSources), forKey: "ignored_contact_sources") } }
    var favoritesViewType: ViewType { didSet { d.set(favoritesViewType.rawValue, forKey: "view_type") } }
    var contactsGridColumnCount: Int { didSet { d.set(contactsGridColumnCount, forKey: "contacts_grid_column_count") } }

    // Favorites live here: iOS keeps its own favorites private, so like Fossify's
    // local "starred" flag they are stored per contact identifier.
    var favorites: Set<String> { didSet { d.set(Array(favorites), forKey: "favorites") } }
    var defaultNumbers: [String: String] { didSet { d.set(defaultNumbers, forKey: "default_numbers") } }

    // Backups
    var autoBackup: Bool { didSet { d.set(autoBackup, forKey: "auto_backup") } }
    var autoBackupFilename: String { didSet { d.set(autoBackupFilename, forKey: "auto_backup_filename") } }
    var lastAutoBackupTime: Double { didSet { d.set(lastAutoBackupTime, forKey: "last_auto_backup_time") } }
    var autoBackupContactSources: Set<String> { didSet { d.set(Array(autoBackupContactSources), forKey: "auto_backup_contact_sources") } }
    var lastExportFilename: String { didSet { d.set(lastExportFilename, forKey: "last_export_filename") } }

    private init() {
        theme = ThemeKind(rawValue: d.integer(forKey: "theme")) ?? .system
        customTextColor = UInt32(truncatingIfNeeded: d.object(forKey: "text_color") as? Int ?? 0xFF2D2D2D)
        customBackgroundColor = UInt32(truncatingIfNeeded: d.object(forKey: "background_color") as? Int ?? 0xFFFFFFFF)
        customPrimaryColor = UInt32(truncatingIfNeeded: d.object(forKey: "primary_color") as? Int ?? 0xFF106D1F)
        fontSize = FontSize(rawValue: d.object(forKey: "font_size") as? Int ?? FontSize.large.rawValue) ?? .large
        showContactFields = ShowField(rawValue: d.object(forKey: "show_contact_fields") as? Int ?? ShowField.defaults.rawValue)
        mergeDuplicateContacts = d.object(forKey: "merge_duplicate_contacts") as? Bool ?? true
        showCallConfirmation = d.object(forKey: "show_call_confirmation") as? Bool ?? false
        showTabs = d.object(forKey: "show_tabs") as? Int ?? Tab.allMask
        defaultTab = d.object(forKey: "default_tab") as? Int ?? Tab.lastUsed
        lastUsedViewPagerPage = d.object(forKey: "last_used_view_pager_page") as? Int ?? 0
        onContactClick = OnContactClick(rawValue: d.object(forKey: "on_contact_click") as? Int ?? 2) ?? .view
        showDialpadButton = d.object(forKey: "show_dialpad_button") as? Bool ?? true
        showOnlyContactsWithNumbers = d.object(forKey: "show_only_contacts_with_numbers") as? Bool ?? false
        showContactThumbnails = d.object(forKey: "show_contact_thumbnails") as? Bool ?? true
        showPhoneNumbers = d.object(forKey: "show_phone_numbers") as? Bool ?? false
        formatPhoneNumbers = d.object(forKey: "format_phone_numbers") as? Bool ?? true
        startNameWithSurname = d.object(forKey: "start_name_with_surname") as? Bool ?? false
        sorting = d.object(forKey: "sort_order") as? Int ?? Sort.firstName
        isCustomOrderSelected = d.object(forKey: "is_custom_order_selected") as? Bool ?? false
        favoritesContactsOrder = d.stringArray(forKey: "favorites_contacts_order") ?? []
        ignoredContactSources = Set(d.stringArray(forKey: "ignored_contact_sources") ?? [])
        favoritesViewType = ViewType(rawValue: d.object(forKey: "view_type") as? Int ?? 2) ?? .list
        contactsGridColumnCount = d.object(forKey: "contacts_grid_column_count") as? Int ?? 3
        favorites = Set(d.stringArray(forKey: "favorites") ?? [])
        defaultNumbers = d.dictionary(forKey: "default_numbers") as? [String: String] ?? [:]
        autoBackup = d.object(forKey: "auto_backup") as? Bool ?? false
        autoBackupFilename = d.string(forKey: "auto_backup_filename") ?? "contacts_%Y_%M_%D_%h_%m_%s"
        lastAutoBackupTime = d.double(forKey: "last_auto_backup_time")
        autoBackupContactSources = Set(d.stringArray(forKey: "auto_backup_contact_sources") ?? [])
        lastExportFilename = d.string(forKey: "last_export_filename") ?? ""
    }

    func isTabVisible(_ tab: Tab) -> Bool { showTabs & tab.rawValue != 0 }
    func isFieldShown(_ f: ShowField) -> Bool { showContactFields.contains(f) }
}
