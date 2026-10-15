//
//  BottleDetailView.swift
//  Bourbon
//

import AppKit
import BourbonKit
import SwiftUI

struct BottleDetailView: View {
    @Environment(AppModel.self) private var model
    @Binding var bottle: Bottle
    @State private var isDropTargeted = false
    @State private var editingProgram: Program?

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 190), spacing: 16)]

    var body: some View {
        @Bindable var model = model
        let programs = model.programs(in: bottle)
        let pinned = model.pinnedPrograms(in: bottle)

        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HeroHeader(bottle: bottle)

                if !pinned.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Pinned")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(pinned) { program in
                                    ProgramCard(program: program, tint: bottle.settings.tint, isPinned: true,
                                                isRunning: model.isRunning(program), large: true)
                                        .onTapGesture(count: 2) { model.launch(program, in: bottle) }
                                        .contextMenu { programMenu(program) }
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        SectionHeader(title: "Library", count: programs.count)
                        Picker("Sort", selection: $model.libraryQuery.sort) {
                            Text("Name").tag(LibraryQuery.Sort.name)
                            Text("Recently Played").tag(LibraryQuery.Sort.recent)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .fixedSize()
                    }

                    if model.scanning.contains(bottle.id) && programs.isEmpty {
                        ProgressView("Looking for programs…")
                            .frame(maxWidth: .infinity, minHeight: 160)
                    } else if programs.isEmpty {
                        EmptyLibrary(searching: !model.libraryQuery.text.isEmpty)
                    } else {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(programs) { program in
                                ProgramCard(program: program, tint: bottle.settings.tint,
                                            isPinned: bottle.settings.isPinned(program.relativePath),
                                            isRunning: model.isRunning(program))
                                    .onTapGesture(count: 2) { model.launch(program, in: bottle) }
                                    .contextMenu { programMenu(program) }
                            }
                        }
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity)
        }
        .background(alignment: .top) {
            bottle.settings.tint.gradient
                .opacity(0.22)
                .frame(height: 360)
                .mask(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom))
                .ignoresSafeArea()
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(bottle.settings.tint.color, style: StrokeStyle(lineWidth: 3, dash: [10, 8]))
                    .overlay {
                        Label("Drop to run in \(bottle.name)", systemImage: "arrow.down.app.fill")
                            .font(.title2.weight(.semibold))
                            .padding(20)
                            .glassSurface(cornerRadius: 20, tint: bottle.settings.tint.color)
                    }
                    .padding(12)
                    .allowsHitTesting(false)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            let runnable = urls.filter { ["exe", "msi", "bat"].contains($0.pathExtension.lowercased()) }
            runnable.forEach { model.run(fileAt: $0, in: bottle) }
            return !runnable.isEmpty
        } isTargeted: { isDropTargeted = $0 }
        .searchable(text: $model.libraryQuery.text, placement: .toolbar, prompt: "Search programs")
        .navigationTitle(bottle.name)
        .navigationSubtitle(bottle.settings.windowsVersion.displayName)
        .toolbar { toolbar }
        .inspector(isPresented: $model.inspectorPresented) {
            BottleInspector(bottle: $bottle)
                .inspectorColumnWidth(min: 280, ideal: 310, max: 380)
        }
        .sheet(item: $editingProgram) { program in
            ProgramSettingsSheet(bottle: $bottle, program: program)
        }
        .onAppear { if model.programs[bottle.id] == nil { model.refreshPrograms(in: bottle) } }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup {
            Button {
                model.refreshPrograms(in: bottle)
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .help("Scan the bottle for programs again")

            Menu {
                ForEach(WineTool.allCases) { tool in
                    Button {
                        model.open(tool, in: bottle)
                    } label: {
                        Label(LocalizedStringKey(tool.displayName), systemImage: tool.symbol)
                    }
                }
                Divider()
                Button {
                    model.showingWinetricks = true
                } label: {
                    Label("Winetricks…", systemImage: "wand.and.stars")
                }
            } label: {
                Label("Tools", systemImage: "wrench.and.screwdriver")
            }
            .accessibilityIdentifier("toolsMenu")

            Button {
                model.inspectorPresented.toggle()
            } label: {
                Label("Inspector", systemImage: "sidebar.trailing")
            }
            .accessibilityIdentifier("inspectorToggle")
        }
    }

    @ViewBuilder
    private func programMenu(_ program: Program) -> some View {
        Button("Run", systemImage: "play.fill") { model.launch(program, in: bottle) }
        let pinned = bottle.settings.isPinned(program.relativePath)
        Button(pinned ? LocalizedStringKey("Unpin") : LocalizedStringKey("Pin"),
               systemImage: pinned ? "pin.slash" : "pin") {
            model.togglePin(program, in: bottle)
        }
        Button("Launch Options…", systemImage: "slider.horizontal.3") { editingProgram = program }
        Divider()
        Button("Show in Finder", systemImage: "folder") { model.reveal(program) }
        Button("Copy Terminal Command", systemImage: "terminal") { model.copyLaunchCommand(program, in: bottle) }
        Divider()
        Button("Hide from Library", systemImage: "eye.slash") { model.hide(program, in: bottle) }
    }
}

