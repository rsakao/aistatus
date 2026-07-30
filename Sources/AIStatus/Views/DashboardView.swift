import AppKit
import SwiftUI

struct DashboardView: View {
    let store: StatusStore

    private let columns = [
        GridItem(.adaptive(minimum: 235, maximum: 310), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                overviewCard
                servicesSection
                incidentsSection
                disclaimer
            }
            .padding(28)
        }
        .background(.background)
        .task { store.start() }
        .toolbar {
            ToolbarItem {
                Button {
                    Task { await store.refresh() }
                } label: {
                    Label("更新", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(store.isRefreshing)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 6) {
                Text("LIVE STATUS BOARD")
                    .font(.caption.weight(.bold))
                    .tracking(1.6)
                    .foregroundStyle(.green)
                Text("AIの「いま」を、ひと目で。")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text("主要AIサービスの公式ステータスを一画面に集約")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if store.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    private var overviewCard: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(store.overallHealth.color.opacity(0.14))
                    .frame(width: 52, height: 52)
                Image(systemName: store.overallHealth.symbolName)
                    .font(.title2)
                    .foregroundStyle(store.overallHealth.color)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("現在の全体状況")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(overallTitle)
                    .font(.title3.weight(.semibold))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(store.operationalCount) / \(store.services.count)")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text("正常稼働")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Divider().frame(height: 36)
            VStack(alignment: .trailing, spacing: 3) {
                Text("最終確認")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(store.lastUpdated?.formatted(date: .omitted, time: .standard) ?? "確認中")
                    .font(.system(.body, design: .monospaced, weight: .semibold))
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
    }

    private var servicesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(number: "01", title: "サービス一覧", trailing: "\(store.services.count) SERVICES MONITORED")
            if store.services.isEmpty {
                ContentUnavailableView(
                    "監視対象がありません",
                    systemImage: "switch.2",
                    description: Text("設定から監視するAIサービスを選択してください。")
                )
                .frame(maxWidth: .infinity, minHeight: 150)
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                    ForEach(store.services) { status in
                        ServiceCard(status: status)
                    }
                }
            }
        }
    }

    private var incidentsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(number: "02", title: "進行中の障害", trailing: "AUTOMATICALLY UPDATED")
            if store.services.isEmpty {
                Text("監視対象を選択すると、進行中の障害がここに表示されます。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
            } else if store.showsAllClear {
                HStack(spacing: 14) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("現在、重大な障害はありません")
                            .font(.headline)
                        Text("各サービスの公式情報を定期的に確認しています。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("ALL CLEAR")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.green)
                }
                .padding(18)
                .background(.green.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
            } else if store.activeIncidents.isEmpty {
                HStack(spacing: 14) {
                    Image(systemName: store.overallHealth.symbolName)
                        .font(.title2)
                        .foregroundStyle(store.overallHealth.color)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(overallTitle)
                            .font(.headline)
                        Text("障害の詳細は各サービスの公式ページをご確認ください。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(store.overallHealth.shortTitle.uppercased())
                        .font(.caption.weight(.bold))
                        .foregroundStyle(store.overallHealth.color)
                }
                .padding(18)
                .background(
                    store.overallHealth.color.opacity(0.07),
                    in: RoundedRectangle(cornerRadius: 14)
                )
            } else {
                ForEach(Array(store.activeIncidents.enumerated()), id: \.offset) { _, incident in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(incident.service.name)
                                .font(.headline)
                            Text(incident.title)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(.orange.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    private var disclaimer: some View {
        Text("非公式のステータス表示です。最終判断は各社の公式ページをご確認ください。")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 4)
    }

    private func sectionTitle(number: String, title: String, trailing: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(number)
                .font(.caption.monospacedDigit().weight(.bold))
                .foregroundStyle(.green)
            Text(title)
                .font(.title2.weight(.bold))
            Spacer()
            Text(trailing)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var overallTitle: String {
        if store.services.isEmpty { return "監視対象がありません" }
        return switch store.overallHealth {
        case .operational: "すべて順調です"
        case .degraded: "一部サービスに障害があります"
        case .outage: "重大な障害が発生しています"
        case .unknown:
            store.lastUpdated == nil
                ? "ステータスを確認しています"
                : "一部サービスを確認できません"
        }
    }
}

private struct ServiceCard: View {
    let status: ServiceStatus

    var body: some View {
        Button {
            NSWorkspace.shared.open(status.service.statusPageURL)
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(status.service.monogram)
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .frame(width: 38, height: 38)
                        .background(.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    Spacer()
                    Label(status.health.title, systemImage: status.health.symbolName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(status.health.color)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(status.service.name)
                            .font(.title3.weight(.bold))
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(status.service.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { _ in
                        Capsule()
                            .fill(status.health.color.opacity(status.health == .operational ? 0.65 : 0.35))
                            .frame(height: 4)
                    }
                }

                Text(status.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.quaternary, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .help("\(status.service.name)の公式ステータスを開く")
    }
}
