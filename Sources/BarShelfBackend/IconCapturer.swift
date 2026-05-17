// IconCapturer.swift — BarShelfBackend
//
// On-demand single-window image capture using ScreenCaptureKit (macOS 14+).
//
// DEVIATION FROM SPEC: The spec referenced `CGWindowListCreateImage`, which was
// obsoleted in macOS 15.0 and is fully unavailable on the macOS 26.0 deployment target
// (compiler error: "'CGWindowListCreateImage' is unavailable in macOS: Please use
// ScreenCaptureKit instead"). The implementation uses
// `SCScreenshotManager.captureImage(contentFilter:configuration:)` (macOS 14.0+)
// which is the correct replacement. The signature is `async throws` rather than the
// spec's synchronous `-> Data?` because SCK screenshot capture is inherently async.
// Callers must `await` on a `@MainActor` context (e.g. inside a `Task { @MainActor in … }`).
//
// Called only when the BarShelf Bar is being shown (so the purple Screen Recording
// indicator lights only briefly — Risk Register #3).
//
// Swift 6 concurrency:
//   • @MainActor on the entry point — NSBitmapImageRep is AppKit.
//   • SCShareableContent.current() and SCScreenshotManager.captureImage are async;
//     called with `await` inside the @MainActor method.
//   • No global mutable state.

import AppKit
import ScreenCaptureKit

// MARK: - IconCapturer

/// Captures a single menu-bar status-item window as a PNG-encoded ``Data`` blob.
public enum IconCapturer {

    // MARK: Public API

    /// Capture window `wid` and return a PNG-encoded ``Data``.
    ///
    /// Uses `SCShareableContent.current()` to locate the ``SCWindow`` matching `wid`,
    /// then `SCScreenshotManager.captureImage(contentFilter:configuration:)` to obtain
    /// the pixel data. Crops to window content bounds (no shadow) by using
    /// `SCContentFilter(desktopIndependentWindow:)`.
    ///
    /// - Parameter wid: The CGWindowID of the status-item window to capture.
    /// - Returns: PNG data on success.
    /// - Throws: Any error from SCK or if no matching window is found.
    ///
    /// **Note:** Screen Recording permission must be granted before calling; no
    /// permission check is performed here (`PermissionsManager`'s responsibility).
    ///
    /// **Deviation from spec:** `CGWindowListCreateImage` is unavailable on macOS 26.0;
    /// this async SCK-based implementation is the required replacement.
    @MainActor
    public static func capture(wid: UInt32) async throws -> Data {
        // 1. Enumerate shareable content to find the SCWindow matching our wid.
        let content = try await SCShareableContent.current
        guard let scWindow = content.windows.first(where: { $0.windowID == wid }) else {
            throw CaptureError.windowNotFound(wid: wid)
        }

        // 2. Build a filter for just this window (desktop-independent = no shadow/bg).
        let filter = SCContentFilter(desktopIndependentWindow: scWindow)

        // 3. Minimal stream configuration — default size / pixel format is sufficient for
        //    a thumbnail; SCK will use the window's own pixel dimensions.
        let config = SCStreamConfiguration()
        config.scalesToFit = true

        // 4. Capture a single frame as a CGImage.
        let cgImage = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )

        // 5. PNG-encode via NSBitmapImageRep.
        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let data = rep.representation(using: .png, properties: [:] as [NSBitmapImageRep.PropertyKey: Any]) else {
            throw CaptureError.encodingFailed
        }
        return data
    }

    // MARK: Error type

    public enum CaptureError: Error, Sendable {
        case windowNotFound(wid: UInt32)
        case encodingFailed
    }
}
