import SwiftUI

struct SettingsView: View {
    let store: StatusStore

    var body: some View {
        Form {
            Section("メニューバー") {
                Toggle("稼働数を表示", isOn: Bindable(store).showsServiceCount)
                Text("オンにすると、アイコンの横に「6/6」のような稼働数を表示します。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("監視するAIサービス") {
                ForEach(AIService.allCases) { service in
                    Toggle(
                        service.name,
                        isOn: Binding(
                            get: { store.isServiceEnabled(service) },
                            set: { store.setService(service, enabled: $0) }
                        )
                    )
                }
                Text("オフにしたサービスは取得・集計・一覧表示の対象から外れます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("更新") {
                Picker("自動更新", selection: Bindable(store).refreshInterval) {
                    Text("1分ごと").tag(TimeInterval(60))
                    Text("5分ごと").tag(TimeInterval(300))
                    Text("15分ごと").tag(TimeInterval(900))
                    Text("30分ごと").tag(TimeInterval(1_800))
                }
                Text("選択した間隔で有効なサービスの公式情報を確認します。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 520)
    }
}
