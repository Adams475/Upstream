//
//  StreamingDataHandler.swift
//  UpstreamProject
//
//  Created by Simon Mason on 12/3/23.
//

import Foundation
import CoreMedia

struct H264Unit {
    
    enum NALUType {
        case sps
        case pps
        case vcl
    }
    
    let type: NALUType
    
    private let payload: Data
    
    /// 4 bytes data represents NAL Unit's length
    private var lengthData: Data?
    
    /// it could be
    /// - pure NALU data(if SPS or PPS)
    /// - 4 bytes length data + NALU data(if not SPS or PPS)
    var data: Data {
        if type == .vcl {
            return lengthData! + payload
        } else {
            return payload
        }
    }
     
    /// - paramter payload: pure NALU data(no length data or start code)
    init(payload: Data) {
        //for byte in payload {
         //   print(String(format: "%02X", byte), terminator: " ")
        //}
        var d = payload
        do {
            let payload = try (d as NSData).decompressed(using: .lzfse) as Data
            //print()
            //print()

            let typeNumber = payload[0] & 0x1F
            //print("size of pure nalu data: \(payload.count + 4)")
            if typeNumber == 7 {
                self.type = .sps
                //print("incoming data packet is of type SPS")
            } else if typeNumber == 8 {
                self.type = .pps
                //print("incoming data packet is of type PPS")
            } else {
                self.type = .vcl
                //print("incoming datapacket is of some other type (\(typeNumber))")
                var naluLength = UInt32(payload.count)
                naluLength = CFSwapInt32HostToBig(naluLength)
                
                self.lengthData = Data(bytes: &naluLength, count: 4)
            }
            
            self.payload = payload as Data
        } catch {
            print(error.localizedDescription)
            self.type = .sps
            self.lengthData = Data()
            self.payload = payload
        }

    }
}

class NALUParser {
    
    /// Data stream received from the client.
    /// It'll be a seqeunce of NALU so we should pick out NALU from it.
    private var dataStream = Data()
    
    /// We should search data stream sequentially to pick out NALU of it.
    /// This is uesed for searching data stream.
    private var searchIndex = 0
    
    private lazy var parsingQueue = DispatchQueue.init(label: "parsing.queue",
                                                    qos: .userInteractive)
    
    /// callback when a NALU is seperated from data stream
    var h264UnitHandling: ((H264Unit) -> Void)?
    
    func enqueue(_ data: Data) {
        //print("parsing data block of size = \(data.count)")
        parsingQueue.async { [self] in
            dataStream.append(data)
            while searchIndex < dataStream.endIndex-3 {
                // examine if dataStream[searchIndex...searchIndex+3] is start code(0001)
                if (dataStream[searchIndex] == 0xDE && dataStream[searchIndex+1] == 0xCA &&
                    dataStream[searchIndex+2] == 0xFF && dataStream[searchIndex+3] == 0xBE) {
                    // if searchIndex is zero, that means there's nothing to extract cause
                    // we only care left side of searchIndex
                    if searchIndex != 0 {
                        let h264Unit = H264Unit(payload: dataStream[0..<searchIndex])
                        h264UnitHandling?(h264Unit)
                    }
                    
                    // We excute O(n) complexity operation here which is terribly inefficent.
                    // I hope you to refactor this part with more efficent way like a circular buffer.
                    dataStream.removeSubrange(0...searchIndex+3)
                    searchIndex = 0
                } else { // dataStream[searchIndex+3] == 0
                    searchIndex += 1
                }
            }
        }
    }
}

class H264Converter {
    
    // MARK: - properties
    
    private var sps: H264Unit?
    private var pps: H264Unit?
    
    private var description: CMVideoFormatDescription?
    
    private lazy var convertingQueue = DispatchQueue.init(label: "convertingQueue", qos: .userInteractive)
    
    var sampleBufferCallback: ((CMSampleBuffer) -> Void)?
    
    private func createDescription(with h264Format: H264Unit) {
        if h264Format.type == .sps {
            sps = h264Format
        } else if h264Format.type == .pps {
            pps = h264Format
        }
        
        guard let sps = sps,
              let pps = pps else {
            return
        }
        
        let spsPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: sps.data.count)
        sps.data.copyBytes(to: spsPointer, count: sps.data.count)
        
