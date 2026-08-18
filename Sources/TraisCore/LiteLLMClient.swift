import Foundation

public protocol SpendFetching: Sendable {
    func fetchSpend(endpoint: URL, apiKey: String) async throws -> Decimal
}

public enum LiteLLMClientError: LocalizedError, Equatable {
    case insecureEndpoint
    case invalidResponse
    case httpStatus(Int)
    case missingSpend

    public var errorDescription: String? {
        switch self {
        case .insecureEndpoint:
            return "The LiteLLM endpoint must use HTTPS."
        case .invalidResponse:
            return "The server returned an invalid response."
        case .httpStatus(let status):
            return "LiteLLM returned HTTP \(status)."
        case .missingSpend:
            return "The response did not contain a numeric info.spend value."
        }
    }
}

public final class LiteLLMClient: SpendFetching, @unchecked Sendable {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func fetchSpend(endpoint: URL, apiKey: String) async throws -> Decimal {
        guard endpoint.scheme?.lowercased() == "https", endpoint.host != nil else {
            throw LiteLLMClientError.insecureEndpoint
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(apiKey, forHTTPHeaderField: "x-litellm-api-key")

        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw LiteLLMClientError.invalidResponse
        }
        guard (200..<300).contains(response.statusCode) else {
            throw LiteLLMClientError.httpStatus(response.statusCode)
        }

        do {
            return try Self.decodeSpend(from: data)
        } catch {
            throw LiteLLMClientError.missingSpend
        }
    }

    public static func decodeSpend(from data: Data) throws -> Decimal {
        try JSONDecoder().decode(Response.self, from: data).info.spend.value
    }

    private struct Response: Decodable {
        let info: Info
    }

    private struct Info: Decodable {
        let spend: FlexibleDecimal
    }

    private struct FlexibleDecimal: Decodable {
        let value: Decimal

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let value = try? container.decode(Decimal.self) {
                self.value = value
                return
            }
            if let string = try? container.decode(String.self),
                let value = Decimal(string: string, locale: Locale(identifier: "en_US_POSIX"))
            {
                self.value = value
                return
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected a number or numeric string."
            )
        }
    }
}
