import Foundation
import XCTest

/// Intercepts every request on a session made by `makeSession()` and answers
/// with whatever `handler` returns. Records requests, including bodies that
/// URLSession moves into `httpBodyStream`.
final class FakeURLProtocol: URLProtocol {
    struct Recorded { let request: URLRequest; let body: Data }

    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    nonisolated(unsafe) static var recorded: [Recorded] = []
    private static let lock = NSLock()

    static func reset() { lock.withLock { handler = nil; recorded = [] } }

    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FakeURLProtocol.self]
        return URLSession(configuration: config)
    }

    /// Queue responses in order; each request consumes the next one.
    static func respond(with responses: [(status: Int, body: Data)]) {
        var queue = responses
        lock.withLock {
            handler = { request in
                let next = queue.isEmpty ? (status: 500, body: Data("no fixture left".utf8)) : queue.removeFirst()
                let response = HTTPURLResponse(url: request.url!, statusCode: next.status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": next.status == 200 ? "text/event-stream" : "application/json"])!
                return (response, next.body)
            }
        }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let body = Self.bodyData(of: request)
        let handler = Self.lock.withLock { Self.handler }
        Self.lock.withLock { Self.recorded.append(Recorded(request: request, body: body)) }
        do {
            guard let handler else { throw URLError(.unsupportedURL) }
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    private static func bodyData(of request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open(); defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: buffer.count)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}
