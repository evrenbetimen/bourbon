//
//  WinetricksSheet.swift
//  Bourbon
//

import BourbonKit
import SwiftUI

struct WinetricksSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let bottle: Bottle

    @State private var verbs = Winetricks.essentials
    @State private var query = ""
    @State private var selection: WinetricksVerb.ID?
    @State private var loadingAll = false

    private var filtered: [WinetricksVerb] { Winetricks.filter(verbs, query: query) }
    private var categories: [String] { Array(Set(filtered.map(\.category))).sorted() }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "wand.and.stars")
                    .font(.title)
                    .foregroundStyle(bottle.settings.tint.gradient)
                VStack(alignment: .leading) {
                    Text("Winetricks").font(.title2.weight(.bold))
                    Text("Install runtimes, fonts and fixes into \(bottle.name).")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if loadingAll {
                    ProgressView().controlSize(.small)
                } else if verbs.count == Winetricks.essentials.count {
                    Button("Show All") { Task { await loadAll() } }
                        .secondaryGlassButton()
                }
            }
            .padding(20)

            TextField("Search verbs", text: $query)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 20)
                .accessibilityIdentifier("winetricksSearch")

            List(selection: $selection) {
                ForEach(categories, id: \.self) { category in
                    Section(category.capitalized) {
                        ForEach(filtered.filter { $0.category == category }) { verb in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verb.name).font(.body.monospaced().weight(.medium))
                                if !verb.summary.isEmpty {
                                    Text(verb.summary).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .tag(verb.id)
                        }
                    }
                }
            }
            .listStyle(.inset)
            .frame(minHeight: 300)
            .overlay {
                if filtered.isEmpty { ContentUnavailableView.search(text: query) }
            }

            HStack {
                Spacer()
                Button("Close", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Install") {
                    if let verb = verbs.first(where: { $0.id == selection }) {
                        model.runWinetricks(verb, in: bottle)
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .prominentGlassButton(tint: bottle.settings.tint.color)
                .disabled(selection == nil)
                .accessibilityIdentifier("installVerbButton")
            }
            .padding(20)
        }
        .frame(width: 560, height: 560)
    }

    private func loadAll() async {
        loadingAll = true
        defer { loadingAll = false }
        guard !model.environment.isUITesting,
              let script = try? await WinetricksScript.ensure(at: model.environment.winetricksScript, simulated: false)
        else { return }
        let all = await WinetricksScript.listAll(script: script)
        if !all.isEmpty { verbs = all }
    }
}
