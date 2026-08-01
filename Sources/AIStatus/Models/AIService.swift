import Foundation

enum AIService: String, CaseIterable, Identifiable, Sendable {
    case openAI
    case claude
    case gemini
    case cursor
    case perplexity
    case copilot

    var id: String { rawValue }

    var name: String {
        switch self {
        case .openAI: "OpenAI"
        case .claude: "Claude"
        case .gemini: "Gemini"
        case .cursor: "Cursor"
        case .perplexity: "Perplexity"
        case .copilot: "GitHub Copilot"
        }
    }

    func subtitle(in language: AppLanguage) -> String {
        switch self {
        case .openAI: "ChatGPT · API"
        case .claude: "Claude · API · Code"
        case .gemini: "Vertex AI Gemini API"
        case .cursor: language.text("エディター・AI機能", "Editor · AI features")
        case .perplexity: language.text("検索・API", "Search · API")
        case .copilot: language.text("補完・チャット", "Code completion · Chat")
        }
    }

    var monogram: String {
        switch self {
        case .openAI: "O"
        case .claude: "C"
        case .gemini: "G"
        case .cursor: "Cu"
        case .perplexity: "P"
        case .copilot: "Co"
        }
    }

    var statusPageURL: URL {
        switch self {
        case .openAI: URL(string: "https://status.openai.com/")!
        case .claude: URL(string: "https://status.claude.com/")!
        case .gemini: URL(string: "https://status.cloud.google.com/products/Z0FZJAMvEB4j3NbCJs6B/history")!
        case .cursor: URL(string: "https://status.cursor.com/")!
        case .perplexity: URL(string: "https://status.perplexity.com/")!
        case .copilot: URL(string: "https://www.githubstatus.com/")!
        }
    }
}

struct ServiceStatus: Identifiable, Sendable {
    let service: AIService
    let health: ServiceHealth
    let detail: String
    let incidents: [String]
    let checkedAt: Date

    var id: AIService.ID { service.id }

    static func waiting(for service: AIService) -> ServiceStatus {
        ServiceStatus(
            service: service,
            health: .unknown,
            detail: "確認を待っています",
            incidents: [],
            checkedAt: .distantPast
        )
    }

    func detail(in language: AppLanguage) -> String {
        switch detail {
        case "確認を待っています":
            language.text("確認を待っています", "Waiting for status update")
        case "公式情報を取得できませんでした":
            language.text("公式情報を取得できませんでした", "Couldn't fetch official status")
        case "Google Cloudで障害が発生しています":
            language.text("Google Cloudで障害が発生しています", "An issue has occurred in Google Cloud")
        default:
            detail == health.title(in: .japanese) ? health.title(in: language) : detail
        }
    }
}
