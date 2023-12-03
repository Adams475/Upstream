//
//  StartStreamingViewController.swift
//  UpstreamProject
//
//  Created by Simon Mason on 11/28/23.
//

import Foundation
import UIKit

class StartStreamViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    
    var streamId = ""
    var si = ServerInteracter()

    
    @IBOutlet weak var promptLabel: UILabel!
    @IBOutlet weak var streamTitleText: UITextField!
    
    @IBAction func buttonTapped(_ sender: UIButton) {
        if let text = streamTitleText.text {
            let textLength = text.count
            if (textLength == 0) {
                promptLabel.text = "Title must be at least 1 character"
                return
            }
            else if (textLength > 64) {
                promptLabel.text = "Title must be less than 64 characters"
                return
            }
            else if (!text.isAlphanumeric) {
                promptLabel.text = "Title must be Alpha numeric"
                return
            }
        }
        else {
            promptLabel.text = "Text is nil"
            return
        }
        si.askToMakeStreamTitle(streamTitle: streamTitleText.text!) { result in
            switch result {
            case .success(let data):
                // Handle successful response
                if let textString = String(data: data, encoding: .utf8) {
                    self.streamId = textString
                } else {
                    print("Couldn't convert data to text.")
                }
                // Trigger the segue on the main thread
                DispatchQueue.main.async {
                    self.performSegue(withIdentifier: "startStream", sender: nil)
                }

            case .failure(let error):
                // Handle error
                print("Error: \(error.localizedDescription)")
            }
        }
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "startStream" {
            if let destinationVC = segue.destination as? StreamingViewController {
                destinationVC.dataToPass = self.streamId
            }
        }
    }
    
    
}

extension String {
    var isAlphanumeric: Bool {
        return !isEmpty && range(of: "[^a-zA-Z0-9]", options: .regularExpression) == nil
    }
}

