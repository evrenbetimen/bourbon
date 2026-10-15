//
//  AppModel.swift
//  Bourbon
//

import AppKit
import BourbonKit
import Observation
import SwiftUI

/// A long-running operation shown in the activity bar.
struct Activity: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var symbol: String
    var progress: Double?
}

@MainActor
@Observable
final class AppModel {
    let environment: AppEnvironment
    let store: BottleStore
    private let runner: ProcessRunning

    // MARK: State

    var bottles: [Bottle] = []
    var selection: Bottle.ID?
    var programs: [Bottle.ID: [Program]] = [:]
    var scanning: Set<Bottle.ID> = []

    var runtime: WineRuntime?
    var detectedRuntimes: [WineRuntime] = []
    var rosettaInstalled = true

    var activities: [Activity] = []
    var runningPrograms: [String: Int] = [:]
    var errorMessage: String?
    var toast: String?

    // MARK: Presentation

    var showingNewBottle = false
    var showingOnboarding = false
    var showingWinetricks = false
    var showingRunPicker = false
    var inspectorPresented = true
    var sidebarSearch = ""
    var libraryQuery = LibraryQuery()
    var bootstrapped = false

    var runtimeFlavor: RuntimeRelease.Flavor {
        didSet { defaults.set(runtimeFlavor.rawValue, forKey: Keys.runtimeFlavor) }
    }

    @ObservationIgnored private let defaults = UserDefaults.standard

    private enum Keys {
        static let preferredRuntimePath = "preferredRuntimePath"
        static let runtimeFlavor = "runtimeFlavor"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
    }

    private var preferredRuntimePath: String {
        get { defaults.string(forKey: Keys.preferredRuntimePath) ?? "" }
        set { defaults.set(newValue, forKey: Keys.preferredRuntimePath) }
    }

