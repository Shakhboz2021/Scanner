//
//  CardScanner.swift
//  Scanner
//
//  Created by Muhammad Tohirov on 20/05/25.
//

import AVFoundation
import CoreImage
import Extensions
import Localization
import Photos
import Scanner
import UIKit
import Vision

public class CardScanner: NSObject {
    weak var delegate: ScanDelegate?
    var needExpiryDate: Bool = false
    var infoText: String?
    var unableToReadCardFromPhotoTitle: String?
    var unableToReadCardFromPhotoSubtitle: String?

    public init(
        delegate: ScanDelegate,
        needExpiryDate: Bool = false,
        infoText: String? = nil,
        unableToReadCardFromPhotoTitle: String? = nil,
        unableToReadCardFromPhotoSubtitle: String? = nil
    ) {
        self.delegate = delegate
        self.needExpiryDate = needExpiryDate
        self.infoText = infoText
        self.unableToReadCardFromPhotoTitle = unableToReadCardFromPhotoTitle
        self.unableToReadCardFromPhotoSubtitle =
            unableToReadCardFromPhotoSubtitle
        super.init()
    }

    public func presentScanner(from viewController: UIViewController) {
        let scannerVC = CardScannerViewController()
        scannerVC.cardScanner = self
        scannerVC.needExpiryDate = needExpiryDate
        scannerVC.unableToReadCardFromPhotoTitle =
            unableToReadCardFromPhotoTitle ?? L10n.unableToReadTitle
        scannerVC.unableToReadCardFromPhotoSubtitle =
            unableToReadCardFromPhotoSubtitle ?? L10n.unableToReadSubtitle
        scannerVC.infoText = infoText ?? L10n.scanCardInfo
        viewController.present(scannerVC, animated: true, completion: nil)
    }
}

