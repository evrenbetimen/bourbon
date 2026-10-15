//
//  SettingsView.swift
//  Bourbon
//

import AppKit
import BourbonKit
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
            RuntimeSettings()
                .tabItem { Label("Wine", systemImage: "shippingbox") }
            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 520, height: 380)
    }
}

private struct GeneralSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            LabeledContent("Bottles folder") {
                HStack {
                    Text(model.store.root.path)
                        .font(.caption.monospaced())
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Button("Show") { NSWorkspace.shared.open(model.store.root) }
                }
            }
            LabeledContent("Logs folder") {
                HStack {
                    Text(model.environment.logsDirectory.path)
                        .font(.caption.monospaced())
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Button("Show") {
                        try? FileManager.default.createDirectory(at: model.environment.logsDirectory,
                                                                 withIntermediateDirectories: true)
                        NSWorkspace.shared.open(model.environment.logsDirectory)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct RuntimeSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Form {
            Section("Installed runtimes") {
                if model.detectedRuntimes.isEmpty {
                    Text("No Wine runtime found yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(model.detectedRuntimes) { runtime in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(runtime.displayName)
                            Text(runtime.binDirectory.path)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        if runtime == model.runtime {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        } else {
                            Button("Use") { model.useRuntime(runtime) }
                        }
                    }
                }
            }
            Section("Download") {
                Picker("Build", selection: $model.runtimeFlavor) {
                    ForEach(RuntimeRelease.Flavor.allCases) { flavor in
                        Text(LocalizedStringKey(flavor.displayName)).tag(flavor)
                    }
                }
                HStack {
                    Button("Download Latest") { Task { await model.installRuntime() } }
                    Button("Rescan") { Task { await model.refreshRuntimes() } }
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct AboutView: View {
    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)
            Text("Bourbon")
                .font(.title.weight(.bold))
            Text("Version \(appVersion)")
                .foregroundStyle(.secondary)
            Text("Bourbon is free software under the GNU GPL v3. It is inspired by Whisky by Isaac Marovitz and contributors, and builds on Wine, DXVK, MoltenVK and winetricks.")
                .multilineTextAlignment(.center)
                .font(.callout)
                .frame(maxWidth: 400)
            HStack {
                Link("Whisky", destination: URL(string: "https://github.com/Whisky-App/Whisky")!)
                Text("·")
                Link("Wine", destination: URL(string: "https://www.winehq.org")!)
                Text("·")
                Link("GPL v3", destination: URL(string: "https://www.gnu.org/licenses/gpl-3.0.html")!)
            }
            .font(.callout)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
