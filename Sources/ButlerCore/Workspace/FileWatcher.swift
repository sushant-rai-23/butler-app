import Foundation

/// Watches a directory and a fixed set of files with DispatchSource. Editors
/// save atomically (write temp, rename), which fires on the directory and
/// invalidates the file descriptor, so file sources are re-armed after every
/// event. Events are debounced so one save fires the handler once.
final class FileWatcher {
    private let directory: URL
    private let files: [URL]
    private let handler: () -> Void
    private let queue = DispatchQueue(label: "com.butler.app.filewatcher")
    private var sources: [DispatchSourceFileSystemObject] = []
    private var pending: DispatchWorkItem?

    init(directory: URL, files: [URL], handler: @escaping () -> Void) {
        self.directory = directory
        self.files = files
        self.handler = handler
    }

    deinit {
        sources.forEach { $0.cancel() }
    }

    func start() {
        queue.sync { arm() }
    }

    func stop() {
        queue.sync {
            sources.forEach { $0.cancel() }
            sources.removeAll()
            pending?.cancel()
        }
    }

    private func arm() {
        sources.forEach { $0.cancel() }
        sources = ([directory] + files).compactMap { url in
            let fd = open(url.path, O_EVTONLY)
            guard fd >= 0 else { return nil }
            let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename, .delete, .attrib, .extend], queue: queue)
            source.setEventHandler { [weak self] in self?.changed() }
            source.setCancelHandler { close(fd) }
            source.resume()
            return source
        }
    }

    private func changed() {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.arm()
            self.handler()
        }
        pending = work
        queue.asyncAfter(deadline: .now() + 0.25, execute: work)
    }
}
