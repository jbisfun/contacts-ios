import FossifyCommons
import Observation
import SwiftUI
import UIKit

enum Route: Hashable {
    case view(String)
    case edit(String)
    case newContact(number: String?)
    case group(String)
    case settings
    case customizeColors
    case about
}

@MainActor
@Observable
final class Router {
    var path: [Route] = []
    var importURL: URL?

    func push(_ r: Route) { path.append(r) }
    func pop() { if !path.isEmpty { path.removeLast() } }
}

struct ContactsApp: App {
    @State private var store = ContactsStore()
    @State private var router = Router()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(router)
                .environment(Config.shared)
                .fossifyTheme()
                .onOpenURL { url in router.importURL = url }
        }
    }
}

struct RootView: View {
    @Environment(ContactsStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.scenePhase) private var phase

    var body: some View {
        @Bindable var router = router
        @Bindable var store = store
        NavigationStack(path: $router.path) {
            Group {
                switch store.access {
                case .granted: MainView()
                case .denied: PermissionDenied()
                case .unknown: Color.clear.paletteBackground()
                }
            }
            .navigationDestination(for: Route.self) { route in
                Group {
                    switch route {
                    case .view(let id): ViewContactView(contactID: id)
                    case .edit(let id): EditContactView(contactID: id, prefillNumber: nil)
                    case .newContact(let number): EditContactView(contactID: nil, prefillNumber: number)
                    case .group(let id): GroupContactsView(groupID: id)
                    case .settings: SettingsView()
                    case .customizeColors: CustomizeColorsView()
                    case .about: AboutView(app: .contacts)
                    }
                }
                .toolbar(.hidden, for: .navigationBar)
                .paletteBackground()
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .toast($store.toast)
        .sheet(item: Binding(get: { router.importURL.map(IdentifiedURL.init) }, set: { router.importURL = $0?.url })) { item in
            ImportContactsDialog(url: item.url)
        }
        .onAppear { store.requestAccess() }
        .onChange(of: phase) { _, p in if p == .active { store.requestAccess() } }
    }
}

struct IdentifiedURL: Identifiable {
    let url: URL
    var id: URL { url }
}

struct PermissionDenied: View {
    @Environment(\.palette) private var palette

    var body: some View {
        Placeholder(text: "Contacts permission is required to show your contacts.", action: "Open settings") {
            Launcher.open(URL(string: UIApplication.openSettingsURLString))
        }
        .background(palette.backgroundColor.ignoresSafeArea())
    }
}
