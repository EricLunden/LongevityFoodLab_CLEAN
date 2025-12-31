import UIKit
import UniformTypeIdentifiers
import SwiftUI

class ShareViewController: UIViewController {
    
    private lazy var loadingView: LoadingView = {
        print("SE/INIT: Creating LoadingView")
        return LoadingView()
    }()
    private lazy var recipeBrowserService: RecipeBrowserService = {
        print("SE/INIT: Creating RecipeBrowserService")
        return RecipeBrowserService()
    }()
    private var hostingController: UIHostingController<RecipePreviewView>?
    private var sourceURL: URL?
    
    override init(nibName: String?, bundle: Bundle?) {
        super.init(nibName: nil, bundle: nil)
        print("SE/INIT: ShareViewController initialized")
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        print("SE/INIT: ShareViewController initialized via storyboard (init coder)")
    }
    
    override func viewDidLoad() {
        print("SE/INIT: viewDidLoad START")
        super.viewDidLoad()
        print("SE/INIT: viewDidLoad called (after super)")
        
        // Override storyboard contentMode to prevent zoom/scaling issue
        view.contentMode = .redraw
        view.clipsToBounds = true
        print("ShareViewController contentMode overridden to redraw")
        
        setupUI()
        processShare()
        print("SE/INIT: viewDidLoad END")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    private func setupUI() {
        print("SE/INIT: setupUI called")
        view.addSubview(loadingView)
        
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            loadingView.topAnchor.constraint(equalTo: view.topAnchor),
            loadingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        loadingView.isHidden = true // Initially hidden
    }
    
    private func processShare() {
        print("SE/INIT: processShare START")
        print("SE/STATE: idle → downloading")
        print("SE/CTX: attempting URL extraction")
        
        // Show downloading animation first
        showDownloadingPopup()
        
        // Extract URL from share
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = item.attachments else {
            print("SE/CTX: no-url - no attachments found")
            print("SE/CTX: inputItems count: \(extensionContext?.inputItems.count ?? 0)")
            showFallbackPreview(hostname: "Unknown Site")
            return
        }
        
        print("SE/CTX: Found \(attachments.count) attachment(s)")
        
        // First, try to get URL directly (public.url)
        for attachment in attachments {
            print("SE/CTX: Checking attachment type identifiers...")
            let typeIdentifiers = attachment.registeredTypeIdentifiers
            print("SE/CTX: Available types: \(typeIdentifiers)")
            
            if attachment.hasItemConformingToTypeIdentifier("public.url") {
                print("SE/CTX: Found public.url type")
                attachment.loadItem(forTypeIdentifier: "public.url") { [weak self] (url, error) in
                    DispatchQueue.main.async {
                        if let error = error {
                            print("SE/CTX: Error loading public.url: \(error.localizedDescription)")
                            self?.tryPlainTextExtraction(from: attachments)
                            return
                        }
                        
                        if let shareURL = url as? URL {
                            print("SE/CTX: url=\(shareURL.absoluteString)")
                            self?.sourceURL = shareURL
                            self?.extractRecipe(from: shareURL)
                        } else {
                            print("SE/CTX: public.url is not a URL object, trying plain text")
                            self?.tryPlainTextExtraction(from: attachments)
                        }
                    }
                }
                return
            }
        }
        
        // If no public.url found, try plain text
        tryPlainTextExtraction(from: attachments)
    }
    
    private func tryPlainTextExtraction(from attachments: [NSItemProvider]) {
        print("SE/CTX: Trying plain text extraction")
        
        for attachment in attachments {
            if attachment.hasItemConformingToTypeIdentifier("public.plain-text") {
                print("SE/CTX: Found public.plain-text type")
                attachment.loadItem(forTypeIdentifier: "public.plain-text") { [weak self] (text, error) in
                    DispatchQueue.main.async {
                        if let error = error {
                            print("SE/CTX: Error loading public.plain-text: \(error.localizedDescription)")
                            self?.showFallbackPreview(hostname: "Unknown Site")
                            return
                        }
                        
                        if let textString = text as? String {
                            print("SE/CTX: Got plain text: \(textString.prefix(100))")
                            
                            // Try to extract URL from text
                            if let url = self?.extractURL(from: textString) {
                                print("SE/CTX: Extracted URL from text: \(url.absoluteString)")
                                self?.sourceURL = url
                                self?.extractRecipe(from: url)
                            } else {
                                print("SE/CTX: No URL found in plain text")
                                self?.showFallbackPreview(hostname: "Unknown Site")
                            }
                        } else {
                            print("SE/CTX: Plain text is not a String")
                            self?.showFallbackPreview(hostname: "Unknown Site")
                        }
                    }
                }
                return
            }
        }
        
        // No URL found in any format
        print("SE/CTX: no-url - checked all attachment types")
        showFallbackPreview(hostname: "Unknown Site")
    }
    
    private func extractURL(from text: String) -> URL? {
        // Look for URLs in the text (YouTube URLs specifically)
        let patterns = [
            #"https?://(?:www\.)?(?:youtube\.com/watch\?v=|youtu\.be/|youtube\.com/shorts/)([a-zA-Z0-9_-]{11})"#,
            #"https?://[^\s]+"#  // General URL pattern
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)),
               let range = Range(match.range, in: text) {
                let urlString = String(text[range])
                if let url = URL(string: urlString) {
                    return url
                }
            }
        }
        
