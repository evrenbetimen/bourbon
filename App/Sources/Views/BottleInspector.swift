//
//  BottleInspector.swift
//  Bourbon
//

import BourbonKit
import SwiftUI

struct BottleInspector: View {
    @Binding var bottle: Bottle

    var body: some View {
        Form {
            Section {
                AppearancePicker(symbol: $bottle.settings.symbol, tint: $bottle.settings.tint)
            } header: {
                Text("Appearance")
            }

            Section {
                Picker("Windows Version", selection: $bottle.settings.windowsVersion) {
                    ForEach(WindowsVersion.allCases.reversed()) { version in
                        Text(version.displayName).tag(version)
                    }
                }
                .accessibilityIdentifier("windowsVersionPicker")
                Picker("Log Level", selection: $bottle.settings.logLevel) {
                    Text("Quiet").tag(LogLevel.quiet)
                    Text("Standard").tag(LogLevel.standard)
                    Text("Verbose").tag(LogLevel.verbose)
                }
            } header: {
                Text("Windows")
            }

            Section {
                Picker("Synchronization", selection: $bottle.settings.syncMode) {
                    ForEach(SyncMode.allCases) { mode in
                        Text(LocalizedStringKey(mode.displayName)).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                Toggle("Advertise AVX to Rosetta", isOn: $bottle.settings.advertiseAVX)
            } header: {
                Text("Performance")
            } footer: {
                Text("MSync is the fastest option on macOS. AVX helps newer games that refuse to start without it.")
            }

            Section {
                Toggle("DXVK", isOn: $bottle.settings.dxvkEnabled.animation())
                    .accessibilityIdentifier("dxvkToggle")
                if bottle.settings.dxvkEnabled {
                    Toggle("Asynchronous shaders", isOn: $bottle.settings.dxvkAsync)
                    Picker("DXVK HUD", selection: $bottle.settings.dxvkHUD) {
                        Text("Off").tag(DXVKHUD.off)
                        Text("FPS").tag(DXVKHUD.fps)
                        Text("Partial").tag(DXVKHUD.partial)
                        Text("Full").tag(DXVKHUD.full)
                    }
                }
                Toggle("Metal HUD", isOn: $bottle.settings.metalHUD)
                Toggle("Metal capture", isOn: $bottle.settings.metalTrace)
                Toggle("Retina mode", isOn: $bottle.settings.retinaMode)
                    .accessibilityIdentifier("retinaToggle")
            } header: {
                Text("Graphics")
            } footer: {
                Text("DXVK translates Direct3D 9–11 to Vulkan, which MoltenVK runs on Metal.")
            }

            Section {
                EnvironmentEditor(environment: $bottle.settings.environment)
            } header: {
                Text("Environment Variables")
            }

            Section {
                LabeledContent("Location") {
                    Text(bottle.url.path)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
                LabeledContent("Created") {
                    Text(bottle.settings.createdAt, format: .dateTime.day().month().year())
                }
                if let last = bottle.settings.lastLaunchedAt {
                    LabeledContent("Last played") {
                        Text(last, format: .relative(presentation: .named))
                    }
                }
            } header: {
                Text("Info")
            }
        }
        .formStyle(.grouped)
        .accessibilityIdentifier("bottleInspector")
    }
}

struct AppearancePicker: View {
    @Binding var symbol: String
    @Binding var tint: BottleTint

    private let symbolColumns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 6)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ForEach(BottleTint.allCases) { option in
                    Button {
                        withAnimation(.snappy) { tint = option }
                    } label: {
                        Circle()
                            .fill(option.gradient)
                            .frame(width: 22, height: 22)
                            .overlay {
                                if option == tint {
                                    Circle().strokeBorder(.white, lineWidth: 2).padding(2)
                                }
                            }
                            .shadow(color: option.color.opacity(option == tint ? 0.6 : 0), radius: 5)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(option.label))
                    .accessibilityAddTraits(option == tint ? .isSelected : [])
                }
            }
            LazyVGrid(columns: symbolColumns, spacing: 6) {
                ForEach(BottleSymbols.all, id: \.self) { name in
                    Button {
                        symbol = name
                    } label: {
                        Image(systemName: name)
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 30, height: 30)
                            .background {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(name == symbol ? AnyShapeStyle(tint.gradient) : AnyShapeStyle(.quaternary))
                            }
                            .foregroundStyle(name == symbol ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(name))
                }
            }
        }
        .padding(.vertical, 4)
    }
}

/// Edits a dictionary of environment variables, saving only when every name is valid.
struct EnvironmentEditor: View {
    @Binding var environment: [String: String]

    private struct Row: Identifiable, Equatable {
        let id = UUID()
        var name: String
        var value: String
    }

    @State private var rows: [Row] = []

    var body: some View {
        ForEach($rows) { $row in
            HStack(spacing: 6) {
                TextField("NAME", text: $row.name)
                    .font(.callout.monospaced())
                    .foregroundStyle(row.name.isEmpty || CommandLineText.isValidEnvironmentName(row.name)
                                     ? Color.primary : Color.red)
                TextField("value", text: $row.value)
                    .font(.callout.monospaced())
                Button {
                    rows.removeAll { $0.id == row.id }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove variable")
            }
            .labelsHidden()
        }
        Button {
            rows.append(Row(name: "", value: ""))
        } label: {
            Label("Add Variable", systemImage: "plus")
        }
        .onAppear { rows = environment.keys.sorted().map { Row(name: $0, value: environment[$0] ?? "") } }
        .onChange(of: rows) { _, newRows in
            let named = newRows.filter { !$0.name.isEmpty }
            guard named.allSatisfy({ CommandLineText.isValidEnvironmentName($0.name)
                && !WineEnvironment.reservedNames.contains($0.name) }) else { return }
            let updated = Dictionary(named.map { ($0.name, $0.value) }, uniquingKeysWith: { $1 })
            if updated != environment { environment = updated }
        }
    }
}
