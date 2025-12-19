import UIKit

class LoadingView: UIView {
    
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let statusLabel = UILabel()
    private let progressLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        backgroundColor = UIColor.systemBackground
        
        // Activity indicator
        activityIndicator.color = UIColor.systemBlue
        activityIndicator.startAnimating()
        
        // Status label
        statusLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        statusLabel.textColor = UIColor.label
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        
        // Progress label
        progressLabel.font = UIFont.systemFont(ofSize: 14)
        progressLabel.textColor = UIColor.secondaryLabel
        progressLabel.textAlignment = .center
        progressLabel.numberOfLines = 0
        
        // Add subviews
        addSubview(activityIndicator)
        addSubview(statusLabel)
        addSubview(progressLabel)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Activity indicator
            activityIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -40),
            
            // Status label
            statusLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            
            // Progress label
            progressLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 8),
            progressLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            progressLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20)
        ])
    }
    
    func updateStatus(_ status: String, progress: String? = nil) {
        statusLabel.text = status
        progressLabel.text = progress
    }
    
    func showError(_ message: String, retryAction: @escaping () -> Void) {
        activityIndicator.stopAnimating()
        statusLabel.text = "Error"
        statusLabel.textColor = UIColor.systemRed
        progressLabel.text = message
        progressLabel.textColor = UIColor.systemRed
        
        // Add retry button
        let retryButton = UIButton(type: .system)
        retryButton.setTitle("Retry", for: .normal)
        retryButton.backgroundColor = UIColor.systemBlue
        retryButton.setTitleColor(.white, for: .normal)
        retryButton.layer.cornerRadius = 8
        retryButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        
        retryButton.addAction(UIAction { _ in
            retryAction()
        }, for: .touchUpInside)
        
        addSubview(retryButton)
        retryButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            retryButton.topAnchor.constraint(equalTo: progressLabel.bottomAnchor, constant: 20),
            retryButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            retryButton.widthAnchor.constraint(equalToConstant: 120),
            retryButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
}
