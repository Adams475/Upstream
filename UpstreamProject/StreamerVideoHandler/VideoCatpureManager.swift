//
//  VideoCaptureManager.swift
//  NetworksProjTake2
//
//  Created by Simon Mason on 11/22/23.
//

import AVFoundation

class VideoCaptureManager {
    
    private enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
    
    private enum ConfigurationError: Error {
        case cannotAddInput
        case cannotAddOutput
        case defaultDeviceNotExist
    }
    
    // MARK: - dependencies
    
    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    
    // MARK: - DispatchQueues to make the most of multithreading
    
    private let sessionQueue = DispatchQueue(label: "session.queue")
    private let videoOutputQueue = DispatchQueue(label: "video.output.queue")
    
    private var setupResult: SessionSetupResult = .success
    
    
    private func requestCameraAuthorizationIfNeeded() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            // we suspend the queue here and request access because
            // if the authorization is not granted, we always fail to configure AVCaptureSession
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { granted in
                if !granted {
                    self.setupResult = .notAuthorized
                }
                self.sessionQueue.resume()
            })
        default:
            setupResult = .notAuthorized
        }
    }
    
    private func addVideoDeviceInputToSession() throws {
        do {
            var defaultVideoDevice: AVCaptureDevice?
            
            // camera devices you can use vary depending on which iPhone you are
            // using so we want to
            if let dualCameraDevice = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) {
                defaultVideoDevice = dualCameraDevice
            } else if let dualWideCameraDevice = AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back) {
                defaultVideoDevice = dualWideCameraDevice
            } else if let backCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                defaultVideoDevice = backCameraDevice
            } else if let frontCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
                defaultVideoDevice = frontCameraDevice
            }
            
            guard let videoDevice = defaultVideoDevice else {
                print("Default video device is unavailable.")
                setupResult = .configurationFailed
                session.commitConfiguration()
                
                throw ConfigurationError.defaultDeviceNotExist
            }
            
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
            } else {
                setupResult = .configurationFailed
                session.commitConfiguration()
                
                throw ConfigurationError.cannotAddInput
            }
        } catch {
            setupResult = .configurationFailed
            session.commitConfiguration()
            
            throw error
        }
    }
    
    private func addVideoOutputToSession() throws {
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        } else {
            setupResult = .configurationFailed
            session.commitConfiguration()
            
            throw ConfigurationError.cannotAddOutput
        }
    }

    private func configureSession() {
        if setupResult != .success {
            return
        }
        
        session.beginConfiguration()
        
        if session.canSetSessionPreset(.iFrame1280x720) {
            session.sessionPreset = .iFrame1280x720
        }
        
        do {
            try addVideoDeviceInputToSession()
            try addVideoOutputToSession()
            
            if let connection = session.connections.first {
                connection.videoRotationAngle = 0 //Might be the source of a bug. Look into addConnection or video rotation angle API.
            }
        } catch {
            print("error ocurred : \(error.localizedDescription)")
            return
        }
        
        session.commitConfiguration()
    }

    private func startSessionIfPossible() {
        switch self.setupResult {
        case .success:
            session.startRunning()
        case .notAuthorized:
            print("camera usage not authorized")
        case .configurationFailed:
            print("configuration failed")
        }
    }
    
    init() {
        sessionQueue.async {
            self.requestCameraAuthorizationIfNeeded()
        }

        sessionQueue.async {
            self.configureSession()
        }
        
        sessionQueue.async {
            self.startSessionIfPossible()
        }
    }
    
    func setVideoOutputDelegate(with delegate: AVCaptureVideoDataOutputSampleBufferDelegate) {
        // AVCaptureVideoDataOutput has a method named 'setSampleBufferDelegate' which set the object
        // to receive raw picture data
        videoOutput.setSampleBufferDelegate(delegate, queue: videoOutputQueue)
    }
}