class CardScannerViewController: UIViewController,
    AVCaptureVideoDataOutputSampleBufferDelegate,
    UIImagePickerControllerDelegate,
    UINavigationControllerDelegate
{
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer!
    var needExpiryDate: Bool = false
    var infoText: String?
    var unableToReadCardFromPhotoTitle: String?
    var unableToReadCardFromPhotoSubtitle: String?
    var cardNumber: String?
    var expiryDate: String?
    private let cameraQueue = DispatchQueue(
        label: "com.cardscanner.cameraQueue"
    )
    private var isCardFound: Bool = false
    private var isCancelling: Bool = false
    var cardScanner: CardScanner?
    private var isFlashOn = false
    private var captureDevice: AVCaptureDevice?
    private weak var flashButton: UIButton?
    private var lastCapturedSampleBuffer: CMSampleBuffer?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        checkCameraPermission()
        if let device = AVCaptureDevice.default(for: .video) {
            captureDevice = device
        }
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

        // Top Overlay (20% of the screen height)
        let topOverlay = UIView()
        topOverlay.translatesAutoresizingMaskIntoConstraints = false
        topOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.1)
        view.addSubview(topOverlay)

        // Scan Status Label (Inside Bottom Overlay)
        let statusLabel = UILabel()
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = infoText ?? L10n.scanCardInfo
        statusLabel.textColor = .white
        statusLabel.font = .systemFont(ofSize: 20, weight: .medium)
        statusLabel.textAlignment = .center
        view.addSubview(statusLabel)

        // Cancel Button (Top Left with X Icon, Inside Top Overlay)
        let cancelButton = UIButton(type: .system)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        cancelButton.tintColor = .white
        cancelButton.backgroundColor = .clear
        cancelButton.addTarget(
            self,
            action: #selector(cancelTapped),
            for: .touchUpInside
        )
        view.addSubview(cancelButton)

        // Flashlight Button
        let flashButton = UIButton(type: .system)
        flashButton.translatesAutoresizingMaskIntoConstraints = false
        flashButton.setImage(UIImage(systemName: "bolt.fill"), for: .normal)
        flashButton.tintColor = .white
        flashButton.backgroundColor = .clear
        flashButton.addTarget(
            self,
            action: #selector(toggleFlash),
            for: .touchUpInside
        )
        self.flashButton = flashButton

        // Add Photo Button
        let addPhotoButton = UIButton(type: .system)
        addPhotoButton.translatesAutoresizingMaskIntoConstraints = false
        addPhotoButton.setImage(
            UIImage(systemName: "photo.artframe"),
            for: .normal
        )
        addPhotoButton.tintColor = .white
        addPhotoButton.backgroundColor = .clear
        addPhotoButton.addTarget(
            self,
            action: #selector(selectPhotoFromGallery),
            for: .touchUpInside
        )

        // Stack View for Flash and Add Photo Buttons (Inside Bottom Overlay)
        let buttonStackView = UIStackView(arrangedSubviews: [
            addPhotoButton, flashButton,
        ])
        buttonStackView.translatesAutoresizingMaskIntoConstraints = false
        buttonStackView.axis = .horizontal
        buttonStackView.spacing = 80
        buttonStackView.alignment = .center
        buttonStackView.distribution = .equalSpacing
        view.addSubview(buttonStackView)

        // Constraints
        NSLayoutConstraint.activate([
            // Top Overlay (20% height)
            topOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            topOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topOverlay.heightAnchor.constraint(
                equalTo: view.heightAnchor,
                multiplier: 1
            ),

            // Status Label (Inside Bottom Overlay)
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.bottomAnchor.constraint(
                equalTo: buttonStackView.topAnchor,
                constant: -20
            ),

            // Cancel Button (Inside Top Overlay)
            cancelButton.leadingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.leadingAnchor,
                constant: 8
            ),
            cancelButton.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: 8
            ),
            cancelButton.widthAnchor.constraint(equalToConstant: 40),
            cancelButton.heightAnchor.constraint(equalToConstant: 40),

            // Button Stack View (Inside Bottom Overlay)
            buttonStackView.centerXAnchor.constraint(
                equalTo: view.centerXAnchor
            ),
            buttonStackView.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -20
            ),

            flashButton.widthAnchor.constraint(equalToConstant: 40),
            flashButton.heightAnchor.constraint(equalToConstant: 40),

            addPhotoButton.widthAnchor.constraint(equalToConstant: 40),
            addPhotoButton.heightAnchor.constraint(equalToConstant: 40),
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

    private func checkPhotoLibraryPermission(
        completion: @escaping (Bool) -> Void
    ) {
        let status = PHPhotoLibrary.authorizationStatus()
        print("Checking photo library permission, status: \(status.rawValue)")
        switch status {
        case .authorized:
            completion(true)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { newStatus in
                DispatchQueue.main.async {
                    print(
                        "Photo library permission request result: \(newStatus.rawValue)"
                    )
                    completion(newStatus == .authorized)
                }
            }
        case .denied, .restricted:
            showPhotoLibraryPermissionAlert()
            completion(false)
        case .limited:
            completion(true)  // Allow limited access if granted
        @unknown default:
            showPhotoLibraryPermissionAlert()
            completion(false)
        }
    }

    private func showPhotoLibraryPermissionAlert() {
        print("Showing photo library permission alert")
        DispatchQueue.main.async { [weak self] in
            let alert = UIAlertController(
                title: L10n.photoLibraryRequired,
                message: L10n.photoLibraryMessage,
                preferredStyle: .alert
            )
            alert.addAction(
                UIAlertAction(title: L10n.settings, style: .default) { _ in
                    if let settingsURL = URL(
                        string: UIApplication.openSettingsURLString
                    ) {
                        UIApplication.shared.open(settingsURL)
                    }
                }
            )
            alert.addAction(
                UIAlertAction(title: L10n.cancel, style: .cancel, handler: nil)
            )
            self?.present(alert, animated: true, completion: nil)
        }
    }

    private func showPermissionAlert() {
        print("Showing permission alert")
        DispatchQueue.main.async { [weak self] in
            let alert = UIAlertController(
                title: L10n.cameraAccessRequired,
                message: L10n.cameraAccessMessage,
                preferredStyle: .alert
            )
            alert.addAction(
                UIAlertAction(title: L10n.settings, style: .default) { _ in
                    if let settingsURL = URL(
                        string: UIApplication.openSettingsURLString
                    ) {
                        UIApplication.shared.open(settingsURL)
                    }
                }
            )
            alert.addAction(
                UIAlertAction(title: L10n.cancel, style: .cancel) {
                    [weak self] _ in
                    self?.dismissAndFinish(with: nil)
                }
            )
            self?.present(alert, animated: true, completion: nil)
        }
    }

    private func showFailedToReadPhotoAlert() {
        print("Showing failed to read photo alert")
        DispatchQueue.main.async { [weak self] in
            let alert = UIAlertController(
                title: self?.unableToReadCardFromPhotoTitle
                    ?? L10n.unableToReadTitle,
                message: self?.unableToReadCardFromPhotoSubtitle
                    ?? L10n.unableToReadSubtitle,
                preferredStyle: .alert
            )
            alert.addAction(
                UIAlertAction(title: L10n.ok, style: .default, handler: nil)
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

    @objc private func toggleFlash() {
        guard let device = AVCaptureDevice.default(for: .video),
            device.hasTorch
        else {
            print("Device has no torch capability")
            return
        }
        captureDevice = device

        do {
            try device.lockForConfiguration()
            if device.isTorchActive {
                device.torchMode = .off
                isFlashOn = false
                flashButton?.setImage(
                    UIImage(systemName: "bolt.fill"),
                    for: .normal
                )
            } else {
                try device.setTorchModeOn(level: 1.0)
                isFlashOn = true
                flashButton?.setImage(
                    UIImage(systemName: "bolt.slash.fill"),
                    for: .normal
                )
            }
            device.unlockForConfiguration()
        } catch {
            print("Failed to toggle torch: \(error)")
        }
    }

    @objc private func selectPhotoFromGallery() {
        print("Select Photo from Gallery button tapped")
        checkPhotoLibraryPermission { [weak self] granted in
            guard granted else {
                print("Photo library access not granted")
                return
            }
            let imagePicker = UIImagePickerController()
            imagePicker.delegate = self
            imagePicker.sourceType = .photoLibrary
            imagePicker.allowsEditing = false
            self?.present(imagePicker, animated: true, completion: nil)
        }
    }

    // UIImagePickerControllerDelegate method
    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey:
            Any]
    ) {
        picker.dismiss(animated: true, completion: nil)
        guard let image = info[.originalImage] as? UIImage else {
            print("No image selected from gallery")
            return
        }
        print("Image selected from gallery, processing...")
        guard let pixelBuffer = image.toCVPixelBuffer() else {
            print("Failed to convert image to CVPixelBuffer")
            return
        }
        // Reset cardNumber and expiryDate before scanning
        self.cardNumber = nil
        self.expiryDate = nil
        cameraQueue.async { [weak self] in
            self?.recognizeText(in: pixelBuffer)
            DispatchQueue.main.async { [weak self] in
                // Check if cardNumber is still nil after scanning
                if self?.cardNumber == nil {
                    self?.showFailedToReadPhotoAlert()
                }
            }
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
        print("Image picker cancelled")
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
            lastCapturedSampleBuffer = sampleBuffer
            cameraQueue.async { [weak self] in
                self?.recognizeText(in: pixelBuffer)
            }
        #else
            fatalError("CardScanner is only supported on iOS.")
        #endif
    }
}

// Extension to convert UIImage to CVPixelBuffer
extension UIImage {
    func toCVPixelBuffer() -> CVPixelBuffer? {
        let width = Int(self.size.width)
        let height = Int(self.size.height)

        let attrs =
            [
                kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
                kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!,
            ] as CFDictionary
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                | CGBitmapInfo.byteOrder32Little.rawValue
        )

        guard let cgContext = context else { return nil }

        cgContext.draw(
            self.cgImage!,
            in: CGRect(x: 0, y: 0, width: width, height: height)
        )

        return buffer
    }
}
