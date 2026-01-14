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
    
    private var server: Server?
    private var webSocketClient: WebSocketClient?
    
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
                try server?.start(port: 8080, interface: "0.0.0.0") // Bind to all interfaces
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
        self.isRunning = false
    }
    
    func send(message: Encodable) {
        // Send to connected client
        // Telegraph handles sending to all or specific. We assume 1 client for MVP.
        guard let client = webSocketClient else { return }
        
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
            // We cast to WebSocketClient if needed, or if WebSocketClient IS (any WebSocket)
            self.webSocketClient = webSocket as? WebSocketClient
            self.clientConnected = true
        }
    }
    
    func server(_ server: Telegraph.Server, webSocketDidDisconnect webSocket: any Telegraph.WebSocket, error: (any Error)?) {
        print("WebSocket disconnected")
        DispatchQueue.main.async {
            // Compare identity if possible, or just clear if it matches the current one
            // Note: '===' might not work on 'any' types easily without casting to AnyObject
            if let current = self.webSocketClient, (current as AnyObject) === (webSocket as AnyObject) {
                self.webSocketClient = nil
                self.clientConnected = false
            }
        }
    }
    
    func server(_ server: Telegraph.Server, webSocket: any Telegraph.WebSocket, didReceiveMessage message: Telegraph.WebSocketMessage) {
        // Handle incoming messages if needed
    }
}
