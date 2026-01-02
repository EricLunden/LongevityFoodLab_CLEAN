import SwiftUI

/// Minimal, ATS-safe remote image loader with short timeouts and in-memory cache.
/// Use HTTPS only. Logs are prefixed with IMG:
struct RecipeRemoteImage: View {
    let urlString: String
    let isShorts: Bool

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
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 200)
                    .frame(height: 200)
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
        .frame(maxWidth: .infinity)
        .frame(height: 200)
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
