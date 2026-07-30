import SwiftUI

enum ServiceHealth: String, Codable, CaseIterable, Sendable {
    case operational
    case degraded
    case outage
    case unknown

    var title: String {
        switch self {
        case .operational: "正常稼働"
        case .degraded: "一部障害"
        case .outage: "重大障害"
        case .unknown: "確認できません"
        }
    }

    var shortTitle: String {
        switch self {
        case .operational: "正常"
        case .degraded: "注意"
        case .outage: "障害"
        case .unknown: "不明"
        }
    }

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
