import Darwin
import Foundation
import TraisCore

@main
struct TraisCoreChecks {
    static func main() async {
        do {
            try checkDecoding()
            try await checkRequestConstruction()
            try await checkUnauthorizedResponse()
            try await checkRejectsInsecureEndpoint()
            try await runHistoryChecks()
            print("All trais core checks passed.")
        } catch {
            fputs("Check failed: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }

    private static func checkDecoding() throws {
        let numeric = Data(#"{"info":{"spend":123.456}}"#.utf8)
        let numericValue = try LiteLLMClient.decodeSpend(from: numeric)
        try require(
            numericValue == Decimal(string: "123.456"),
            "Numeric spend was not decoded exactly."
        )

        let string = Data(#"{"info":{"spend":"42.75"}}"#.utf8)
        let stringValue = try LiteLLMClient.decodeSpend(from: string)
        try require(
            stringValue == Decimal(string: "42.75"),
            "String spend was not decoded exactly."
        )
    }

    private static func checkRequestConstruction() async throws {
        defer { MockURLProtocol.handler = nil }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let endpoint = URL(string: "https://example.com/key/info")!

        MockURLProtocol.handler = { request in
            try require(request.httpMethod == "GET", "Expected a GET request.")
            try require(request.url == endpoint, "The request used the wrong endpoint.")
            try require(
                request.value(forHTTPHeaderField: "Accept") == "application/json",
                "The Accept header was missing."
            )
            try require(
                request.value(forHTTPHeaderField: "x-litellm-api-key") == "secret",
                "The API-key header was missing."
            )
            let response = HTTPURLResponse(
                url: endpoint,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(#"{"info":{"spend":7.5}}"#.utf8))
        }

        let value = try await LiteLLMClient(session: URLSession(configuration: configuration))
            .fetchSpend(endpoint: endpoint, apiKey: "secret")
        try require(value == Decimal(string: "7.5"), "The fetched spend was incorrect.")
    }

    private static func checkRejectsInsecureEndpoint() async throws {
        let endpoint = URL(string: "http://example.com/key/info")!
        do {
            _ = try await LiteLLMClient().fetchSpend(endpoint: endpoint, apiKey: "secret")
            throw CheckFailure("An insecure endpoint was accepted.")
        } catch let error as LiteLLMClientError {
            try require(error == .insecureEndpoint, "The wrong endpoint error was returned.")
        }
    }

    private static func checkUnauthorizedResponse() async throws {
        defer { MockURLProtocol.handler = nil }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let endpoint = URL(string: "https://example.com/key/info")!

        MockURLProtocol.handler = { _ in
            let response = HTTPURLResponse(
                url: endpoint,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        do {
            _ = try await LiteLLMClient(session: URLSession(configuration: configuration))
                .fetchSpend(endpoint: endpoint, apiKey: "secret")
            throw CheckFailure("An unauthorized response did not throw.")
        } catch let error as LiteLLMClientError {
            try require(error == .httpStatus(401), "The wrong HTTP error was returned.")
        }
    }
}

struct CheckFailure: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? { message }
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else { throw CheckFailure(message) }
}

private final class MockURLProtocol: URLProtocol {
    // The check executable installs one handler at a time and waits for each request to finish.
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
