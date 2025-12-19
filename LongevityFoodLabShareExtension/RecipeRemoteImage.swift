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
                    .aspectRatio(contentMode: .fill)  // Fill entire frame
                    .frame(maxWidth: .infinity)  // Fill available width
                    .frame(height: 200)
                    .clipped()  // Crop to fill rectangle (no letterboxing)
                    .contentShape(Rectangle())
                    .cornerRadius(12)
            } else if isLoading {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 200)
                    .overlay(ProgressView())
            } else if let err = loadError {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 200)
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
                    .frame(height: 200)
                    .onAppear { fetch() }
            }
        }
        .onAppear {
            if uiImage == nil && !isLoading { fetch() }
        }
        .clipped()
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

        // HEAD check (optional) to fail fast on huge assets
        var headReq = URLRequest(url: url)
        headReq.httpMethod = "HEAD"
        headReq.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        let headTask = session.dataTask(with: headReq) { _, response, error in
            if let error = error {
                print("IMG: HEAD error \(urlString) err=\(error.localizedDescription)")
                // Continue anyway; some CDNs block HEAD
                self.download(session: session, url: url)
                return
            }
            if let http = response as? HTTPURLResponse {
                if let lenStr = http.allHeaderFields["Content-Length"] as? String,
                   let len = Int64(lenStr), len > 10_000_000 {
                    // >10 MB guard
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.loadError = "Image too large"
                    }
                    print("IMG: too large \(urlString) size=\(len)")
                    return
                }
            }
            self.download(session: session, url: url)
        }
        headTask.resume()
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
                DispatchQueue.main.async {
                    self.uiImage = img
                    self.isLoading = false
                }
                print("IMG: success \(url.absoluteString) bytes=\(data.count)")
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
}
