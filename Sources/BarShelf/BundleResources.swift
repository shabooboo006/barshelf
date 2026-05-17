// BundleResources.swift — canonical resource-bundle accessor for the shipped .app.
//
// SwiftPM generates resource_bundle_accessor.swift with Bundle.module that resolves:
//   Bundle.main.bundleURL.appendingPathComponent("BarShelf_BarShelf.bundle")
// For a hand-assembled .app, Bundle.main.bundleURL = the .app itself, so this would
// look for .app/BarShelf_BarShelf.bundle — at the bundle ROOT, where codesign does not
// allow nested bundles (only items inside Contents/ are permitted).
//
// Instead, the build script places BarShelf_BarShelf.bundle inside Contents/Resources/,
// where codesign allows it.  This accessor finds the bundle there, with a dev-build
// fallback matching what SwiftPM's generated accessor uses.

import Foundation

extension Bundle {
    /// The BarShelf SwiftPM resource bundle, containing icons and PNGs from
    /// Sources/BarShelf/Resources/ (copied via `.copy("Resources")` in Package.swift).
    ///
    /// Lookup order:
    ///   1. Contents/Resources/BarShelf_BarShelf.bundle  — hand-assembled .app (production)
    ///   2. SwiftPM build output directory               — `swift run` / Xcode dev builds
    static var barshelfResources: Bundle {
        // 1. Production: bundle sits in Contents/Resources/ (codesign-safe location).
        if let resourceURL = Bundle.main.resourceURL {
            let candidate = resourceURL.appendingPathComponent("BarShelf_BarShelf.bundle")
            if let bundle = Bundle(url: candidate) {
                return bundle
            }
        }
        // 2. Dev / swift-build fallback: beside the executable in the SwiftPM build dir.
        let execDir = URL(fileURLWithPath: Bundle.main.executablePath ?? "")
            .deletingLastPathComponent()
        let devCandidate = execDir.appendingPathComponent("BarShelf_BarShelf.bundle")
        if let bundle = Bundle(url: devCandidate) {
            return bundle
        }
        // 3. Last resort: SwiftPM build-path baked in by the generated accessor.
        //    (Bundle.module uses this same path; calling it here avoids duplicating the
        //     hardcoded path while still giving a useful crash message.)
        return Bundle.module
    }
}
