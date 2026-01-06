//
//  ScannerViewController.swift
//  LongevityFoodLab
//
//  Universal Food/Supplement Scanner
//

import SwiftUI
import AVFoundation
import UIKit
import CoreImage
import CoreGraphics
import Vision

struct ScannerViewController: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onBarcodeCaptured: (UIImage, String?) -> Void
    let onFrontLabelCaptured: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> ScannerVC {
        let controller = ScannerVC()
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: ScannerVC, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, ScannerVCDelegate {
        let parent: ScannerViewController
        
        init(_ parent: ScannerViewController) {
            self.parent = parent
        }
        
        func didCaptureBarcodeImage(_ image: UIImage, barcode: String?) {
            parent.onBarcodeCaptured(image, barcode)
        }
        
        func didCaptureFrontLabelImage(_ image: UIImage) {
            parent.onFrontLabelCaptured(image)
        }
        
        func didCancel() {
            parent.isPresented = false
        }
    }
}

protocol ScannerVCDelegate: AnyObject {
    func didCaptureBarcodeImage(_ image: UIImage, barcode: String?)
    func didCaptureFrontLabelImage(_ image: UIImage)
    func didCancel()
}

enum ScannerState {
    case scanningBarcode
    case barcodeDetected
    case capturingFrontLabel
}

class ScannerVC: UIViewController {
    weak var delegate: ScannerVCDelegate?
    
    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var metadataOutput: AVCaptureMetadataOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var captureButton: UIButton?
    private var cancelButton: UIButton?
    private var buttonContainer: UIView?
    private var scanningOverlay: UIView?
    private var promptLabel: UILabel?
    
