//
//  RequestingStreamViewController.swift
//  UpstreamProject
//
//  Created by Simon Mason on 12/3/23.
//

import UIKit
import AVFoundation

class RequestingStreamViewController: UIViewController {
    
    var streamId = "1";
    var serverIp = "52.14.122.191"
    var serverPort: UInt16 = 9090
    var listeningPort: UInt16 = 7070
    var tcpConnection = TCPRequester()
    let videoServer = VideoServer()
    
    @IBOutlet weak var buttonStopWatching: UIButton!
    let layer = AVSampleBufferDisplayLayer()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("stream id? = \(streamId)")
        layer.frame = view.frame
        view.layer.addSublayer(layer)
        print("Setting up listener")
        do {
            try videoServer.start(on: self.listeningPort)
            print("Listener successfully setup")
            videoServer.setSampleBufferCallback { [layer] sample in
                layer.enqueue(sample)
            }
        } catch {
            print("error with initialization of listening server")
            print(error.localizedDescription)
        }
        
        print("Setting up Requester...")
        do {
            print("Requester connecting to server...")
            try tcpConnection.connect(to: self.serverIp, with: self.serverPort)
            print("Requester connected to server")
        }
        catch{
            print("Failed to establish TCP connection, returning...")
            //return
        }

        print("Sending HTTP Streaming Video Data Request")
        tcpConnection.sendStreamHTTPRequest(streamId: self.streamId, port: listeningPort)
    }
    
    
    @IBAction func onStopWatching(_ sender: Any) {
        videoServer.end()
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
