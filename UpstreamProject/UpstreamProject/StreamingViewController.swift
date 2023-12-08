//
//  StreamingViewController.swift
//  UpstreamProject

import UIKit
import AVFoundation

class StreamingViewController: UIViewController {
    var dataToPass = ""
    var videoClient: VideoClient?
    var serverIP = "52.14.122.191"
    var serverPort: UInt16 = 9090
    let layer = AVSampleBufferDisplayLayer()
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func startButtonTapped(_ sender: UIButton) {
        print("Start streaming button tapped!\n")
        print(dataToPass)
        videoClient = VideoClient(streamId: dataToPass)
        do {
            layer.frame = view.frame
            view.layer.addSublayer(layer)
            try videoClient?.connect(to: self.serverIP, with: self.serverPort)
            try videoClient?.startSendingVideoToServer()
            videoClient?.setSampleBufferCallback { [layer] sample in
                layer.enqueue(sample)
            }
            
        } catch {
            print("error occured : \(error.localizedDescription)")
        }
    }
    
    @IBAction func startRawButtonTapped(_ sender: Any) {
        print("Start streaming (raw) button tapped!\n")
        print(dataToPass)
        videoClient = VideoClient(streamId: dataToPass)
        do {
            layer.frame = view.frame
            view.layer.addSublayer(layer)
            try videoClient?.connect(to: self.serverIP, with: self.serverPort)
            try videoClient?.startSendingVideoToServer()
            videoClient?.setSampleBufferCallback { [layer] sample in
                print("samplebuffer callback")
                self.videoClient?.sendRawVideo(buff: sample)
                layer.enqueue(sample)
            }
            
        } catch {
            print("error occured : \(error.localizedDescription)")
        }
    }
    
    @IBAction func stopButtonTapped(_ sender: UIButton) {
        videoClient?.disconnect()
    }
}
