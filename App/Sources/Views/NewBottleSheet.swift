//
//  NewBottleSheet.swift
//  Bourbon
//

import BourbonKit
import SwiftUI

struct NewBottleSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var windowsVersion = WindowsVersion.recommended
    @State private var symbol = "wineglass.fill"
    @State private var tint = BottleTint.amber
    @State private var dxvk = false
    @FocusState private var nameFocused: Bool

    private var validation: Result<String, BottleNameError> { BottleStore.validateName(name) }
    private var preview: BottleSettings {
        BottleSettings(name: name.isEmpty ? String(localized: "New Bottle") : name, symbol: symbol, tint: tint,
                       windowsVersion: windowsVersion, dxvkEnabled: dxvk)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                BottleIcon(settings: preview, size: 64)
                    .shadow(color: tint.color.opacity(0.5), radius: 14, y: 6)
                    .animation(.snappy, value: tint)
                VStack(alignment: .leading, spacing: 4) {
                    Text("New Bottle")
                        .font(.title.weight(.bold))
                    Text("A fresh Windows environment with its own C: drive and settings.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(24)

            Form {
                Section {
                    TextField("Name", text: $name, prompt: Text("e.g. Steam, Office, Retro Games"))
                        .focused($nameFocused)
                        .accessibilityIdentifier("bottleNameField")
                        .onSubmit(create)
                    if case .failure(let error) = validation, !name.isEmpty {
                        Label(Self.message(for: error), systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.callout)
                            .accessibilityIdentifier("bottleNameError")
                    }
                    Picker("Windows Version", selection: $windowsVersion) {
                        ForEach(WindowsVersion.allCases.reversed()) { version in
                            Text(version.displayName).tag(version)
                        }
                    }
                    Toggle("Enable DXVK for Direct3D 9–11 games", isOn: $dxvk)
                }
                Section("Appearance") {
                    AppearancePicker(symbol: $symbol, tint: $tint)
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)

            HStack {
                if model.runtime == nil {
                    Label("Wine isn't set up yet, so the bottle will be prepared later.", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .controlSize(.large)
                Button("Create Bottle", action: create)
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)
                    .prominentGlassButton(tint: tint.color)
                    .disabled((try? validation.get()) == nil)
                    .accessibilityIdentifier("createBottleButton")
            }
            .padding(20)
        }
        .frame(width: 520)
        .onAppear { nameFocused = true }
    }

    static func message(for error: BottleNameError) -> LocalizedStringKey {
        switch error {
        case .empty: return "Give your bottle a name."
        case .tooLong(let limit): return "Bottle names can be up to \(limit) characters."
        case .invalidCharacters: return "Bottle names can't contain “/” or “:”."
        }
    }

    private func create() {
        guard case .success = validation else { return }
        if model.createBottle(preview) != nil {
            dismiss()
        }
    }
}