        return nil
    }
    
    private func extractRecipe(from url: URL) {
        print("🔍 SE/ShareViewController: extractRecipe called with URL: \(url.absoluteString)")
        
        // Show loading screen with custom message
        showDownloadingPopup()
        
        // Start watchdog timer (30s for slow extractions)
        startWatchdogTimer()
        
        // Use RecipeBrowserService to fetch HTML and send to Lambda
        recipeBrowserService.extractRecipeWithHTML(from: url) { [weak self] result in
            print("🔍 SE/ShareViewController: extractRecipeWithHTML completion called")
            DispatchQueue.main.async {
                self?.handleExtractionResult(result)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Finds the UINavigationBar in the view hierarchy
    private func findNavigationBar(in view: UIView) -> UINavigationBar? {
        if let navBar = view as? UINavigationBar {
            return navBar
        }
        for subview in view.subviews {
            if let navBar = findNavigationBar(in: subview) {
                return navBar
            }
        }
        return nil
    }
    
    // MARK: - Color Scheme Resolution
    
    /// Resolves the system color scheme using multiple sources to handle degraded trait collections in Share Extensions.
    /// Checks all UIKit trait sources first, then falls back to UserDefaults for system-level detection.
    private func resolveColorScheme() -> ColorScheme {
        // Check all UIKit trait sources - if ANY reports .dark, resolve to dark immediately
        let windowStyle = view.window?.traitCollection.userInterfaceStyle
        let selfStyle = traitCollection.userInterfaceStyle
        let viewStyle = view.traitCollection.userInterfaceStyle
        let screenStyle = UIScreen.main.traitCollection.userInterfaceStyle
        
        // Log all trait values for debugging
        print("SE/VIEW: Color scheme resolution - window: \(windowStyle?.rawValue ?? -1), self: \(selfStyle.rawValue), view: \(viewStyle.rawValue), screen: \(screenStyle.rawValue)")
        
        // If ANY UIKit trait reports .dark, resolve to dark immediately
        if windowStyle == .dark || selfStyle == .dark || viewStyle == .dark || screenStyle == .dark {
            print("SE/VIEW: Resolved to DARK (UIKit trait detected)")
            return .dark
        }
        
        // If none are .dark, check UserDefaults for system-level setting
        if let interfaceStyle = UserDefaults.standard.string(forKey: "AppleInterfaceStyle"),
           interfaceStyle == "Dark" {
            print("SE/VIEW: Resolved to DARK (UserDefaults AppleInterfaceStyle=Dark)")
            return .dark
        }
        
        // Log UserDefaults value for debugging
        let userDefaultsValue = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") ?? "nil"
        print("SE/VIEW: UserDefaults AppleInterfaceStyle: \(userDefaultsValue)")
        
        // Otherwise resolve to light
        print("SE/VIEW: Resolved to LIGHT (no dark mode detected)")
        return .light
    }
    
    private func showRecipePreview(_ recipe: ImportedRecipe) {
        print("SE/VIEW: Share flow complete — showing recipe")
        
        // Hide downloading popup
        hideDownloadingPopup()
        
        // Resolve color scheme explicitly BEFORE creating view (fixes TikTok dark mode timing issue)
        let resolvedColorScheme = resolveColorScheme()
        
        // Create recipe preview view with explicitly resolved color scheme
        let recipePreviewView = RecipePreviewView(
            recipe: recipe,
            isLoading: false,
            colorScheme: resolvedColorScheme,
            onCancel: { [weak self] in
                self?.handleCancel()
            },
            onSave: { [weak self] in
                self?.handleSave(recipe)
            }
        )
        
        // Remove existing hosting controller if present
        if let existingHosting = hostingController {
            existingHosting.willMove(toParent: nil)
            existingHosting.view.removeFromSuperview()
            existingHosting.removeFromParent()
            hostingController = nil
        }
        
        // Create hosting controller with explicitly resolved color scheme
        hostingController = UIHostingController(rootView: recipePreviewView)
        guard let hostingController = hostingController else { return }
        
        // Set hosting controller's root view background color to match resolved scheme
        hostingController.view.backgroundColor = resolvedColorScheme == .dark ? .black : .systemBackground
        
        // Pin hosting controller view frame to prevent zoom/scaling
        hostingController.view.frame = view.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Add as child view controller
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
        
        // Set up constraints
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Set navigation bar appearance to match resolved color scheme
        // Access navigation bar through hosting controller's view hierarchy
        DispatchQueue.main.async { [weak self, weak hostingController] in
            guard let self = self, let hostingController = hostingController else { return }
            
            // Try to find navigation bar in the view hierarchy
            if let navBar = self.findNavigationBar(in: hostingController.view) {
                if resolvedColorScheme == .dark {
                    navBar.barStyle = .black
                    navBar.tintColor = .white
                    navBar.titleTextAttributes = [.foregroundColor: UIColor.white]
                    
                    let appearance = UINavigationBarAppearance()
                    appearance.configureWithOpaqueBackground()
                    appearance.backgroundColor = .black
                    appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
                    appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
                    navBar.standardAppearance = appearance
                    navBar.scrollEdgeAppearance = appearance
                } else {
                    navBar.barStyle = .default
                    navBar.tintColor = nil
                    navBar.titleTextAttributes = nil
                    
                    let appearance = UINavigationBarAppearance()
                    appearance.configureWithDefaultBackground()
                    navBar.standardAppearance = appearance
                    navBar.scrollEdgeAppearance = appearance
                }
            }
        }
    }
    
    // MARK: - New Methods for HTML Fetching and Fallback
    
    private var watchdogTimer: Timer?
    private var hasFinished = false
    
    private func startWatchdogTimer() {
        // Increased to 30s to allow for slow extractions (network timeout is 25s)
        watchdogTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { [weak self] _ in
            print("SE/NET: watchdog fired (30s timeout)")
            // Show fallback if loading view is still visible
            if let loadingView = self?.loadingView, !loadingView.isHidden {
            self?.showFallbackPreview(hostname: self?.sourceURL?.host ?? "Unknown Site")
            }
        }
    }
    
    private func handleExtractionResult(_ result: RecipeExtractionResult) {
        // Cancel watchdog timer
        watchdogTimer?.invalidate()
        watchdogTimer = nil
        
        // Hide loading screen
        hideDownloadingPopup()
        
        switch result {
        case .success(let recipe):
            print("SE/STATE: downloading → preview (lambda)")
            print("SE/VIEW: show preview")
            showPreviewWith(data: recipe)
        case .fallbackMeta(let title, let imageURL, let siteLink):
            print("SE/STATE: downloading → preview (fallback-meta)")
            print("SE/VIEW: show preview")
            // Check if this is a YouTube URL
            let isYouTube = (siteLink?.contains("youtube.com") == true) || 
                           (siteLink?.contains("youtu.be") == true)
            let fallbackData = FallbackRecipeData(
                title: title,
                imageURL: imageURL,
                siteLink: siteLink,
                prepTime: nil,
                servings: nil,
                isYouTube: isYouTube
            )
            showPreviewWith(data: fallbackData)
        case .fallbackHostname(let hostname):
            print("SE/STATE: downloading → preview (fallback-hostname)")
            print("SE/VIEW: show preview")
            // Check if this is a YouTube URL (extraction failed)
            let isYouTube = (sourceURL?.absoluteString.contains("youtube.com") == true) || 
                           (sourceURL?.absoluteString.contains("youtu.be") == true)
            showFallbackPreview(hostname: hostname, isYouTube: isYouTube)
        }
    }
    
    private func showFallbackPreview(hostname: String, isYouTube: Bool = false) {
        let fallbackData = FallbackRecipeData(
            title: hostname,
            imageURL: nil,
            siteLink: sourceURL?.absoluteString,
            prepTime: nil,
            servings: nil,
            isYouTube: isYouTube
        )
        showPreviewWith(data: fallbackData)
    }
    
    private func showPreviewWith(data: Any) {
        // Hide downloading popup
        hideDownloadingPopup()
        
        // Remove existing hosting controller if present (from skeleton)
        if let existingHosting = hostingController {
            existingHosting.willMove(toParent: nil)
            existingHosting.view.removeFromSuperview()
            existingHosting.removeFromParent()
            hostingController = nil
        }
        
        // Create recipe preview view based on data type
        if let recipe = data as? ImportedRecipe {
            showRecipePreview(recipe)
        } else if let fallbackData = data as? FallbackRecipeData {
            showFallbackRecipePreview(fallbackData)
        }
    }
    
    private func showFallbackRecipePreview(_ data: FallbackRecipeData) {
        // Resolve color scheme explicitly BEFORE creating view (fixes dark mode timing issue)
        let resolvedColorScheme = resolveColorScheme()
        
        // Create fallback preview view with explicitly resolved color scheme
        let fallbackPreviewView = FallbackRecipePreviewView(
            data: data,
            onCancel: { [weak self] in
                print("SE/VIEW: user tapped Cancel")
                self?.handleCancel()
            },
            onSave: { [weak self] in
                print("SE/VIEW: user tapped Save")
                self?.handleFallbackSave(data)
            },
            colorScheme: resolvedColorScheme
        )
        
        let hostingController = UIHostingController(rootView: fallbackPreviewView)
        
        // Set hosting controller's root view background color to match resolved scheme
        hostingController.view.backgroundColor = resolvedColorScheme == .dark ? .black : .systemBackground
        
        // Pin hosting controller view frame to prevent zoom/scaling
        hostingController.view.frame = view.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Add as child view controller
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
        
        // Set up constraints
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Set navigation bar appearance to match resolved color scheme
        // Access navigation bar through hosting controller's view hierarchy
        DispatchQueue.main.async { [weak self, weak hostingController] in
            guard let self = self, let hostingController = hostingController else { return }
            
            // Try to find navigation bar in the view hierarchy
            if let navBar = self.findNavigationBar(in: hostingController.view) {
                if resolvedColorScheme == .dark {
                    navBar.barStyle = .black
                    navBar.tintColor = .white
                    navBar.titleTextAttributes = [.foregroundColor: UIColor.white]
                    
                    let appearance = UINavigationBarAppearance()
                    appearance.configureWithOpaqueBackground()
                    appearance.backgroundColor = .black
                    appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
                    appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
                    navBar.standardAppearance = appearance
                    navBar.scrollEdgeAppearance = appearance
                } else {
                    navBar.barStyle = .default
                    navBar.tintColor = nil
                    navBar.titleTextAttributes = nil
                    
                    let appearance = UINavigationBarAppearance()
                    appearance.configureWithDefaultBackground()
                    navBar.standardAppearance = appearance
                    navBar.scrollEdgeAppearance = appearance
                }
            }
        }
    }
    
    private func handleFallbackSave(_ data: FallbackRecipeData) {
        // Prevent saving empty YouTube recipes (extraction failed)
        if data.isYouTube {
            print("⚠️ SE/ShareViewController: Attempted to save YouTube fallback recipe - blocked")
            // Show error message instead
            showError("Cannot save: Recipe extraction failed for this YouTube video")
            return
        }
        
        // Convert fallback data to ImportedRecipe for saving (non-YouTube only)
        let recipe = ImportedRecipe(
            title: data.title,
            sourceUrl: data.siteLink ?? "",
            ingredients: [],
            instructions: "",
            servings: data.servings ?? 1,
            prepTimeMinutes: data.prepTime ?? 0,
            imageUrl: data.imageURL,
            rawIngredients: [],
            rawInstructions: ""
        )
        
        showSaveConfirmation(recipe)
    }
    
    private func handleTimeoutOrError() {
        // Hide downloading popup
        hideDownloadingPopup()
        
        // Show basic error and dismiss
        showError("Recipe will be processed later")
        
        // Dismiss after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        }
    }
    
    private func handleCancel() {
        print("SE/VIEW: user tapped Cancel")
        finishOnce(reason: "cancel")
    }
    
    private func handleSave(_ recipe: ImportedRecipe) {
        showSaveConfirmation(recipe)
    }
    
    private func showSaveConfirmation(_ recipe: ImportedRecipe) {
        let alert = UIAlertController(
            title: "Save Recipe",
            message: "Save '\(recipe.title)' to your recipe collection?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            self.dismissConfirmation()
        })
        
        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            print("SE/VIEW: user tapped Save")
            self.saveRecipe(recipe)
        })
        
        present(alert, animated: true)
    }
    
    private func dismissConfirmation() {
        // Return to recipe preview
    }
    
    private func saveRecipe(_ recipe: ImportedRecipe) {
        // Save recipe using App Groups
        saveRecipeToAppGroups(recipe)
        
        // Finish immediately - no popups
        finishOnce(reason: "success")
    }
    
    private func showSavedConfirmation() {
        // Show the existing "Saved" confirmation popup
        let alert = UIAlertController(
            title: "Saved",
            message: "Recipe saved to Longevity Food Lab",
            preferredStyle: .alert
        )
        
        present(alert, animated: true)
        
        // Dismiss after delay and finish
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            alert.dismiss(animated: true) {
                self?.finishOnce(reason: "success")
            }
        }
    }
    
    private func finishOnce(reason: String) {
        guard !hasFinished else { return }
        hasFinished = true
        
        print("SE/VIEW: finishing (reason=\(reason))")
        extensionContext?.completeRequest(returningItems: nil)
    }
    
    
    private func showDownloadingPopup() {
        // Create full-screen light gray overlay
        let overlayView = UIView()
        overlayView.backgroundColor = UIColor.lightGray.withAlphaComponent(0.1)
        overlayView.tag = 999 // For easy removal
        view.addSubview(overlayView)
        
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            overlayView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Create rounded square container
        let containerView = UIView()
        containerView.backgroundColor = UIColor.black
        containerView.layer.cornerRadius = 15
        containerView.layer.borderWidth = 0.5
        containerView.layer.borderColor = UIColor.green.withAlphaComponent(0.6).cgColor
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        containerView.layer.shadowRadius = 10
        containerView.layer.shadowOpacity = 0.3
        overlayView.addSubview(containerView)
        
        containerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: overlayView.centerYAnchor, constant: -50),
            containerView.widthAnchor.constraint(equalToConstant: 300),
            containerView.heightAnchor.constraint(equalToConstant: 240)
        ])
        
        // Create a container for animation and text to center them together
        let contentContainer = UIView()
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(contentContainer)
        
        // Add loading animation
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.color = UIColor.systemBlue
        activityIndicator.startAnimating()
        contentContainer.addSubview(activityIndicator)
        
        // Add text - split into title and subtitle
        let titleLabel = UILabel()
        titleLabel.text = "That recipe looks AMAZING!"
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = UIColor.white
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        contentContainer.addSubview(titleLabel)
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = "The Longevity Chef is fetching it for you now. It may take a few seconds!"
        subtitleLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.9)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        contentContainer.addSubview(subtitleLabel)
        
        // Center the content container in the main container
        NSLayoutConstraint.activate([
            contentContainer.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            contentContainer.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            contentContainer.leadingAnchor.constraint(greaterThanOrEqualTo: containerView.leadingAnchor, constant: 20),
            contentContainer.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -20)
        ])
        
        // Position animation and text within content container
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Animation at top of content container
            activityIndicator.centerXAnchor.constraint(equalTo: contentContainer.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            
            // Title below animation
            titleLabel.centerXAnchor.constraint(equalTo: contentContainer.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 15),
            titleLabel.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            
            // Subtitle below title
            subtitleLabel.centerXAnchor.constraint(equalTo: contentContainer.centerXAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
        ])
    }
    
    private func hideDownloadingPopup() {
        // Remove overlay view
        if let overlayView = view.viewWithTag(999) {
            UIView.animate(withDuration: 0.3, animations: {
                overlayView.alpha = 0
            }) { _ in
                overlayView.removeFromSuperview()
            }
        }
    }
    
    private func showError(_ message: String) {
        loadingView.showError(message) { [weak self] in
            self?.loadingView.isHidden = false
            if let url = self?.sourceURL {
                self?.extractRecipe(from: url)
            } else {
                self?.processShare()
            }
        }
    }
    
    private func saveRecipeToAppGroups(_ recipe: ImportedRecipe) {
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.ericbetuel.longevityfoodlab") else {
            showError("Failed to save recipe")
            return
        }
        
        // Save recipe data as JSON
        var recipeData: [String: Any] = [
            "title": recipe.title,
            "ingredients": recipe.ingredients,
            "instructions": recipe.instructions,
            "imageURL": recipe.imageUrl ?? "",
            "prepTime": recipe.prepTimeMinutes,
            "servings": recipe.servings,
            "sourceURL": sourceURL?.absoluteString ?? "",
            "importedAt": Date().timeIntervalSince1970
        ]
        
        // Include extracted nutrition if available
        if let nutrition = recipe.extractedNutrition {
            // Encode NutritionInfo to JSON
            if let nutritionData = try? JSONEncoder().encode(nutrition),
               let nutritionDict = try? JSONSerialization.jsonObject(with: nutritionData) as? [String: Any] {
                recipeData["extractedNutrition"] = nutritionDict
                print("SE/VIEW: Including extractedNutrition in App Groups save - calories: \(nutrition.calories)")
            }
        }
        
        // Include nutrition source
        if let source = recipe.nutritionSource {
            recipeData["nutritionSource"] = source
            print("SE/VIEW: Including nutritionSource in App Groups save: \(source)")
        }
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: recipeData),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            sharedDefaults.set(jsonString, forKey: "pendingRecipeData")
            sharedDefaults.set(Date(), forKey: "pendingRecipeTimestamp")
            sharedDefaults.synchronize()
            
            print("SE/VIEW: recipe saved to App Groups successfully")
            
            // REMOVED: showSuccess() - silent save, no popups
            // finishOnce() is called from saveRecipe() instead
        } else {
            showError("Failed to save recipe")
        }
    }
    
    private func showSuccess() {
        // Hide recipe preview
        hostingController?.view.removeFromSuperview()
        hostingController?.removeFromParent()
        hostingController = nil
        
        // Show success popup with same style as downloading popup
        showSuccessPopup()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.extensionContext?.completeRequest(returningItems: nil)
        }
    }
    
    private func showSuccessPopup() {
        // Create full-screen light gray overlay (same as downloading popup)
        let overlayView = UIView()
        overlayView.backgroundColor = UIColor.lightGray.withAlphaComponent(0.1)
        overlayView.tag = 998 // Different tag from downloading popup
        view.addSubview(overlayView)
        
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            overlayView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Create rounded square container (same style as downloading popup)
        let containerView = UIView()
        containerView.backgroundColor = UIColor.black
        containerView.layer.cornerRadius = 15
        containerView.layer.borderWidth = 0.5
        containerView.layer.borderColor = UIColor.green.withAlphaComponent(0.6).cgColor
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        containerView.layer.shadowRadius = 10
        containerView.layer.shadowOpacity = 0.3
        overlayView.addSubview(containerView)
        
        containerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: overlayView.centerYAnchor, constant: -50),
            containerView.widthAnchor.constraint(equalToConstant: 280),
            containerView.heightAnchor.constraint(equalToConstant: 200)
        ])
        
        // Create a container for icon and text to center them together
        let contentContainer = UIView()
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(contentContainer)
        
        // Add success checkmark icon (instead of spinner)
        let checkmarkImageView = UIImageView()
        checkmarkImageView.image = UIImage(systemName: "checkmark.circle.fill")
        checkmarkImageView.tintColor = UIColor.systemGreen
        checkmarkImageView.contentMode = .scaleAspectFit
        contentContainer.addSubview(checkmarkImageView)
        
        // Add text (same style as downloading popup)
        let titleLabel = UILabel()
        titleLabel.text = "Recipe Saved to Longevity Food Lab"
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = UIColor.white
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        contentContainer.addSubview(titleLabel)
        
        // Center the content container in the main container
        NSLayoutConstraint.activate([
            contentContainer.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            contentContainer.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            contentContainer.leadingAnchor.constraint(greaterThanOrEqualTo: containerView.leadingAnchor, constant: 20),
            contentContainer.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -20)
        ])
        
        // Position icon and text within content container
        checkmarkImageView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Icon at top of content container
            checkmarkImageView.centerXAnchor.constraint(equalTo: contentContainer.centerXAnchor),
            checkmarkImageView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            checkmarkImageView.widthAnchor.constraint(equalToConstant: 40),
            checkmarkImageView.heightAnchor.constraint(equalToConstant: 40),
            
            // Text below icon with same spacing as downloading popup
            titleLabel.centerXAnchor.constraint(equalTo: contentContainer.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: checkmarkImageView.bottomAnchor, constant: 15),
            titleLabel.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
        ])
    }
    
}
