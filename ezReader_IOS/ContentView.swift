import SwiftUI
import WebKit
import GoogleSignIn

// MARK: - WebViewManager
class WebViewManager: ObservableObject {
    @Published var webView: WKWebView?
    
    /// 웹페이지로 메시지 전송
    func sendToWeb(type: String, data: [String: Any]) {
        guard let webView = webView else {
            print("⚠️ WebView가 초기화되지 않았습니다")
            return
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: data)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            
            let script = """
            if (window.onIOSMessage) {
                window.onIOSMessage('\(type)', \(jsonString));
            } else {
                console.warn('onIOSMessage 콜백이 정의되지 않았습니다');
            }
            """
            
            webView.evaluateJavaScript(script) { result, error in
                if let error = error {
                    print("❌ JS 실행 오류: \(error.localizedDescription)")
                } else {
                    print("✅ 웹으로 메시지 전송 완료: \(type)")
                }
            }
        } catch {
            print("❌ JSON 직렬화 오류: \(error)")
        }
    }
}

// MARK: - ContentView
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
        
        // 개발 모드: 로컬 네트워크 서버 사용
        // let url = URL(string: "http://192.168.0.41:4101")!
        
        // 로컬호스트 테스트
        // let url = URL(string: "http://localhost:4200")!
        
        // 프로덕션 모드: GitHub Pages 사용
        let url = URL(string: "https://loworldsoft-ops.github.io/ezReader_Mobile_Page")!
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
                
                guard let user = result?.user else {
                    self?.sendError("Failed to get user")
                    return
                }
                
                let token = user.accessToken.tokenString
                
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
