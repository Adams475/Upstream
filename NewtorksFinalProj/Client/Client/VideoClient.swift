import Foundation
import AVFoundation
import Network

/// Abstract: An object to capture video data, encode it and finally send it to the server
class VideoClient {
    
    // MARK: - dependencies
    
    private lazy var captureManager = VideoCaptureManager()
    private lazy var videoEncoder = H264Encoder()
    private lazy var tcpClient = TCPClient()
    
    func connect(to ipAddress: String, with port: UInt16) throws {
        try tcpClient.connect(to: ipAddress, with: port)
    }
    
    func startSendingVideoToServer() throws {
        try videoEncoder.configureCompressSession()
        
        captureManager.setVideoOutputDelegate(with: videoEncoder)
        
        // if connection is not established, 'send(:)' method in TCPClient doesn't
        // have any N so it's okay to send data before establishing connection
        var stupid = 0
        videoEncoder.naluHandling = { [unowned self] data in
            stupid += data.count
            print(stupid)
            tcpClient.send(data: data)
        }
    }
}

