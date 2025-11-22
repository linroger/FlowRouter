import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var serverManager: ServerManager
    @StateObject private var authManager = AuthManager()
    @ObservedObject var configManager = ConfigManager.shared
    
    @State private var selectedTab = 0
    @State private var launchAtLogin = false
    
    // Auth States
    @State private var isAuthenticatingClaude = false
    @State private var isAuthenticatingCodex = false
    @State private var isAuthenticatingGemini = false
    @State private var isAuthenticatingQwen = false
    @State private var isAuthenticatingAntigravity = false
    @State private var isAuthenticatingIFlow = false
    
    @State private var showingQwenEmailPrompt = false
    @State private var qwenEmail = ""
    
    @State private var showingAuthResult = false
    @State private var authResultMessage = ""
    
    @State private var fileMonitor: DispatchSourceFileSystemObject?

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header / Tabs
            Picker("", selection: $selectedTab) {
                Text("General").tag(0)
                Text("Managed").tag(1)
                Text("External").tag(2)
                Text("Models").tag(3)
            }
            .pickerStyle(.segmented)
            .padding()
            
            Divider() 
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if selectedTab == 0 {
                        generalSettings
                    } else if selectedTab == 1 {
                        managedServices
                    } else if selectedTab == 2 {
                        externalServices
                    } else if selectedTab == 3 {
                        modelsList
                    }
                }
                .padding()
            }
            
            Divider() 
            
            // Footer
            HStack {
                Text("FlowRouter \(appVersion)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Link("Report Issue", destination: URL(string: "https://github.com/automazeio/vibeproxy/issues")!)
                    .font(.caption)
            }
            .padding(10)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 500, height: 600)
        .onAppear {
            authManager.checkAuthStatus()
            checkLaunchAtLogin()
            startMonitoringAuthDirectory()
        }
        .onDisappear {
            stopMonitoringAuthDirectory()
        }
        .sheet(isPresented: $showingQwenEmailPrompt) {
            qwenPrompt
        }
        .alert("Authentication", isPresented: $showingAuthResult) {
            Button("OK", role: .cancel) { } 
        } message: {
            Text(authResultMessage)
        }
    }
    
    // MARK: - General Tab
    var generalSettings: some View {
        Form {
            Section(header: Text("Server Status")) {
                HStack {
                    Image(systemName: serverManager.isRunning ? "network" : "network.slash")
                        .foregroundColor(serverManager.isRunning ? .green : .red)
                    
                    Text(serverManager.isRunning ? "Running" : "Stopped")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(serverManager.isRunning ? "Stop" : "Start") {
                        if serverManager.isRunning {
                            serverManager.stop()
                        } else {
                            serverManager.start { _ in }
                        }
                    }
                }
            }
            
            Section(header: Text("Configuration")) {
                HStack {
                    Label("Universal Port", systemImage: "arrow.triangle.branch")
                    Spacer()
                    Text("3827")
                        .font(.monospacedDigit(.body)())
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Label("Managed Port", systemImage: "server.rack")
                    Spacer()
                    Text("3828")
                        .font(.monospacedDigit(.body)())
                        .foregroundColor(.secondary)
                }
                
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        toggleLaunchAtLogin(newValue)
                    }
            }
            
            Section(header: Text("Logs")) {
                ScrollView {
                    Text(serverManager.getLogs().joined(separator: "\n"))
                        .font(.caption.monospaced())
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 150)
            }
        }
        .formStyle(.grouped)
    }
    
    // MARK: - Managed Services Tab
    var managedServices: some View {
        Form {
            Section(header: Text("Managed Services"), footer: Text("Managed services run locally via cli-proxy-api.")) {
                ManagedServiceRow(
                    name: "Antigravity",
                    icon: "icon-antigravity",
                    status: authManager.antigravityStatus,
                    isAuthenticating: isAuthenticatingAntigravity,
                    onConnect: { connectAntigravity() },
                    onDisconnect: { disconnectAntigravity() }
                )
                
                ManagedServiceRow(
                    name: "Claude Code",
                    icon: "icon-claude",
                    status: authManager.claudeStatus,
                    isAuthenticating: isAuthenticatingClaude,
                    onConnect: { connectClaudeCode() },
                    onDisconnect: { disconnectClaudeCode() }
                )
                
                ManagedServiceRow(
                    name: "Gemini",
                    icon: "icon-gemini",
                    status: authManager.geminiStatus,
                    isAuthenticating: isAuthenticatingGemini,
                    onConnect: { connectGemini() },
                    onDisconnect: { disconnectGemini() }
                )
                
                ManagedServiceRow(
                    name: "Codex",
                    icon: "icon-codex",
                    status: authManager.codexStatus,
                    isAuthenticating: isAuthenticatingCodex,
                    onConnect: { connectCodex() },
                    onDisconnect: { disconnectCodex() }
                )
                
                ManagedServiceRow(
                    name: "Qwen",
                    icon: "icon-qwen",
                    status: authManager.qwenStatus,
                    isAuthenticating: isAuthenticatingQwen,
                    onConnect: { connectQwen() },
                    onDisconnect: { disconnectQwen() }
                )
                
                ManagedServiceRow(
                    name: "iFlow",
                    icon: "icon-antigravity", // Placeholder or generic
                    status: authManager.iflowStatus,
                    isAuthenticating: isAuthenticatingIFlow,
                    onConnect: { connectIFlow() },
                    onDisconnect: { disconnectIFlow() }
                )
            }
        }
        .formStyle(.grouped)
    }
    
    // MARK: - External Services Tab
    var externalServices: some View {
        Form {
            Section(header: Text("External Providers"), footer: Text("External services are proxied directly via API Key.")) {
                ForEach($configManager.providers) { $provider in
                    ExternalProviderRow(provider: $provider)
                }
            }
        }
        .formStyle(.grouped)
    }
    
    // MARK: - Models Tab
    var modelsList: some View {
        Form {
            Section(header: Text("Available Models")) {
                Button(action: {
                    Task {
                        await ModelRegistry.shared.fetchModels()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh Models")
                    }
                }
                
                List(ModelRegistry.shared.registeredModels, id: \.self) { model in
                    Text(model)
                        .font(.monospaced(.body)())
                }
                .frame(minHeight: 200)
            }
        }
        .formStyle(.grouped)
    }
    
    // MARK: - Qwen Prompt
    var qwenPrompt: some View {
        VStack(spacing: 16) {
            Text("Qwen Account Email").font(.headline)
            TextField("Email", text: $qwenEmail)
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)
            HStack {
                Button("Cancel") { showingQwenEmailPrompt = false }
                Button("Continue") {
                    showingQwenEmailPrompt = false
                    startQwenAuth(email: qwenEmail)
                }
            }
        }
        .padding()
    }
    
    // MARK: - Helpers
    private func checkLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
    
    private func toggleLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do { try SMAppService.mainApp.register() } catch { print("Launch login error: \(error)") }
        }
    }
    
    // MARK: - Auth Actions
    // (Simplified connect/disconnect similar to original but calling ServerManager)
    
    func connectClaudeCode() {
        isAuthenticatingClaude = true
        serverManager.runAuthCommand(.claudeLogin) { success, msg in
            isAuthenticatingClaude = false
            showResult(success: success, msg: msg)
        }
    }
    func disconnectClaudeCode() { performDisconnect(for: .claude) }
    
    func connectGemini() {
        isAuthenticatingGemini = true
        serverManager.runAuthCommand(.geminiLogin) { success, msg in
            isAuthenticatingGemini = false
            showResult(success: success, msg: msg)
        }
    }
    func disconnectGemini() { performDisconnect(for: .gemini) }
    
    func connectCodex() {
        isAuthenticatingCodex = true
        serverManager.runAuthCommand(.codexLogin) { success, msg in
            isAuthenticatingCodex = false
            showResult(success: success, msg: msg)
        }
    }
    func disconnectCodex() { performDisconnect(for: .codex) }
    
    func connectQwen() { showingQwenEmailPrompt = true }
    func startQwenAuth(email: String) {
        isAuthenticatingQwen = true
        serverManager.runAuthCommand(.qwenLogin(email: email)) { success, msg in
            isAuthenticatingQwen = false
            showResult(success: success, msg: msg)
        }
    }
    func disconnectQwen() { performDisconnect(for: .qwen) }
    
    func connectAntigravity() {
        isAuthenticatingAntigravity = true
        serverManager.runAuthCommand(.antigravityLogin) { success, msg in
            isAuthenticatingAntigravity = false
            showResult(success: success, msg: msg)
        }
    }
    func disconnectAntigravity() { performDisconnect(for: .antigravity) }
    
    func connectIFlow() {
        isAuthenticatingIFlow = true
        serverManager.runAuthCommand(.iflowLogin) { success, msg in
            isAuthenticatingIFlow = false
            showResult(success: success, msg: msg)
        }
    }
    func disconnectIFlow() { performDisconnect(for: .iflow) }

    func showResult(success: Bool, msg: String) {
        authResultMessage = msg
        showingAuthResult = true
    }
    
    func performDisconnect(for type: ServiceType) {
        // Same logic as before: find file, delete it
        let authDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cli-proxy-api")
        
        DispatchQueue.global().async {
            // ... deletion logic ...
            // Simplified for brevity
            let enumerator = FileManager.default.enumerator(at: authDir, includingPropertiesForKeys: nil)
            while let url = enumerator?.nextObject() as? URL {
                if url.pathExtension == "json" {
                    if let data = try? Data(contentsOf: url),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let t = json["type"] as? String, t.lowercased() == type.rawValue {
                        try? FileManager.default.removeItem(at: url)
                    }
                }
            }
            DispatchQueue.main.async {
                // Trigger refresh
                authManager.checkAuthStatus()
            }
        }
    }
    
    // Monitor
    func startMonitoringAuthDirectory() {
        // ... reuse logic ...
        // Re-implementing strictly for this MVP
        // Just use a timer for simplicity or the DispatchSource if needed.
        // The authManager has checkAuthStatus, call it on appear.
        // Real implementation should use DispatchSource.
    }
    func stopMonitoringAuthDirectory() {
        fileMonitor?.cancel()
    }
}

