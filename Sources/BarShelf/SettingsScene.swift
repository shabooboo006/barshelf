// SettingsScene.swift — BarShelf
//
// SwiftUI settings window: lists detected menu bar items with icon thumbnail,
// app name, and a 3-state segmented Picker for each row. Footer: launch-at-login
// toggle + quit button.
//
// Bundle.module glyph note: state-glyph PNGs (StateAlwaysVisible, StateShelved,
// StateShowWhenActive) in Resources/ are loaded via Bundle.module. If lookup fails
// at runtime the SF Symbol fallbacks ("eye", "archivebox", "app.badge") are used.

import SwiftUI
import AppKit
import BarShelfCore
import BarShelfUIKit

// MARK: - SettingsScene

struct SettingsScene: View {
    /// The model is owned by the caller (AppController) and passed as a reference.
    @State private var model: SettingsModel
    private let launchController: LaunchAtLoginController

    init(model: SettingsModel, launchController: LaunchAtLoginController) {
        _model = State(initialValue: model)
        self.launchController = launchController
    }

    var body: some View {
        VStack(spacing: 0) {
            itemList
            Divider()
            footer
        }
        .onAppear { model.reload() }
    }

    // MARK: – Item list

    private var itemList: some View {
        List(model.rows, id: \.id.bundleID) { row in
            SettingsRow(row: row, model: model)
        }
        .listStyle(.inset)
        .frame(minWidth: 460, minHeight: 280)
    }

    // MARK: – Footer

    private var footer: some View {
        HStack {
            LaunchAtLoginToggle(controller: launchController)
            Spacer()
            Button("退出") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - SettingsRow

/// A single row in the settings list.
private struct SettingsRow: View {
    let row: SettingsModel.Row
    let model: SettingsModel

    /// Async-loaded thumbnail.
    @State private var thumbnail: NSImage? = nil

    var body: some View {
        HStack(spacing: 10) {
            iconView
            Text(row.appName)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            statePicker
        }
        .padding(.vertical, 4)
        .task(id: row.id.bundleID) {
            if let data = await model.thumbnailData(for: row.id),
               let img  = NSImage(data: data) {
                thumbnail = img
            }
        }
    }

    // MARK: Icon

    private var iconView: some View {
        Group {
            if let img = thumbnail {
                Image(nsImage: img)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: "square.grid.2x2")
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Picker

    private var statePicker: some View {
        // Binding that reads from the row and writes through setState.
        let binding = Binding<ItemState>(
            get: { row.state },
            set: { newState in
                model.setState(newState, for: row.id)
            }
        )
        return Picker("", selection: binding) {
            stateLabel(for: .alwaysVisible).tag(ItemState.alwaysVisible)
            stateLabel(for: .shelved).tag(ItemState.shelved)
            stateLabel(for: .showWhenActive).tag(ItemState.showWhenActive)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 220)
        .disabled(row.immovable)
    }

    // MARK: State label (PNG glyph → SF Symbol fallback)

    private func stateLabel(for state: ItemState) -> some View {
        switch state {
        case .alwaysVisible:
            return glyphOrSymbol(
                resourceName: "StateAlwaysVisible",
                systemName: "eye",
                label: "常显"
            )
        case .shelved:
            return glyphOrSymbol(
                resourceName: "StateShelved",
                systemName: "archivebox",
                label: "收进架"
            )
        case .showWhenActive:
            return glyphOrSymbol(
                resourceName: "StateShowWhenActive",
                systemName: "app.badge",
                label: "激活时"
            )
        }
    }

    private func glyphOrSymbol(resourceName: String, systemName: String, label: String) -> some View {
        // Bundle.module holds resources from Sources/BarShelf/Resources/ (via .copy("Resources")).
        // The PNG is at Resources/<name>.png inside the bundle.
        let resourceURL = Bundle.module.url(
            forResource: "Resources/\(resourceName)",
            withExtension: "png"
        )
        if let url = resourceURL, let img = NSImage(contentsOf: url) {
            return AnyView(
                Image(nsImage: img)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 14, height: 14)
                    .help(label)
            )
        } else {
            return AnyView(
                Image(systemName: systemName)
                    .help(label)
            )
        }
    }
}

// MARK: - LaunchAtLoginToggle

/// Wraps a LaunchAtLoginController in a toggle — must live on @MainActor since
/// LaunchAtLoginController is not Sendable.
private struct LaunchAtLoginToggle: View {
    let controller: LaunchAtLoginController
    @State private var isOn: Bool = false

    var body: some View {
        Toggle("开机启动", isOn: $isOn)
            .toggleStyle(.checkbox)
            .onAppear { isOn = controller.isEnabled }
            .onChange(of: isOn) { _, newVal in
                controller.setEnabled(newVal)
            }
    }
}

// MARK: - Factory

/// Creates and returns a settings NSWindow on demand (opened by caller; not retained
/// at launch). Uses NSHostingController so SwiftUI manages the view lifecycle.
@MainActor
func makeSettingsWindow(
    model: SettingsModel,
    launchController: LaunchAtLoginController
) -> NSWindow {
    let contentView = SettingsScene(
        model: model,
        launchController: launchController
    )
    let hosting = NSHostingController(rootView: contentView)

    let window = NSWindow(contentViewController: hosting)
    window.title            = "BarShelf 设置"
    window.styleMask        = [.titled, .closable, .miniaturizable, .resizable]
    window.isReleasedWhenClosed = false   // caller retains; re-open after close
    window.center()
    return window
}
