import SwiftUI
import AppKit

@main
struct DrawOverApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            Button("Show DrawOver") {
                appDelegate.showToolbar()
            }
            Divider()
            SettingsLink {
                Text("Settings...")
            }
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            Image(systemName: "pencil.tip")
        }

        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var toolbarController: ToolbarWindowController?
    var overlayWindow: DrawingOverlayWindow?
    private var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Asegura que hay un valor por defecto guardado
        if UserDefaults.standard.string(forKey: "shortcutKey") == nil {
            UserDefaults.standard.set("s", forKey: "shortcutKey")
        }
        overlayWindow = DrawingOverlayWindow()
        overlayWindow?.ignoresMouseEvents = true
        showToolbar()
        setupGlobalShortcut()
    }

    func setupGlobalShortcut() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        let key = UserDefaults.standard.string(forKey: "shortcutKey") ?? "s"

        // Monitor global — cuando otra app tiene el foco
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            let cmdShift = event.modifierFlags.contains([.command, .shift])
            if cmdShift && event.charactersIgnoringModifiers == key {
                DispatchQueue.main.async { self.toggleToolbar() }
            }
        }

        // Monitor local — cuando DrawOver tiene el foco
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let cmdShift = event.modifierFlags.contains([.command, .shift])
            if cmdShift && event.charactersIgnoringModifiers == key {
                DispatchQueue.main.async { self.toggleToolbar() }
                return nil
            }
            return event
        }
    
    }

    func showToolbar() {
        if toolbarController == nil {
            toolbarController = ToolbarWindowController(appDelegate: self)
        }
        toolbarController?.showWindow(nil)
    }

    func toggleToolbar() {
        if toolbarController?.window?.isVisible == true {
            toolbarController?.close()
            overlayWindow?.orderOut(nil)
            overlayWindow?.ignoresMouseEvents = true
            ToolState.shared.isCursorMode = true
        } else {
            showToolbar()
            ToolState.shared.isCursorMode = true
            overlayWindow?.ignoresMouseEvents = true
            overlayWindow?.orderOut(nil) // ← añade esto
        }
    }
}

struct SettingsView: View {
    @AppStorage("shortcutKey") private var shortcutKey: String = "s"
    @State private var isRecording = false
    @State private var recordedShortcut = ""
    private var keyMonitor: Any? = nil

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Toggle shortcut")
                    Spacer()
                    Button {
                        isRecording = true
                        startRecording()
                    } label: {
                        HStack(spacing: 6) {
                            if isRecording {
                                Text("Press any key...")
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("⌘ ⇧ \(shortcutKey.uppercased())")
                                    .fontWeight(.medium)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(isRecording ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isRecording ? Color.accentColor : Color.clear, lineWidth: 1.5)
                        )
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Keyboard")
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .padding()
    }

    func startRecording() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            guard self.isRecording else { return event }
            let key = event.charactersIgnoringModifiers ?? ""
            guard !key.isEmpty && key != "\u{1B}" else {
                self.isRecording = false
                return nil
            }
            self.shortcutKey = key
            self.isRecording = false
            UserDefaults.standard.set(key, forKey: "shortcutKey")
            if let delegate = NSApp.delegate as? AppDelegate {
                delegate.setupGlobalShortcut()
            }
            return nil
        }
    }
}
