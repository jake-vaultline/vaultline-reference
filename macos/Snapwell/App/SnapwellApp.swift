import SwiftUI
import SwiftData

@main
struct SnapwellApp: App {
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.dark.rawValue
    let container: ModelContainer
    let startupIssue: String?

    private var appearanceColorScheme: ColorScheme? {
        (AppearanceMode(rawValue: appearanceMode) ?? .dark).colorScheme
    }

    init() {
        NSWindow.allowsAutomaticWindowTabbing = false

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let snapwellDir = appSupport.appendingPathComponent("VaultlineReference", isDirectory: true)
        try? FileManager.default.createDirectory(at: snapwellDir, withIntermediateDirectories: true)
        let storeURL = snapwellDir.appendingPathComponent("default.store")

        do {
            let config = ModelConfiguration("Snapwell", url: storeURL)
            container = try ModelContainer(for: MediaItem.self, Space.self, AnalysisResult.self, configurations: config)
            startupIssue = nil
        } catch {
            // Never delete an operator library to recover automatically.
            startupIssue = error.localizedDescription
            let config = ModelConfiguration("Recovery", isStoredInMemoryOnly: true)
            container = try! ModelContainer(for: MediaItem.self, Space.self, AnalysisResult.self, configurations: config)
        }
    }

    var body: some Scene {
        WindowGroup("Vaultline Reference") {
            Group {
                if let startupIssue {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Your library needs recovery").font(.title)
                        Text("The library database could not open. Its database, media and sidecars were preserved; no reset was performed.")
                        Text(startupIssue).font(.caption).textSelection(.enabled)
                        Button("Open preserved library folder") { NSWorkspace.shared.open(MediaStorageService.shared.baseURL) }
                        Text("Keep a copy of this folder before restoring a backup or contacting support.").font(.callout)
                    }.padding(36).frame(width: 680)
                } else { ContentView() }
            }.preferredColorScheme(appearanceColorScheme)
        }
        .modelContainer(container)
        .defaultSize(width: 1280, height: 800)
        .windowResizability(.contentMinSize)
        .defaultPosition(.center)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Import Images...") {
                    NotificationCenter.default.post(name: .importFiles, object: nil)
                }
                .keyboardShortcut("o")

                Button("Import Folder...") {
                    NotificationCenter.default.post(name: .importElectronLibrary, object: nil)
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])

                Button("Open Storage Location") {
                    NSWorkspace.shared.open(MediaStorageService.shared.baseURL)
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }

            CommandMenu("Spaces") {
                SpacesMenuContent()
                    .modelContainer(container)

                Divider()

                Button("New Space") {
                    NotificationCenter.default.post(name: .createNewSpace, object: nil)
                }
                .keyboardShortcut("n")
            }

            CommandGroup(replacing: .pasteboard) {
                Button("Cut") {
                    NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("x")

                Button("Copy") {
                    NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("c")

                Button("Paste") {
                    if let firstResponder = NSApp.keyWindow?.firstResponder, firstResponder is NSText {
                        firstResponder.tryToPerform(#selector(NSText.paste(_:)), with: nil)
                    } else {
                        NotificationCenter.default.post(name: .pasteImages, object: nil)
                    }
                }
                .keyboardShortcut("v")

                Divider()

                Button("Find") {
                    NotificationCenter.default.post(name: .focusSearch, object: nil)
                }
                .keyboardShortcut("f")

                Button("Select All") {
                    // If a text field is focused (e.g. search), do standard text select all;
                    // otherwise select all grid images
                    if let firstResponder = NSApp.keyWindow?.firstResponder, firstResponder is NSText {
                        firstResponder.tryToPerform(#selector(NSText.selectAll(_:)), with: nil)
                    } else {
                        NotificationCenter.default.post(name: .selectAll, object: nil)
                    }
                }
                .keyboardShortcut("a")
            }

            CommandGroup(replacing: .toolbar) {
                Button {
                    NotificationCenter.default.post(name: .zoomIn, object: nil)
                } label: {
                    Label("Zoom In", systemImage: "plus.magnifyingglass")
                }
                .keyboardShortcut("+")

                Button {
                    NotificationCenter.default.post(name: .zoomOut, object: nil)
                } label: {
                    Label("Zoom Out", systemImage: "minus.magnifyingglass")
                }
                .keyboardShortcut("-")
            }

            CommandGroup(replacing: .undoRedo) {
                Button("Undo") {
                    NotificationCenter.default.post(name: .undo, object: nil)
                }
                .keyboardShortcut("z")

                Button("Redo") {
                    NotificationCenter.default.post(name: .redo, object: nil)
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])

                Divider()

                Button("Delete") {
                    NotificationCenter.default.post(name: .deleteSelected, object: nil)
                }
                .keyboardShortcut(.delete)
            }
        }

        Settings {
            SettingsView()
                .preferredColorScheme(appearanceColorScheme)
        }
        .modelContainer(container)
    }
}

private struct SpacesMenuContent: View {
    @Query(sort: \Space.order) private var spaces: [Space]

    var body: some View {
        Button("All") {
            NotificationCenter.default.post(name: .switchToSpaceByIndex, object: nil, userInfo: ["digit": 1])
        }
        .keyboardShortcut("1")

        ForEach(Array(spaces.prefix(8).enumerated()), id: \.element.id) { index, space in
            Button(space.name) {
                NotificationCenter.default.post(name: .switchToSpaceByIndex, object: nil, userInfo: ["digit": index + 2])
            }
            .keyboardShortcut(KeyEquivalent(Character(String(index + 2))))
        }
    }
}

extension Notification.Name {
    static let importFiles = Notification.Name("importFiles")
    static let undo = Notification.Name("undo")
    static let redo = Notification.Name("redo")
    static let apiKeySaved = Notification.Name("apiKeySaved")
    static let importElectronLibrary = Notification.Name("importElectronLibrary")
    static let willResetAllData = Notification.Name("willResetAllData")
    static let switchToSpaceByIndex = Notification.Name("switchToSpaceByIndex")
    static let createNewSpace = Notification.Name("createNewSpace")
    static let focusSearch = Notification.Name("focusSearch")
    static let selectAll = Notification.Name("selectAll")
    static let pasteImages = Notification.Name("pasteImages")
    static let importFolder = Notification.Name("importFolder")
    static let deleteSelected = Notification.Name("deleteSelected")
    static let analysisCompleted = Notification.Name("analysisCompleted")
    static let zoomIn = Notification.Name("zoomIn")
    static let zoomOut = Notification.Name("zoomOut")
    static let closeDetail = Notification.Name("closeDetail")
    static let showAPIKeyToast = Notification.Name("showAPIKeyToast")
    static let thumbnailsRegenerated = Notification.Name("thumbnailsRegenerated")
}
