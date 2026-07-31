import XCTest
@testable import AIStatus

final class ServiceHealthTests: XCTestCase {
    func testOfficialStatusValuesMapToExpectedHealth() {
        XCTAssertEqual(ServiceHealth.from(raw: "operational"), .operational)
        XCTAssertEqual(ServiceHealth.from(raw: "UP"), .operational)
        XCTAssertEqual(ServiceHealth.from(raw: "degraded_performance"), .degraded)
        XCTAssertEqual(ServiceHealth.from(raw: "partial_outage"), .degraded)
        XCTAssertEqual(ServiceHealth.from(raw: "major_outage"), .outage)
        XCTAssertEqual(ServiceHealth.from(raw: "unexpected"), .unknown)
    }

    func testMenuBarIconsPreserveTheirStatusColor() {
        for health in ServiceHealth.allCases {
            XCTAssertFalse(MenuBarIconFactory.image(for: health).isTemplate)
        }
    }

    func testOperationalMenuBarIconUsesBlackCheckAndGreenCircle() {
        let palette = MenuBarIconFactory.paletteColors(for: .operational)

        XCTAssertEqual(palette.count, 2)
        XCTAssertEqual(palette[0], .black)
        XCTAssertEqual(palette[1], .systemGreen)
    }

    func testUnknownHealthUsesQuestionMarkIcon() {
        XCTAssertEqual(ServiceHealth.unknown.symbolName, "questionmark.circle.fill")
        XCTAssertNotEqual(
            MenuBarIconFactory.image(for: .unknown).tiffRepresentation,
            MenuBarIconFactory.image(for: .operational).tiffRepresentation
        )
    }

    func testClaudeUsesCurrentOfficialStatusDomain() {
        XCTAssertEqual(StatusAPIClient.claudeStatusEndpoint.host(), "status.claude.com")
        XCTAssertEqual(AIService.claude.statusPageURL.host(), "status.claude.com")
    }

    @MainActor
    func testNewInstallHidesCountAndEnablesEveryService() {
        let suiteName = "AIStatusTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = StatusStore(defaults: defaults)

        XCTAssertFalse(store.showsServiceCount)
        XCTAssertEqual(store.services.map(\.service), AIService.allCases)
    }

    @MainActor
    func testCountPreferencePersists() {
        let suiteName = "AIStatusTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let firstStore = StatusStore(defaults: defaults)
        firstStore.showsServiceCount = true

        XCTAssertTrue(StatusStore(defaults: defaults).showsServiceCount)
    }

    @MainActor
    func testServiceSelectionPersists() {
        let suiteName = "AIStatusTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let firstStore = StatusStore(defaults: defaults)
        firstStore.setService(.gemini, enabled: false)
        let restoredStore = StatusStore(defaults: defaults)

        XCTAssertFalse(restoredStore.isServiceEnabled(.gemini))
        XCTAssertFalse(restoredStore.services.contains { $0.service == .gemini })
        XCTAssertEqual(restoredStore.services.count, AIService.allCases.count - 1)
    }

    @MainActor
    func testAllClearRequiresCompletedOperationalRefresh() {
        let suiteName = "AIStatusTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = StatusStore(defaults: defaults)
        store.services = [status(.operational)]
        XCTAssertFalse(store.showsAllClear, "Initial state must not claim all clear")

        store.lastUpdated = .now
        XCTAssertTrue(store.showsAllClear)

        store.services = [status(.degraded)]
        XCTAssertFalse(store.showsAllClear, "Degraded health must not claim all clear")

        store.services = [status(.outage)]
        XCTAssertFalse(store.showsAllClear, "Outage health must not claim all clear")

        store.services = [status(.unknown)]
        XCTAssertFalse(store.showsAllClear, "Unknown health must not claim all clear")

        store.services = [status(.operational, incidents: ["Active incident"])]
        XCTAssertFalse(store.showsAllClear, "Active incidents must not claim all clear")
    }

    func testOversizedStatusResponseIsRejected() async {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [OversizedResponseURLProtocol.self]
        let client = StatusAPIClient(session: URLSession(configuration: configuration))

        let result = await client.fetchAll(services: [.perplexity])

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].health, .unknown)
        XCTAssertEqual(result[0].detail, "公式情報を取得できませんでした")
    }

    func testDestinationPolicyAllowsOnlySameHTTPSOrigin() {
        let original = URL(string: "https://status.openai.com/api/v2/summary.json")!

        XCTAssertTrue(StatusDestinationPolicy.isAllowed(
            URL(string: "https://status.openai.com/maintenance.json"),
            relativeTo: original
        ))
        XCTAssertTrue(StatusDestinationPolicy.isAllowed(
            URL(string: "https://status.openai.com:443/maintenance.json"),
            relativeTo: original
        ))
        XCTAssertFalse(StatusDestinationPolicy.isAllowed(
            URL(string: "https://example.com/summary.json"),
            relativeTo: original
        ))
        XCTAssertFalse(StatusDestinationPolicy.isAllowed(
            URL(string: "http://status.openai.com/summary.json"),
            relativeTo: original
        ))
        XCTAssertFalse(StatusDestinationPolicy.isAllowed(
            URL(string: "https://127.0.0.1/summary.json"),
            relativeTo: original
        ))
        XCTAssertFalse(StatusDestinationPolicy.isAllowed(
            URL(string: "https://192.168.1.10/summary.json"),
            relativeTo: original
        ))
        XCTAssertFalse(StatusDestinationPolicy.isAllowed(
            URL(string: "https://169.254.1.1/summary.json"),
            relativeTo: original
        ))
        XCTAssertFalse(StatusDestinationPolicy.isAllowed(
            URL(string: "https://user@status.openai.com/summary.json"),
            relativeTo: original
        ))
        XCTAssertFalse(StatusDestinationPolicy.isAllowed(
            URL(string: "file:///tmp/summary.json"),
            relativeTo: original
        ))
    }

    func testMismatchedFinalResponseURLIsRejected() async {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MismatchedFinalURLProtocol.self]
        let client = StatusAPIClient(session: URLSession(configuration: configuration))

        let result = await client.fetchAll(services: [.perplexity])

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].health, .unknown)
        XCTAssertEqual(result[0].detail, "公式情報を取得できませんでした")
    }
}

private func status(
    _ health: ServiceHealth,
    incidents: [String] = []
) -> ServiceStatus {
    ServiceStatus(
        service: .openAI,
        health: health,
        detail: health.title,
        incidents: incidents,
        checkedAt: .now
    )
}

private final class OversizedResponseURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Length": "5242881", "Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class MismatchedFinalURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: URL(string: "http://127.0.0.1/internal-status")!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(#"{"page":{"status":"UP"}}"#.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
