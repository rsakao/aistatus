import SwiftUI

struct SettingsView: View {
    let store: StatusStore
    @State private var launchesAtLogin = false
    @State private var launchAtLoginRequiresApproval = false
    @State private var isSynchronizingLaunchAtLogin = false
    @State private var launchAtLoginError: String?

    var body: some View {
        Form {
            Section("アプリ") {
                Toggle("ログイン時に起動", isOn: $launchesAtLogin)
                Text("Macにログインしたときに、AI Statusを自動的に起動します。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if launchAtLoginRequiresApproval {
                    Text("macOSでの許可が必要です。ログイン項目でAI Statusを許可してください。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("ログイン項目を開く") {
                        LaunchAtLoginManager.openLoginItemsSettings()
                    }
                }

                if let launchAtLoginError {
                    Text(launchAtLoginError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

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
        .frame(width: 460, height: 610)
        .onAppear {
            synchronizeLaunchAtLogin()
        }
        .onChange(of: launchesAtLogin) { _, enabled in
            guard !isSynchronizingLaunchAtLogin else { return }
            updateLaunchAtLogin(enabled)
        }
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLoginManager.setEnabled(enabled)
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = "ログイン時起動を変更できませんでした: \(error.localizedDescription)"
        }
        synchronizeLaunchAtLogin()
    }

    private func synchronizeLaunchAtLogin() {
        isSynchronizingLaunchAtLogin = true
        launchesAtLogin = LaunchAtLoginManager.isEnabled
        launchAtLoginRequiresApproval = LaunchAtLoginManager.requiresApproval
        isSynchronizingLaunchAtLogin = false
    }
}
