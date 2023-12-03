import Foundation
import AVFoundation
import Network

/// Abstract: An object to capture video data, encode it and finally send it to the server
class VideoClient {
    
    var streamId = ""
    // MARK: - dependencies
    init(streamId: String) {
        self.streamId = streamId
    }
    

    private lazy var captureManager = VideoCaptureManager()
    private lazy var videoEncoder = H264Encoder()
    private lazy var tcpCon = TCPStreamer()
    
    func setSampleBufferCallback(_ callback: @escaping (CMSampleBuffer) -> Void) {
        videoEncoder.rawDataHandling = callback
    }
    
    func connect(to ipAddress: String, with port: UInt16) throws {
        try tcpCon.connect(to: ipAddress, with: port)
    }
    
    func disconnect() {
        tcpCon.end()
    }
    
    func startSendingVideoToServer() throws {
        
        try videoEncoder.configureCompressSession()
        
        captureManager.setVideoOutputDelegate(with: videoEncoder)
        
        // if connection is not established, 'send(:)' method in TCPClient doesn't
        // have any N so it's okay to send data before establishing connection
        videoEncoder.naluHandling = { [unowned self] data, type in
            tcpCon.send(data: data, type: type, streamId: streamId)
        }
    }
    
}
