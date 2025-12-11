import SwiftUI
import WebKit
import GoogleSignIn

// MARK: - 로딩 모드 정의
enum WebViewLoadingMode: Identifiable, CaseIterable {
    case remote
    case localBundle
    
    var id: String { title }
    
    var title: String {
        switch self {
        case .remote: return "개발 버전"
        case .localBundle: return "iOS 배포 버전"
        }
    }
    
    var subtitle: String {
        switch self {
        case .remote: return "최신 개발 버전"
        case .localBundle: return "오프라인 사용 가능"
        }
    }
    
    var icon: String {
        switch self {
        case .remote: return "globe"
        case .localBundle: return "internaldrive"
        }
    }
    
    var url: URL? {
        switch self {
        case .remote:
            return URL(string: "https://loworldsoft-ops.github.io/ezReader_Mobile_Page")
        case .localBundle:
            return nil // 로컬 번들은 별도 처리
        }
    }
}

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

// MARK: - ContentView (모드 선택 화면)
struct ContentView: View {
    @StateObject private var webViewManager = WebViewManager()
    @State private var selectedMode: WebViewLoadingMode?
    @AppStorage("skipModeSelection") private var skipModeSelection = false
    @AppStorage("lastSelectedMode") private var lastSelectedModeRaw = "remote"
    
    var body: some View {
        Group {
            if let mode = selectedMode {
                // 웹뷰 화면
                WebViewScreen(manager: webViewManager, mode: mode) {
                    // 뒤로가기 시 선택 화면으로
                    selectedMode = nil
                }
                .onAppear {
                    NSLog("🚀 [ezReader] 웹뷰 화면 로드 - 모드: \(mode.title)")
                }
            } else if skipModeSelection {
                // 자동 시작 모드
                WebViewScreen(manager: webViewManager, mode: lastMode) {
                    skipModeSelection = false
                    selectedMode = nil
                }
            } else {
                // 모드 선택 화면
                ModeSelectionView(
                    selectedMode: $selectedMode,
                    skipModeSelection: $skipModeSelection,
                    lastSelectedModeRaw: $lastSelectedModeRaw
                )
            }
        }
        .onOpenURL { url in
            GIDSignIn.sharedInstance.handle(url)
        }
    }
    
    private var lastMode: WebViewLoadingMode {
        switch lastSelectedModeRaw {
        case "localBundle": return .localBundle
        default: return .remote
        }
    }
}