/// The large, glassy card at the top of a bottle.
struct HeroHeader: View {
    @Environment(AppModel.self) private var model
    let bottle: Bottle

    var body: some View {
        HStack(alignment: .center, spacing: 22) {
            BottleIcon(settings: bottle.settings, size: 88)
                .shadow(color: bottle.settings.tint.color.opacity(0.45), radius: 18, y: 8)

            VStack(alignment: .leading, spacing: 10) {
                Text(bottle.name)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .accessibilityIdentifier("bottleTitle")
                HStack(spacing: 6) {
                    ForEach(bottle.settings.highlights, id: \.self) { Chip(text: $0) }
                }
                HStack(spacing: 10) {
                    Button {
                        model.showingRunPicker = true
                    } label: {
                        Label("Run Program…", systemImage: "play.fill")
                            .padding(.horizontal, 6)
                    }
                    .controlSize(.large)
                    .prominentGlassButton(tint: bottle.settings.tint.color)
                    .accessibilityIdentifier("runProgramButton")

                    Button {
                        model.revealDriveC()
                    } label: {
                        Label("C: Drive", systemImage: "internaldrive")
                    }
                    .controlSize(.large)
                    .secondaryGlassButton()

                    Button {
                        model.killAllInSelectedBottle()
                    } label: {
                        Label("Stop All", systemImage: "stop.fill")
                    }
                    .controlSize(.large)
                    .secondaryGlassButton()
                }
            }
            Spacer(minLength: 0)
        }
        .padding(24)
        .glassSurface(cornerRadius: 30, tint: bottle.settings.tint.color)
    }
}

struct ProgramCard: View {
    let program: Program
    let tint: BottleTint
    let isPinned: Bool
    let isRunning: Bool
    var large = false

    @State private var hovering = false

    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .topTrailing) {
                ProgramIcon(program: program, size: large ? 64 : 52, tint: tint)
                if isRunning {
                    Circle()
                        .fill(.green)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                        .offset(x: 4, y: -4)
                        .accessibilityLabel("Running")
                }
            }
            VStack(spacing: 2) {
                Text(program.name)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                Text(program.directory.lastPathComponent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(16)
        .frame(width: large ? 170 : nil)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topLeading) {
            if isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(tint.color)
                    .padding(10)
            }
        }
        .glassSurface(cornerRadius: 20, tint: hovering ? tint.color : nil, interactive: true)
        .scaleEffect(hovering ? 1.03 : 1)
        .animation(.spring(duration: 0.25), value: hovering)
        .onHover { hovering = $0 }
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .help(program.relativePath)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Double-click to run")
        .accessibilityIdentifier("programCard-\(program.name)")
    }
}

struct EmptyLibrary: View {
    let searching: Bool

    var body: some View {
        if searching {
            ContentUnavailableView("No Matching Programs", systemImage: "magnifyingglass",
                                   description: Text("Try a different search."))
        } else {
            ContentUnavailableView {
                Label("No programs yet", systemImage: "square.dashed")
            } description: {
                Text("Run an installer with **Run Program…** or drop a .exe here. Installed programs appear automatically.")
            }
        }
    }
}