    private var currentState: ScannerState = .scanningBarcode
    private var detectedBarcode: String?
    private var barcodeImage: UIImage?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        setupUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopSession()
    }
    
    // MARK: - Camera Setup
    
    private func setupCamera() {
        let session = AVCaptureSession()
        session.sessionPreset = .photo
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            print("Scanner: Camera not available")
            return
        }
        
        do {
            let videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
            } else {
                print("Scanner: Cannot add video input")
                return
            }
        } catch {
            print("Scanner: Error setting up camera: \(error)")
            return
        }
        
        // Setup photo output
        let photoOutput = AVCapturePhotoOutput()
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            self.photoOutput = photoOutput
        } else {
            print("Scanner: Cannot add photo output")
            return
        }
        
        // Setup metadata output for continuous barcode detection
        let metadataOutput = AVCaptureMetadataOutput()
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.ean13, .ean8, .upce, .code128, .code39, .code93]
            self.metadataOutput = metadataOutput
        } else {
            print("Scanner: Cannot add metadata output")
            return
        }
        
        captureSession = session
        
        // Setup preview layer
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        self.previewLayer = previewLayer
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Set metadata output rect of interest after preview layer is set up
        if let metadataOutput = self.metadataOutput,
           let previewLayer = self.previewLayer {
            // Set rect of interest to full screen (normalized coordinates)
            metadataOutput.rectOfInterest = CGRect(x: 0, y: 0, width: 1, height: 1)
        }
        
        // Initialize scanning overlay
        updateScanningOverlay()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.backgroundColor = .black
        
        // Button container - bottom of screen, horizontal layout
        let container = UIView()
        container.backgroundColor = .clear
        view.addSubview(container)
        self.buttonContainer = container
        
        // Cancel button - styled like secondary buttons in app
        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold) // .headline equivalent
        cancelButton.setTitleColor(UIColor.secondaryLabel, for: .normal)
        cancelButton.backgroundColor = UIColor.systemGray6
        cancelButton.layer.cornerRadius = 12
        cancelButton.contentEdgeInsets = UIEdgeInsets(top: 14, left: 0, bottom: 14, right: 0)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        container.addSubview(cancelButton)
        self.cancelButton = cancelButton
        
        // Capture button - initially hidden, shown when front label capture is needed
        let captureButton = UIButton(type: .system)
        captureButton.setTitle("Capture Label", for: .normal)
        captureButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        captureButton.setTitleColor(.white, for: .normal)
        captureButton.backgroundColor = UIColor(red: 0.42, green: 0.557, blue: 0.498, alpha: 1.0)
        captureButton.layer.cornerRadius = 12
        captureButton.contentEdgeInsets = UIEdgeInsets(top: 14, left: 0, bottom: 14, right: 0)
        captureButton.addTarget(self, action: #selector(captureTapped), for: .touchUpInside)
        captureButton.isHidden = true // Hidden initially, shown when barcode is detected
        container.addSubview(captureButton)
        self.captureButton = captureButton
        
        // Scanning overlay with corner brackets
        let overlay = UIView()
        overlay.backgroundColor = .clear
        overlay.isUserInteractionEnabled = false
        view.addSubview(overlay)
        self.scanningOverlay = overlay
        
        // Prompt label for front label capture
        let promptLabel = UILabel()
        promptLabel.text = "Take a photo of the front label for reference"
        promptLabel.font = .systemFont(ofSize: 17, weight: .medium)
        promptLabel.textColor = .white
        promptLabel.textAlignment = .center
        promptLabel.numberOfLines = 0
        promptLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        promptLabel.layer.cornerRadius = 12
        promptLabel.isHidden = true
        promptLabel.layer.masksToBounds = true
        view.addSubview(promptLabel)
        self.promptLabel = promptLabel
        
        // Ensure button container is on top
        view.bringSubviewToFront(container)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Update preview layer frame
        previewLayer?.frame = view.bounds
        
        // Update button container and buttons
        let buttonHeight: CGFloat = 50
        let buttonPadding: CGFloat = 20
        let buttonSpacing: CGFloat = 12
        let bottomPadding: CGFloat = 40
        
        let containerY = view.bounds.height - buttonHeight - bottomPadding
        buttonContainer?.frame = CGRect(
            x: buttonPadding,
            y: containerY,
            width: view.bounds.width - (buttonPadding * 2),
            height: buttonHeight
        )
        
        // Calculate button widths (equal width, sharing space)
        let containerWidth = view.bounds.width - (buttonPadding * 2)
        let totalSpacing = buttonSpacing
        let buttonWidth = (containerWidth - totalSpacing) / 2
        
        // Cancel button (left)
        cancelButton?.frame = CGRect(
            x: 0,
            y: 0,
            width: buttonWidth,
            height: buttonHeight
        )
        
        // Capture button layout based on state
        if currentState == .capturingFrontLabel {
            // Full width capture button at bottom, cancel button above it
            captureButton?.frame = CGRect(
                x: 0,
                y: 0,
                width: containerWidth,
                height: buttonHeight
            )
            // Position cancel button above capture button
            cancelButton?.isHidden = false
            cancelButton?.frame = CGRect(
                x: buttonPadding,
                y: -buttonHeight - 8,
                width: 100,
                height: 40
            )
        } else {
            // Normal layout: cancel and capture buttons side by side
            cancelButton?.frame = CGRect(
                x: 0,
                y: 0,
                width: buttonWidth,
                height: buttonHeight
            )
            captureButton?.frame = CGRect(
                x: buttonWidth + buttonSpacing,
                y: 0,
                width: buttonWidth,
                height: buttonHeight
            )
        }
        
        // Update scanning overlay
        updateScanningOverlay()
        
        // Update prompt label position
        if let promptLabel = promptLabel {
            let promptWidth = view.bounds.width - 40
            let promptHeight: CGFloat = 60
            promptLabel.frame = CGRect(
                x: 20,
                y: view.bounds.height / 2 - promptHeight / 2,
                width: promptWidth,
                height: promptHeight
            )
            promptLabel.layer.masksToBounds = true
        }
    }
    
    private func updateScanningOverlay() {
        guard let overlay = scanningOverlay else { return }
        
        overlay.frame = view.bounds
        
        // Remove existing sublayers
        overlay.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        
        if currentState == .scanningBarcode {
            // Draw corner brackets
            let bracketLength: CGFloat = 30
            let bracketWidth: CGFloat = 4
            let margin: CGFloat = 50
            
            let scanningRect = CGRect(
                x: margin,
                y: view.bounds.height / 2 - 100,
                width: view.bounds.width - margin * 2,
                height: 200
            )
            
            let path = UIBezierPath()
            
            // Top-left corner
            path.move(to: CGPoint(x: scanningRect.minX, y: scanningRect.minY + bracketLength))
            path.addLine(to: CGPoint(x: scanningRect.minX, y: scanningRect.minY))
            path.addLine(to: CGPoint(x: scanningRect.minX + bracketLength, y: scanningRect.minY))
            
            // Top-right corner
            path.move(to: CGPoint(x: scanningRect.maxX - bracketLength, y: scanningRect.minY))
            path.addLine(to: CGPoint(x: scanningRect.maxX, y: scanningRect.minY))
            path.addLine(to: CGPoint(x: scanningRect.maxX, y: scanningRect.minY + bracketLength))
            
            // Bottom-left corner
            path.move(to: CGPoint(x: scanningRect.minX, y: scanningRect.maxY - bracketLength))
            path.addLine(to: CGPoint(x: scanningRect.minX, y: scanningRect.maxY))
            path.addLine(to: CGPoint(x: scanningRect.minX + bracketLength, y: scanningRect.maxY))
            
            // Bottom-right corner
            path.move(to: CGPoint(x: scanningRect.maxX - bracketLength, y: scanningRect.maxY))
            path.addLine(to: CGPoint(x: scanningRect.maxX, y: scanningRect.maxY))
            path.addLine(to: CGPoint(x: scanningRect.maxX, y: scanningRect.maxY - bracketLength))
            
            let shapeLayer = CAShapeLayer()
            shapeLayer.path = path.cgPath
            shapeLayer.strokeColor = UIColor.white.cgColor
            shapeLayer.lineWidth = bracketWidth
            shapeLayer.fillColor = UIColor.clear.cgColor
            overlay.layer.addSublayer(shapeLayer)
            
            // Scanning line animation
            let scanningLine = CALayer()
            scanningLine.frame = CGRect(x: scanningRect.minX, y: scanningRect.minY, width: scanningRect.width, height: 2)
            scanningLine.backgroundColor = UIColor.white.cgColor
            
            let animation = CABasicAnimation(keyPath: "position.y")
            animation.fromValue = scanningRect.minY
            animation.toValue = scanningRect.maxY
            animation.duration = 2.0
            animation.repeatCount = .infinity
            animation.autoreverses = true
            scanningLine.add(animation, forKey: "scanning")
            
            overlay.layer.addSublayer(scanningLine)
        }
    }
    
    // MARK: - Actions
    
    @objc private func captureTapped() {
        guard let session = captureSession, session.isRunning else {
            print("Scanner: Session not running")
            return
        }
        
        // Haptic feedback (impact, medium)
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Capture photo WHILE session is running
        guard let photoOutput = self.photoOutput else {
            print("Scanner: Photo output not available")
            delegate?.didCancel()
            return
        }
        
        // Configure photo settings - use default settings (JPEG is default)
        let settings = AVCapturePhotoSettings()
        
        // Check if JPEG is available (it should be by default)
        if photoOutput.availablePhotoCodecTypes.contains(.jpeg) {
            print("Scanner: JPEG codec available")
        } else {
            print("Scanner: Warning - JPEG codec not available, using default")
        }
        
        print("Scanner: Capturing photo with settings")
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    @objc private func cancelTapped() {
        delegate?.didCancel()
    }
    
    // MARK: - Session Management
    
    private func startSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
    
    private func stopSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.stopRunning()
        }
    }
    
    // MARK: - State Management
    
    private func transitionToState(_ newState: ScannerState) {
        currentState = newState
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            switch newState {
            case .scanningBarcode:
                self.captureButton?.isHidden = true
                self.promptLabel?.isHidden = true
                self.cancelButton?.isHidden = false
                self.updateScanningOverlay()
                
            case .barcodeDetected:
                // Brief state - processing barcode, show prompt
                self.captureButton?.isHidden = true
                self.promptLabel?.isHidden = false
                self.cancelButton?.isHidden = false
                self.scanningOverlay?.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
                
            case .capturingFrontLabel:
                // Show capture button and prompt, keep cancel button
                self.captureButton?.isHidden = false
                self.captureButton?.setTitle("Capture Label", for: .normal)
                self.captureButton?.alpha = 1.0
                self.captureButton?.isEnabled = true
                self.promptLabel?.isHidden = false
                self.cancelButton?.isHidden = false
                // Update layout to show full-width capture button
                self.viewDidLayoutSubviews()
                // Ensure button container and buttons are on top and visible
                if let container = self.buttonContainer {
                    self.view.bringSubviewToFront(container)
                }
                if let captureBtn = self.captureButton {
                    self.view.bringSubviewToFront(captureBtn)
                }
                if let cancelBtn = self.cancelButton {
                    self.view.bringSubviewToFront(cancelBtn)
                }
                print("Scanner: Transitioned to capturingFrontLabel - button should be visible")
            }
        }
    }
    
    private func handleBarcodeDetected(_ barcode: String) {
        guard currentState == .scanningBarcode else { return }
        
        detectedBarcode = barcode
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Auto-capture barcode image
        guard let photoOutput = self.photoOutput else {
            print("Scanner: Photo output not available")
            return
        }
        
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
        
        // Transition to barcode detected state
        transitionToState(.barcodeDetected)
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension ScannerVC: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        // Don't stop session here - we need it running for front label capture
        // Only stop if we're capturing front label (final capture)
        if currentState == .capturingFrontLabel {
            captureSession?.stopRunning()
        }
        
        if let error = error {
            print("Scanner: Photo capture error: \(error.localizedDescription)")
            delegate?.didCancel()
            return
        }
        
        print("Scanner: Photo captured, extracting image data")
        
        // Try to get image data
        var image: UIImage?
        
        // Method 1: Try fileDataRepresentation (preferred) - Memory-efficient decode
        if let imageData = photo.fileDataRepresentation() {
            print("Scanner: Got image data from fileDataRepresentation, size: \(imageData.count) bytes")
            
            // Memory-efficient decode: downscale during decode to prevent full-resolution image in memory
            image = autoreleasepool {
                let options: [CFString: Any] = [
                    kCGImageSourceThumbnailMaxPixelSize: 1024,
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceShouldCacheImmediately: false
                ]
                
                guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
                      let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                    print("Scanner: Efficient decode failed, falling back to standard decode")
                    return UIImage(data: imageData)
                }
                
                return UIImage(cgImage: cgImage)
            }
        }
        
        // Method 2: Try cgImageRepresentation as fallback
        if image == nil, let cgImage = photo.cgImageRepresentation() {
            print("Scanner: Using cgImageRepresentation as fallback")
            image = UIImage(cgImage: cgImage)
        }
        
        // Method 3: Try previewPixelBuffer as last resort
        if image == nil, let pixelBuffer = photo.previewPixelBuffer {
            print("Scanner: Using previewPixelBuffer as last resort")
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let context = CIContext(options: nil)
            if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
                image = UIImage(cgImage: cgImage)
            }
        }
        
        guard let capturedImage = image else {
            print("Scanner: Failed to extract image from photo - all methods failed")
            delegate?.didCancel()
            return
        }
        
        print("Scanner: Image extracted successfully, processing...")
        
        // Handle based on current state
        switch currentState {
        case .scanningBarcode, .barcodeDetected:
            // This is the auto-captured barcode image
            barcodeImage = capturedImage
            if let barcode = detectedBarcode {
                print("Scanner: Processing barcode image with barcode: \(barcode)")
                processBarcodeImage(capturedImage, barcode: barcode)
                // Restart session for front label capture
                startSession()
                // Transition to front label capture state
                transitionToState(.capturingFrontLabel)
            } else {
                // Fallback: detect barcode from image
                detectBarcode(in: capturedImage) { [weak self] barcode in
                    if let barcode = barcode {
                        print("Scanner: Barcode detected from image: \(barcode)")
                        self?.processBarcodeImage(capturedImage, barcode: barcode)
                        // Restart session for front label capture
                        self?.startSession()
                        self?.transitionToState(.capturingFrontLabel)
                    } else {
                        print("Scanner: No barcode detected, canceling")
                        self?.delegate?.didCancel()
                    }
                }
            }
            
        case .capturingFrontLabel:
            // This is the front label image
            print("Scanner: Processing front label image")
            processFrontLabelImage(capturedImage)
            
        }
    }
    
    // MARK: - Barcode Detection
    
    private func detectBarcode(in image: UIImage, completion: @escaping (String?) -> Void) {
        guard let cgImage = image.cgImage else {
            print("Scanner: No CGImage available for barcode detection")
            completion(nil)
            return
        }
        
        let request = VNDetectBarcodesRequest { request, error in
            if let error = error {
                print("Scanner: Barcode detection error: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let observations = request.results as? [VNBarcodeObservation] else {
                print("Scanner: No barcode observations found")
                completion(nil)
                return
            }
            
            // Return the first detected barcode
            for observation in observations {
                if let payload = observation.payloadStringValue {
                    print("Scanner: Barcode detected - type: \(observation.symbology.rawValue), value: \(payload)")
                    completion(payload)
                    return
                }
            }
            
            print("Scanner: Barcode observations found but no payload string value")
            completion(nil)
        }
        
        // Configure barcode types to detect (common product barcodes)
        // Note: .UPCA doesn't exist in Vision framework, UPC-A is typically detected as .EAN13
        request.symbologies = [.EAN13, .EAN8, .UPCE, .code128, .code39, .code93]
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                print("Scanner: Failed to perform barcode detection: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    
    private func processBarcodeImage(_ image: UIImage, barcode: String) {
        // Compress image: 1024x1024, JPEG 0.8 quality, ~300-500KB target
        let targetSize = CGSize(width: 1024, height: 1024)
        let compressedImage = image.resized(to: targetSize)
        
        guard let compressedData = compressedImage.jpegData(compressionQuality: 0.8) else {
            print("Scanner: Failed to compress barcode image")
            delegate?.didCancel()
            return
        }
        
        print("Scanner: Barcode image captured and compressed to \(compressedData.count) bytes")
        
        if let finalImage = UIImage(data: compressedData) {
            DispatchQueue.main.async {
                self.delegate?.didCaptureBarcodeImage(finalImage, barcode: barcode)
            }
        } else {
            print("Scanner: Failed to create final barcode image from compressed data")
            delegate?.didCancel()
        }
    }
    
    private func processFrontLabelImage(_ image: UIImage) {
        // Compress image: 1024x1024, JPEG 0.8 quality, ~300-500KB target
        let targetSize = CGSize(width: 1024, height: 1024)
        let compressedImage = image.resized(to: targetSize)
        
        guard let compressedData = compressedImage.jpegData(compressionQuality: 0.8) else {
            print("Scanner: Failed to compress front label image")
            delegate?.didCancel()
            return
        }
        
        print("Scanner: Front label image captured and compressed to \(compressedData.count) bytes")
        
        if let finalImage = UIImage(data: compressedData) {
            DispatchQueue.main.async {
                self.delegate?.didCaptureFrontLabelImage(finalImage)
                // Dismiss scanner after front label is captured
                self.stopSession()
            }
        } else {
            print("Scanner: Failed to create final front label image from compressed data")
            delegate?.didCancel()
        }
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension ScannerVC: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        // Only process if we're in scanning state
        guard currentState == .scanningBarcode else { return }
        
        // Find barcode metadata
        for metadataObject in metadataObjects {
            if let barcodeObject = metadataObject as? AVMetadataMachineReadableCodeObject,
               let barcodeString = barcodeObject.stringValue {
                print("Scanner: Barcode detected in live feed: \(barcodeString)")
                
                // Check if barcode is reasonably centered (within middle 60% of screen)
                let bounds = barcodeObject.bounds
                let centerX = bounds.midX
                let centerY = bounds.midY
                
                // Only trigger if barcode is reasonably centered
                if centerX > 0.2 && centerX < 0.8 && centerY > 0.3 && centerY < 0.7 {
                    handleBarcodeDetected(barcodeString)
                    // Stop metadata output to prevent multiple triggers
                    metadataOutput?.setMetadataObjectsDelegate(nil, queue: nil)
                    return
                }
            }
        }
    }
}

// MARK: - UIImage Extension

extension UIImage {
    func resized(to targetSize: CGSize) -> UIImage {
        let size = self.size
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        let scaleFactor = min(widthRatio, heightRatio)
        
        let scaledSize = CGSize(
            width: size.width * scaleFactor,
            height: size.height * scaleFactor
        )
        
        UIGraphicsBeginImageContextWithOptions(scaledSize, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        
        draw(in: CGRect(origin: .zero, size: scaledSize))
        return UIGraphicsGetImageFromCurrentImageContext() ?? self
    }
}

