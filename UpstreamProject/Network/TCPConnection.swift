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
    
    func makeSendServerDataHTTPHeader(data: Data, type: Int, streamId: String) -> Data  {
        var request = "POST /streams/\(streamId) HTTP/1.1\r\n"
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
    
    func send(data: Data, type: Int, streamId: String) {
        guard state == .ready else { return }
        var req = makeSendServerDataHTTPHeader(data: data, type: type, streamId: streamId)
        print(data.map { String(format: "%02x", $0) }.joined())
        req += data
        queuedData += data.count
        connection?.send(content: req,
                         completion: .contentProcessed({ error in
            self.sentData += data.count
            if let error = error {
                print(error)
            }
        }))
    }
    
    func end() {
        connection?.cancel()
    }
}
