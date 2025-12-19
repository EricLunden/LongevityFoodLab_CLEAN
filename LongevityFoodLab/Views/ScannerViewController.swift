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

struct ScannerViewController: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onImageCaptured: (UIImage) -> Void
    
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
        
        func didCaptureImage(_ image: UIImage) {
            // Call the callback immediately - don't dismiss camera yet
            parent.onImageCaptured(image)
            // Don't dismiss here - let ContentView handle it after sheet shows
        }
        
        func didCancel() {
            parent.isPresented = false
        }
    }
}

protocol ScannerVCDelegate: AnyObject {
    func didCaptureImage(_ image: UIImage)
    func didCancel()
}

class ScannerVC: UIViewController {
    weak var delegate: ScannerVCDelegate?
    
    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var captureButton: UIButton?
    private var cancelButton: UIButton?
    private var buttonContainer: UIView?
    
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
        
        captureSession = session
        
        // Setup preview layer
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        self.previewLayer = previewLayer
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
        
        // Quick Scan button - styled like primary buttons in app
        let captureButton = UIButton(type: .system)
        captureButton.setTitle("Quick Scan", for: .normal)
        captureButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold) // .headline equivalent
        captureButton.setTitleColor(.white, for: .normal)
        captureButton.backgroundColor = UIColor(red: 0.42, green: 0.557, blue: 0.498, alpha: 1.0)
        captureButton.layer.cornerRadius = 12
        captureButton.contentEdgeInsets = UIEdgeInsets(top: 14, left: 0, bottom: 14, right: 0)
        captureButton.addTarget(self, action: #selector(captureTapped), for: .touchUpInside)
        container.addSubview(captureButton)
        self.captureButton = captureButton
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
        
        // Quick Scan button (right)
        captureButton?.frame = CGRect(
            x: buttonWidth + buttonSpacing,
            y: 0,
            width: buttonWidth,
            height: buttonHeight
        )
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
        
        // DON'T stop session here - let delegate handle it after processing
        // The session will be stopped in the delegate method after image is processed
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
}

// MARK: - AVCapturePhotoCaptureDelegate

extension ScannerVC: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        // Ensure session is stopped
        captureSession?.stopRunning()
        
        if let error = error {
            print("Scanner: Photo capture error: \(error.localizedDescription)")
            delegate?.didCancel()
            return
        }
        
        print("Scanner: Photo captured, extracting image data")
        
        // Try to get image data
        var image: UIImage?
        
        // Method 1: Try fileDataRepresentation (preferred)
        if let imageData = photo.fileDataRepresentation() {
            print("Scanner: Got image data from fileDataRepresentation, size: \(imageData.count) bytes")
            image = UIImage(data: imageData)
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
        processCapturedImage(capturedImage)
    }
    
    private func processCapturedImage(_ image: UIImage) {
        // Compress image: 1024x1024, JPEG 0.8 quality, ~300-500KB target
        let targetSize = CGSize(width: 1024, height: 1024)
        let compressedImage = image.resized(to: targetSize)
        
        guard let compressedData = compressedImage.jpegData(compressionQuality: 0.8) else {
            print("Scanner: Failed to compress image")
            delegate?.didCancel()
            return
        }
        
        print("Scanner: Image captured and compressed to \(compressedData.count) bytes")
        
        // Return compressed image
        if let finalImage = UIImage(data: compressedData) {
            DispatchQueue.main.async {
                self.delegate?.didCaptureImage(finalImage)
            }
        } else {
            print("Scanner: Failed to create final image from compressed data")
            delegate?.didCancel()
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