// MARK: - 모드 선택 화면
struct ModeSelectionView: View {
    @Binding var selectedMode: WebViewLoadingMode?
    @Binding var skipModeSelection: Bool
    @Binding var lastSelectedModeRaw: String
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 헤더
                VStack(spacing: 8) {
                    Image(systemName: "book.pages")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("ezReader")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("개발테스트")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                .padding(.bottom, 20)
                
                // 모드 선택 버튼들
                VStack(spacing: 12) {
                    ForEach(WebViewLoadingMode.allCases) { mode in
                        ModeButton(mode: mode) {
                            selectMode(mode)
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationBarHidden(true)
        }
    }
    
    private func selectMode(_ mode: WebViewLoadingMode) {
        // 선택한 모드 저장
        switch mode {
        case .remote: lastSelectedModeRaw = "remote"
        case .localBundle: lastSelectedModeRaw = "localBundle"
        }
        
        selectedMode = mode
    }
}

// MARK: - 모드 버튼
struct ModeButton: View {
    let mode: WebViewLoadingMode
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                Image(systemName: mode.icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(buttonColor)
                    .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(mode.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
    }
    
    private var buttonColor: Color {
        switch mode {
        case .remote: return .blue
        case .localBundle: return .green
        }
    }
}

// MARK: - 웹뷰 화면
struct WebViewScreen: View {
    @ObservedObject var manager: WebViewManager
    let mode: WebViewLoadingMode
    let onBack: () -> Void
    
    @State private var showingBackAlert = false
    @State private var errorMessage: String?
    
    init(manager: WebViewManager, mode: WebViewLoadingMode, onBack: @escaping () -> Void) {
        self.manager = manager
        self.mode = mode
        self.onBack = onBack
        
        // 로컬 번들 모드일 때 미리 체크
        if mode == .localBundle {
            if Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "webapp") == nil {
                let bundlePath = Bundle.main.bundlePath
                let errorMsg = """
                ❌ 로컬 웹앱 파일을 찾을 수 없습니다.
                
                경로: webapp/index.html
                Bundle: \(bundlePath)
                
                해결 방법:
                1. Angular 프로젝트를 빌드했는지 확인
                2. webapp 폴더가 Xcode 프로젝트에 추가되었는지 확인
                3. webapp 폴더를 "Create folder references" (파란색 폴더)로 추가했는지 확인
                """
                self._errorMessage = State(initialValue: errorMsg)
            }
        }
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            if let error = errorMessage {
                ErrorView(message: error, mode: mode, onBack: onBack)
            } else {
                IOSWebView(manager: manager, loadingMode: mode)
                .ignoresSafeArea()
            }
            
            // 뒤로가기 버튼 (디버그용)
            #if DEBUG
            Button(action: { showingBackAlert = true }) {
                Image(systemName: "arrow.left.circle.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .shadow(radius: 3)
            }
            .padding(.top, 50)
            .padding(.leading, 10)
            .alert("모드 선택으로 돌아가기", isPresented: $showingBackAlert) {
                Button("취소", role: .cancel) {}
                Button("돌아가기", role: .destructive) { onBack() }
            } message: {
                Text("현재 모드: \(mode.title)")
            }
            #endif
        }
    }
}

// MARK: - 오류 화면
struct ErrorView: View {
    let message: String
    let mode: WebViewLoadingMode
    let onBack: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("로딩 실패")
                .font(.title)
                .fontWeight(.bold)
            
            ScrollView {
                Text(message)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }
            .padding()
            
            Button(action: onBack) {
                Label("모드 선택으로 돌아가기", systemImage: "arrow.left")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

struct IOSWebView: UIViewRepresentable {
    @ObservedObject var manager: WebViewManager
    let loadingMode: WebViewLoadingMode
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        
        // JavaScript 메시지 핸들러 등록
        contentController.add(context.coordinator, name: "iosHandler")
        
        // 🔐 로컬 파일 접근 설정 (로컬 번들 모드에서 필수)
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        config.preferences.javaScriptEnabled = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        
        // 🔓 로컬 리소스 접근 허용 (중요!)
        config.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
        
        config.userContentController = contentController
        config.allowsInlineMediaPlayback = true
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        
        // 🔍 Safari Web Inspector 활성화 & JavaScript 허용 (iOS 16.4+)
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
            webView.configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        }
        
        manager.webView = webView
        
        // 선택된 모드에 따라 로딩
        loadWebView(webView)
        
        return webView
    }
    
    private func loadWebView(_ webView: WKWebView) {
        switch loadingMode {
        case .remote:
            // 원격 URL 로딩
            if let url = loadingMode.url {
                print("🌐 원격 URL 로딩: \(url.absoluteString)")
                webView.load(URLRequest(url: url))
            }
            
        case .localBundle:
            // 로컬 번들 로딩
            loadLocalBundle(webView)
        }
    }
    
    private func loadLocalBundle(_ webView: WKWebView) {
        NSLog("📍 [ezReader] loadLocalBundle 함수 시작")
        
        // webapp 폴더 내의 index.html 찾기
        guard let resourceURL = Bundle.main.url(forResource: "index",
                                                 withExtension: "html",
                                                 subdirectory: "webapp") else {
            NSLog("❌ [ezReader] webapp/index.html을 찾을 수 없습니다")
            NSLog("📁 [ezReader] Bundle path: \(Bundle.main.bundlePath)")
            return
        }
        
        // HTML 내용 읽기
        guard let htmlString = try? String(contentsOf: resourceURL, encoding: .utf8) else {
            NSLog("❌ [ezReader] index.html 읽기 실패")
            return
        }
        
        // baseURL을 webapp 폴더로 설정 (상대 경로 리소스 로드를 위해)
        let baseURL = resourceURL.deletingLastPathComponent()
        
        NSLog("✅ [ezReader] 로컬 번들 로딩")
        NSLog("📁 [ezReader] HTML path: \(resourceURL.path)")
        NSLog("🔗 [ezReader] Base URL: \(baseURL.path)")
        
        // ⚡ baseURL을 명시적으로 설정해서 로드
        webView.loadHTMLString(htmlString, baseURL: baseURL)
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
