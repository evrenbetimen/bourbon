//
//  SidebarView.swift
//  Bourbon
//

import AppKit
import BourbonKit
import SwiftUI

struct SidebarView: View {
    @Environment(AppModel.self) private var model
    @State private var renaming: Bottle?
    @State private var pendingDeletion: Bottle?

    private var pendingDeletionName: String { pendingDeletion?.name ?? "" }

    var body: some View {
        @Bindable var model = model

        List(selection: $model.selection) {
            Section("Bottles") {
                ForEach(model.filteredBottles) { bottle in
                    BottleRow(bottle: bottle, programCount: model.programs[bottle.id]?.count)
                        .tag(bottle.id)
                        .contextMenu { menu(for: bottle) }
                        .accessibilityIdentifier("bottleRow-\(bottle.name)")
                }
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $model.sidebarSearch, placement: .sidebar, prompt: "Search bottles")
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                RuntimeStatus()
                Button {
                    model.showingNewBottle = true
                } label: {
                    Label("New Bottle", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .secondaryGlassButton()
                .accessibilityIdentifier("newBottleButton")
            }
            .padding(12)
        }
        .overlay {
            if model.bootstrapped, model.filteredBottles.isEmpty, !model.sidebarSearch.isEmpty {
                ContentUnavailableView.search(text: model.sidebarSearch)
            }
        }
        .sheet(item: $renaming) { bottle in
            RenameSheet(bottle: bottle)
        }
        .confirmationDialog(
            "Delete \(pendingDeletionName)?",
            isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
            presenting: pendingDeletion
        ) { bottle in
            Button("Move to Trash", role: .destructive) { model.delete(bottle) }
                .accessibilityIdentifier("confirmDeleteButton")
        } message: { _ in
            Text("The bottle and every program installed in it will be moved to the Trash.")
        }
    }

    @ViewBuilder
    private func menu(for bottle: Bottle) -> some View {
        Button("Rename…", systemImage: "pencil") { renaming = bottle }
        Button("Duplicate", systemImage: "plus.square.on.square") { model.duplicate(bottle) }
        Button("Show in Finder", systemImage: "folder") {
            NSWorkspace.shared.activateFileViewerSelecting([bottle.url])
        }
        Divider()
        Button("Delete…", systemImage: "trash", role: .destructive) { pendingDeletion = bottle }
    }
}

struct BottleRow: View {
    let bottle: Bottle
    let programCount: Int?

    var body: some View {
        HStack(spacing: 10) {
            BottleIcon(settings: bottle.settings, size: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(bottle.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(bottle.settings.windowsVersion.displayName)
                    if let programCount {
                        Text("·")
                        Text("\(programCount) programs")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }
}

/// Shows which Wine runtime is in use, or prompts to set one up.
struct RuntimeStatus: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Button {
            model.showingOnboarding = true
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(model.runtime == nil ? Color.orange : Color.green)
                    .frame(width: 8, height: 8)
                Text(model.runtime?.displayName ?? String(localized: "Set up Wine"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("runtimeStatus")
    }
}

struct RenameSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let bottle: Bottle
    @State private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rename Bottle")
                .font(.title2.weight(.semibold))
            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .onSubmit(save)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Rename", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled((try? BottleStore.validateName(name).get()) == nil)
            }
        }
        .padding(24)
        .frame(width: 380)
        .onAppear { name = bottle.name }
    }

    private func save() {
        model.rename(bottle, to: name)
        dismiss()
    }
}
