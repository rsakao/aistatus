import SwiftUI

enum ServiceHealth: String, Codable, CaseIterable, Sendable {
    case operational
    case degraded
    case outage
    case unknown

    func title(in language: AppLanguage) -> String {
        switch self {
        case .operational: language.text("正常稼働", "Operational")
        case .degraded: language.text("一部障害", "Degraded")
        case .outage: language.text("重大障害", "Major outage")
        case .unknown: language.text("確認できません", "Unknown")
        }
    }

    func shortTitle(in language: AppLanguage) -> String {
        switch self {
        case .operational: language.text("正常", "Up")
        case .degraded: language.text("注意", "Degraded")
        case .outage: language.text("障害", "Outage")
        case .unknown: language.text("不明", "Unknown")
        }
    }

    var title: String { title(in: .japanese) }

    var shortTitle: String { shortTitle(in: .japanese) }

    var symbolName: String {
        switch self {
        case .operational: "checkmark.circle.fill"
        case .degraded: "exclamationmark.triangle.fill"
        case .outage: "xmark.octagon.fill"
        case .unknown: "questionmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .operational: .green
        case .degraded: .orange
        case .outage: .red
        case .unknown: .secondary
        }
    }

    var severity: Int {
        switch self {
        case .operational: 0
        case .unknown: 1
        case .degraded: 2
        case .outage: 3
        }
    }

    static func from(raw value: String) -> ServiceHealth {
        switch value.lowercased() {
        case "none", "operational", "up", "resolved", "completed":
            .operational
        case "minor", "maintenance", "under_maintenance", "degraded_performance", "partial_outage":
            .degraded
        case "major", "critical", "major_outage", "down":
            .outage
        default:
            .unknown
        }
    }
}
