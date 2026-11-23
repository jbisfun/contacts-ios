import FossifyCommons
import SwiftUI
import UniformTypeIdentifiers

/// SettingsActivity.
struct SettingsView: View {
    @Environment(ContactsStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(Config.self) private var config
    @Environment(\.palette) private var palette

    @State private var fontSize = false
    @State private var manageFields = false
    @State private var manageTabs = false
    @State private var defaultTab = false
    @State private var onClick = false
    @State private var manageBackups = false
    @State private var export = false
    @State private var importer = false
    @State private var exported: ShareItem?
    @State private var importURL: URL?

    var body: some View {
        @Bindable var config = config
        VStack(spacing: 0) {
            TopBar(title: "Settings")
            ScrollView {
                VStack(spacing: 0) {
                    Text("Color customization").sectionHeader(palette)
                    SettingsItem("Customize colors") { router.push(.customizeColors) }

                    Text("General").sectionHeader(palette)
                    SettingsItem("Font size", value: BaseConfig.shared.fontSize.title) { fontSize = true }
                    SettingsItem("Manage shown contact fields") { manageFields = true }
                    SettingsToggle("Merge duplicate contacts", isOn: $config.mergeDuplicateContacts)
                    SettingsToggle("Show a call confirmation dialog", isOn: $config.showCallConfirmation)

                    Text("Main screen").sectionHeader(palette)
                    SettingsItem("Manage shown tabs") { manageTabs = true }
                    SettingsItem("Default tab to open", value: defaultTabTitle) { defaultTab = true }
                    SettingsItem("On contact click", value: config.onContactClick.title) { onClick = true }
                    SettingsToggle("Show a dialpad button on the main screen", isOn: $config.showDialpadButton)
                    SettingsToggle("Show only contacts with phone numbers", isOn: $config.showOnlyContactsWithNumbers)

                    Text("List view").sectionHeader(palette)
                    SettingsToggle("Show contact thumbnails", isOn: $config.showContactThumbnails)
                    SettingsToggle("Show phone numbers", isOn: $config.showPhoneNumbers)
                    SettingsToggle("Format phone numbers", isOn: $config.formatPhoneNumbers)
                    SettingsToggle("Start name with surname", isOn: $config.startNameWithSurname)

                    Text("Backups").sectionHeader(palette)
                    SettingsToggle("Enable automatic backups", isOn: Binding(get: { config.autoBackup }, set: { on in
                        if on { manageBackups = true } else { config.autoBackup = false }
                    }))
                    if config.autoBackup {
                        SettingsItem("Manage automatic backups") { manageBackups = true }
                    }

                    Text("Migrating").sectionHeader(palette)
                    SettingsItem("Export contacts to a .vcf file") { export = true }
                    SettingsItem("Import contacts from a .vcf file") { importer = true }
                }
                .padding(.bottom, 32)
            }
        }
        .background(palette.backgroundColor.ignoresSafeArea())
        .sheet(isPresented: $fontSize) {
            RadioDialog(title: nil, items: FontSize.allCases.map { ($0, $0.title) }, selected: BaseConfig.shared.fontSize) { BaseConfig.shared.fontSize = $0 }
        }
        .sheet(isPresented: $manageFields) { ManageVisibleFieldsDialog() }
        .sheet(isPresented: $manageTabs) { ManageVisibleTabsDialog() }
        .sheet(isPresented: $defaultTab) {
            RadioDialog(title: nil, items: [(Tab.contacts.rawValue, "Contacts"), (Tab.favorites.rawValue, "Favorites"),
                                            (Tab.groups.rawValue, "Groups"), (Tab.lastUsed, "Last used one")],
                        selected: config.defaultTab) { config.defaultTab = $0 }
        }
        .sheet(isPresented: $onClick) {
            RadioDialog(title: nil, items: OnContactClick.allCases.map { ($0, $0.title) }, selected: config.onContactClick) {
                config.onContactClick = $0
            }
        }
        .sheet(isPresented: $manageBackups) {
            ManageAutoBackupsDialog()
        }
        .sheet(isPresented: $export) {
            ExportContactsDialog { url in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { exported = ShareItem(url: url) }
            }
        }
        .sheet(item: $exported) { ShareSheet(items: [$0.url]) }
        .fileImporter(isPresented: $importer, allowedContentTypes: [.vCard, UTType(filenameExtension: "vcf") ?? .vCard]) { result in
            if case .success(let url) = result {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { importURL = url }
            }
        }
        .sheet(item: Binding(get: { importURL.map(IdentifiedURL.init) }, set: { importURL = $0?.url })) { ImportContactsDialog(url: $0.url) }
    }

    private var defaultTabTitle: String {
        switch config.defaultTab {
        case Tab.contacts.rawValue: return "Contacts"
        case Tab.favorites.rawValue: return "Favorites"
        case Tab.groups.rawValue: return "Groups"
        default: return "Last used one"
        }
    }
}

extension AppInfo {
    static let contacts = AppInfo(name: "Contacts", icon: "person.fill", upstream: "Contacts", port: "contacts-ios", policy: "contacts")
}
