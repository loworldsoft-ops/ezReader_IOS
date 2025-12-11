# iOS WebView 로딩 전략 설계 문서

## 📋 개요

iOS 앱에서 Angular 웹앱을 로드하는 두 가지 방식을 지원하는 설계안입니다:
1. **원격 URL 로딩** - GitHub Pages 등 외부 서버에서 로드
2. **로컬 번들 로딩** - 앱에 포함된 빌드 파일에서 로드

---

## 🎯 두 방식의 비교

| 구분 | 원격 URL | 로컬 번들 |
|------|----------|-----------|
| **초기 로딩** | 네트워크 속도에 의존 | 즉시 로드 (매우 빠름) |
| **오프라인** | ❌ 불가능 | ✅ 가능 |
| **업데이트** | 서버 배포만으로 즉시 반영 | 앱 업데이트 필요 |
| **앱 용량** | 최소 | 웹앱 크기만큼 증가 |
| **심사** | 웹 콘텐츠 변경 자유로움 | 콘텐츠 변경 시 재심사 |

---

## 🏗️ 아키텍처 설계

### 1. 프로젝트 구조

```
ezReader_IOS/
├── ezReader_IOS/
│   ├── ContentView.swift
│   ├── WebViewManager.swift
│   ├── Config/
│   │   └── WebViewConfig.swift      # 웹뷰 설정 관리
│   └── Resources/
│       └── webapp/                   # Angular 빌드 결과물 (로컬 모드용)
│           ├── index.html
│           ├── main.js
│           ├── polyfills.js
│           ├── styles.css
│           └── assets/
│               └── ...
```

### 2. 로딩 모드 Enum

```swift
// WebViewConfig.swift
import Foundation

enum WebViewLoadingMode {
    case remote(url: URL)
    case local(folderName: String)
    
    static var current: WebViewLoadingMode {
        #if DEBUG
        // 개발 모드: 원격 또는 로컬 선택
        return .remote(url: URL(string: "http://localhost:4200")!)
        #else
        // 프로덕션: 로컬 번들 사용 (오프라인 지원)
        return .local(folderName: "webapp")
        // 또는 원격 사용 시:
        // return .remote(url: URL(string: "https://loworldsoft-ops.github.io/ezReader_Mobile_Page")!)
        #endif
    }
}
```

---

## 📱 iOS 구현 코드

### WebViewConfig.swift (새 파일)

```swift
import Foundation
import WebKit

// MARK: - 로딩 모드 정의
enum WebViewLoadingMode {
    case remote(url: URL)
    case local(folderName: String)
}

// MARK: - 웹뷰 설정
struct WebViewConfig {
    
    // 현재 사용할 로딩 모드 설정
    static var loadingMode: WebViewLoadingMode {
        // 환경에 따라 선택
        #if DEBUG
        // 개발: 로컬 서버 사용
        return .remote(url: URL(string: "http://localhost:4200")!)
        #else
        // 프로덕션: 번들된 파일 사용
        return .local(folderName: "webapp")
        #endif
    }
    
    // 강제로 특정 모드 사용 시
    static let forceMode: WebViewLoadingMode? = nil
    // 예: .remote(url: URL(string: "https://...")!)
    // 예: .local(folderName: "webapp")
    
    static var activeMode: WebViewLoadingMode {
        return forceMode ?? loadingMode
    }
}

// MARK: - WKWebView 로딩 Extension
extension WKWebView {
    
    func loadWebApp(mode: WebViewLoadingMode) {
        switch mode {
        case .remote(let url):
            loadRemoteURL(url)
            
        case .local(let folderName):
            loadLocalBundle(folderName: folderName)
        }
    }
    
    // MARK: - 원격 URL 로딩
    private func loadRemoteURL(_ url: URL) {
        print("🌐 원격 URL 로딩: \(url.absoluteString)")
        load(URLRequest(url: url))
    }
    
    // MARK: - 로컬 번들 로딩
    private func loadLocalBundle(folderName: String) {
        guard let resourceURL = Bundle.main.url(forResource: "index", 
                                                 withExtension: "html", 
                                                 subdirectory: folderName) else {
            print("❌ 로컬 웹앱을 찾을 수 없습니다: \(folderName)/index.html")
            return
        }
        
        // 상위 폴더 URL (에셋 접근을 위해 필요)
        let folderURL = resourceURL.deletingLastPathComponent()
        
        print("📦 로컬 번들 로딩: \(resourceURL.path)")
        
        // allowingReadAccessTo: 해당 폴더의 모든 리소스에 접근 허용
        loadFileURL(resourceURL, allowingReadAccessTo: folderURL)
    }
}
```

