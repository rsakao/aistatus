import AppKit
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class StatusStore {
    var services: [ServiceStatus]
    var isRefreshing = false
    var lastUpdated: Date?
    var showsServiceCount: Bool {
        didSet {
            defaults.set(showsServiceCount, forKey: Self.showsServiceCountKey)
        }
    }
    var refreshInterval: TimeInterval {
        didSet {
            defaults.set(refreshInterval, forKey: Self.refreshIntervalKey)
            restartRefreshLoop()
        }
    }
    var language: AppLanguage {
        didSet {
            defaults.set(language.rawValue, forKey: Self.languageKey)
        }
    }

    @ObservationIgnored private let client: StatusAPIClient
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var refreshLoopTask: Task<Void, Never>?
    @ObservationIgnored private var hasStarted = false
    @ObservationIgnored private var refreshAgainAfterCurrent = false
    private var enabledServiceIDs: Set<AIService.ID>

    private static let refreshIntervalKey = "refreshInterval"
    private static let showsServiceCountKey = "showsServiceCount"
    private static let enabledServiceIDsKey = "enabledServiceIDs"
    private static let languageKey = "language"

    init(
        client: StatusAPIClient = StatusAPIClient(),
        defaults: UserDefaults = .standard
    ) {
        self.client = client
        self.defaults = defaults
        let savedInterval = defaults.double(forKey: Self.refreshIntervalKey)
        refreshInterval = savedInterval > 0 ? savedInterval : 300
        showsServiceCount = defaults.bool(forKey: Self.showsServiceCountKey)
        language = AppLanguage(rawValue: defaults.string(forKey: Self.languageKey) ?? "") ?? .japanese

        let initialEnabledServiceIDs: Set<AIService.ID>
        if let savedIDs = defaults.array(forKey: Self.enabledServiceIDsKey) as? [String] {
            initialEnabledServiceIDs = Set(savedIDs).intersection(Set(AIService.allCases.map(\.id)))
        } else {
            initialEnabledServiceIDs = Set(AIService.allCases.map(\.id))
        }
        enabledServiceIDs = initialEnabledServiceIDs
        services = AIService.allCases
            .filter { initialEnabledServiceIDs.contains($0.id) }
            .map(ServiceStatus.waiting)
    }

    var overallHealth: ServiceHealth {
        services.map(\.health).max { $0.severity < $1.severity } ?? .unknown
    }

    var operationalCount: Int {
        services.filter { $0.health == .operational }.count
    }

    var activeIncidents: [(service: AIService, title: String)] {
        services.flatMap { status in
            status.incidents.map { (status.service, $0) }
        }
    }

    var showsAllClear: Bool {
        lastUpdated != nil
            && !services.isEmpty
            && overallHealth == .operational
            && activeIncidents.isEmpty
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        Task { await refresh() }
        restartRefreshLoop()
    }

    func refresh() async {
        guard !isRefreshing else {
            refreshAgainAfterCurrent = true
            return
        }
        isRefreshing = true
        defer {
            isRefreshing = false
            if refreshAgainAfterCurrent {
                refreshAgainAfterCurrent = false
                Task { await refresh() }
            }
        }

        let targets = enabledServices
        guard !targets.isEmpty else {
            services = []
            lastUpdated = .now
            return
        }

        let fresh = await client.fetchAll(services: targets)
        services = enabledServices.map { service in
            fresh.first(where: { $0.service == service })
                ?? services.first(where: { $0.service == service })
                ?? ServiceStatus.waiting(for: service)
        }
        lastUpdated = .now
    }

    func isServiceEnabled(_ service: AIService) -> Bool {
        enabledServiceIDs.contains(service.id)
    }

    func setService(_ service: AIService, enabled: Bool) {
        if enabled {
            enabledServiceIDs.insert(service.id)
        } else {
            enabledServiceIDs.remove(service.id)
        }
        defaults.set(enabledServiceIDs.sorted(), forKey: Self.enabledServiceIDsKey)

        services = enabledServices.map { service in
            services.first(where: { $0.service == service }) ?? ServiceStatus.waiting(for: service)
        }
        if hasStarted {
            Task { await refresh() }
        }
    }

    func openDashboard(_ openWindow: OpenWindowAction) {
        openWindow(id: "dashboard")
        NSApp.activate(ignoringOtherApps: true)
    }

    private func restartRefreshLoop() {
        guard hasStarted else { return }
        refreshLoopTask?.cancel()
        let interval = refreshInterval
        refreshLoopTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { break }
                await self?.refresh()
            }
        }
    }

    private var enabledServices: [AIService] {
        AIService.allCases.filter { enabledServiceIDs.contains($0.id) }
    }
}
