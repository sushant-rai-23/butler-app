import Foundation

/// Gemini via the AI Studio REST API. The key comes from the Keychain under
/// `keychainKey` and travels only in the `x-goog-api-key` header.
public final class GeminiProvider: ModelProvider, @unchecked Sendable {
    public static let keychainKey = "gemini.apiKey"
    public static let defaultBaseURL = URL(string: "https://generativelanguage.googleapis.com/v1beta")!

    public let id = "gemini"
    private let keychain: any KeychainStore
    private let session: URLSession
    private let baseURL: URL

    public init(keychain: any KeychainStore, session: URLSession = .shared, baseURL: URL = GeminiProvider.defaultBaseURL) {
        self.keychain = keychain
        self.session = session
        self.baseURL = baseURL
    }

    public func listModels() async throws -> [ModelInfo] {
        let key = try apiKey()
        var models: [ModelInfo] = []
        var pageToken: String?
        repeat {
            var components = URLComponents(url: baseURL.appending(path: "models"), resolvingAgainstBaseURL: false)!
            var items = [URLQueryItem(name: "pageSize", value: "200")]
            if let pageToken { items.append(URLQueryItem(name: "pageToken", value: pageToken)) }
            components.queryItems = items
            var request = URLRequest(url: components.url!)
            request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
            let (data, response) = try await perform(request)
            guard response.statusCode == 200 else { throw GeminiMapping.error(status: response.statusCode, body: data) }
            let list: GeminiWire.ModelList
            do { list = try JSONDecoder().decode(GeminiWire.ModelList.self, from: data) }
            catch { throw ProviderError.malformedResponse("model list: \(error)") }
            models += GeminiMapping.modelInfos(from: list)
            pageToken = list.nextPageToken
        } while pageToken != nil
        return models
    }

    public func stream(_ chat: ChatRequest) -> AsyncThrowingStream<StreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let key = try apiKey()
                    var components = URLComponents(url: baseURL.appending(path: "models/\(chat.model):streamGenerateContent"), resolvingAgainstBaseURL: false)!
                    components.queryItems = [URLQueryItem(name: "alt", value: "sse")]
                    var request = URLRequest(url: components.url!)
                    request.httpMethod = "POST"
                    request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = try JSONEncoder().encode(GeminiMapping.request(from: chat))

                    let (bytes, response) = try await session.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else { throw ProviderError.network("no HTTP response") }
                    if http.statusCode != 200 {
                        var body = Data()
                        for try await byte in bytes { body.append(byte) }
                        throw GeminiMapping.error(status: http.statusCode, body: body)
                    }

                    var parser = SSEParser()
                    var finished = false
                    func handle(_ payload: String) throws {
                        let chunk: GeminiWire.Response
                        do { chunk = try JSONDecoder().decode(GeminiWire.Response.self, from: Data(payload.utf8)) }
                        catch { throw ProviderError.malformedResponse("chunk: \(payload.prefix(120))") }
                        for event in GeminiMapping.events(from: chunk) {
                            if case .finished = event { finished = true }
                            continuation.yield(event)
                        }
                    }
                    // `bytes.lines` drops the blank lines that separate SSE
                    // events, so split on newlines by hand.
                    var lineBuffer = Data()
                    for try await byte in bytes {
                        if byte == UInt8(ascii: "\n") {
                            let line = String(decoding: lineBuffer, as: UTF8.self)
                            lineBuffer.removeAll(keepingCapacity: true)
                            if let payload = parser.consume(line: line) { try handle(payload) }
                        } else {
                            lineBuffer.append(byte)
                        }
                    }
                    if !lineBuffer.isEmpty, let payload = parser.consume(line: String(decoding: lineBuffer, as: UTF8.self)) { try handle(payload) }
                    if let payload = parser.flush() { try handle(payload) }
                    if !finished { continuation.yield(.finished(.stop)) }
                    continuation.finish()
                } catch let error as ProviderError {
                    continuation.finish(throwing: error)
                } catch let error as URLError {
                    continuation.finish(throwing: ProviderError.network(error.localizedDescription))
                } catch {
                    continuation.finish(throwing: ProviderError.network(String(describing: error)))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func apiKey() throws -> String {
        guard let key = try keychain.get(Self.keychainKey), !key.isEmpty else { throw ProviderError.missingKey }
        return key
    }

    private func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ProviderError.network("no HTTP response") }
            return (data, http)
        } catch let error as URLError {
            throw ProviderError.network(error.localizedDescription)
        }
    }
}
