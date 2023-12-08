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
    
    func sendRawVideo(buff: CMSampleBuffer) {
        //Change CMSampleBuffer to Data()
        print("----------Attempting to print raw data----------")
        print(Data.from(pixelBuffer: CMSampleBufferGetImageBuffer(buff)!) as NSData)
        print("----------Printing done raw data----------")
        //tcpCon.send(data: Data.from(pixelBuffer: CMSampleBufferGetImageBuffer(buff)!), type: 0, streamId: streamId, isEncoded: false)
    }
    
    func startSendingVideoToServer() throws {
        
        try videoEncoder.configureCompressSession()
        
        captureManager.setVideoOutputDelegate(with: videoEncoder)
        
        // if connection is not established, 'send(:)' method in TCPClient doesn't
        // have any N so it's okay to send data before establishing connection
        videoEncoder.naluHandling = { [unowned self] data, type, naluType in
            tcpCon.send(data: data, type: type,  streamId: streamId, isEncoded: true, naluType: naluType)
        }
    }
    
    
    
}

extension CVPixelBuffer {
    public static func from(_ data: Data, width: Int, height: Int, pixelFormat: OSType) -> CVPixelBuffer {
        data.withUnsafeBytes { buffer in
            var pixelBuffer: CVPixelBuffer!

            let result = CVPixelBufferCreate(kCFAllocatorDefault, width, height, pixelFormat, nil, &pixelBuffer)
            guard result == kCVReturnSuccess else { fatalError() }

            CVPixelBufferLockBaseAddress(pixelBuffer, [])
            defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

            var source = buffer.baseAddress!

            for plane in 0 ..< CVPixelBufferGetPlaneCount(pixelBuffer) {
                let dest      = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, plane)
                let height      = CVPixelBufferGetHeightOfPlane(pixelBuffer, plane)
                let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, plane)
                let planeSize = height * bytesPerRow

                memcpy(dest, source, planeSize)
                source += planeSize
            }

            return pixelBuffer
        }
    }
}

extension Data {
    public static func from(pixelBuffer: CVPixelBuffer) -> Self {
        CVPixelBufferLockBaseAddress(pixelBuffer, [.readOnly])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, [.readOnly]) }

        // Calculate sum of planes' size
        var totalSize = 0
        for plane in 0 ..< CVPixelBufferGetPlaneCount(pixelBuffer) {
            let height      = CVPixelBufferGetHeightOfPlane(pixelBuffer, plane)
            let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, plane)
            let planeSize   = height * bytesPerRow
            totalSize += planeSize
        }

        guard let rawFrame = malloc(totalSize) else { fatalError() }
        var dest = rawFrame

        for plane in 0 ..< CVPixelBufferGetPlaneCount(pixelBuffer) {
            let source      = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, plane)
            let height      = CVPixelBufferGetHeightOfPlane(pixelBuffer, plane)
            let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, plane)
            let planeSize   = height * bytesPerRow

            memcpy(dest, source, planeSize)
            dest += planeSize
        }

        return Data(bytesNoCopy: rawFrame, count: totalSize, deallocator: .free)
    }
}
