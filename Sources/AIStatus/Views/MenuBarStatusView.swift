import AppKit
import SwiftUI

struct MenuBarStatusView: View {
    let store: StatusStore
    @Environment(\.openWindow) private var openWindow

    private var language: AppLanguage { store.language }

    var body: some View {
        VStack(spacing: 0) {
            overview
            Divider()
            serviceList
            Divider()
            actions
        }
        .frame(width: 330)
        .task { store.start() }
    }

    private var overview: some View {
        HStack(spacing: 12) {
            Image(systemName: store.overallHealth.symbolName)
                .font(.title2)
                .foregroundStyle(store.overallHealth.color)

            VStack(alignment: .leading, spacing: 2) {
                Text(overallTitle)
                    .font(.headline)
                Text(updatedText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if store.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(16)
    }

    private var serviceList: some View {
        VStack(spacing: 2) {
            if store.services.isEmpty {
                Text(language.text("監視対象が選択されていません", "No services selected"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
            } else {
                ForEach(store.services) { status in
                    Button {
                        NSWorkspace.shared.open(status.service.statusPageURL)
                    } label: {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(status.health.color)
                                .frame(width: 8, height: 8)
                            Text(status.service.name)
                                .lineLimit(1)
                            Spacer()
                            Text(status.health.shortTitle(in: language))
                                .foregroundStyle(.secondary)
                            Image(systemName: "arrow.up.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var actions: some View {
        VStack(spacing: 0) {
            Button {
                Task { await store.refresh() }
            } label: {
                Label(language.text("今すぐ更新", "Refresh now"), systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .disabled(store.isRefreshing)

            Button {
                store.openDashboard(openWindow)
            } label: {
                Label(language.text("詳細を表示", "Show details"), systemImage: "rectangle.grid.2x2")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            SettingsLink {
                Label(language.text("設定", "Settings"), systemImage: "gearshape")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label(language.text("AI Statusを終了", "Quit AI Status"), systemImage: "power")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
    }

    private var overallTitle: String {
        if store.services.isEmpty { return language.text("監視対象がありません", "No services selected") }
        return switch store.overallHealth {
        case .operational: language.text("すべて順調です", "All systems operational")
        case .degraded: language.text("一部サービスに障害があります", "Some services are degraded")
        case .outage: language.text("重大な障害が発生しています", "A major outage is in progress")
        case .unknown: language.text("ステータスを確認しています", "Checking service status")
        }
    }

    private var updatedText: String {
        guard let date = store.lastUpdated else { return language.text("初回確認中", "Checking for the first time") }
        let time = date.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(language.locale))
        return language.text("最終確認 \(time)", "Last checked \(time)")
    }
}
