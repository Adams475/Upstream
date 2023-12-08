//
//  ServerInteracter.swift
//  UpstreamProject
//
//  Created by Simon Mason on 11/28/23.
//

import Foundation

class ServerInteracter {
    
    //private lazy var tcpConnection = TCPConnection()
    
    init() {
        /*
        do {
            //try tcpConnection.connect(to: "127.0.0.1", with: 9090)

        } catch let error {
            print(error.localizedDescription)
        }
        */
    }
    
    
    func askToMakeStreamTitle(streamTitle : String, completion: @escaping (Result<Data, Error>) -> Void) {
        guard let url = URL(string: "http://ec2-52-14-122-191.us-east-2.compute.amazonaws.com:9090/streams") else {
            completion(.failure(NSError(domain: "YourApp", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST" // Or "POST", "PUT", etc. depending on your use case
        request.httpBody = streamTitle.data(using: .utf8)
        request.allHTTPHeaderFields!["Data-Type"] = "Text"
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            if let data = data {
                completion(.success(data))
            } else {
                completion(.failure(NSError(domain: "YourApp", code: 2, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
            }
        }
        task.resume()
    }

}
