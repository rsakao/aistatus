import Foundation

struct StatusAPIClient: Sendable {
    private static let maximumResponseBytes = 5 * 1024 * 1024
    private let session: URLSession
    private let redirectDelegate: StatusRedirectDelegate?

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
            redirectDelegate = nil
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 20
            configuration.timeoutIntervalForResource = 30
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            configuration.httpCookieStorage = nil
            configuration.urlCache = nil
            let redirectDelegate = StatusRedirectDelegate()
            self.redirectDelegate = redirectDelegate
            self.session = URLSession(
                configuration: configuration,
                delegate: redirectDelegate,
                delegateQueue: nil
            )
        }
    }

    func fetchAll(services: [AIService]) async -> [ServiceStatus] {
        await withTaskGroup(of: ServiceStatus.self, returning: [ServiceStatus].self) { group in
            for service in services {
                group.addTask {
                    await fetch(service)
                }
            }

            var results: [ServiceStatus] = []
            for await status in group {
                results.append(status)
            }
            let order = Dictionary(uniqueKeysWithValues: AIService.allCases.enumerated().map { ($1, $0) })
            return results.sorted { order[$0.service, default: .max] < order[$1.service, default: .max] }
        }
    }

    private func fetch(_ service: AIService) async -> ServiceStatus {
        do {
            switch service {
            case .openAI:
                return try await fetchStatusPage(
                    service,
                    endpoint: "https://status.openai.com/api/v2/summary.json"
                )
            case .claude:
                return try await fetchStatusPage(
                    service,
                    endpoint: "https://status.anthropic.com/api/v2/summary.json"
                )
            case .cursor:
                return try await fetchStatusPage(
                    service,
                    endpoint: "https://status.cursor.com/api/v2/summary.json"
                )
            case .copilot:
                return try await fetchStatusPage(
                    service,
                    endpoint: "https://www.githubstatus.com/api/v2/summary.json",
                    preferredComponents: ["Copilot", "Copilot AI Model Providers"]
                )
            case .perplexity:
                return try await fetchPerplexity()
            case .gemini:
                return try await fetchGemini()
            }
        } catch {
            return ServiceStatus(
                service: service,
                health: .unknown,
                detail: "公式情報を取得できませんでした",
                incidents: [],
                checkedAt: .now
            )
        }
    }

    private func fetchStatusPage(
        _ service: AIService,
        endpoint: String,
        preferredComponents: Set<String> = []
    ) async throws -> ServiceStatus {
        let data = try await data(from: endpoint)
        let summary = try JSONDecoder().decode(StatusPageSummary.self, from: data)
        let relevantComponents = preferredComponents.isEmpty
            ? summary.components
            : summary.components.filter { preferredComponents.contains($0.name) }

        let componentHealth = relevantComponents.map { ServiceHealth.from(raw: $0.status) }
        let pageHealth = summary.status.map { ServiceHealth.from(raw: $0.indicator) } ?? .unknown
        let health = (componentHealth + [pageHealth]).max { $0.severity < $1.severity } ?? .unknown
        let activeIncidents = summary.incidents
            .filter { !["resolved", "completed"].contains($0.status.lowercased()) }
            .prefix(20)
            .map { String($0.name.prefix(500)) }

        return ServiceStatus(
            service: service,
            health: activeIncidents.isEmpty || health.severity >= ServiceHealth.degraded.severity ? health : .degraded,
            detail: activeIncidents.first ?? health.title,
            incidents: activeIncidents,
            checkedAt: .now
        )
    }

    private func fetchPerplexity() async throws -> ServiceStatus {
        let data = try await data(from: "https://status.perplexity.com/api/v2/summary.json")
        let response = try JSONDecoder().decode(PerplexityResponse.self, from: data)
        let health = ServiceHealth.from(raw: response.page.status)
        return ServiceStatus(
            service: .perplexity,
            health: health,
            detail: health.title,
            incidents: [],
            checkedAt: .now
        )
    }

    private func fetchGemini() async throws -> ServiceStatus {
        let data = try await data(from: "https://status.cloud.google.com/incidents.json")
        let incidents = try JSONDecoder().decode([GoogleCloudIncident].self, from: data)
        let activeGeminiIncidents = incidents.filter { incident in
            guard incident.end == nil else { return false }
            let searchable = ([incident.externalDescription] + incident.affectedProducts.map(\.title))
                .joined(separator: " ")
                .lowercased()
            return searchable.contains("gemini") || searchable.contains("vertex ai")
        }
        let titles = activeGeminiIncidents
            .prefix(20)
            .map { String($0.externalDescription.prefix(500)) }
        let health: ServiceHealth = titles.isEmpty ? .operational : .degraded

        return ServiceStatus(
            service: .gemini,
            health: health,
            detail: titles.first ?? health.title,
            incidents: titles,
            checkedAt: .now
        )
    }

    private func data(from endpoint: String) async throws -> Data {
        guard let endpointURL = URL(string: endpoint),
              StatusDestinationPolicy.isAllowed(endpointURL, relativeTo: endpointURL) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: endpointURL)
        request.setValue("AIStatus-macOS/1.0", forHTTPHeaderField: "User-Agent")
        let (bytes, response) = try await session.bytes(for: request)
        guard StatusDestinationPolicy.isAllowed(response.url, relativeTo: endpointURL) else {
            throw URLError(.unsupportedURL)
        }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        if http.expectedContentLength > Self.maximumResponseBytes {
            throw URLError(.dataLengthExceedsMaximum)
        }

        var data = Data()
        data.reserveCapacity(min(max(Int(http.expectedContentLength), 0), Self.maximumResponseBytes))
        for try await byte in bytes {
            guard data.count < Self.maximumResponseBytes else {
                throw URLError(.dataLengthExceedsMaximum)
            }
            data.append(byte)
        }
        return data
    }
}

