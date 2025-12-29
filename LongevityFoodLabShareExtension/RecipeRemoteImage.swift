import SwiftUI

/// Minimal, ATS-safe remote image loader with short timeouts and in-memory cache.
/// Use HTTPS only. Logs are prefixed with IMG:
struct RecipeRemoteImage: View {
    let urlString: String
    let isShorts: Bool  // For YouTube Shorts - zoom to fill without letterboxing

    @State private var uiImage: UIImage?
    @State private var isLoading = false
    @State private var loadError: String?
    
    init(urlString: String, isShorts: Bool = false) {
        self.urlString = urlString
        self.isShorts = isShorts
    }

    var body: some View {
        Group {
            if let img = uiImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()  // Aggressively fill frame - zoom to remove letterboxing
                    .frame(maxWidth: .infinity, maxHeight: 200)  // Fill width, constrain height
                    .frame(height: 200)  // Fixed horizontal box for all recipes
                    .clipped()  // Crop to fill rectangle (removes letterboxing for Shorts)
                    .cornerRadius(12)
                    .contentShape(Rectangle())
            } else if isLoading {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(maxWidth: .infinity, maxHeight: 200)
                    .frame(height: 200)
                    .cornerRadius(12)
                    .overlay(ProgressView())
            } else if let err = loadError {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(maxWidth: .infinity, maxHeight: 200)
                    .frame(height: 200)
                    .cornerRadius(12)
                    .overlay(
                        VStack(spacing: 6) {
                            Image(systemName: "photo")
                                .font(.title2)
                                .foregroundColor(.gray)
                            Text("Image failed")
                                .font(.footnote)
                                .foregroundColor(.gray)
                            Text(err)
                                .font(.caption2)
                                .foregroundColor(.gray)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 8)
                        }
                    )
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.15))
                    .frame(maxWidth: .infinity, maxHeight: 200)
                    .frame(height: 200)
                    .cornerRadius(12)
                    .onAppear { fetch() }
            }
        }
        .frame(maxWidth: .infinity)  // Fill available width
        .frame(height: 200)  // Fixed horizontal box for all recipes
        .clipped()  // Ensure no overflow
        .onAppear {
            if uiImage == nil && !isLoading { fetch() }
        }
    }

    private func fetch() {
        guard uiImage == nil, !isLoading else { return }
        guard urlString.lowercased().hasPrefix("https://") else {
            self.loadError = "Non-HTTPS URL blocked"
            print("IMG: blocked non-HTTPS \(urlString)")
            return
        }
        guard let url = URL(string: urlString) else {
            self.loadError = "Invalid URL"
            print("IMG: invalid URL \(urlString)")
            return
        }

        isLoading = true
        loadError = nil

        // Ephemeral, short timeouts, small cache
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 6
        config.timeoutIntervalForResource = 8
        config.waitsForConnectivity = false
        config.requestCachePolicy = .reloadIgnoringLocalCacheData

        let session = URLSession(configuration: config)

        // Skip HEAD request for faster loading - go straight to download
        // HEAD requests can cause delays, especially on Bon Appetit/Delish
        // Size check will happen during download instead
        self.download(session: session, url: url)
    }

    private func download(session: URLSession, url: URL) {
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        print("IMG: GET start \(url.absoluteString)")
        let task = session.dataTask(with: req) { data, response, error in
            if let error = error {
                print("IMG: GET error \(url.absoluteString) err=\(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.loadError = error.localizedDescription
                }
                return
            }
            guard let http = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.loadError = "Invalid response"
                }
                print("IMG: invalid response \(url.absoluteString)")
                return
            }
            guard (200..<300).contains(http.statusCode) else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.loadError = "HTTP \(http.statusCode)"
                }
                print("IMG: HTTP \(http.statusCode) \(url.absoluteString)")
                return
            }
            guard let data = data, !data.isEmpty else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.loadError = "No data"
                }
                print("IMG: empty data \(url.absoluteString)")
                return
            }
            // Basic sniff
            if data.count > 10_000_000 {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.loadError = "Image too large"
                }
                print("IMG: payload too large \(url.absoluteString)")
                return
            }
            if let img = UIImage(data: data) {
                // For Shorts, crop letterboxing (black bars) if present
                let processedImage = isShorts ? self.cropLetterboxing(from: img) : img
                DispatchQueue.main.async {
                    self.uiImage = processedImage
                    self.isLoading = false
                }
                print("IMG: success \(url.absoluteString) bytes=\(data.count) isShorts=\(isShorts)")
            } else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.loadError = "Decode failed"
                }
                print("IMG: decode failed \(url.absoluteString) bytes=\(data.count)")
            }
        }
        task.resume()
    }
    
    /// Crop black letterboxing bars from YouTube Shorts thumbnails
    private func cropLetterboxing(from image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        
        let width = cgImage.width
        let height = cgImage.height
        
        // Sample pixels along horizontal center line to detect black bars
        let centerY = height / 2
        var leftBarWidth = 0
        var rightBarWidth = 0
        
        // Find left black bar
        for x in 0..<width {
            if let pixel = getPixelColor(cgImage: cgImage, x: x, y: centerY) {
                let brightness = (pixel.red + pixel.green + pixel.blue) / 3.0
                if brightness > 0.1 { // Not black (threshold for black detection)
                    leftBarWidth = x
                    break
                }
            }
        }
        
        // Find right black bar
        for x in stride(from: width - 1, through: 0, by: -1) {
            if let pixel = getPixelColor(cgImage: cgImage, x: x, y: centerY) {
                let brightness = (pixel.red + pixel.green + pixel.blue) / 3.0
                if brightness > 0.1 { // Not black
                    rightBarWidth = width - x - 1
                    break
                }
            }
        }
        
        // Only crop if significant black bars detected (>5% of width)
        let totalBars = leftBarWidth + rightBarWidth
        if totalBars > Int(Double(width) * 0.05) {
            let cropRect = CGRect(
                x: leftBarWidth,
                y: 0,
                width: width - leftBarWidth - rightBarWidth,
                height: height
            )
            if let croppedCGImage = cgImage.cropping(to: cropRect) {
                return UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
            }
        }
        
        return image
    }
    
    /// Get pixel color at specific coordinates
    private func getPixelColor(cgImage: CGImage, x: Int, y: Int) -> (red: CGFloat, green: CGFloat, blue: CGFloat)? {
        guard x >= 0 && x < cgImage.width && y >= 0 && y < cgImage.height else { return nil }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel
        let bitsPerComponent = 8
        
        var pixelData = [UInt8](repeating: 0, count: bytesPerPixel)
        
        guard let context = CGContext(
            data: &pixelData,
            width: 1,
            height: 1,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        context.draw(cgImage, in: CGRect(x: -x, y: -y, width: cgImage.width, height: cgImage.height))
        
        let red = CGFloat(pixelData[0]) / 255.0
        let green = CGFloat(pixelData[1]) / 255.0
        let blue = CGFloat(pixelData[2]) / 255.0
        
        return (red, green, blue)
    }
}
