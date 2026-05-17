// OnboardingScene.swift — BarShelf
//
// Shown when PermissionsDecision != .ready. Guides the user through granting
// Screen Recording + Accessibility, then calls onContinue when both are granted.
// The window is "not closable to quit" — closing terminates the app because the app
// cannot function without both permissions. A small "退出" button is provided.

import SwiftUI
import AppKit
import BarShelfUIKit

// MARK: - OnboardingView

struct OnboardingView: View {
    let probe: PermissionsProbe
    let onRecheck: @MainActor () -> Void
    let onContinue: @MainActor () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Title
            Text("BarShelf 需要两项权限")
                .font(.title2)
                .bold()

            // One-line explanation
            Text("读取并整理菜单栏图标需要：辅助功能 + 屏幕录制；逐机授权，无法由开发者豁免")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Permission cards
            VStack(spacing: 12) {
                PermissionCard(
                    title: "辅助功能",
                    isGranted: probe.axTrusted,
                    settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                )
                PermissionCard(
                    title: "屏幕录制",
                    isGranted: probe.screenGranted,
                    settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
                )
            }

            // Re-open note
            Text("授权后需退出并重新打开 BarShelf")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            // Bottom actions
            HStack {
                Button("退出") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)

                Spacer()

                Button("重新检查") {
                    onRecheck()
                }

                Button("继续") {
                    onContinue()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!PermissionsDecision.decide(
                    ax: probe.axTrusted,
                    screen: probe.screenGranted
                ).isReady)
            }
        }
        .padding(24)
        .frame(minWidth: 440)
    }
}

// MARK: - PermissionCard

private struct PermissionCard: View {
    let title: String
    let isGranted: Bool
    let settingsURL: String

    var body: some View {
        HStack(spacing: 12) {
            // Status dot
            Circle()
                .fill(isGranted ? Color.green : Color.red)
                .frame(width: 10, height: 10)

            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button("打开系统设置") {
                guard let url = URL(string: settingsURL) else { return }
                NSWorkspace.shared.open(url)
            }
            .buttonStyle(.bordered)
        }
        .padding(12)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }
}

// MARK: - Factory

/// Creates and returns a centered, non-closable-to-quit onboarding NSWindow.
/// Closing the window terminates the app (no onboarding = app cannot function).
@MainActor
func makeOnboardingWindow(
    probe: PermissionsProbe,
    onRecheck: @escaping @MainActor () -> Void,
    onContinue: @escaping @MainActor () -> Void
) -> NSWindow {
    let contentView = OnboardingView(
        probe: probe,
        onRecheck: onRecheck,
        onContinue: onContinue
    )
    let hosting = NSHostingController(rootView: contentView)

    let window = NSWindow(contentViewController: hosting)
    window.title = "BarShelf — 权限设置"
    // Not closable via the red close button — omit .closable so closing is unavailable
    // at the window-chrome level; the "退出" button is the intended exit affordance.
    window.styleMask = [.titled, .miniaturizable]
    window.isReleasedWhenClosed = false
    window.center()
    return window
}
