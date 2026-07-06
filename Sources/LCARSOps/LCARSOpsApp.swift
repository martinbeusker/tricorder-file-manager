import SwiftUI
import AppKit

@main
struct LCARSOpsApp: App {
    @StateObject private var model = FileSystemModel()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() { Fonts.register() }

    var body: some Scene {
        WindowGroup("LCARS · Ops File Manager") {
            ContentView(model: model)
                .preferredColorScheme(.dark)
                .ignoresSafeArea()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 780)
        .windowResizability(.contentMinSize)
        .commands { LCARSCommands(model: model) }
    }
}

/// Guarantees the app launches as a normal, centred window (never full-screen)
/// and behaves like a foreground app.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ note: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        configureWindow(retries: 8)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool { true }

    private func configureWindow(retries: Int) {
        guard let window = NSApp.windows.first(where: { $0.contentView != nil }) else {
            if retries > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.configureWindow(retries: retries - 1)
                }
            }
            return
        }
        window.isRestorable = false
        if window.styleMask.contains(.fullScreen) { window.toggleFullScreen(nil) }
        window.collectionBehavior.insert(.fullScreenPrimary)   // green button still works
        window.setContentSize(NSSize(width: 1200, height: 780))
        window.center()
        window.makeKeyAndOrderFront(nil)
    }
}

struct LCARSCommands: Commands {
    @ObservedObject var model: FileSystemModel

    var body: some Commands {
        // Replace the default New-item items with file operations
        CommandGroup(replacing: .newItem) {
            Button("Open") { model.openSelected() }.keyboardShortcut("o")
            Button("Reveal in Finder") { model.revealSelected() }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            Divider()
            Button("Copy to Clipboard") { model.copySelected() }.keyboardShortcut("c")
            Button("Move…") { model.moveSelected() }
                .keyboardShortcut("m", modifiers: [.command, .shift])
            Button("Move to Trash") { model.purgeSelected() }
                .keyboardShortcut(.delete, modifiers: [.command])
        }

        CommandGroup(after: .textEditing) {
            Button("Find") { model.requestSearchFocus() }
                .keyboardShortcut("f", modifiers: [.command])
        }

        CommandMenu("Go") {
            Button("Back") { model.goBack() }
                .keyboardShortcut("[", modifiers: [.command])
                .disabled(!model.canGoBack)
            Button("Enclosing Folder") { model.goUp() }
                .keyboardShortcut(.upArrow, modifiers: [.command])
                .disabled(!model.canGoUp)
            Button("Home") { model.goHome() }
                .keyboardShortcut("h", modifiers: [.command, .shift])
            Divider()
            Button("Refresh") { model.reload() }.keyboardShortcut("r")
        }

        CommandMenu("Systems") {
            Toggle("Motion", isOn: $model.motion)
                .keyboardShortcut("m", modifiers: [.command, .option])
            Toggle("Red Alert", isOn: $model.redAlert)
                .keyboardShortcut("a", modifiers: [.command, .option])
            Toggle("Compact Density", isOn: $model.compact)
                .keyboardShortcut("d", modifiers: [.command, .option])
        }
    }
}
