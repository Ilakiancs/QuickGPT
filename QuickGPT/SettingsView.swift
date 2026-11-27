import SwiftUI
import WebKit
import KeyboardShortcuts
import Defaults
import ServiceManagement

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gear") }

            ShortcutsSettingsView()
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
        }
        .frame(width: 440, height: 300)
    }
}

struct GeneralSettingsView: View {
    @Default(.keepPanelOpen) private var keepPanelOpen
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var cleared = false

    var body: some View {
        Form {
            Section("Behavior") {
                Toggle("Launch at login", isOn: Binding(get: { launchAtLogin }, set: setLaunchAtLogin))
                Toggle("Keep panel open when clicking away", isOn: $keepPanelOpen)
            }

            Section("Session") {
                HStack {
                    Button("Clear ChatGPT Session", role: .destructive, action: clearWebData)
                    if cleared {
                        Text("Signed out").foregroundStyle(.secondary)
                    }
                }
                Text("Signs you out and clears cached data.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        // The window is reused, so refresh state each time it's shown.
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            cleared = false
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("QuickGPT: launch at login change failed: \(error)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
        // macOS may require the user to approve the login item; take them there instead of silently failing.
        if enabled, SMAppService.mainApp.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
    }

    private func clearWebData() {
        let dataStore = WKWebsiteDataStore.default()
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        dataStore.removeData(ofTypes: dataTypes, modifiedSince: .distantPast) {
            cleared = true
            NotificationCenter.default.post(name: .quickGPTSessionCleared, object: nil)
        }
    }
}

struct ShortcutsSettingsView: View {
    var body: some View {
        Form {
            Section {
                KeyboardShortcuts.Recorder("Toggle QuickGPT", name: .toggleQuickGPT)
            } footer: {
                Text("Default is ⌥X. Inside the panel: ⌘N new chat, ⌘R reload, ⌘± zoom, Esc or ⌘W to close.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
