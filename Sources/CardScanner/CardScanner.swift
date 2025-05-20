//
//  File.swift
//  Scanner
//
//  Created by Muhammad Tohirov on 20/05/25.
//

import AVFoundation
import Vision
import CoreImage
import Scanner

public struct CardScanResult: ScanResult {
    public let cardNumber: String
    public let name: String?
    public let expiryDate: String?
    
    public var data: [String: String] {
        var result: [String: String] = ["cardNumber": cardNumber]
        if let name = name { result["name"] = name }
        if let expiryDate = expiryDate { result["expiryDate"] = expiryDate }
        return result
    }
}

public class CardScanner: NSObject, ScanDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var completion: ((ScanResult?) -> Void)?
    
    public override init() {
        super.init()
        setupCamera()
    }
    
    private func setupCamera() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
            videoOutput.setSampleBufferDelegate(self, queue: .main)
        }
    }
    
    public func startScanning(completion: @escaping (ScanResult?) -> Void) {
        self.completion = completion
        if !captureSession.isRunning {
            captureSession.startRunning()
        }
    }
    
    public func stopScanning() {
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
    
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        let rectangleRequest = VNDetectRectanglesRequest { [weak self] request, error in
            guard let observations = request.results as? [VNRectangleObservation],
                  let rectangle = observations.first else { return }
            self?.extractText(from: ciImage.cropped(to: rectangle.boundingBox))
        }
        rectangleRequest.minimumAspectRatio = 0.5
        rectangleRequest.maximumAspectRatio = 0.7
        
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        try? handler.perform([rectangleRequest])
    }
    
    private func extractText(from image: CIImage) {
        let textRequest = VNRecognizeTextRequest { [weak self] request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                self?.completion?(nil)
                return
            }
            let texts = observations.compactMap { $0.topCandidates(1).first?.string }
            
            let cardNumber = texts.first(where: { $0.replacingOccurrences(of: " ", with: "").count == 16 && $0.allSatisfy { $0.isNumber || $0.isWhitespace } }) ?? ""
            let name = texts.first(where: { $0.split(separator: " ").count >= 2 && !$0.contains("/") })
            let expiry = texts.first(where: { $0.contains("/") && $0.count <= 7 })
            
            let result = CardScanResult(cardNumber: cardNumber, name: name, expiryDate: expiry)
            self?.completion?(result)
        }
        textRequest.recognitionLevel = .accurate
        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        try? handler.perform([textRequest])
    }
}
