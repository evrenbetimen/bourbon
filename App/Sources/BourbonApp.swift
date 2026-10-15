//
//  BourbonApp.swift
//  Bourbon
//
//  Bourbon is free software, distributed under the GNU GPL v3.
//  Inspired by Whisky (https://github.com/Whisky-App/Whisky).
//

import BourbonKit
import SwiftUI

@main
struct BourbonApp: App {
    @State private var model = AppModel(environment: .current())

    var body: some Scene {
        WindowGroup("Bourbon", id: "main") {
            ContentView()
                .environment(model)
                .frame(minWidth: 940, minHeight: 600)
                .task { await model.bootstrap() }
                .onOpenURL { url in model.handleOpen(url) }
        }
        .windowToolbarStyle(.unified)
        .commands {
            BourbonCommands(model: model)
        }

        Settings {
            SettingsView()
                .environment(model)
        }
    }
}

struct BourbonCommands: Commands {
    let model: AppModel

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Bottle…") { model.showingNewBottle = true }
                .keyboardShortcut("n", modifiers: [.command])
            Button("Run Windows Program…") { model.showingRunPicker = true }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(model.selectedBottle == nil)
        }
        CommandGroup(after: .sidebar) {
            Button("Toggle Inspector") { model.inspectorPresented.toggle() }
                .keyboardShortcut("i", modifiers: [.command, .option])
        }
        CommandMenu("Bottle") {
            Button("Open C: Drive") { model.revealDriveC() }
                .disabled(model.selectedBottle == nil)
            Button("Winetricks…") { model.showingWinetricks = true }
                .disabled(model.selectedBottle == nil)
            Divider()
            Button("Stop All Programs") { model.killAllInSelectedBottle() }
                .keyboardShortcut(".", modifiers: [.command, .shift])
                .disabled(model.selectedBottle == nil)
        }
    }
}
