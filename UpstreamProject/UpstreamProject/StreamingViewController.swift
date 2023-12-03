//
//  StreamingViewController.swift
//  UpstreamProject

import UIKit
import AVFoundation

class StreamingViewController: UIViewController {
    var dataToPass = ""
    var videoClient: VideoClient?
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
            try videoClient?.connect(to: "10.0.0.174", with: 9090)
            try videoClient?.startSendingVideoToServer()
            videoClient?.setSampleBufferCallback { [layer] sample in
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
