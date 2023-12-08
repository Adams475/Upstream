import Foundation
import Network

class TCPStreamer: NSObject, StreamDelegate {
    enum ConnectionError: Error {
        case invalidIPAdress
        case invalidPort
    }
    // MARK: - properties
    
    private lazy var queue = DispatchQueue.init(label: "tcp.client.queue")
    
    private var connection: NWConnection?
    
    private var state: NWConnection.State = .preparing
    
    // MARK: - methods
    
    func makeSendServerDataHTTPHeader(data: Data, type: Int, naluType: UInt8, streamId: String, isEncoded: Bool) -> Data  {
        if (isEncoded) {
            print("using compressed HTTP request")
            var request = "POST /streams/\(streamId) HTTP/1.1\r\n"
            if (type == 0) {
                request += "Data-Type: MetaData\r\n"
            }
            else {
                request += "Data-Type: EncodedVideo\r\n"
            }
            request += "Content-Length: \(data.count)\r\n"
            request += "Content-Type: UpstreamedVideo\r\n"
            request += "NALU-Type: \(naluType)\r\n"
            request += "\r\n"
            return request.data(using: .utf8)!
        }
        else {
            print("Using slow http request")
            var request = "POST /slowstreams/\(streamId) HTTP/1.1\r\n"
            if (type == 0) {
                request += "Data-Type: MetaData\r\n"
            }
            else {
                request += "Data-Type: EncodedVideo\r\n"
            }
            request += "Content-Length: \(data.count)\r\n"
            request += "Content-Type: UpstreamedVideo\r\n"
            request += "\r\n"
            return request.data(using: .utf8)!
        }
    }
    
    
    func connect(to ipAddress: String, with port: UInt16) throws {
        guard let ipAddress = IPv4Address(ipAddress) else {
            throw ConnectionError.invalidIPAdress
        }
        guard let port = NWEndpoint.Port.init(rawValue: port) else {
            throw ConnectionError.invalidPort
        }
        let host = NWEndpoint.Host.ipv4(ipAddress)
        
        connection = NWConnection(host: host, port: port, using: .tcp)
        
        connection?.stateUpdateHandler = { [unowned self] state in
            self.state = state
        }
        
        connection?.start(queue: queue)
    }
    
    var sentData = 0
    var queuedData = 0
    
    
    func send(data: Data, type: Int, streamId: String, isEncoded: Bool, naluType: UInt8) {
        guard state == .ready else { return }
        do {
            var req = makeSendServerDataHTTPHeader(data: data as Data, type: type, naluType: naluType, streamId: streamId, isEncoded: isEncoded)
            req += data
            queuedData += data.count
            connection?.send(content: req,
                             completion: .contentProcessed({ error in
                self.sentData += data.count
                if let error = error {
                    print(error)
                }
            }))
        } catch {
            print(error.localizedDescription)
        }
        
    }
    
    func end() {
        connection?.cancel()
    }
}

class TCPRequester: NSObject, StreamDelegate {
    enum ConnectionError: Error {
        case invalidIPAdress
        case invalidPort
    }
    // MARK: - properties
    
    private lazy var queue = DispatchQueue.init(label: "tcp.clientsender.queue")
    
    private var connection: NWConnection?
    
    private var state: NWConnection.State = .preparing
    
    
    func connect(to ipAddress: String, with port: UInt16) throws {
        guard let ipAddress = IPv4Address(ipAddress) else {
            throw ConnectionError.invalidIPAdress
        }
        guard let port = NWEndpoint.Port.init(rawValue: port) else {
            throw ConnectionError.invalidPort
        }
        let host = NWEndpoint.Host.ipv4(ipAddress)
        
        connection = NWConnection(host: host, port: port, using: .tcp)
        
        connection?.stateUpdateHandler = { [unowned self] state in
            self.state = state
        }
        
        connection?.start(queue: queue)
    }
    
    func getIPAddress() -> String {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }

                guard let interface = ptr?.pointee else { return "" }
                let addrFamily = interface.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {

                    // wifi = ["en0"]
                    // wired = ["en2", "en3", "en4"]
                    // cellular = ["pdp_ip0","pdp_ip1","pdp_ip2","pdp_ip3"]

                    let name: String = String(cString: (interface.ifa_name))
                    if  name == "en0" || name == "en2" || name == "en3" || name == "en4" || name == "pdp_ip0" || name == "pdp_ip1" || name == "pdp_ip2" || name == "pdp_ip3" {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface.ifa_addr, socklen_t((interface.ifa_addr.pointee.sa_len)), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                        address = String(cString: hostname)
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        print("ip address = \(address)")
        return address ?? ""
    }
    
    func sendStreamHTTPRequest(streamId: String, port: UInt16) {
        var request = "GET /streams/\(streamId) HTTP/1.1\r\n"
        request += "Content-Type: StreamRequest\r\n"
        request += "Client-IP: 98.223.101.69\r\n"
        request += "Client-Port: \(port)\r\n"
        request += "\r\n" // TODO - This probably doesn't conform to expected output
        let requestData = request.data(using: .utf8)!
        connection?.send(content: requestData,
                         completion: .contentProcessed({ error in
            if let error = error {
                print(error)
            }
        }))
        print("Sent HTTP Streaming Video Request!")
    }
     
    
}

class TCPStreamListener {
    
    enum ServerError: Error {
        case invalidPortNumber
    }
    

    // MARK: - properties
    
    lazy var listeningQueue = DispatchQueue.init(label: "tcp_server_queue")
    lazy var connectionQueue = DispatchQueue.init(label: "connection_queue")
        
    var listener: NWListener?
    
    var recievedDataHandling: ((Data) -> Void)?
  
    func start(port: UInt16) throws {
        listener?.cancel()
        
        guard let port = NWEndpoint.Port.init(rawValue: port) else {
            throw ServerError.invalidPortNumber
        }
        
        listener = try NWListener.init(using: .tcp, on: port)
                
        listener?.stateUpdateHandler = { state in
            if state == .ready {
                print("listener is ready to recieve data")
            }
        }
        
        listener?.newConnectionHandler = { [unowned self] connection in
            print("connection requested --> \(connection.endpoint)")
            
            connection.stateUpdateHandler = { [unowned self] state in
                if state == .ready {
                    // connection established
                    recieveData(on: connection)
                }
            }
            
            connection.start(queue: connectionQueue)
        }
        
        listener?.start(queue: listeningQueue)
    }
    
    private func recieveData(on connection: NWConnection) {
        if connection.state != .ready {
            print("Connection wasn't ready?")
            return
        }
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65000) {
            [unowned self] data, _, _, error in
            if let error = error {
                print(error)
            }

            if let data = data {
                recievedDataHandling?(data) // I would uncompress here before it can go anywhere
            }

            recieveData(on: connection)
        }
    }
    
    func end() {
        listener?.cancel()
    }
    
}