### ContentView.swift 수정

```swift
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
        
        // 로컬 파일 접근 설정 (로컬 모드에서 필요)
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        
        config.userContentController = contentController
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        
        manager.webView = webView
        
        // ⭐ 설정에 따라 로딩 모드 선택
        webView.loadWebApp(mode: WebViewConfig.activeMode)
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(manager: manager)
    }
    
    // ... Coordinator 코드는 동일
}
```

---

## 🅰️ Angular 빌드 설정

### 1. 로컬 번들용 빌드 설정

Angular 앱을 iOS 번들에 포함시키려면 **base href**를 올바르게 설정해야 합니다.

#### angular.json 수정

```json
{
  "projects": {
    "ezReader": {
      "architect": {
        "build": {
          "configurations": {
            "production": {
              "baseHref": "/",
              "outputPath": "dist/ezReader"
            },
            "ios-bundle": {
              "baseHref": "./",
              "deployUrl": "./",
              "outputPath": "dist/ios-bundle",
              "optimization": true,
              "aot": true,
              "sourceMap": false
            }
          }
        }
      }
    }
  }
}
```

### 2. 빌드 스크립트

#### package.json

```json
{
  "scripts": {
    "build": "ng build",
    "build:ios": "ng build --configuration=ios-bundle",
    "build:ghpages": "ng build --configuration=production --base-href=/ezReader_Mobile_Page/"
  }
}
```

### 3. 빌드 명령어

```bash
# iOS 로컬 번들용 빌드
npm run build:ios

# 빌드 결과물 위치: dist/ios-bundle/
```

---

## 📂 iOS 프로젝트에 웹앱 추가하기

### 방법 1: Xcode에서 직접 추가

1. Finder에서 `dist/ios-bundle` 폴더를 `webapp`으로 이름 변경
2. Xcode에서 프로젝트 네비게이터 열기
3. `ezReader_IOS` 폴더에 드래그 앤 드롭
4. **중요 설정**:
   - ☑️ Copy items if needed
   - ☑️ Create folder references (폴더 참조 생성)
   - Target: ezReader_IOS 체크

### 방법 2: 빌드 스크립트 자동화

Xcode Build Phase에 스크립트 추가:

```bash
# Build Phases > New Run Script Phase

WEBAPP_SOURCE="${PROJECT_DIR}/../ezReader_Web/dist/ios-bundle"
WEBAPP_DEST="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/webapp"

if [ -d "$WEBAPP_SOURCE" ]; then
    rm -rf "$WEBAPP_DEST"
    cp -R "$WEBAPP_SOURCE" "$WEBAPP_DEST"
    echo "✅ 웹앱 복사 완료"
else
    echo "⚠️ 웹앱 소스를 찾을 수 없습니다: $WEBAPP_SOURCE"
fi
```

---

## ⚠️ 주의사항 및 해결책

### 1. Angular 라우팅 문제

로컬 파일 로딩 시 Angular Router가 정상 작동하지 않을 수 있습니다.

**해결책**: Hash 라우팅 사용

```typescript
// app.module.ts 또는 app.config.ts
import { HashLocationStrategy, LocationStrategy } from '@angular/common';

// Module 방식
@NgModule({
  providers: [
    { provide: LocationStrategy, useClass: HashLocationStrategy }
  ]
})

// Standalone 방식
export const appConfig: ApplicationConfig = {
  providers: [
    provideRouter(routes, withHashLocation())
  ]
};
```

