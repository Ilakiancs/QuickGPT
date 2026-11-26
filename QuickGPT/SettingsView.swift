import SwiftUI
import WebKit
import KeyboardShortcuts

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            ShortcutsSettingsView()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
        }
        .frame(width: 400, height: 200)
    }
}

struct GeneralSettingsView: View {
    var body: some View {
        Form {
            Section("Session") {
                Button("Clear ChatGPT Session") {
                    clearWebData()
                }
                Text("Sign out and clear cached data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func clearWebData() {
        let dataStore = WKWebsiteDataStore.default()
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        dataStore.fetchDataRecords(ofTypes: dataTypes) { records in
            dataStore.removeData(ofTypes: dataTypes, for: records) {}
        }
    }
}

struct ShortcutsSettingsView: View {
    var body: some View {
        Form {
            Section("Toggle QuickGPT") {
                KeyboardShortcuts.Recorder(for: .toggleQuickGPT)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
