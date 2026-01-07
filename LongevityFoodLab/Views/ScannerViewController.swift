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

enum ScannerMode {
    case groceries    // Keep barcode detection
    case supplements  // Skip barcode detection
}

struct ScannerViewController: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let mode: ScannerMode
    let onBarcodeCaptured: (UIImage, String?) -> Void
    let onFrontLabelCaptured: (UIImage) -> Void
    var onSupplementScanComplete: ((UIImage, UIImage) -> Void)? = nil
    
    func makeUIViewController(context: Context) -> ScannerVC {
        let controller = ScannerVC()
        controller.delegate = context.coordinator
        controller.scannerMode = mode
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
        
        func didCompleteSupplementScan(frontImage: UIImage, factsImage: UIImage) {
            parent.onSupplementScanComplete?(frontImage, factsImage)
        }
    }
}

protocol ScannerVCDelegate: AnyObject {
    func didCaptureBarcodeImage(_ image: UIImage, barcode: String?)
    func didCaptureFrontLabelImage(_ image: UIImage)
    func didCancel()
    func didCompleteSupplementScan(frontImage: UIImage, factsImage: UIImage)
}

enum ScannerState {
    case scanningBarcode
    case barcodeDetected
    case capturingFrontLabel
}

enum SupplementCapturePhase {
    case frontLabel         // First: product name image
    case supplementFacts    // Second: ingredients image
}

class ScannerVC: UIViewController {
    weak var delegate: ScannerVCDelegate?
    
    var scannerMode: ScannerMode = .groceries  // Default to groceries for backward compatibility
    
    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var metadataOutput: AVCaptureMetadataOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var captureButton: UIButton?
    private var cancelButton: UIButton?
    private var buttonContainer: UIView?
    private var scanningOverlay: UIView?
    private var promptLabel: UILabel?
    private var subtextLabel: UILabel?
    
    private var currentState: ScannerState = .scanningBarcode
    private var detectedBarcode: String?
    private var barcodeImage: UIImage?
    
    // For supplements two-capture flow
    private var supplementPhase: SupplementCapturePhase = .frontLabel
    private var frontLabelImage: UIImage?
    private var supplementFactsImage: UIImage?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set initial state based on mode
        if scannerMode == .supplements {
            currentState = .capturingFrontLabel  // Skip barcode phase for supplements
            supplementPhase = .frontLabel  // Start with front label capture
        }
        
        setupCamera()
        setupUI()
        
        // Update supplement UI if in supplements mode
        if scannerMode == .supplements {
            updateSupplementUI()
        }
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
        