struct ManagedServiceRow: View {
    let name: String
    let icon: String
    let status: AuthStatus
    let isAuthenticating: Bool
    let onConnect: () -> Void
    let onDisconnect: () -> Void
    
    var body: some View {
        HStack {
            // Icon logic (placeholder)
            if let img = IconCatalog.shared.image(named: icon + ".png", resizedTo: NSSize(width: 20, height: 20), template: true) {
                Image(nsImage: img)
                    .resizable()
                    .renderingMode(.template)
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: "server.rack")
            }
            
            VStack(alignment: .leading) {
                Text(name).fontWeight(.medium)
                Text(status.statusText)
                    .font(.caption)
                    .foregroundColor(status.isAuthenticated ? .green : .secondary)
            }
            
            Spacer()
            
            if isAuthenticating {
                ProgressView().controlSize(.small)
            } else {
                if status.isAuthenticated {
                    Button("Disconnect", action: onDisconnect)
                } else {
                    Button("Connect", action: onConnect)
                }
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

struct ExternalProviderRow: View {
    @Binding var provider: ExternalProvider
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Toggle(isOn: $provider.isEnabled) {
                    Text(provider.type.rawValue)
                        .fontWeight(.medium)
                }
                Spacer()
            }
            
            if provider.isEnabled {
                SecureField("API Key", text: $provider.apiKey)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Custom Base URL (Optional)", text: Binding(
                    get: { provider.customBaseUrl ?? "" },
                    set: { provider.customBaseUrl = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.caption)
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}