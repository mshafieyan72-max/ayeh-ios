import UIKit
import WebKit
import AVFoundation

class ViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {

    private var webView: WKWebView!
    private var progressView: UIProgressView!
    private let refreshControl = UIRefreshControl()

    private let appURL = URL(string: "https://ai.ayehnet.ir")!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupStatusBar()
        setupWKWebView()
        setupProgressView()
        requestMicrophonePermission()
        loadApplication()
    }

    private func setupStatusBar() {
        view.backgroundColor = .systemBackground
    }

    private func setupWKWebView() {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        // WebScript Bridge
        let contentController = WKUserContentController()
        contentController.add(self, name: "AyehMobileBridge")
        configuration.userContentController = contentController

        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.bounces = true

        // 1. Anti-Bot / Anti-Ban: Pure Mobile Safari Native User-Agent
        // Eliminates any custom/hybrid webview signatures
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"

        // 2. Pull to Refresh
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        refreshControl.tintColor = UIColor(red: 5/255, green: 150/255, blue: 105/255, alpha: 1.0) // Ayeh Emerald
        webView.scrollView.refreshControl = refreshControl

        view.addSubview(webView)

        // Safe Area Constraints (respects Dynamic Island and Home Bar)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // KVO Progress Observer
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
    }

    private func setupProgressView() {
        progressView = UIProgressView(progressViewStyle: .default)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.progressTintColor = UIColor(red: 5/255, green: 150/255, blue: 105/255, alpha: 1.0)
        progressView.trackTintColor = .clear
        view.addSubview(progressView)

        NSLayoutConstraint.activate([
            progressView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2.5)
        ])
    }

    private func loadApplication() {
        let request = URLRequest(url: appURL)
        webView.load(request)
    }

    @objc private func handleRefresh() {
        webView.reload()
    }

    private func requestMicrophonePermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            // Microphone access granted for Persian voice input
        }
    }

    // Observer for progress bar
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(WKWebView.estimatedProgress) {
            progressView.progress = Float(webView.estimatedProgress)
            progressView.isHidden = webView.estimatedProgress >= 1.0
            if webView.estimatedProgress >= 1.0 {
                refreshControl.endRefreshing()
            }
        }
    }

    // WKNavigationDelegate: Did finish loading page -> Inject Extension Bridge
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let bridgeScript = """
        (function() {
            if (window._ayehBridgeActive) return;
            window._ayehBridgeActive = true;
            window.AYEH_EXTENSION_INSTALLED = true;
            window.__AYEH_EXTENSION_INSTALLED__ = true;
            document.documentElement.setAttribute('data-ayeh-extension', 'true');

            function announce() {
                window.postMessage({
                    source: 'AYEH_EXTENSION',
                    type: 'AYEH_EXTENSION_INSTALLED',
                    version: '2.5.0'
                }, '*');
            }
            announce();
            setInterval(announce, 2500);

            window.addEventListener('message', function(event) {
                if (!event.data || event.data.target !== 'AYEH_EXTENSION') return;
                var type = event.data.type;
                var reqId = event.data.requestId;
                if (type === 'CHECK_STATUS') {
                    window.postMessage({
                        source: 'AYEH_EXTENSION',
                        type: 'STATUS_RESPONSE',
                        payload: { ready: true, loggedIn: true },
                        requestId: reqId
                    }, '*');
                } else if (type === 'OPEN_LOGIN') {
                    window.location.href = 'https://chat.deepseek.com';
                }
            });
        })();
        """
        webView.evaluateJavaScript(bridgeScript, completionHandler: nil)
    }

    // WKNavigationDelegate: External link routing
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }

        let host = url.host ?? ""
        if host.contains("ayehnet.ir") || host.contains("deepseek.com") {
            decisionHandler(.allow)
            return
        }

        // Open external links in default Mobile Safari
        if navigationAction.navigationType == .linkActivated {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
            return
        }

        decisionHandler(.allow)
    }

    // WKScriptMessageHandler for window.webkit.messageHandlers.AyehMobileBridge
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "AyehMobileBridge" {
            // Handle mobile native bridge events
        }
    }

    deinit {
        webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
    }
}
