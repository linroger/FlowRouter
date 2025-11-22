import Foundation
import Network
import Combine

class UniversalRouter {
    private var listener: NWListener?
    let proxyPort: UInt16 = 3827
    private let managedPort: UInt16 = 3828
    private let managedHost = "127.0.0.1"
    private(set) var isRunning = false
    
    static let shared = UniversalRouter()
    
    func start() {
        guard !isRunning else { return }
        
        // Start model sync in background
        Task {
            await ModelRegistry.shared.fetchModels()
        }
        
        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: proxyPort)!)
            
            listener?.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    self?.isRunning = true
                    print("[Router] Listening on \(self?.proxyPort ?? 0)")
                case .failed(let error):
                    print("[Router] Failed: \(error)")
                    self?.isRunning = false
                case .cancelled:
                    self?.isRunning = false
                default: break
                }
            }
            
            listener?.newConnectionHandler = { connection in
                connection.start(queue: .global())
                self.handleConnection(connection)
            }
            
            listener?.start(queue: .global())
        } catch {
            print("[Router] Start failed: \(error)")
        }
    }
    
    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }
    
    private func handleConnection(_ connection: NWConnection) {
        // Simple HTTP parser/accumulator
        var buffer = Data()
        
        func receive() {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
                if let data = data {
                    buffer.append(data)
                    
                    // Check for header end
                    if let range = buffer.range(of: Data("\r\n\r\n".utf8)) {
                        let headerData = buffer.subdata(in: 0..<range.lowerBound)
                        let bodyStart = buffer.subdata(in: range.upperBound..<buffer.endIndex)
                        
                        if let headerString = String(data: headerData, encoding: .utf8) {
                            self.processRequest(header: headerString, bodyStart: bodyStart, connection: connection)
                        }
                    } else {
                        if !isComplete { receive() }
                    }
                } else if isComplete {
                    connection.cancel()
                }
            }
        }
        receive()
    }
    
    private func processRequest(header: String, bodyStart: Data, connection: NWConnection) {
        let lines = header.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return }
        let parts = requestLine.components(separatedBy: " ")
        guard parts.count >= 3 else { return }
        
        let method = parts[0]
        let path = parts[1]
        
        // Headers map
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            if let idx = line.firstIndex(of: ":") {
                let key = String(line[..<idx]).trimmingCharacters(in: .whitespaces)
                let val = String(line[line.index(after: idx)...]).trimmingCharacters(in: .whitespaces)
                headers[key] = val
            }
        }
        
        // Read full body if Content-Length matches bodyStart
        // For simplicity in this MVP, assuming body is small enough or we stream it?
        // But we need the 'model' from the body. So we must wait for full body.
        let contentLength = Int(headers["Content-Length"] ?? "0") ?? 0
        
        // If bodyStart has everything
        if bodyStart.count >= contentLength {
            let fullBody = bodyStart.prefix(contentLength)
            handleCompleteRequest(method: method, path: path, headers: headers, body: fullBody, connection: connection)
        } else {
            // Need to read more
            var remainingBody = bodyStart
            let needed = contentLength - remainingBody.count
            connection.receive(minimumIncompleteLength: needed, maximumLength: needed) { data, _, _, _ in
                if let data = data {
                    remainingBody.append(data)
                    self.handleCompleteRequest(method: method, path: path, headers: headers, body: remainingBody, connection: connection)
                }
            }
        }
    }
    
    private func handleCompleteRequest(method: String, path: String, headers: [String: String], body: Data, connection: NWConnection) {
        
        if path == "/v1/models" {
             handleModelsRequest(connection: connection)
             return
        }
        
        // Parse model from body
        var targetProvider: ExternalProvider? = nil
        
        if let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
           let model = json["model"] as? String {
            targetProvider = ModelRegistry.shared.providerFor(model: model)
        }
        
        if let provider = targetProvider {
            // Forward to External
            forwardToExternal(provider: provider, method: method, path: path, headers: headers, body: body, connection: connection)
        } else {
            // Forward to Managed (CLIProxyAPI)
            forwardToManaged(method: method, path: path, headers: headers, body: body, connection: connection)
        }
    }
    
    private func forwardToManaged(method: String, path: String, headers: [String: String], body: Data, connection: NWConnection) {
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(managedHost), port: NWEndpoint.Port(rawValue: managedPort)!)
        let target = NWConnection(to: endpoint, using: .tcp)
        
        target.stateUpdateHandler = { state in
            if case .ready = state {
                // Reconstruct request
                var req = "\(method) \(path) HTTP/1.1\r\n"
                for (k, v) in headers {
                    if k.lowercased() != "host" {
                        req += "\(k): \(v)\r\n"
                    }
                }
                req += "Host: \(self.managedHost):\(self.managedPort)\r\n"
                req += "Connection: close\r\n\r\n"
                
                target.send(content: req.data(using: .utf8), completion: .contentProcessed { _ in
                    target.send(content: body, completion: .contentProcessed { _ in
                        // Stream back
                        self.streamResponse(from: target, to: connection)
                    })
                })
            }
        }
        target.start(queue: .global())
    }
    
    private func forwardToExternal(provider: ExternalProvider, method: String, path: String, headers: [String: String], body: Data, connection: NWConnection) {
        guard let url = URL(string: provider.effectiveBaseUrl + (path.replacingOccurrences(of: "/v1", with: ""))) else { 
            connection.cancel()
            return
        }
        
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.httpBody = body
        req.setValue("Bearer \(provider.apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Pass through other headers?
        if let accept = headers["Accept"] { req.setValue(accept, forHTTPHeaderField: "Accept") }
        
        let task = URLSession.shared.dataTask(with: req) { data, response, error in
            guard let httpResp = response as? HTTPURLResponse, let data = data else {
                connection.cancel()
                return
            }
            
            // Send Header
            var head = "HTTP/1.1 \(httpResp.statusCode) OK\r\n"
            for (k, v) in httpResp.allHeaderFields {
                if let ks = k as? String, let vs = v as? String {
                    head += "\(ks): \(vs)\r\n"
                }
            }
            head += "\r\n"
            
            connection.send(content: head.data(using: .utf8), completion: .contentProcessed { _ in
                connection.send(content: data, completion: .contentProcessed { _ in
                    connection.cancel()
                })
            })
        }
        task.resume()
    }
    
    private func streamResponse(from source: NWConnection, to dest: NWConnection) {
        source.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, _ in
            if let data = data {
                dest.send(content: data, completion: .contentProcessed { _ in
                    if !isComplete {
                        self.streamResponse(from: source, to: dest)
                    } else {
                        dest.cancel()
                        source.cancel()
                    }
                })
            } else if isComplete {
                dest.cancel()
                source.cancel()
            }
        }
    }
    
    private func handleModelsRequest(connection: NWConnection) {
        Task {
            // 1. Fetch Managed Models
            let managedModels = await fetchManagedModels()
            
            // 2. Fetch External Models (already in registry?)
            // We will just return all registered models from Registry + Managed
            
            var allModels: [[String: Any]] = []
            
            // managed
            allModels.append(contentsOf: managedModels)
            
            // external
            let externalModels = ModelRegistry.shared.registeredModels.map { id in
                ["id": id, "object": "model", "created": 0, "owned_by": "external"]
            }
            
            allModels.append(contentsOf: externalModels)
            
            // Let's construct the response
            let response: [String: Any] = [
                "object": "list",
                "data": allModels
            ]
            
            if let data = try? JSONSerialization.data(withJSONObject: response) {
                let head = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: \(data.count)\r\n\r\n"
                connection.send(content: head.data(using: .utf8), completion: .contentProcessed { _ in
                    connection.send(content: data, completion: .contentProcessed { _ in
                        connection.cancel()
                    })
                })
            }
        }
    }
    
    private func fetchManagedModels() async -> [[String: Any]] {
        // Fetch from localhost:8328/v1/models
        guard let url = URL(string: "http://\(managedHost):\(managedPort)/v1/models") else { return [] }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let list = json["data"] as? [[String: Any]] {
                return list
            }
        } catch {
             print("Managed fetch failed")
        }
        return []
    }
}