//
//  OnboardingView.swift
//  Bourbon
//

import BourbonKit
import SwiftUI

struct OnboardingView: View {
    @Environment(AppModel.self) private var model

    enum Step: Int, CaseIterable {
        case welcome, rosetta, wine, ready
    }

    @State private var step = Step.welcome
    @State private var installingRosetta = false

    var body: some View {
        ZStack {
            BourbonBackdrop()
            VStack(spacing: 0) {
                StepIndicator(current: step)
                    .padding(.top, 26)

                Group {
                    switch step {
                    case .welcome: welcome
                    case .rosetta: rosetta
                    case .wine: wine
                    case .ready: ready
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 48)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)))
                .id(step)
            }
            .foregroundStyle(.white)
        }
        .frame(width: 640, height: 520)
        .environment(\.colorScheme, .dark)
    }

    // MARK: Steps

    private var welcome: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "wineglass.fill")
                .font(.system(size: 72, weight: .semibold))
                .foregroundStyle(BottleTint.amber.gradient)
                .symbolEffect(.bounce, value: step)
            Text("Welcome to Bourbon")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .accessibilityIdentifier("onboardingTitle")
            Text("Run Windows apps and games on your Mac. Bourbon keeps each one in its own bottle, tuned and ready to go.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.75))
                .frame(maxWidth: 440)
            Spacer()
            continueButton(String(localized: "Get Started")) { advance(from: .welcome) }
        }
        .padding(.bottom, 36)
    }

    private var rosetta: some View {
        StepLayout(symbol: "cpu", title: "Install Rosetta",
                   message: "Wine runs Intel code. Rosetta 2 translates it for Apple silicon. You'll be asked for your password.") {
            if installingRosetta {
                ProgressView().controlSize(.large)
            } else {
                continueButton(String(localized: "Install Rosetta")) {
                    Task {
                        installingRosetta = true
                        defer { installingRosetta = false }
                        do {
                            try await RosettaSupport.install()
                            model.rosettaInstalled = true
                            advance(from: .rosetta)
                        } catch {
                            model.present(error)
                        }
                    }
                }
                Button("Skip for now") { advance(from: .rosetta) }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    private var wine: some View {
        @Bindable var model = model
        let downloading = model.activities.contains { $0.symbol == "arrow.down.circle" }
        let progress = model.activities.first { $0.symbol == "arrow.down.circle" }?.progress

        return StepLayout(symbol: "shippingbox.fill", title: "Get Wine",
                          message: "Bourbon uses Wine to translate Windows calls into macOS ones. Use one you already have, or download a fresh build.") {
            if !model.detectedRuntimes.isEmpty {
                VStack(spacing: 8) {
                    ForEach(model.detectedRuntimes) { runtime in
                        Button {
                            model.useRuntime(runtime)
                        } label: {
                            HStack {
                                Image(systemName: runtime == model.runtime ? "checkmark.circle.fill" : "circle")
                                Text(runtime.displayName)
                                Spacer()
                                Text(runtime.binDirectory.path)
                                    .font(.caption.monospaced())
                                    .lineLimit(1)
                                    .truncationMode(.head)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            .padding(12)
                            .glassSurface(cornerRadius: 14)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: 460)
            }

            if downloading {
                VStack(spacing: 8) {
                    ProgressView(value: progress ?? 0)
                        .frame(width: 320)
                    Text("Downloading and unpacking Wine…")
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.75))
                }
                .accessibilityIdentifier("wineDownloadProgress")
            } else if model.runtime == nil {
                Picker("Build", selection: $model.runtimeFlavor) {
                    ForEach(RuntimeRelease.Flavor.allCases) { flavor in
                        Text(LocalizedStringKey(flavor.displayName)).tag(flavor)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 280)
                continueButton(String(localized: "Download Wine"), id: "downloadWineButton") {
                    Task {
                        await model.installRuntime()
                        if model.runtime != nil { advance(from: .wine) }
                    }
                }
            } else {
                continueButton(String(localized: "Continue")) { advance(from: .wine) }
            }
        }
    }

    private var ready: some View {
        StepLayout(symbol: "checkmark.seal.fill", title: "You're all set",
                   message: "Create a bottle, then run any Windows installer or drop a .exe onto it.") {
            continueButton(String(localized: "Start Using Bourbon"), id: "finishOnboardingButton") {
                model.completeOnboarding()
                if model.bottles.isEmpty { model.showingNewBottle = true }
            }
        }
    }

    // MARK: Helpers

    private func continueButton(_ title: String, id: String = "onboardingContinue",
                                action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(minWidth: 200)
                .padding(.vertical, 4)
        }
        .controlSize(.large)
        .prominentGlassButton(tint: BottleTint.amber.color)
        .keyboardShortcut(.defaultAction)
        .accessibilityIdentifier(id)
    }

    private func advance(from current: Step) {
        var next = Step(rawValue: current.rawValue + 1) ?? .ready
        if next == .rosetta, model.rosettaInstalled { next = .wine }
        withAnimation(.spring(duration: 0.45)) { step = next }
    }
}

private struct StepLayout<Actions: View>: View {
    let symbol: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: symbol)
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(BottleTint.amber.gradient)
            Text(title)
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.75))
                .frame(maxWidth: 440)
            Spacer()
            VStack(spacing: 12) { actions }
        }
        .padding(.bottom, 36)
    }
}

private struct StepIndicator: View {
    let current: OnboardingView.Step

    var body: some View {
        HStack(spacing: 8) {
            ForEach(OnboardingView.Step.allCases, id: \.self) { step in
                Capsule()
                    .fill(step.rawValue <= current.rawValue ? AnyShapeStyle(BottleTint.amber.gradient)
                                                             : AnyShapeStyle(Color.white.opacity(0.2)))
                    .frame(width: step == current ? 28 : 8, height: 8)
            }
        }
        .animation(.spring(duration: 0.4), value: current)
        .accessibilityHidden(true)
    }
}
