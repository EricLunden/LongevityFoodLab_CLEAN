//
//  ImagePicker.swift
//  LongevityFoodLab
//
//  Created by Eric Betuel on 7/12/25.
//

import SwiftUI
import UIKit

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    let sourceType: UIImagePickerController.SourceType
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        
        // Add overlay for camera view
        if sourceType == .camera {
            let overlayView = CameraOverlayView()
            overlayView.frame = picker.view.bounds
            overlayView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            picker.cameraOverlayView = overlayView
        }
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // Update overlay frame if needed
        if sourceType == .camera, let overlayView = uiViewController.cameraOverlayView as? CameraOverlayView {
            overlayView.frame = uiViewController.view.bounds
            overlayView.setNeedsDisplay()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Camera Overlay View

class CameraOverlayView: UIView {
    private let squareSize: CGFloat = 350 // Size of the square frame
    private let hashMarkLength: CGFloat = 30 // Length of hash marks
    private let hashMarkWidth: CGFloat = 3 // Width of hash marks
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false // Allow touches to pass through
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        // Calculate center position
        let centerX = rect.width / 2
        let centerY = rect.height / 2 - 50 // Slightly above center to account for controls
        
        // Draw semi-transparent overlay (darken outside square)
        context.setFillColor(UIColor.black.withAlphaComponent(0.4).cgColor)
        context.fill(rect)
        
        // Clear the square area
        let squareRect = CGRect(
            x: centerX - squareSize / 2,
            y: centerY - squareSize / 2,
            width: squareSize,
            height: squareSize
        )
        context.setBlendMode(.clear)
        context.fill(squareRect)
        context.setBlendMode(.normal)
        
        // Draw square border
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(2)
        context.stroke(squareRect)
        
        // Draw hash marks at corners
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(hashMarkWidth)
        
        // Top-left corner
        // Horizontal line (left)
        context.move(to: CGPoint(x: squareRect.minX, y: squareRect.minY))
        context.addLine(to: CGPoint(x: squareRect.minX + hashMarkLength, y: squareRect.minY))
        // Vertical line (top)
        context.move(to: CGPoint(x: squareRect.minX, y: squareRect.minY))
        context.addLine(to: CGPoint(x: squareRect.minX, y: squareRect.minY + hashMarkLength))
        
        // Top-right corner
        // Horizontal line (right)
        context.move(to: CGPoint(x: squareRect.maxX, y: squareRect.minY))
        context.addLine(to: CGPoint(x: squareRect.maxX - hashMarkLength, y: squareRect.minY))
        // Vertical line (top)
        context.move(to: CGPoint(x: squareRect.maxX, y: squareRect.minY))
        context.addLine(to: CGPoint(x: squareRect.maxX, y: squareRect.minY + hashMarkLength))
        
        // Bottom-left corner
        // Horizontal line (left)
        context.move(to: CGPoint(x: squareRect.minX, y: squareRect.maxY))
        context.addLine(to: CGPoint(x: squareRect.minX + hashMarkLength, y: squareRect.maxY))
        // Vertical line (bottom)
        context.move(to: CGPoint(x: squareRect.minX, y: squareRect.maxY))
        context.addLine(to: CGPoint(x: squareRect.minX, y: squareRect.maxY - hashMarkLength))
        
        // Bottom-right corner
        // Horizontal line (right)
        context.move(to: CGPoint(x: squareRect.maxX, y: squareRect.maxY))
        context.addLine(to: CGPoint(x: squareRect.maxX - hashMarkLength, y: squareRect.maxY))
        // Vertical line (bottom)
        context.move(to: CGPoint(x: squareRect.maxX, y: squareRect.maxY))
        context.addLine(to: CGPoint(x: squareRect.maxX, y: squareRect.maxY - hashMarkLength))
        
        context.strokePath()
        
        // Draw text below the square
        let text = "Center Plate in Square"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
            .foregroundColor: UIColor.white,
            .strokeColor: UIColor.black,
            .strokeWidth: -2.0 // Negative for fill with stroke
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedString.size()
        let textRect = CGRect(
            x: centerX - textSize.width / 2,
            y: squareRect.maxY + 20,
            width: textSize.width,
            height: textSize.height
        )
        
        // Draw text with shadow for better visibility
        context.setShadow(offset: CGSize(width: 0, height: 1), blur: 3, color: UIColor.black.withAlphaComponent(0.5).cgColor)
        attributedString.draw(in: textRect)
    }
} 