    private var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Keys.hasCompletedOnboarding) }
        set { defaults.set(newValue, forKey: Keys.hasCompletedOnboarding) }
    }

    init(environment: AppEnvironment) {
        self.environment = environment
        self.store = BottleStore(root: environment.bottlesRoot)
        self.runtimeFlavor = RuntimeRelease.Flavor(
            rawValue: UserDefaults.standard.string(forKey: Keys.runtimeFlavor) ?? ""
        ) ?? .stable
        if environment.isUITesting {
            runner = SimulatedRunner()
        } else {
            runner = SystemProcessRunner(logDirectory: environment.logsDirectory)
        }
    }

    // MARK: Derived

    var selectedBottle: Bottle? {
        guard let selection else { return nil }
        return bottles.first { $0.id == selection }
    }

    var filteredBottles: [Bottle] {
        LibraryQuery.filter(bottles, text: sidebarSearch)
    }

    var launcher: WineLauncher? {
        runtime.map { WineLauncher(runtime: $0, runner: runner) }
    }

    func programs(in bottle: Bottle) -> [Program] {
        libraryQuery.apply(to: programs[bottle.id] ?? [], settings: bottle.settings)
    }

    func pinnedPrograms(in bottle: Bottle) -> [Program] {
        bottle.settings.pinnedPrograms.map { pin in
            programs[bottle.id]?.first { $0.relativePath == pin.relativePath }
                ?? Program(url: bottle.resolve(relativePath: pin.relativePath), relativePath: pin.relativePath)
        }
    }

    func isRunning(_ program: Program) -> Bool {
        (runningPrograms[program.url.path] ?? 0) > 0
    }

    // MARK: Lifecycle

    func bootstrap() async {
        guard !bootstrapped else { return }
        bootstrapped = true

        if case .uiTest(let showOnboarding) = environment.mode {
            try? UITestSeed.populate(store)
            if showOnboarding {
                showingOnboarding = true
            } else {
                runtime = UITestSeed.runtime
            }
        } else {
            await refreshRuntimes()
            rosettaInstalled = await RosettaSupport.isInstalled()
            if runtime == nil || !hasCompletedOnboarding || !rosettaInstalled {
                showingOnboarding = true
            }
        }

        reloadBottles()
        if selection == nil { selection = bottles.first?.id }
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        showingOnboarding = false
        if environment.isUITesting, runtime == nil {
            runtime = UITestSeed.runtime
        }
    }

    func reloadBottles() {
        do {
            bottles = try store.loadAll()
        } catch {
            present(error)
        }
        for bottle in bottles where programs[bottle.id] == nil {
            refreshPrograms(in: bottle)
        }
    }

    // MARK: Runtimes

    func refreshRuntimes() async {
        let locator = RuntimeLocator(managedRoot: environment.runtimesRoot)
        var found = await Task.detached { locator.locateAll() }.value
        for index in found.indices {
            found[index].version = await WineLauncher(runtime: found[index], runner: runner).detectVersion()
        }
        detectedRuntimes = found
        runtime = found.first { $0.wineBinary.path == preferredRuntimePath } ?? found.first
    }

    func useRuntime(_ runtime: WineRuntime) {
        self.runtime = runtime
        preferredRuntimePath = runtime.wineBinary.path
    }

    func installRuntime() async {
        let flavor = runtimeFlavor
        let activity = begin(String(localized: "Downloading Wine"), symbol: "arrow.down.circle", progress: 0)
        defer { end(activity) }
        do {
            if environment.isUITesting {
                for step in 1...5 {
                    try await Task.sleep(nanoseconds: 120_000_000)
                    update(activity, progress: Double(step) / 5)
                }
                runtime = UITestSeed.runtime
                detectedRuntimes = [UITestSeed.runtime]
                return
            }
            let installer = RuntimeInstaller(runtimesRoot: environment.runtimesRoot)
            let installed = try await installer.installLatest(flavor: flavor) { [weak self] fraction in
                Task { @MainActor in self?.update(activity, progress: fraction) }
            }
            await refreshRuntimes()
            useRuntime(detectedRuntimes.first { $0.wineBinary == installed.wineBinary } ?? installed)
            showToast(String(localized: "Wine is ready"))
        } catch {
            present(error)
        }
    }

    // MARK: Bottles

    @discardableResult
    func createBottle(_ settings: BottleSettings) -> Bottle? {
        do {
            let bottle = try store.create(settings)
            reloadBottles()
            selection = bottle.id
            prepare(bottle)
            return bottle
        } catch {
            present(error)
            return nil
        }
    }

    private func prepare(_ bottle: Bottle) {
        guard let launcher else { return }
        Task {
            let activity = begin(String(localized: "Setting up \(bottle.name)"), symbol: "shippingbox")
            defer { end(activity) }
            do {
                try await launcher.prepare(bottle)
                refreshPrograms(in: bottle)
                showToast(String(localized: "\(bottle.name) is ready"))
            } catch {
                present(error)
            }
        }
    }

    /// Saves edited settings and applies registry-backed options to the prefix.
    func update(_ bottle: Bottle) {
        guard let index = bottles.firstIndex(where: { $0.id == bottle.id }) else { return }
        let old = bottles[index].settings
        guard old != bottle.settings else { return }
        bottles[index] = bottle
        do {
            try store.save(bottle)
        } catch {
            present(error)
            return
        }

        let needsRegistry = old.windowsVersion != bottle.settings.windowsVersion
            || old.retinaMode != bottle.settings.retinaMode
        guard needsRegistry, bottle.isInitialized || environment.isUITesting, let launcher else { return }
        Task {
            let activity = begin(String(localized: "Applying settings"), symbol: "gearshape.2")
            defer { end(activity) }
            do {
                try await launcher.apply(changesFrom: old, to: bottle)
            } catch {
                present(error)
            }
        }
    }

    func rename(_ bottle: Bottle, to name: String) {
        do {
            let renamed = try store.rename(bottle, to: name)
            if let index = bottles.firstIndex(where: { $0.id == bottle.id }) { bottles[index] = renamed }
        } catch {
            present(error)
        }
    }

    func duplicate(_ bottle: Bottle) {
        do {
            let copy = try store.duplicate(bottle)
            reloadBottles()
            selection = copy.id
        } catch {
            present(error)
        }
    }

    func delete(_ bottle: Bottle) {
        do {
            try store.delete(bottle, useTrash: !environment.isUITesting)
            programs[bottle.id] = nil
            if selection == bottle.id { selection = nil }
            reloadBottles()
            if selection == nil { selection = bottles.first?.id }
            showToast(String(localized: "Moved \(bottle.name) to the Trash"))
        } catch {
            present(error)
        }
    }

    func binding(for bottle: Bottle) -> Binding<Bottle> {
        Binding(
            get: { [weak self] in self?.bottles.first { $0.id == bottle.id } ?? bottle },
            set: { [weak self] in self?.update($0) }
        )
    }

    // MARK: Programs

    func refreshPrograms(in bottle: Bottle) {
        scanning.insert(bottle.id)
        Task {
            let found = await Task.detached { ProgramScanner().scan(bottle) }.value
            programs[bottle.id] = found
            scanning.remove(bottle.id)
        }
    }

    func launch(_ program: Program, in bottle: Bottle) {
        guard let launcher else { return requireRuntime() }
        runningPrograms[program.url.path, default: 0] += 1
        Task {
            defer { runningPrograms[program.url.path, default: 1] -= 1 }
            do {
                let updated = try await launcher.launch(program, in: currentVersion(of: bottle))
                update(updated)
            } catch {
                present(error)
            }
        }
    }

    /// Runs an executable or installer the user picked or dropped.
    func run(fileAt url: URL, in bottle: Bottle) {
        guard let launcher else { return requireRuntime() }
        Task {
            let activity = begin(String(localized: "Running \(url.lastPathComponent)"), symbol: "play.circle")
            defer { end(activity) }
            do {
                _ = try await launcher.run(fileAt: url, in: bottle)
                refreshPrograms(in: bottle)
            } catch {
                present(error)
            }
        }
    }

    func handleOpen(_ url: URL) {
        guard RunnableFile.isRunnable(url) else { return }
        guard let bottle = selectedBottle ?? bottles.first else {
            showingNewBottle = true
            return
        }
        run(fileAt: url, in: bottle)
    }

    func togglePin(_ program: Program, in bottle: Bottle) {
        var updated = currentVersion(of: bottle)
        updated.settings.togglePin(name: program.name, relativePath: program.relativePath)
        update(updated)
    }

    func hide(_ program: Program, in bottle: Bottle) {
        var updated = currentVersion(of: bottle)
        updated.settings.hiddenPrograms.append(program.relativePath)
        updated.settings.pinnedPrograms.removeAll { $0.relativePath == program.relativePath }
        update(updated)
        programs[bottle.id]?.removeAll { $0.relativePath == program.relativePath }
    }

    func reveal(_ program: Program) {
        NSWorkspace.shared.activateFileViewerSelecting([program.url])
    }

    func copyLaunchCommand(_ program: Program, in bottle: Bottle) {
        guard let runtime else { return requireRuntime() }
        do {
            let command = try WineCommandFactory(runtime: runtime).launch(program, in: currentVersion(of: bottle))
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(command.shellLine, forType: .string)
            showToast(String(localized: "Command copied"))
        } catch {
            present(error)
        }
    }

    // MARK: Bottle tools

    func open(_ tool: WineTool, in bottle: Bottle) {
        guard let launcher else { return requireRuntime() }
        Task {
            do {
                try await launcher.open(tool, in: bottle)
            } catch {
                present(error)
            }
        }
    }

    func revealDriveC() {
        guard let bottle = selectedBottle else { return }
        NSWorkspace.shared.open(bottle.driveC)
    }

    func killAllInSelectedBottle() {
        guard let bottle = selectedBottle, let launcher else { return }
        Task {
            do {
                try await launcher.killAll(in: bottle)
                runningPrograms = runningPrograms.filter { !$0.key.hasPrefix(bottle.url.path) }
                showToast(String(localized: "Stopped all programs"))
            } catch {
                present(error)
            }
        }
    }

    func runWinetricks(_ verb: WinetricksVerb, in bottle: Bottle) {
        guard let runtime else { return requireRuntime() }
        Task {
            let activity = begin(String(localized: "Installing \(verb.name)"), symbol: "wand.and.stars")
            defer { end(activity) }
            do {
                let script = try await WinetricksScript.ensure(at: environment.winetricksScript,
                                                               simulated: environment.isUITesting)
                let command = try WineCommandFactory(runtime: runtime).winetricks(verb.name, script: script, in: bottle)
                let result = try await runner.run(command)
                guard result.succeeded else {
                    throw ProcessRunnerError.failed(command: "winetricks \(verb.name)", exitCode: result.exitCode,
                                                    output: result.output)
                }
                refreshPrograms(in: bottle)
                showToast(String(localized: "Installed \(verb.name)"))
            } catch {
                present(error)
            }
        }
    }

    // MARK: Activity & feedback

    func begin(_ title: String, symbol: String, progress: Double? = nil) -> Activity.ID {
        let activity = Activity(title: title, symbol: symbol, progress: progress)
        withAnimation(.snappy) { activities.append(activity) }
        return activity.id
    }

    func update(_ id: Activity.ID, progress: Double) {
        guard let index = activities.firstIndex(where: { $0.id == id }) else { return }
        activities[index].progress = progress
    }

    func end(_ id: Activity.ID) {
        withAnimation(.snappy) { activities.removeAll { $0.id == id } }
    }

    func showToast(_ message: String) {
        withAnimation(.spring(duration: 0.35)) { toast = message }
        Task {
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            if toast == message {
                withAnimation(.easeOut) { toast = nil }
            }
        }
    }

    func present(_ error: Error) {
        errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    private func requireRuntime() {
        showingOnboarding = true
    }

    private func currentVersion(of bottle: Bottle) -> Bottle {
        bottles.first { $0.id == bottle.id } ?? bottle
    }
}
