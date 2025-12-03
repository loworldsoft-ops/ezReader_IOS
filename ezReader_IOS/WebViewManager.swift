import Foundation
import WebKit

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
