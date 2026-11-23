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
                    item("Customize colors") { router.push(.customizeColors) }

                    Text("General").sectionHeader(palette)
                    item("Font size", value: config.fontSize.title) { fontSize = true }
                    item("Manage shown contact fields") { manageFields = true }
                    toggle("Merge duplicate contacts", $config.mergeDuplicateContacts)
                    toggle("Show a call confirmation dialog", $config.showCallConfirmation)

                    Text("Main screen").sectionHeader(palette)
                    item("Manage shown tabs") { manageTabs = true }
                    item("Default tab to open", value: defaultTabTitle) { defaultTab = true }
                    item("On contact click", value: config.onContactClick.title) { onClick = true }
                    toggle("Show a dialpad button on the main screen", $config.showDialpadButton)
                    toggle("Show only contacts with phone numbers", $config.showOnlyContactsWithNumbers)

                    Text("List view").sectionHeader(palette)
                    toggle("Show contact thumbnails", $config.showContactThumbnails)
                    toggle("Show phone numbers", $config.showPhoneNumbers)
                    toggle("Format phone numbers", $config.formatPhoneNumbers)
                    toggle("Start name with surname", $config.startNameWithSurname)

                    Text("Backups").sectionHeader(palette)
                    toggle("Enable automatic backups", Binding(get: { config.autoBackup }, set: { on in
                        if on { manageBackups = true } else { config.autoBackup = false }
                    }))
                    if config.autoBackup {
                        item("Manage automatic backups") { manageBackups = true }
                    }

                    Text("Migrating").sectionHeader(palette)
                    item("Export contacts to a .vcf file") { export = true }
                    item("Import contacts from a .vcf file") { importer = true }
                }
                .padding(.bottom, 32)
            }
        }
        .background(palette.backgroundColor.ignoresSafeArea())
        .sheet(isPresented: $fontSize) {
            RadioDialog(title: nil, items: FontSize.allCases.map { ($0, $0.title) }, selected: config.fontSize) { config.fontSize = $0 }
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

    private func item(_ title: String, value: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 16)).foregroundStyle(palette.textColor)
                if let value {
                    Text(value).font(.system(size: 14)).foregroundStyle(palette.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggle(_ title: String, _ on: Binding<Bool>) -> some View {
        Toggle(isOn: on) {
            Text(title).font(.system(size: 16)).foregroundStyle(palette.textColor)
        }
        .tint(palette.primaryColor)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

/// CustomizationActivity (theme, text/background/primary colors).
struct CustomizeColorsView: View {
    @Environment(Config.self) private var config
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var scheme
    @State private var pickTheme = false

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: "Customize colors")
            ScrollView {
                VStack(spacing: 0) {
                    Button { pickTheme = true } label: {
                        row("Theme") { Text(config.theme.title).foregroundStyle(palette.secondaryText) }
                    }
                    .buttonStyle(.plain)
                    colorRow("Text color", \.customTextColor)
                    colorRow("Background color", \.customBackgroundColor)
                    colorRow("Primary color", \.customPrimaryColor)
                }
            }
        }
        .background(palette.backgroundColor.ignoresSafeArea())
        .sheet(isPresented: $pickTheme) {
            RadioDialog(title: nil, items: ThemeKind.allCases.map { ($0, $0.title) }, selected: config.theme) { kind in
                if kind == .custom && config.theme != .custom {
                    // Start the custom theme from what is currently on screen.
                    config.customTextColor = palette.text
                    config.customBackgroundColor = palette.background
                    config.customPrimaryColor = palette.primary
                }
                config.theme = kind
            }
        }
    }

    private func row<V: View>(_ title: String, @ViewBuilder value: () -> V) -> some View {
        HStack {
            Text(title).font(.system(size: 16))
            Spacer()
            value()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private func colorRow(_ title: String, _ key: ReferenceWritableKeyPath<Config, UInt32>) -> some View {
        let current: UInt32 = {
            switch key {
            case \Config.customTextColor: return palette.text
            case \Config.customBackgroundColor: return palette.background
            default: return palette.primary
            }
        }()
        return row(title) {
            ColorPicker("", selection: Binding(
                get: { Color(argb: current) },
                set: { c in
                    if config.theme != .custom {
                        config.customTextColor = palette.text
                        config.customBackgroundColor = palette.background
                        config.customPrimaryColor = palette.primary
                        config.theme = .custom
                    }
                    config[keyPath: key] = c.argb | 0xFF000000
                }), supportsOpacity: false)
                .labelsHidden()
        }
    }
}

/// AboutActivity (trimmed to what applies on iOS).
struct AboutView: View {
    @Environment(\.palette) private var palette

    var body: some View {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        VStack(spacing: 0) {
            TopBar(title: "About")
            ScrollView {
                VStack(spacing: 0) {
                    VStack(spacing: 8) {
                        Avatar(name: "Contacts", size: 80)
                            .overlay(Image(systemName: "person.fill").font(.system(size: 36)).foregroundStyle(.white))
                        Text("Fossify Contacts").font(.system(size: 22, weight: .medium))
                        Text("Version \(version)").foregroundStyle(palette.secondaryText)
                    }
                    .padding(.vertical, 24)
                    Text("Support").sectionHeader(palette)
                    link("Frequently asked questions", "https://www.fossify.org/faq")
                    Text("Help us").sectionHeader(palette)
                    link("Contribute", "https://github.com/FossifyOrg/Contacts/blob/master/CONTRIBUTING.md")
                    link("Donate", "https://fossify.org/donate")
                    Text("Social").sectionHeader(palette)
                    link("Reddit", "https://www.reddit.com/r/Fossify")
                    link("Telegram", "https://t.me/Fossify")
                    Text("Other").sectionHeader(palette)
                    link("Website", "https://www.fossify.org")
                    link("Source code (Android)", "https://github.com/FossifyOrg/Contacts")
                    link("Source code (iOS port)", "https://github.com/jbisfun/contacts-ios")
                    link("Privacy policy", "https://www.fossify.org/policy/contacts")
                    link("License (GPL-3.0)", "https://www.gnu.org/licenses/gpl-3.0.html")
                }
                .padding(.bottom, 32)
            }
        }
        .background(palette.backgroundColor.ignoresSafeArea())
    }

    private func link(_ title: String, _ url: String) -> some View {
        Button { Launcher.open(URL(string: url)) } label: {
            Text(title)
                .font(.system(size: 16))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
