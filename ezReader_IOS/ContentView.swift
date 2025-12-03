import SwiftUI
import WebKit
import GoogleSignIn

struct ContentView: View {
    @StateObject private var webViewManager = WebViewManager()
    
    var body: some View {
        IOSWebView(manager: webViewManager)
            .ignoresSafeArea()
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
    }
}

struct IOSWebView: UIViewRepresentable {
    @ObservedObject var manager: WebViewManager
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        
        // JavaScript 메시지 핸들러 등록
        contentController.add(context.coordinator, name: "iosHandler")
        
        config.userContentController = contentController
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        
        manager.webView = webView
        
        let url = URL(string: "https://loworldsoft-ops.github.io/ezReader_Mobile_Page/")!
        webView.load(URLRequest(url: url))
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(manager: manager)
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let manager: WebViewManager
        
        init(manager: WebViewManager) {
            self.manager = manager
        }
        
        // MARK: - WKNavigationDelegate
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("✅ 웹페이지 로딩 완료")
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("❌ WebView 로딩 실패: \(error.localizedDescription)")
        }
        
        // MARK: - WKScriptMessageHandler (웹에서 메시지 수신)
        func userContentController(_ userContentController: WKUserContentController, 
                                   didReceive message: WKScriptMessage) {
            guard let command = message.body as? String else { return }
            
            print("📩 웹에서 수신: \(command)")
            
            switch command {
            case "requestGeminiAuth":
                requestGoogleSignIn()
            case "isGeminiAuthAvailable":
                checkAuthStatus()
            case "signOut":
                signOut()
            case "test":
                testBridge()
            default:
                print("⚠️ 알 수 없는 명령: \(command)")
            }
        }
        
        // MARK: - Google Sign In
        private func requestGoogleSignIn() {
            guard let rootViewController = getRootViewController() else {
                sendError("No root view controller")
                return
            }
            
            // Gemini API 스코프
            let scopes = [
                "https://www.googleapis.com/auth/cloud-platform",
                "https://www.googleapis.com/auth/generative-language.retriever"
            ]
            
            GIDSignIn.sharedInstance.signIn(
                withPresenting: rootViewController,
                hint: nil,
                additionalScopes: scopes
            ) { [weak self] result, error in
                if let error = error {
                    self?.sendError(error.localizedDescription)
                    return
                }
                
                guard let user = result?.user,
                      let token = user.accessToken.tokenString else {
                    self?.sendError("Failed to get access token")
                    return
                }
                
                print("✅ 토큰 획득: \(token)")
                
                self?.manager.sendToWeb(type: "authSuccess", data: [
                    "token": token,
                    "email": user.profile?.email ?? ""
                ])
            }
        }
        
        private func checkAuthStatus() {
            GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, error in
                let isAvailable = user != nil
                self?.manager.sendToWeb(type: "authStatus", data: [
                    "isAvailable": isAvailable
                ])
            }
        }
        
        private func signOut() {
            GIDSignIn.sharedInstance.signOut()
            manager.sendToWeb(type: "signOutComplete", data: [:])
        }
        
        private func testBridge() {
            manager.sendToWeb(type: "testResponse", data: [
                "message": "iOS Bridge is working!"
            ])
        }
        
        private func sendError(_ message: String) {
            manager.sendToWeb(type: "authError", data: [
                "error": message
            ])
        }
        
        private func getRootViewController() -> UIViewController? {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }?
                .rootViewController
        }
    }
}

#Preview {
    ContentView()
}
