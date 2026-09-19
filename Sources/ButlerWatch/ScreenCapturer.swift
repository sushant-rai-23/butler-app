import Foundation

/// Wraps ScreenCaptureKit behind a protocol.
///
/// The real implementation uses `SCScreenshotManager`, excludes Butler's own
/// windows, hides the cursor, downscales to `maxDimension`, and returns JPEG
/// bytes in memory. Pixels are requested lazily, only when a nudge rule needs
/// them, and are never written to disk.
public protocol ScreenCapturer: Sendable {
    var hasPermission: Bool { get }
    func captureJPEG(maxDimension: Int, quality: Double) async throws -> Data
}