### 2. 상대 경로 에셋 문제

**index.html에서 상대 경로 확인**:

```html
<!-- ❌ 절대 경로 (로컬에서 작동 안 함) -->
<script src="/main.js"></script>

<!-- ✅ 상대 경로 (로컬에서 작동) -->
<script src="./main.js"></script>
<script src="main.js"></script>
```

### 3. API 호출 시 CORS

로컬 파일에서는 origin이 `null`이 되어 CORS 문제 발생 가능.

**해결책**: iOS 네이티브 브릿지로 API 호출

```typescript
// Angular 서비스
async callAPI(endpoint: string, data: any) {
  if (this.isIOSWebView()) {
    // iOS 네이티브를 통해 API 호출
    return this.callViaIOSBridge(endpoint, data);
  } else {
    // 일반 HTTP 호출
    return this.http.post(endpoint, data);
  }
}
```

### 4. 로컬 스토리지 / IndexedDB

로컬 파일 로딩 시에도 정상 작동하지만, 앱 삭제 시 데이터 손실.

---

## 🔄 모드 전환 쉽게 하기

### 환경별 자동 전환

```swift
// WebViewConfig.swift
struct WebViewConfig {
    
    static var activeMode: WebViewLoadingMode {
        // 1. 강제 설정이 있으면 사용
        if let forced = forceMode {
            return forced
        }
        
        // 2. 시뮬레이터에서는 원격 사용 (개발 편의)
        #if targetEnvironment(simulator)
        return .remote(url: URL(string: "http://localhost:4200")!)
        #endif
        
        // 3. 디버그 빌드
        #if DEBUG
        return .remote(url: URL(string: "http://192.168.0.41:4101")!)
        #else
        // 4. 릴리즈 빌드: 로컬 번들
        return .local(folderName: "webapp")
        #endif
    }
}
```

### Scheme으로 전환

Xcode에서 여러 Scheme 생성:
- `ezReader-Local`: 로컬 번들 사용
- `ezReader-Remote`: 원격 URL 사용
- `ezReader-Dev`: 로컬 개발 서버 사용

---

## 📝 체크리스트

### Angular 빌드 시

- [ ] `baseHref`가 `./`로 설정되어 있는지 확인
- [ ] `deployUrl`이 `./`로 설정되어 있는지 확인
- [ ] AOT 빌드가 정상적으로 완료되는지 확인
- [ ] 빌드 결과물의 index.html에서 스크립트 경로가 상대경로인지 확인

### iOS 프로젝트 설정 시

- [ ] webapp 폴더가 "Create folder references"로 추가되었는지 확인
- [ ] 빌드 후 앱 번들에 webapp 폴더가 포함되어 있는지 확인
- [ ] Info.plist에 필요한 권한이 설정되어 있는지 확인

### 테스트

- [ ] 원격 URL 모드에서 정상 로딩되는지 확인
- [ ] 로컬 번들 모드에서 정상 로딩되는지 확인
- [ ] JavaScript 브릿지가 양쪽 모드에서 작동하는지 확인
- [ ] 에셋(이미지, 폰트 등)이 정상 로딩되는지 확인
- [ ] Angular 라우팅이 정상 작동하는지 확인

---

## 🚀 권장 전략

### 개발 단계
```
원격 URL (localhost:4200) → 빠른 개발 사이클
```

### 테스트 단계
```
로컬 번들 → 실제 배포 환경과 동일하게 테스트
```

### 프로덕션 배포
```
로컬 번들 (기본) + 원격 URL (폴백)
→ 오프라인 지원 + 긴급 업데이트 가능
```

---

## 📚 참고 자료

- [WKWebView loadFileURL 문서](https://developer.apple.com/documentation/webkit/wkwebview/1414973-loadfileurl)
- [Angular Deployment Guide](https://angular.io/guide/deployment)
- [iOS App Bundle Structure](https://developer.apple.com/library/archive/documentation/CoreFoundation/Conceptual/CFBundles/BundleTypes/BundleTypes.html)