struct StatusDestinationPolicy {
    static func isAllowed(_ candidate: URL?, relativeTo original: URL?) -> Bool {
        guard let candidate,
              let original,
              candidate.scheme?.lowercased() == "https",
              original.scheme?.lowercased() == "https",
              candidate.user == nil,
              candidate.password == nil,
              original.user == nil,
              original.password == nil,
              candidate.host?.lowercased() == original.host?.lowercased(),
              effectiveHTTPSPort(candidate) == effectiveHTTPSPort(original) else {
            return false
        }
        return true
    }

    private static func effectiveHTTPSPort(_ url: URL) -> Int {
        url.port ?? 443
    }
}

private final class StatusRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        let originalURL = task.originalRequest?.url
        completionHandler(
            StatusDestinationPolicy.isAllowed(request.url, relativeTo: originalURL)
                ? request
                : nil
        )
    }
}

private struct StatusPageSummary: Decodable {
    let status: PageStatus?
    let components: [Component]
    let incidents: [Incident]

    struct PageStatus: Decodable {
        let indicator: String
    }

    struct Component: Decodable {
        let name: String
        let status: String
    }

    struct Incident: Decodable {
        let name: String
        let status: String
    }

    private enum CodingKeys: String, CodingKey {
        case status, components, incidents
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decodeIfPresent(PageStatus.self, forKey: .status)
        components = try container.decodeIfPresent([Component].self, forKey: .components) ?? []
        incidents = try container.decodeIfPresent([Incident].self, forKey: .incidents) ?? []
    }
}

private struct PerplexityResponse: Decodable {
    let page: Page

    struct Page: Decodable {
        let status: String
    }
}

private struct GoogleCloudIncident: Decodable {
    let end: String?
    let externalDescription: String
    let affectedProducts: [Product]

    struct Product: Decodable {
        let title: String
    }

    private enum CodingKeys: String, CodingKey {
        case end
        case externalDescription = "external_desc"
        case affectedProducts = "affected_products"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        end = try container.decodeIfPresent(String.self, forKey: .end)
        externalDescription = try container.decodeIfPresent(String.self, forKey: .externalDescription) ?? "Google Cloudで障害が発生しています"
        affectedProducts = try container.decodeIfPresent([Product].self, forKey: .affectedProducts) ?? []
    }
}
