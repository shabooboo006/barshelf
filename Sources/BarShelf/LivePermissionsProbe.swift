// LivePermissionsProbe.swift — BarShelf
//
// Production implementation of PermissionsProbe using CoreGraphics and
// ApplicationServices APIs. Lives in the executable target so it is never
// imported by unit-tested modules.

@preconcurrency import ApplicationServices
import CoreGraphics
import BarShelfUIKit

// MARK: - LivePermissionsProbe

struct LivePermissionsProbe: PermissionsProbe {
    var axTrusted: Bool {
        AXIsProcessTrusted()
    }

    var screenGranted: Bool {
        CGPreflightScreenCaptureAccess()
    }
}

// MARK: - Request helpers (fire-and-forget; prompt shown by macOS)

/// Triggers the macOS Accessibility permission prompt for BarShelf.
func requestAccessibilityPrompt() {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    _ = AXIsProcessTrustedWithOptions(options)
}

/// Requests Screen Recording access (shows the TCC prompt the first time AND
/// registers BarShelf in the Screen & System Audio Recording pane — preflight
/// alone never registers the app, which was the rc1 onboarding deadlock).
func requestScreenRecording() {
    CGRequestScreenCaptureAccess()
}

// MARK: - LivePermissionRequester

/// Live `PermissionRequester`: wires the onboarding cards to the real OS request
/// APIs. Lives in the exe target (never unit-tested), mirroring `LivePermissionsProbe`.
struct LivePermissionRequester: PermissionRequester {
    func request(_ kind: PermissionKind) {
        switch kind {
        case .accessibility:   requestAccessibilityPrompt()
        case .screenRecording: requestScreenRecording()
        }
    }
}
