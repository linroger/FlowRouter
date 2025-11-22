import Foundation

enum ProviderType: String, CaseIterable, Codable {
    case openRouter = "OpenRouter"
    case minimax = "Minimax"
    case moonshot = "Moonshot (Kimi)"
    case grok = "Grok (xAI)"
    case zai = "Z.ai"
    
    var baseUrl: String {
        switch self {
        case .openRouter: return "https://openrouter.ai/api/v1"
        case .minimax: return "https://api.minimax.chat/v1"
        case .moonshot: return "https://api.moonshot.ai/v1"
        case .grok: return "https://api.x.ai/v1"
        case .zai: return "https://api.z.ai/api/paas/v4"
        }
    }
}

struct ExternalProvider: Codable, Identifiable {
    var id: String { type.rawValue }
    let type: ProviderType
    var isEnabled: Bool
    var apiKey: String
    var customBaseUrl: String?
    
    var effectiveBaseUrl: String {
        customBaseUrl?.isEmpty == false ? customBaseUrl! : type.baseUrl
    }
}

class ConfigManager: ObservableObject {
    static let shared = ConfigManager()
    
    @Published var providers: [ExternalProvider] = [] {
        didSet {
            save()
        }
    }
    
    private let defaultsKey = "FlowRouterExternalProviders"
    
    init() {
        load()
    }
    
    private func load() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([ExternalProvider].self, from: data) {
            providers = decoded
        } else {
            // Defaults
            providers = ProviderType.allCases.map {
                ExternalProvider(type: $0, isEnabled: false, apiKey: "", customBaseUrl: nil)
            }
        }
    }
    
    private func save() {
        if let encoded = try? JSONEncoder().encode(providers) {
            UserDefaults.standard.set(encoded, forKey: defaultsKey)
        }
    }
    
    func getProvider(for model: String) -> ExternalProvider? {
        // Simple heuristic or explicit mapping could be added here.
        // For now, we might need to fetch models to know which provider to use, 
        // or rely on user prefixing (e.g. "openrouter/model").
        // BUT the requirement is "pull and display all available models".
        // So we should probably have a "Model Registry" that maps model IDs to providers.
        
        // For this MVP, we will iterate enabled providers and check if they claim the model?
        // No, that's inefficient per request.
        // We will implement a generic "Try Routing" or assume the user selects the provider in the UI?
        // The user said "pass the server url as a baseurl... in any ai client". 
        // This implies the Router decides based on the model name.
        
        // Let's assume we match based on known prefixes or we query the providers.
        // For now, let's check the ModelRegistry (which we'll build).
        return ModelRegistry.shared.providerFor(model: model)
    }
}

class ModelRegistry {
    static let shared = ModelRegistry()
    private var modelMap: [String: ProviderType] = [:]
    private(set) var registeredModels: [String] = []
    
    func register(models: [String], for provider: ProviderType) {
        for model in models {
            modelMap[model] = provider
            if !registeredModels.contains(model) {
                registeredModels.append(model)
            }
        }
    }
    
    func providerFor(model: String) -> ExternalProvider? {
        guard let type = modelMap[model] else { return nil }
        return ConfigManager.shared.providers.first(where: { $0.type == type && $0.isEnabled })
    }
    
    func fetchModels() async {
        for provider in ConfigManager.shared.providers where provider.isEnabled {
            // Implement fetch logic here (standard GET /v1/models)
            // and register.
             await fetchModels(for: provider)
        }
    }
    
    private func fetchModels(for provider: ExternalProvider) async {
         guard let url = URL(string: provider.effectiveBaseUrl + "/models") else { return }
         var request = URLRequest(url: url)
         request.setValue("Bearer \(provider.apiKey)", forHTTPHeaderField: "Authorization")
         // Add extra headers for OpenRouter if needed
         
         do {
             let (data, _) = try await URLSession.shared.data(for: request)
             // Parse OpenAI format: { data: [{id: "..."}] }
             struct ModelList: Decodable {
                 struct Model: Decodable { var id: String }
                 var data: [Model]
             }
             if let list = try? JSONDecoder().decode(ModelList.self, from: data) {
                 register(models: list.data.map { $0.id }, for: provider.type)
                 print("Registered \(list.data.count) models for \(provider.type.rawValue)")
             }
         } catch {
             print("Failed to fetch models for \(provider.type.rawValue): \(error)")
         }
    }
}
