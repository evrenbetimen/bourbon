//
//  ContentView.swift
//  Bourbon
//

import BourbonKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 320)
        } detail: {
            if let bottle = model.selectedBottle {
                BottleDetailView(bottle: model.binding(for: bottle))
                    .id(bottle.id)
            } else {
                NoBottleView()
            }
        }
        .overlay(alignment: .bottom) { FeedbackOverlay().padding(.bottom, 18) }
        .sheet(isPresented: $model.showingNewBottle) {
            NewBottleSheet()
        }
        .sheet(isPresented: $model.showingOnboarding) {
            OnboardingView()
                .interactiveDismissDisabled(model.runtime == nil)
        }
        .sheet(isPresented: $model.showingWinetricks) {
            if let bottle = model.selectedBottle {
                WinetricksSheet(bottle: bottle)
            }
        }
        .fileImporter(
            isPresented: $model.showingRunPicker,
            allowedContentTypes: Self.runnableTypes
        ) { result in
            guard case .success(let url) = result, let bottle = model.selectedBottle else { return }
            model.run(fileAt: url, in: bottle)
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    static let runnableTypes: [UTType] = [
        .exe,
        UTType(filenameExtension: "msi") ?? .data,
        UTType(filenameExtension: "bat") ?? .data
    ]
}

/// Shown when there are no bottles yet.
struct NoBottleView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            BourbonBackdrop()
            VStack(spacing: 18) {
                Image(systemName: "wineglass.fill")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(BottleTint.amber.gradient)
                    .symbolEffect(.pulse, options: .repeating)
                Text("Pour your first bottle")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)
                Text("A bottle is a self-contained Windows environment. Create one, then install or drop in any Windows program.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(maxWidth: 460)
                Button {
                    model.showingNewBottle = true
                } label: {
                    Label("New Bottle", systemImage: "plus")
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                }
                .controlSize(.large)
                .prominentGlassButton(tint: BottleTint.amber.color)
                .accessibilityIdentifier("emptyStateNewBottleButton")
            }
            .padding(40)
        }
    }
}

/// Activity capsules and toasts float above the content.
struct FeedbackOverlay: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 8) {
            ForEach(model.activities) { activity in
                HStack(spacing: 10) {
                    Image(systemName: activity.symbol)
                        .symbolEffect(.pulse, options: .repeating)
                    Text(activity.title)
                        .font(.callout.weight(.medium))
                    if let progress = activity.progress {
                        ProgressView(value: progress)
                            .frame(width: 120)
                    } else {
                        ProgressView().controlSize(.small)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .glassSurface(cornerRadius: 22)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("activity")
            }
            if let toast = model.toast {
                Label(toast, systemImage: "checkmark.circle.fill")
                    .font(.callout.weight(.medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .glassSurface(cornerRadius: 22, tint: .green)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .accessibilityIdentifier("toast")
            }
        }
        .animation(.snappy, value: model.activities)
        .animation(.snappy, value: model.toast)
    }
}
