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

    var subtitle: String {
        switch self {
        case .openAI: "ChatGPT・API"
        case .claude: "Claude・API・Code"
        case .gemini: "Vertex AI Gemini API"
        case .cursor: "エディター・AI機能"
        case .perplexity: "検索・API"
        case .copilot: "補完・チャット"
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
}
