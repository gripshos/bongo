import Foundation
import Network
// IMPORT REQUIRED: Add 'Telegraph' via Swift Package Manager
// URL: https://github.com/Building42/Telegraph
import Telegraph
import Combine

class WebSocketServerManager: ObservableObject {
    @Published var isRunning = false
    @Published var clientConnected = false
    @Published var serverIP: String = "Unknown"
    @Published var shouldStartGame = false // Trigger for remote start (Debug Mode)
    
    private var server: Server?
    private var webSocketClient: (any Telegraph.WebSocket)?
    private var netService: NetService?
    
    init() {
        setupServer()
    }
    
    private func setupServer() {
        server = Server()
        server?.webSocketDelegate = self
    }
    
    func start() {
         do {
            // Get local IP
            if let ip = getWiFiAddress() {
                self.serverIP = ip
                
                // Publish Bonjour Service (Before start to ensure prompt is triggered even if start fails momentarily)
                self.netService = NetService(domain: "local.", type: "_http._tcp.", name: "BongoController", port: 8080)
                self.netService?.publish()
                
                // Bind to specific IP to avoid "Unknown interface" error
                try server?.start(port: 8080, interface: ip)
                
                self.isRunning = true
                print("Server started on ws://\(ip):8080")
            } else {
                print("Could not get IP address")
                self.serverIP = "No WiFi"
            }
        } catch {
            print("Server start error: \(error)")
        }
    }
    
    func stop() {
        server?.stop()
        netService?.stop()
        self.isRunning = false
    }
    
    func send(message: Encodable) {
        // Send to connected client
        guard let client = webSocketClient else {
            print("Send failed: No client connected")
            return
        }
        
        do {
            let data = try JSONEncoder().encode(message)
            if let jsonString = String(data: data, encoding: .utf8) {
                client.send(text: jsonString)
            }
        } catch {
            print("Encoding error: \(error)")
        }
    }
    
    // Helper to get IP address (StackOverflow standard solution for Swift)
    private func getWiFiAddress() -> String? {
        var address: String?
        
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        guard let firstAddr = ifaddr else { return nil }
        
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            
            if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" { // en0 is usually WiFi
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                    // Prefer IPv4
                    if addrFamily == UInt8(AF_INET) {
                        break
                    }
                }
            }
        }
        freeifaddrs(ifaddr)
        return address
    }
}

extension WebSocketServerManager: ServerWebSocketDelegate {
    func server(_ server: Telegraph.Server, webSocketDidConnect webSocket: any Telegraph.WebSocket, handshake: Telegraph.HTTPRequest) {
        print("WebSocket connected")
        DispatchQueue.main.async {
            // Store reference to the connected client
            self.webSocketClient = webSocket
            self.clientConnected = true
        }
    }
    
    func server(_ server: Telegraph.Server, webSocketDidDisconnect webSocket: any Telegraph.WebSocket, error: (any Error)?) {
        print("WebSocket disconnected")
        DispatchQueue.main.async {
            // Compare identity if possible, or just clear if it matches the current one
            // Using identity check roughly
            if self.webSocketClient != nil {
                self.webSocketClient = nil
                self.clientConnected = false
            }
        }
    }
    
    func server(_ server: Telegraph.Server, webSocket: any Telegraph.WebSocket, didReceiveMessage message: Telegraph.WebSocketMessage) {
        // Use Reflection to robustly extract payload regardless of struct/class definition
        let mirror = Mirror(reflecting: message)
        var messageData: Data?
        
        // 1. Try to find 'data' or 'payload' property holding Data
        for child in mirror.children {
            if let label = child.label {
                if (label == "data" || label == "payload"), let d = child.value as? Data {
                    messageData = d
                    break
                }
            }
        }
        
        // 2. If no data, try to find 'text' or 'string' property holding String
        if messageData == nil {
            for child in mirror.children {
                if let label = child.label {
                    if (label == "text" || label == "string"), let s = child.value as? String {
                        messageData = s.data(using: .utf8)
                        break
                    }
                }
            }
        }
        
        // 3. Fallback: Check if message ITSELF is text or data (if it were an enum associated value we somehow have access to, unlikely here but valid for direct aliases)
        if messageData == nil {
           if let s = message as? String {
               messageData = s.data(using: .utf8)
           } else if let d = message as? Data {
               messageData = d
           }
        }

        guard let validData = messageData else {
            print("Could not extract data from WebSocketMessage: \(message)")
            return 
        }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: validData) as? [String: Any],
               let type = json["type"] as? String {
                
                if type == "debugStart" {
                    DispatchQueue.main.async {
                        self.shouldStartGame = true
                    }
                }
            }
        } catch {
            print("Error parsing incoming message: \(error)")
        }
    }
}
