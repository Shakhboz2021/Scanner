//
//  File.swift
//  Scanner
//
//  Created by Muhammad Tohirov on 20/05/25.
//

import AVFoundation
import CoreImage
import Extensions
import Scanner
import UIKit
import Vision

public class CardScanner: NSObject {
    weak var delegate: ScanDelegate?
    var needExpiryDate: Bool = false

    public init(delegate: ScanDelegate, needExpiryDate: Bool = false) {
        self.delegate = delegate
        self.needExpiryDate = needExpiryDate
        super.init()
    }

    public func presentScanner(from viewController: UIViewController) {
        let scannerVC = CardScannerViewController()
        scannerVC.cardScanner = self
        scannerVC.needExpiryDate = needExpiryDate
        viewController.present(scannerVC, animated: true, completion: nil)
    }
}

class CardScannerViewController: UIViewController,
    AVCaptureVideoDataOutputSampleBufferDelegate
{
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer!
    var needExpiryDate: Bool = false
    var cardNumber: String?
    var expiryDate: String?
    private let cameraQueue = DispatchQueue(
        label: "com.cardscanner.cameraQueue"
    )
    private var isCardFound: Bool = false
    private var isCancelling: Bool = false
    var cardScanner: CardScanner?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        checkCameraPermission()
        print("View did load completed")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.main.async { [weak self] in
            self?.previewLayer.frame = self?.view.bounds ?? .zero
            print(
                "View did appear, preview layer frame: \(self?.previewLayer.frame ?? .zero)"
            )
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        DispatchQueue.main.async { [weak self] in
            self?.previewLayer.frame = self?.view.bounds ?? .zero
            print(
                "Layout subviews, updated preview layer frame to: \(self?.previewLayer.frame ?? .zero)"
            )
        }
    }

    private func setupUI() {
        view.backgroundColor = .black

        // Camera Preview
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        print("Preview layer added to view with frame: \(previewLayer.frame)")

        // Very Subtle Blur Effect for Overall View
        let blurEffect = UIBlurEffect(style: .extraLight)  // Very light blur to keep background visible
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.alpha = 0.2  // Reduce opacity to make blur almost unnoticeable
        blurEffectView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(blurEffectView)

        // Very Subtle Gradient Layer for Vignette Effect
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = view.bounds
        let centerColor = UIColor.black.withAlphaComponent(0.05).cgColor  // Almost transparent center
        let edgeColor = UIColor.black.withAlphaComponent(0.15).cgColor  // Very light edges
        gradientLayer.colors = [edgeColor, centerColor, edgeColor]
        gradientLayer.locations = [0.0, 0.4, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        gradientLayer.opacity = 0.3  // Further reduce gradient visibility
        blurEffectView.layer.addSublayer(gradientLayer)

        // Subtle Shadow for Center Focus Area
        let focusLayer = CALayer()  // Corrected from previous error
        let focusRect = CGRect(
            x: view.bounds.width * 0.2,
            y: view.bounds.height * 0.3,
            width: view.bounds.width * 0.6,
            height: view.bounds.height * 0.4
        )
        focusLayer.frame = focusRect
        focusLayer.shadowColor = UIColor.black.cgColor
        focusLayer.shadowOpacity = 0.1  // Very subtle shadow
        focusLayer.shadowOffset = CGSize(width: 0, height: 2)
        focusLayer.shadowRadius = 3
        blurEffectView.layer.addSublayer(focusLayer)

        // Scan Status Label (Moved to Top)
        let statusLabel = UILabel()
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "Scanning..."
        statusLabel.textColor = .white
        statusLabel.font = .systemFont(ofSize: 20, weight: .bold)
        statusLabel.textAlignment = .center
        view.addSubview(statusLabel)

        // Cancel Button
        let cancelButton = UIButton(type: .system)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.backgroundColor = .red
        cancelButton.layer.cornerRadius = 8
        cancelButton.addTarget(
            self,
            action: #selector(cancelTapped),
            for: .touchUpInside
        )
        view.addSubview(cancelButton)

        // Constraints
        NSLayoutConstraint.activate([
            blurEffectView.topAnchor.constraint(equalTo: view.topAnchor),
            blurEffectView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            blurEffectView.leadingAnchor.constraint(
                equalTo: view.leadingAnchor
            ),
            blurEffectView.trailingAnchor.constraint(
                equalTo: view.trailingAnchor
            ),

            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: 20
            ),

            cancelButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cancelButton.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -20
            ),
            cancelButton.widthAnchor.constraint(equalToConstant: 200),
            cancelButton.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    private func setupCamera(completion: @escaping (Bool) -> Void) {
        cameraQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            print("Setting up camera on background queue...")
            guard let device = AVCaptureDevice.default(for: .video) else {
                print("No default video device found")
                DispatchQueue.main.async { completion(false) }
                return
            }
            guard let input = try? AVCaptureDeviceInput(device: device) else {
                print("Failed to create device input")
                DispatchQueue.main.async { completion(false) }
                return
            }
            if self.captureSession.canAddInput(input) {
                self.captureSession.addInput(input)
                print("Added input to session")
            } else {
                print("Cannot add input to session")
                DispatchQueue.main.async { completion(false) }
                return
            }
            if self.captureSession.canAddOutput(self.videoOutput) {
                self.captureSession.addOutput(self.videoOutput)
                self.videoOutput.setSampleBufferDelegate(
                    self,
                    queue: self.cameraQueue
                )
                print("Added output and set delegate")
            } else {
                print("Cannot add output to session")
                DispatchQueue.main.async { completion(false) }
                return
            }
            self.captureSession.startRunning()
            print("Capture session started")
            DispatchQueue.main.async {
                self.previewLayer.frame = self.view.bounds
                completion(true)
            }
        }
    }

    private func checkCameraPermission() {
        print(
            "Checking camera permission, status: \(AVCaptureDevice.authorizationStatus(for: .video).rawValue)"
        )
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera { [weak self] success in
                if !success {
                    self?.showPermissionAlert()
                }
            }
        case .notDetermined:
            cameraQueue.async { [weak self] in
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    DispatchQueue.main.async {
                        print("Permission request result: \(granted)")
                        if granted {
                            self?.setupCamera { success in
                                if !success {
                                    self?.showPermissionAlert()
                                }
                            }
                        } else {
                            self?.showPermissionAlert()
                        }
                    }
                }
            }
        case .denied, .restricted:
            showPermissionAlert()
        @unknown default:
            showPermissionAlert()
        }
    }

    private func showPermissionAlert() {
        print("Showing permission alert")
        DispatchQueue.main.async { [weak self] in
            let alert = UIAlertController(
                title: "Camera Access Required",
                message:
                    "Please enable camera access in Settings to scan cards.",
                preferredStyle: .alert
            )
            alert.addAction(
                UIAlertAction(title: "Settings", style: .default) { _ in
                    if let settingsURL = URL(
                        string: UIApplication.openSettingsURLString
                    ) {
                        UIApplication.shared.open(settingsURL)
                    }
                }
            )
            alert.addAction(
                UIAlertAction(title: "Cancel", style: .cancel) {
                    [weak self] _ in
                    self?.dismissAndFinish(with: nil)
                }
            )
            self?.present(alert, animated: true, completion: nil)
        }
    }

    @objc private func cancelTapped() {
        print("Cancel button tapped")
        isCancelling = true
        DispatchQueue.main.async { [weak self] in
            self?.captureSession.stopRunning()
            self?.dismissAndFinish(with: nil)
        }
    }

    private func dismissAndFinish(with result: CardScanResult?) {
        captureSession.stopRunning()
        dismiss(animated: true) { [weak self] in
            self?.cardScanner?.delegate?.scannerDidFinish(with: result)
            self?.isCancelling = false
            self?.isCardFound = false
            self?.cardNumber = nil
            self?.expiryDate = nil
        }
    }

    // Unchanged as per request
    private func validateExpirationDate(_ text: String) -> String? {
        var expiryDate = ""
        if text.contains("/") {
            let array = text.split(
                separator: "/",
                omittingEmptySubsequences: true
            )
            guard array.count > 1 else { return nil }
            let left = "\(array[0])".removeNonDigits()
            let right = "\(array[1])".removeNonDigits()
            if left.count > 1 && right.count > 1 {
                expiryDate = "\(array[0].suffix(2))/" + "\(array[1].prefix(2))"
            }
        }
        guard
            expiryDate.range(
                of: "^(0[1-9]|1[0-2])[/|-]([0-9]{2})$",
                options: .regularExpression
            ) != nil
        else {
            return nil
        }

        let components = expiryDate.components(
            separatedBy: CharacterSet(charactersIn: "/")
        )
        guard components.count == 2,
            let month = Int(components[0]),
            let year = Int("20" + components[1])
        else {
            return nil
        }

        let currentDate = Date()
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: currentDate)
        let currentYear = calendar.component(.year, from: currentDate)

        if year > currentYear || (year == currentYear && month >= currentMonth)
        {
            return expiryDate
        }
        return nil
    }

    // Unchanged as per request
    private func processTextObservations(
        _ observations: [VNRecognizedTextObservation]
    ) {
        for observation in observations {
            guard let text = observation.topCandidates(1).first?.string else {
                continue
            }
            print("Detected text: \(text)")

            // Clean text and check for card number (15 or 16 digits)
            let cleanedText = text.removeAll().removeNonDigits()
            if cardNumber == nil,
                cleanedText.count == 16,
                cleanedText.allSatisfy({ $0.isNumber })
            {
                if cleanedText.luhnCheck() {
                    cardNumber = cleanedText
                }
            }

            // Validate expiry date (MM/YY or MM-YY)
            if needExpiryDate,
                let date = validateExpirationDate(text.removeSpaces())
            {
                expiryDate = date
            }
        }

        // Only dismiss if both card number and expiry date are found
        if needExpiryDate {
            if let number = cardNumber, let date = expiryDate {
                DispatchQueue.main.async { [weak self] in
                    let details = CardScanResult(
                        cardNumber: number,
                        expiryDate: date
                    )
                    self?.dismissAndFinish(with: details)
                }
            }
        } else if let number = cardNumber {
            DispatchQueue.main.async { [weak self] in
                let details = CardScanResult(
                    cardNumber: number,
                    expiryDate: nil
                )
                self?.dismissAndFinish(with: details)
            }
        }
    }

    func recognizeText(in pixelBuffer: CVPixelBuffer) {
        let request = VNRecognizeTextRequest { [weak self] (request, error) in
            guard let self = self else { return }
            guard
                let observations = request.results
                    as? [VNRecognizedTextObservation], error == nil
            else {
                print("Error in text recognition: \(String(describing: error))")
                return
            }
            DispatchQueue.main.async {
                self.processTextObservations(observations)
            }
        }
        request.recognitionLevel = .accurate
        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            options: [:]
        )
        do {
            try handler.perform([request])
        } catch {
            print("Failed to perform text recognition: \(error)")
        }
    }

    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        #if os(iOS)
            guard !isCardFound, !isCancelling,
                let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
            else { return }
            cameraQueue.async { [weak self] in
                self?.recognizeText(in: pixelBuffer)
            }
        #else
            fatalError("CardScanner is only supported on iOS.")
        #endif
    }
}
