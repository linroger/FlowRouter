import Foundation

enum ServiceType: String, CaseIterable {
    case claude
    case codex
    case gemini
    case qwen
    case antigravity
    case iflow
    
    var displayName: String {
        switch self {
        case .claude: return "Claude Code"
        case .codex: return "Codex"
        case .gemini: return "Gemini"
        case .qwen: return "Qwen"
        case .antigravity: return "Antigravity"
        case .iflow: return "iFlow"
        }
    }
}

struct AuthStatus {
    var isAuthenticated: Bool
    var email: String?
    var type: ServiceType
    var expired: Date?
    
    init(isAuthenticated: Bool, email: String? = nil, type: ServiceType, expired: Date? = nil) {
        self.isAuthenticated = isAuthenticated
        self.email = email
        self.type = type
        self.expired = expired
    }
    
    var isExpired: Bool {
        guard let expired = expired else { return false }
        return expired < Date()
    }
    
    var statusText: String {
        if !isAuthenticated {
            return "Not Connected"
        } else if isExpired {
            return "Expired - Reconnect Required"
        } else if let email = email {
            return "Connected as \(email)"
        } else {
            return "Connected"
        }
    }
}

class AuthManager: ObservableObject {
    @Published var claudeStatus = AuthStatus(isAuthenticated: false, type: .claude)
    @Published var codexStatus = AuthStatus(isAuthenticated: false, type: .codex)
    @Published var geminiStatus = AuthStatus(isAuthenticated: false, type: .gemini)
    @Published var qwenStatus = AuthStatus(isAuthenticated: false, type: .qwen)
    @Published var antigravityStatus = AuthStatus(isAuthenticated: false, type: .antigravity)
    @Published var iflowStatus = AuthStatus(isAuthenticated: false, type: .iflow)
    
    func checkAuthStatus() {
        let authDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cli-proxy-api")
        
        // Reset statuses first
        var foundClaude = false
        var foundCodex = false
        var foundGemini = false
        var foundQwen = false
        var foundAntigravity = false
        var foundIFlow = false
        
        // Check for auth files
        do {
            let files = try FileManager.default.contentsOfDirectory(at: authDir, includingPropertiesForKeys: nil)
            NSLog("[AuthStatus] Scanning %d files in auth directory", files.count)
            
            for file in files where file.pathExtension == "json" {
                NSLog("[AuthStatus] Checking file: %@", file.lastPathComponent)
                if let data = try? Data(contentsOf: file),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let type = json["type"] as? String,
                   let serviceType = ServiceType(rawValue: type.lowercased()) {
                    NSLog("[AuthStatus] Found type '%@' in %@", type, file.lastPathComponent)
                    
                    let email = json["email"] as? String
                    var expiredDate: Date?
                    
                    if let expiredStr = json["expired"] as? String {
                        let formatter = ISO8601DateFormatter()
                        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        expiredDate = formatter.date(from: expiredStr)
                    }
                    
                    let status = AuthStatus(
                        isAuthenticated: true,
                        email: email,
                        type: serviceType,
                        expired: expiredDate
                    )
                    
                    DispatchQueue.main.async {
                        
                        switch serviceType {
                        case .claude:
                            foundClaude = true
                            self.claudeStatus = status
                            NSLog("[AuthStatus] Found Claude auth: %@", email ?? "unknown")
                        case .codex:
                            foundCodex = true
                            self.codexStatus = status
                            NSLog("[AuthStatus] Found Codex auth: %@", email ?? "unknown")
                        case .gemini:
                            foundGemini = true
                            self.geminiStatus = status
                            NSLog("[AuthStatus] Found Gemini auth: %@", email ?? "unknown")
                        case .qwen:
                            foundQwen = true
                            self.qwenStatus = status
                            NSLog("[AuthStatus] Found Qwen auth: %@", email ?? "unknown")
                        case .antigravity:
                            foundAntigravity = true
                            self.antigravityStatus = status
                            NSLog("[AuthStatus] Found Antigravity auth: %@", email ?? "unknown")
                        case .iflow:
                            foundIFlow = true
                            self.iflowStatus = status
                             NSLog("[AuthStatus] Found iFlow auth: %@", email ?? "unknown")
                        }
                    }
                }
            }
            
            // Reset statuses for services without auth files
            DispatchQueue.main.async {
                if !foundClaude {
                    self.claudeStatus = AuthStatus(isAuthenticated: false, type: .claude)
                }
                if !foundCodex {
                    self.codexStatus = AuthStatus(isAuthenticated: false, type: .codex)
                }
                if !foundGemini {
                    self.geminiStatus = AuthStatus(isAuthenticated: false, type: .gemini)
                }
                if !foundQwen {
                    self.qwenStatus = AuthStatus(isAuthenticated: false, type: .qwen)
                }
                if !foundAntigravity {
                    self.antigravityStatus = AuthStatus(isAuthenticated: false, type: .antigravity)
                }
                if !foundIFlow {
                    self.iflowStatus = AuthStatus(isAuthenticated: false, type: .iflow)
                }
            }
        } catch {
            NSLog("[AuthStatus] Error checking auth status: %@", error.localizedDescription)
            // Reset all on error
            DispatchQueue.main.async {
                self.claudeStatus = AuthStatus(isAuthenticated: false, type: .claude)
                self.codexStatus = AuthStatus(isAuthenticated: false, type: .codex)
                self.geminiStatus = AuthStatus(isAuthenticated: false, type: .gemini)
                self.qwenStatus = AuthStatus(isAuthenticated: false, type: .qwen)
                self.antigravityStatus = AuthStatus(isAuthenticated: false, type: .antigravity)
                self.iflowStatus = AuthStatus(isAuthenticated: false, type: .iflow)
            }
        }
    }
}