        // Setup metadata output for continuous barcode detection (only for groceries mode)
        if scannerMode == .groceries {
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
        } else {
            // Supplements mode: skip barcode detection
            self.metadataOutput = nil
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
        
        // Set metadata output rect of interest after preview layer is set up (only for groceries)
        if scannerMode == .groceries,
           let metadataOutput = self.metadataOutput,
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
        container.clipsToBounds = false // Allow buttons to be positioned outside bounds if needed
        view.addSubview(container)
        self.buttonContainer = container
        
        // Capture button - initially hidden for groceries, shown immediately for supplements
        let captureButton = UIButton(type: .system)
        captureButton.setTitle("Capture Label", for: .normal)
        captureButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        captureButton.setTitleColor(.white, for: .normal)
        captureButton.layer.cornerRadius = 12
        captureButton.contentEdgeInsets = UIEdgeInsets(top: 14, left: 0, bottom: 14, right: 0)
        captureButton.addTarget(self, action: #selector(captureTapped), for: .touchUpInside)
        // Show immediately for supplements mode, hidden for groceries (shown after barcode detected)
        captureButton.isHidden = (scannerMode == .groceries)
        container.addSubview(captureButton)
        self.captureButton = captureButton
        
        // Cancel button - same size as Capture button, placed below it
        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.layer.cornerRadius = 12
        cancelButton.contentEdgeInsets = UIEdgeInsets(top: 14, left: 0, bottom: 14, right: 0)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        container.addSubview(cancelButton)
        self.cancelButton = cancelButton
        
        // Scanning overlay with corner brackets
        let overlay = UIView()
        overlay.backgroundColor = .clear
        overlay.isUserInteractionEnabled = false
        view.addSubview(overlay)
        self.scanningOverlay = overlay
        
        // Prompt label for front label capture - moved to top
        let promptLabel = UILabel()
        promptLabel.text = "Take A Photo Of The Front Label For Reference"
        promptLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        promptLabel.textColor = .white
        promptLabel.textAlignment = .center
        promptLabel.numberOfLines = 0
        // Background will be set by gradient, start with clear
        promptLabel.backgroundColor = .clear
        promptLabel.layer.cornerRadius = 12
        // Show immediately for supplements mode, hidden for groceries (shown after barcode detected)
        promptLabel.isHidden = (scannerMode == .groceries)
        promptLabel.clipsToBounds = true
        promptLabel.layer.masksToBounds = true
        view.addSubview(promptLabel)
        self.promptLabel = promptLabel
        
        // Subtext label for supplements two-phase guidance
        let subtextLabel = UILabel()
        subtextLabel.font = .systemFont(ofSize: 14, weight: .regular)
        subtextLabel.textColor = .white
        subtextLabel.textAlignment = .center
        subtextLabel.numberOfLines = 0
        subtextLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        subtextLabel.layer.cornerRadius = 8
        subtextLabel.isHidden = (scannerMode == .groceries)
        subtextLabel.layer.masksToBounds = true
        view.addSubview(subtextLabel)
        self.subtextLabel = subtextLabel
        
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
        
        // Calculate container width
        let containerWidth = view.bounds.width - (buttonPadding * 2)
        
        // Capture button layout based on state
        if currentState == .capturingFrontLabel {
            // Stacked layout: Capture button at top, Cancel button below it
            let totalHeight = (buttonHeight * 2) + buttonSpacing
            let containerY = view.bounds.height - totalHeight - bottomPadding
            
            buttonContainer?.frame = CGRect(
                x: buttonPadding,
                y: containerY,
                width: containerWidth,
                height: totalHeight
            )
            
            // Capture button at top (full width)
            if let captureButton = captureButton {
                captureButton.frame = CGRect(
                    x: 0,
                    y: 0,
                    width: containerWidth,
                    height: buttonHeight
                )
            }
            
            // Cancel button below capture button (same size, full width)
            if let cancelButton = cancelButton {
                cancelButton.isHidden = false
                cancelButton.frame = CGRect(
                    x: 0,
                    y: buttonHeight + buttonSpacing,
                    width: containerWidth,
                    height: buttonHeight
                )
            }
        } else {
            // Normal layout: single button container
            let containerY = view.bounds.height - buttonHeight - bottomPadding
            buttonContainer?.frame = CGRect(
                x: buttonPadding,
                y: containerY,
                width: containerWidth,
                height: buttonHeight
            )
            
            // Cancel button only (full width)
            if let cancelButton = cancelButton {
                cancelButton.frame = CGRect(
                    x: 0,
                    y: 0,
                    width: containerWidth,
                    height: buttonHeight
                )
            }
        }
        
        // Apply gradients/styles after frames are set
        if let captureButton = captureButton, !captureButton.isHidden {
            applyGreenGradient(to: captureButton)
        }
        if let cancelButton = cancelButton, !cancelButton.isHidden {
            applyDarkGrayBackground(to: cancelButton)
        }
        
        // Update scanning overlay
        updateScanningOverlay()
        
        // Update prompt label position - moved to top
        if let promptLabel = promptLabel {
            let promptWidth = view.bounds.width - 40
            // Increased height for comfortable padding - 80 for both single and multi-line
            let promptHeight: CGFloat = 80
            let topPadding: CGFloat = 60 // Safe area + padding
            promptLabel.frame = CGRect(
                x: 20,
                y: topPadding,
                width: promptWidth,
                height: promptHeight
            )
            // Ensure center alignment
            promptLabel.textAlignment = .center
            promptLabel.numberOfLines = 0 // Allow multiple lines
            promptLabel.layer.masksToBounds = true
            
            // Apply gradient after frame is set (for supplements mode)
            // This ensures label.bounds is correct when gradient is created
            if scannerMode == .supplements {
                // Ensure text is white and visible before applying gradient
                promptLabel.textColor = .white
                promptLabel.backgroundColor = .clear
                
                // Update gradient background view frame to match label
                if let gradientView = promptLabel.superview?.subviews.first(where: { $0.tag == 9999 }) {
                    // Update existing gradient view frame
                    gradientView.frame = promptLabel.frame
                    if let gradientLayer = gradientView.layer.sublayers?.first as? CAGradientLayer {
                        gradientLayer.frame = gradientView.bounds
                    }
                } else {
                    // Create gradient if it doesn't exist
                    if supplementPhase == .frontLabel {
                        applyGradientToLabel(promptLabel, colors: [
                            UIColor(red: 0.7, green: 0.1, blue: 0.05, alpha: 1.0).cgColor,  // Darker red
                            UIColor(red: 0.85, green: 0.35, blue: 0.0, alpha: 1.0).cgColor   // Darker orange
                        ])
                    } else if supplementPhase == .supplementFacts {
                        applyGradientToLabel(promptLabel, colors: [
                            UIColor(red: 0.05, green: 0.5, blue: 0.05, alpha: 1.0).cgColor,  // Darker green
                            UIColor(red: 0.6, green: 0.5, blue: 0.0, alpha: 1.0).cgColor   // Darker yellow/olive
                        ])
                    }
                }
            }
        }
        
        // Update subtext label position (below prompt label for supplements)
        if let subtextLabel = subtextLabel, scannerMode == .supplements {
            let promptBottom = (promptLabel?.frame.maxY ?? 0) + 8
            let subtextWidth = view.bounds.width - 40
            let subtextHeight: CGFloat = 40
            subtextLabel.frame = CGRect(
                x: 20,
                y: promptBottom,
                width: subtextWidth,
                height: subtextHeight
            )
            subtextLabel.layer.masksToBounds = true
        }
    }
    
    // MARK: - Button Gradient Helpers
    
    private func applyGreenGradient(to button: UIButton) {
        // Remove existing gradient layers
        button.layer.sublayers?.forEach { layer in
            if layer is CAGradientLayer {
                layer.removeFromSuperlayer()
            }
        }
        
        // Create green gradient (same as View More button)
        let gradient = CAGradientLayer()
        gradient.frame = button.bounds
        gradient.cornerRadius = 12
        gradient.colors = [
            UIColor(red: 29/255.0, green: 139/255.0, blue: 31/255.0, alpha: 1.0).cgColor,  // Green #1D8B1F
            UIColor(red: 159/255.0, green: 169/255.0, blue: 13/255.0, alpha: 1.0).cgColor  // Yellow-green #9FA90D
        ]
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        
        // Insert gradient below button's title label
        button.layer.insertSublayer(gradient, at: 0)
    }
    
    private func applyDarkGrayBackground(to button: UIButton) {
        // Remove existing gradient layers
        button.layer.sublayers?.forEach { layer in
            if layer is CAGradientLayer {
                layer.removeFromSuperlayer()
            }
        }
        
        // Set dark gray background color
        button.backgroundColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
    }
    
    private func updateSupplementUI() {
        guard scannerMode == .supplements else { return }
        
        // Hide subtext label for both phases
        subtextLabel?.isHidden = true
        
        switch supplementPhase {
        case .frontLabel:
            // Set text first
            promptLabel?.text = "Photograph the FRONT of the bottle"
            promptLabel?.textColor = .white
            promptLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
            promptLabel?.textAlignment = .center
            promptLabel?.numberOfLines = 0
            captureButton?.setTitle("Capture Front", for: .normal)
            // Gradient will be applied in viewDidLayoutSubviews when frame is set
            
        case .supplementFacts:
            // Add line spacing for multi-line text with white color and center alignment
            let attributedText = NSMutableAttributedString(string: "Now photograph the\nSUPPLEMENT FACTS panel")
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 8
            paragraphStyle.alignment = .center // Center align the text
            attributedText.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: attributedText.length))
            // Ensure white text color with semibold font
            attributedText.addAttribute(.foregroundColor, value: UIColor.white, range: NSRange(location: 0, length: attributedText.length))
            attributedText.addAttribute(.font, value: UIFont.systemFont(ofSize: 17, weight: .semibold), range: NSRange(location: 0, length: attributedText.length))
            promptLabel?.attributedText = attributedText
            promptLabel?.textColor = .white
            promptLabel?.textAlignment = .center
            promptLabel?.numberOfLines = 0
            captureButton?.setTitle("Capture Supplement Facts", for: .normal)
            // Gradient will be applied in viewDidLayoutSubviews when frame is set
        }
    }
    
    private func applyGradientToLabel(_ label: UILabel?, colors: [CGColor]) {
        guard let label = label else { return }
        
        // Debug: Check if text is set
        print("🔍 Applying gradient to label with text: '\(label.text ?? "nil")'")
        
        // Ensure layout is complete before applying gradient
        label.layoutIfNeeded()
        
        // Remove any existing gradient background view
        if let gradientView = label.superview?.subviews.first(where: { $0.tag == 9999 }) {
            gradientView.removeFromSuperview()
        }
        
        // Remove existing gradient layers from label itself
        label.layer.sublayers?.forEach { layer in
            if layer is CAGradientLayer {
                layer.removeFromSuperlayer()
            }
        }
        
        // Create gradient background view BEHIND the label (not as sublayer of label)
        let gradientView = UIView(frame: label.frame)
        gradientView.tag = 9999 // Tag to identify and remove later
        gradientView.layer.cornerRadius = 12
        gradientView.clipsToBounds = true
        gradientView.isUserInteractionEnabled = false // Don't block touches
        
        // Create gradient layer for the background view
        let gradient = CAGradientLayer()
        gradient.frame = gradientView.bounds
        gradient.cornerRadius = 12
        gradient.colors = colors
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        gradientView.layer.addSublayer(gradient)
        
        // Insert gradient view BEHIND the label in superview
        if let superview = label.superview {
            superview.insertSubview(gradientView, belowSubview: label)
            print("🔍 Gradient view inserted behind label")
        }
        
        // Ensure label has clear background so gradient shows through
        label.backgroundColor = .clear
        
        // Ensure text color is white and visible - CRITICAL
        label.textColor = .white
        print("🔍 Label textColor set to white: \(label.textColor == .white)")
        
        // Ensure label doesn't clip text
        label.clipsToBounds = false // Don't clip text
        label.layer.masksToBounds = false // Allow text to render properly
    }
    
    private func handleSupplementCapture(_ image: UIImage) {
        switch supplementPhase {
        case .frontLabel:
            print("📸 SUPPLEMENT: Phase 1 - Front label captured")
            frontLabelImage = image
            supplementPhase = .supplementFacts
            updateSupplementUI()
            // Update overlay for facts phase
            updateScanningOverlay()
            // Stay in scanner for second capture
            
        case .supplementFacts:
            print("📸 SUPPLEMENT: Phase 2 - Supplement Facts captured")
            supplementFactsImage = image
            // Both images captured — call completion
            if let front = frontLabelImage, let facts = supplementFactsImage {
                delegate?.didCompleteSupplementScan(frontImage: front, factsImage: facts)
            }
            // Dismiss scanner
            stopSession()
        }
    }
    
    private func updateScanningOverlay() {
        guard let overlay = scanningOverlay else { return }
        
        overlay.frame = view.bounds
        
        // Remove existing sublayers
        overlay.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        
        if currentState == .scanningBarcode {
            // Draw corner brackets for barcode scanning
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
        } else if currentState == .capturingFrontLabel {
            // Draw vertical rectangle frame markers for supplement capture
            drawSupplementFrame(overlay: overlay, isFactsPhase: false)
        } else if scannerMode == .supplements && supplementPhase == .supplementFacts {
            // Draw vertical rectangle frame markers for supplement facts capture
            drawSupplementFrame(overlay: overlay, isFactsPhase: true)
        }
    }
    
    private func drawSupplementFrame(overlay: UIView, isFactsPhase: Bool) {
        let bracketLength: CGFloat = 40
        let bracketWidth: CGFloat = 2  // Thinner lines
        let margin: CGFloat = 40
        
        // Vertical rectangle (portrait orientation) - taller than wide
        let frameWidth = view.bounds.width - (margin * 2)
        let frameHeight = frameWidth * 1.4  // Vertical rectangle: height is 1.4x width
        let frameX = margin
        let frameY = (view.bounds.height - frameHeight) / 2
        
        let frameRect = CGRect(
            x: frameX,
            y: frameY,
            width: frameWidth,
            height: frameHeight
        )
        
        let path = UIBezierPath()
        
        // Top-left corner
        path.move(to: CGPoint(x: frameRect.minX, y: frameRect.minY + bracketLength))
        path.addLine(to: CGPoint(x: frameRect.minX, y: frameRect.minY))
        path.addLine(to: CGPoint(x: frameRect.minX + bracketLength, y: frameRect.minY))
        
        // Top-right corner
        path.move(to: CGPoint(x: frameRect.maxX - bracketLength, y: frameRect.minY))
        path.addLine(to: CGPoint(x: frameRect.maxX, y: frameRect.minY))
        path.addLine(to: CGPoint(x: frameRect.maxX, y: frameRect.minY + bracketLength))
        
        // Bottom-left corner
        path.move(to: CGPoint(x: frameRect.minX, y: frameRect.maxY - bracketLength))
        path.addLine(to: CGPoint(x: frameRect.minX, y: frameRect.maxY))
        path.addLine(to: CGPoint(x: frameRect.minX + bracketLength, y: frameRect.maxY))
        
        // Bottom-right corner
        path.move(to: CGPoint(x: frameRect.maxX - bracketLength, y: frameRect.maxY))
        path.addLine(to: CGPoint(x: frameRect.maxX, y: frameRect.maxY))
        path.addLine(to: CGPoint(x: frameRect.maxX, y: frameRect.maxY - bracketLength))
        
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.strokeColor = UIColor.white.cgColor
        shapeLayer.lineWidth = bracketWidth
        shapeLayer.fillColor = UIColor.clear.cgColor
        overlay.layer.addSublayer(shapeLayer)
        
        // Draw camera bullseye in center
        let centerX = frameRect.midX
        let centerY = frameRect.midY
        let bullseyeRadius: CGFloat = 20
        
        // Outer circle
        let outerCirclePath = UIBezierPath(arcCenter: CGPoint(x: centerX, y: centerY),
                                           radius: bullseyeRadius,
                                           startAngle: 0,
                                           endAngle: .pi * 2,
                                           clockwise: true)
        let outerCircleLayer = CAShapeLayer()
        outerCircleLayer.path = outerCirclePath.cgPath
        outerCircleLayer.strokeColor = UIColor.white.cgColor
        outerCircleLayer.lineWidth = bracketWidth
        outerCircleLayer.fillColor = UIColor.clear.cgColor
        overlay.layer.addSublayer(outerCircleLayer)
        
        // Inner circle
        let innerCirclePath = UIBezierPath(arcCenter: CGPoint(x: centerX, y: centerY),
                                           radius: bullseyeRadius * 0.5,
                                           startAngle: 0,
                                           endAngle: .pi * 2,
                                           clockwise: true)
        let innerCircleLayer = CAShapeLayer()
        innerCircleLayer.path = innerCirclePath.cgPath
        innerCircleLayer.strokeColor = UIColor.white.cgColor
        innerCircleLayer.lineWidth = bracketWidth
        innerCircleLayer.fillColor = UIColor.clear.cgColor
        overlay.layer.addSublayer(innerCircleLayer)
        
        // Crosshair lines
        let crosshairLength: CGFloat = 15
        let crosshairPath = UIBezierPath()
        // Horizontal line
        crosshairPath.move(to: CGPoint(x: centerX - crosshairLength, y: centerY))
        crosshairPath.addLine(to: CGPoint(x: centerX + crosshairLength, y: centerY))
        // Vertical line
        crosshairPath.move(to: CGPoint(x: centerX, y: centerY - crosshairLength))
        crosshairPath.addLine(to: CGPoint(x: centerX, y: centerY + crosshairLength))
        
        let crosshairLayer = CAShapeLayer()
        crosshairLayer.path = crosshairPath.cgPath
        crosshairLayer.strokeColor = UIColor.white.cgColor
        crosshairLayer.lineWidth = bracketWidth
        crosshairLayer.fillColor = UIColor.clear.cgColor
        overlay.layer.addSublayer(crosshairLayer)
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
                self.cancelButton?.isEnabled = true
                // Update layout to show stacked buttons
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
        // Only stop if we're capturing front label (final capture) AND it's groceries mode
        // For supplements, we keep session running between captures
        if currentState == .capturingFrontLabel && scannerMode == .groceries {
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
        
        // Handle based on current state and mode
        switch currentState {
        case .scanningBarcode, .barcodeDetected:
            // This is the auto-captured barcode image (groceries only)
            if scannerMode == .groceries {
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
            }
            
        case .capturingFrontLabel:
            // This is the front label image
            if scannerMode == .supplements {
                // Handle supplements two-phase capture
                handleSupplementCapture(capturedImage)
            } else {
                // Groceries: process front label image
                print("Scanner: Processing front label image")
                processFrontLabelImage(capturedImage)
            }
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
        // Only process barcodes in groceries mode
        guard scannerMode == .groceries else { return }
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