        let ppsPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: pps.data.count)
        pps.data.copyBytes(to: ppsPointer, count: pps.data.count)
                
        let parameterSet = [UnsafePointer(spsPointer), UnsafePointer(ppsPointer)]
        let parameterSetSizes = [sps.data.count, pps.data.count]
        
        defer {
            parameterSet.forEach {
                $0.deallocate()
            }
        }
                        
        CMVideoFormatDescriptionCreateFromH264ParameterSets(allocator: kCFAllocatorDefault,
                                                            parameterSetCount: 2,
                                                            parameterSetPointers: parameterSet,
                                                            parameterSetSizes: parameterSetSizes,
                                                            nalUnitHeaderLength: 4,
                                                            formatDescriptionOut: &description)
    }
    
    
    private func createBlockBuffer(with h264Format: H264Unit) -> CMBlockBuffer? {
        let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: h264Format.data.count)
        
        h264Format.data.copyBytes(to: pointer, count: h264Format.data.count)
        var blockBuffer: CMBlockBuffer?
        
        let error = CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault,
                                                       memoryBlock: pointer,
                                                       blockLength: h264Format.data.count,
                                                       blockAllocator: kCFAllocatorDefault,
                                                       customBlockSource: nil,
                                                       offsetToData: 0,
                                                       dataLength: h264Format.data.count,
                                                       flags: .zero,
                                                       blockBufferOut: &blockBuffer)
        
        guard error == kCMBlockBufferNoErr else {
            print("fail to create block buffer")
            return nil
        }
        
        return blockBuffer
    }
    
    private func createSampleBuffer(with blockBuffer: CMBlockBuffer) -> CMSampleBuffer? {
        var sampleBuffer : CMSampleBuffer?
        var timingInfo = CMSampleTimingInfo()
        timingInfo.decodeTimeStamp = .invalid
        timingInfo.duration = CMTime.invalid
        timingInfo.presentationTimeStamp = .zero
        
        let error = CMSampleBufferCreateReady(allocator: kCFAllocatorDefault,
                                  dataBuffer: blockBuffer,
                                  formatDescription: description,
                                  sampleCount: 1,
                                  sampleTimingEntryCount: 1,
                                  sampleTimingArray: &timingInfo,
                                  sampleSizeEntryCount: 0,
                                  sampleSizeArray: nil,
                                  sampleBufferOut: &sampleBuffer)
        
        guard error == noErr,
              let sampleBuffer = sampleBuffer else {
            print("fail to create sample buffer")
            return nil
        }
        
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer,
                                                                     createIfNecessary: true) {
            let dic = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0),
                                    to: CFMutableDictionary.self)
            
            CFDictionarySetValue(dic,
                                 Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                                 Unmanaged.passUnretained(kCFBooleanTrue).toOpaque())
        }
        
        return sampleBuffer
    }
    
    func convert(_ h264Unit: H264Unit) {
        convertingQueue.async { [self] in
            if h264Unit.type == .sps || h264Unit.type == .pps {
                description = nil
                createDescription(with: h264Unit)
                return
            } else {
                sps = nil
                pps = nil
            }

            guard let blockBuffer = createBlockBuffer(with: h264Unit),
                  let sampleBuffer = createSampleBuffer(with: blockBuffer) else {
                return
            }
            
            sampleBufferCallback?(sampleBuffer)
        }
    }
    
}

class VideoServer {
    
    // MARK: - dependencies
    
    private let server = TCPStreamListener()
    private let naluParser = NALUParser()
    private let h264Converter = H264Converter()
    
    // MARK: - task methods
    
    func start(on port: UInt16) throws {
        try server.start(port: port)
        
        setServerDataHandling()
        setNALUParserHandling()
    }
    
    func setSampleBufferCallback(_ callback: @escaping (CMSampleBuffer) -> Void) {
        h264Converter.sampleBufferCallback = callback
    }
    
    // MARK: - helper methods
    
    private func setServerDataHandling() {
        server.recievedDataHandling = { [naluParser] data in
                naluParser.enqueue(data as Data)
        }
    }
    
    private func setNALUParserHandling() {
        naluParser.h264UnitHandling = { [h264Converter] h264Unit in
            h264Converter.convert(h264Unit)
        }
    }
    
    func end() {
        server.end()
    }
    
}
