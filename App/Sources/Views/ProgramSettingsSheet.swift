//
//  ProgramSettingsSheet.swift
//  Bourbon
//

import BourbonKit
import SwiftUI

/// Launch options for one program: arguments, locale and extra environment.
struct ProgramSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var bottle: Bottle
    let program: Program

    @State private var settings = ProgramSettings()

    private struct LocaleOption: Identifiable {
        let id: String
        let name: String
        init(_ id: String, _ name: String) {
            self.id = id
            self.name = name
        }
    }

    private static let locales: [LocaleOption] = [
        LocaleOption("", "System default"),
        LocaleOption("en_US.UTF-8", "English (US)"),
        LocaleOption("tr_TR.UTF-8", "Türkçe"),
        LocaleOption("de_DE.UTF-8", "Deutsch"),
        LocaleOption("fr_FR.UTF-8", "Français"),
        LocaleOption("es_ES.UTF-8", "Español"),
        LocaleOption("ja_JP.UTF-8", "日本語"),
        LocaleOption("ko_KR.UTF-8", "한국어"),
        LocaleOption("zh_CN.UTF-8", "简体中文"),
        LocaleOption("ru_RU.UTF-8", "Русский")
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                ProgramIcon(program: program, size: 48, tint: bottle.settings.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(program.name).font(.title2.weight(.bold))
                    Text(program.relativePath)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
            }
            .padding(24)

            Form {
                Section {
                    TextField("Arguments", text: $settings.arguments, prompt: Text("-windowed -dx11"))
                        .font(.body.monospaced())
                        .accessibilityIdentifier("programArgumentsField")
                    if !settings.arguments.isEmpty {
                        LabeledContent("Parsed as") {
                            Text(CommandLineText.split(settings.arguments).joined(separator: " · "))
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                    Picker("Language", selection: Binding(
                        get: { settings.locale ?? "" },
                        set: { settings.locale = $0.isEmpty ? nil : $0 }
                    )) {
                        ForEach(Self.locales) { locale in
                            Text(LocalizedStringKey(locale.name)).tag(locale.id)
                        }
                    }
                } footer: {
                    Text("Some games only show the right characters when started in their own language.")
                }
                Section("Environment Variables") {
                    EnvironmentEditor(environment: $settings.environment)
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    bottle.settings.programSettings[program.relativePath] = settings
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .prominentGlassButton(tint: bottle.settings.tint.color)
                .accessibilityIdentifier("saveProgramSettingsButton")
            }
            .padding(20)
        }
        .frame(width: 520, height: 560)
        .onAppear {
            settings = bottle.settings.programSettings[program.relativePath] ?? ProgramSettings()
        }
    }
}
