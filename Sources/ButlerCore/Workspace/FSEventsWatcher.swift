import CoreServices
import Foundation

/// Watches the workspace root and everything under it.
///
/// FSEvents watches paths rather than file descriptors, so it sees files
/// created inside subfolders and survives the write-temp-then-rename that
/// editors do on save. Events are coalesced by the stream's own latency and
/// delivered on a private queue. NoDefer means the first event of a burst
/// arrives at once and the rest are coalesced behind it, so one save can call
/// the handler twice; the handler only refreshes what is already on screen.
final class FSEventsWatcher {
    /// What the C callback reaches, since a C callback cannot capture context.
    /// The stream owns this box through the context's retain and release
    /// callbacks, so the pointer is never resolved to a dead object, and the
    /// watcher itself is never deallocated on the stream's own queue — which
    /// would deadlock `deinit` against `stop()`'s `queue.sync`.
    private final class Sink {
        let handler: () -> Void
        init(handler: @escaping () -> Void) { self.handler = handler }
    }

    private let root: URL
    private let sink: Sink
    private let queue = DispatchQueue(label: "com.butler.app.fsevents")
    /// Touched only on `queue`, which is also where the callback is delivered,
    /// so arming, disarming and firing are serialised against each other.
    private var stream: FSEventStreamRef?

    init(root: URL, handler: @escaping () -> Void) {
        self.root = root
        self.sink = Sink(handler: handler)
    }

    deinit {
        stop()
    }

    func start() {
        queue.sync {
            guard stream == nil else { return }
            var context = FSEventStreamContext(
                version: 0,
                info: Unmanaged.passUnretained(sink).toOpaque(),
                retain: { info in
                    guard let info else { return nil }
                    return UnsafeRawPointer(Unmanaged<Sink>.fromOpaque(info).retain().toOpaque())
                },
                release: { info in
                    guard let info else { return }
                    Unmanaged<Sink>.fromOpaque(info).release()
                },
                copyDescription: nil
            )
            let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
                guard let info else { return }
                Unmanaged<Sink>.fromOpaque(info).takeUnretainedValue().handler()
            }
            let flags = UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer)
            guard let stream = FSEventStreamCreate(
                kCFAllocatorDefault,
                callback,
                &context,
                [root.path] as CFArray,
                FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
                0.5,
                flags
            ) else {
                // Without a watcher the app is still correct: systemPrompt()
                // reads from disk on every turn.
                return
            }
            FSEventStreamSetDispatchQueue(stream, queue)
            FSEventStreamStart(stream)
            self.stream = stream
        }
    }

    /// Invalidating on the stream's own queue is what makes "no callback after
    /// `stop()` returns" true: a callback already in flight finishes before
    /// this block runs, and none can be scheduled after it.
    func stop() {
        queue.sync {
            guard let stream else { return }
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
        }
    }
}
