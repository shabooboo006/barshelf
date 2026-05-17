import AppKit
@preconcurrency import ApplicationServices
import CoreGraphics

enum Permissions {
    static func report() {
        let ax = AXIsProcessTrusted()
        let screen = CGPreflightScreenCaptureAccess()
        Log.line("Accessibility trusted = \(ax)")
        Log.line("ScreenRecording granted = \(screen)")

        if !ax {
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            _ = AXIsProcessTrustedWithOptions(opts as CFDictionary)
            Log.line("Requested Accessibility (prompt shown if not yet granted).")
        }
        if !screen {
            let ok = CGRequestScreenCaptureAccess()
            Log.line("Requested ScreenRecording, immediate result = \(ok)")
        }
    }
}
