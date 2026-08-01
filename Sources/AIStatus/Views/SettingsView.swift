import SwiftUI

struct SettingsView: View {
    let store: StatusStore
    @State private var launchesAtLogin = false
    @State private var launchAtLoginRequiresApproval = false
    @State private var isSynchronizingLaunchAtLogin = false
    @State private var launchAtLoginError: String?

    private var language: AppLanguage { store.language }

    var body: some View {
        Form {
            Section(language.text("表示言語", "Display language")) {
                Picker(language.text("言語", "Language"), selection: Bindable(store).language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                Text(language.text("アプリ内の表示言語を切り替えます。", "Choose the language used throughout the app."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(language.text("アプリ", "App")) {
                Toggle(language.text("ログイン時に起動", "Launch at login"), isOn: $launchesAtLogin)
                Text(language.text("Macにログインしたときに、AI Statusを自動的に起動します。", "Automatically launch AI Status when you log in to your Mac."))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if launchAtLoginRequiresApproval {
                    Text(language.text("macOSでの許可が必要です。ログイン項目でAI Statusを許可してください。", "macOS approval is required. Allow AI Status in Login Items."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button(language.text("ログイン項目を開く", "Open Login Items")) {
                        LaunchAtLoginManager.openLoginItemsSettings()
                    }
                }

                if let launchAtLoginError {
                    Text(launchAtLoginError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section(language.text("メニューバー", "Menu bar")) {
                Toggle(language.text("稼働数を表示", "Show operational count"), isOn: Bindable(store).showsServiceCount)
                Text(language.text("オンにすると、アイコンの横に「6/6」のような稼働数を表示します。", "Show an operational count such as 6/6 next to the menu bar icon."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(language.text("監視するAIサービス", "AI services to monitor")) {
                ForEach(AIService.allCases) { service in
                    Toggle(
                        service.name,
                        isOn: Binding(
                            get: { store.isServiceEnabled(service) },
                            set: { store.setService(service, enabled: $0) }
                        )
                    )
                }
                Text(language.text("オフにしたサービスは取得・集計・一覧表示の対象から外れます。", "Disabled services are excluded from refreshes, counts, and lists."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(language.text("更新", "Refresh")) {
                Picker(language.text("自動更新", "Automatic refresh"), selection: Bindable(store).refreshInterval) {
                    Text(language.text("1分ごと", "Every minute")).tag(TimeInterval(60))
                    Text(language.text("5分ごと", "Every 5 minutes")).tag(TimeInterval(300))
                    Text(language.text("15分ごと", "Every 15 minutes")).tag(TimeInterval(900))
                    Text(language.text("30分ごと", "Every 30 minutes")).tag(TimeInterval(1_800))
                }
                Text(language.text("選択した間隔で有効なサービスの公式情報を確認します。", "Check the official status of enabled services at the selected interval."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 690)
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
            launchAtLoginError = language.text(
                "ログイン時起動を変更できませんでした: \(error.localizedDescription)",
                "Couldn't change launch at login: \(error.localizedDescription)"
            )
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
