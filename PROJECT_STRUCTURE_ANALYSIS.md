# ezReader iOS 프로젝트 구조 분석

이 문서는 현재 저장소 상태를 기준으로 ezReader iOS 프로젝트의 구조, 실행 흐름, 리소스 배치 방식, 유지보수 포인트를 정리한 분석 문서입니다.

## 1. 프로젝트 성격 요약

이 프로젝트는 순수 네이티브 iOS 앱이라기보다, 다음 두 계층이 결합된 하이브리드 앱에 가깝습니다.

1. SwiftUI로 작성된 iOS 셸 애플리케이션
2. WKWebView 안에서 실행되는 정적 웹 애플리케이션 번들

즉, 사용자가 실제로 보는 주요 화면은 웹앱이며, iOS 쪽 코드는 다음 역할을 담당합니다.

1. 앱 시작 및 화면 컨테이너 제공
2. 원격 웹앱 또는 로컬 번들 웹앱 로딩
3. Google Sign-In 처리
4. 웹과 네이티브 간 메시지 브리지 제공

---

## 2. 최상위 디렉터리 구조

```text
ezReader_IOS/
├── ANGULAR_AUTO_DEPLOY.md
├── ANGULAR_BUILD_GUIDE.md
├── IOS_WEB_INTEGRATION_GUIDE.md
├── PROJECT_STRUCTURE_ANALYSIS.md
├── WEBVIEW_LOADING_STRATEGY.md
├── ezReader_IOS/
│   ├── ContentView.swift
│   ├── ezReaderApp.swift
│   ├── Info.plist
│   ├── WebViewManager.swift
│   ├── Assets.xcassets/
│   ├── Preview Content/
│   └── webapp/
└── ezReader_IOS.xcodeproj/
```

이 구조는 크게 세 층으로 나뉩니다.

### A. 루트 문서 계층

루트에 있는 여러 Markdown 문서는 구현 코드가 아니라 운영/통합 가이드 역할을 합니다.

1. `IOS_WEB_INTEGRATION_GUIDE.md`
   iOS와 웹 간 메시지 포맷 및 브리지 사용 예시를 설명합니다.
2. `WEBVIEW_LOADING_STRATEGY.md`
   원격 로딩과 로컬 번들 로딩 전략을 설계 관점에서 정리합니다.
3. `ANGULAR_BUILD_GUIDE.md`
   Angular 산출물을 iOS 로컬 번들 형태로 만드는 방법을 설명합니다.
4. `ANGULAR_AUTO_DEPLOY.md`
   Angular 빌드 결과를 iOS 프로젝트의 `webapp/`으로 복사하는 자동화 방법을 설명합니다.

즉, 루트 문서들은 현재 저장소의 “실행 코드”가 아니라 “외부 Angular 프로젝트와의 연결 규약 및 운영 방법”을 기록하는 역할입니다.

### B. 앱 소스 계층

`ezReader_IOS/` 폴더는 실제 앱 타깃의 소스 및 리소스가 위치하는 영역입니다.

핵심 파일은 다음과 같습니다.

1. `ezReaderApp.swift`
   앱 엔트리 포인트
2. `ContentView.swift`
   사실상 메인 UI + WebView + 브리지 로직이 모두 들어 있는 핵심 파일
3. `Info.plist`
   앱 설정, Google Sign-In URL 스킴, 배포 메타데이터
4. `webapp/`
   앱 번들에 포함되는 정적 웹 리소스

### C. Xcode 프로젝트 계층

`ezReader_IOS.xcodeproj/`는 빌드 대상, 리소스 포함 방식, Swift Package 의존성 등을 정의합니다.

특히 이 프로젝트에서는 다음 두 가지가 중요합니다.

1. `GoogleSignIn-iOS` Swift Package 사용
2. `webapp` 폴더를 앱 리소스로 포함

---

## 3. 실행 아키텍처

현재 구조를 실행 관점에서 보면 다음과 같습니다.

```text
ezReaderApp
  -> ContentView
    -> 모드 선택 화면
      -> WebViewScreen
        -> IOSWebView (UIViewRepresentable)
          -> WKWebView
            -> 원격 URL 또는 로컬 webapp/index.html 로드
              -> JavaScript <-> iOS 브리지 통신
                -> Google Sign-In / 상태 확인 / 로그아웃 / 테스트
```

핵심 포인트는 “SwiftUI 앱이 직접 많은 비즈니스 UI를 가지지 않고, 웹뷰 컨테이너를 제공한다”는 점입니다.

---

## 4. 주요 파일 상세 분석

### 4.1 ezReaderApp.swift

역할은 매우 단순합니다.

1. 앱 시작 시 로그 출력
2. 루트 화면으로 `ContentView` 연결
3. Google Sign-In 콜백 URL 처리

즉, 이 파일은 애플리케이션 진입점만 담당하며, 실제 앱 동작 로직은 거의 전부 `ContentView.swift`로 위임됩니다.

### 4.2 ContentView.swift

현재 프로젝트에서 가장 중요한 파일입니다. 이 파일 하나에 여러 책임이 집중되어 있습니다.

포함된 책임은 다음과 같습니다.

1. 로딩 모드 정의
   - 원격 웹앱
   - 로컬 번들 웹앱
2. `WebViewManager` 상태 객체 정의
3. 앱 초기 화면 및 모드 선택 UI
4. 오류 화면 UI
5. `UIViewRepresentable` 기반 `WKWebView` 래퍼
6. `WKNavigationDelegate` 처리
7. `WKScriptMessageHandler` 처리
8. Google Sign-In 요청 및 결과 전달
9. 웹으로 메시지 전송

즉, 현재 구조는 기능 분리형 아키텍처가 아니라 “단일 대형 화면 파일” 중심 구조입니다.

#### 내부 구성 요소

`ContentView.swift` 안에는 다음 요소가 함께 존재합니다.

1. `WebViewLoadingMode`
   - `remote`
   - `localBundle`

2. `WebViewManager`
   - `WKWebView` 참조 보관
   - 웹 쪽 `window.onIOSMessage(...)` 호출

3. `ContentView`
   - 모드 선택 여부 판단
   - `@AppStorage`를 이용해 이전 선택값 보존

4. `ModeSelectionView`
   - 사용자가 개발 버전과 iOS 배포 버전 중 선택

5. `WebViewScreen`
   - 실제 웹뷰 표시
   - 로컬 번들 누락 시 오류 화면 표시

6. `IOSWebView`
   - `WKWebViewConfiguration` 설정
   - JS 메시지 핸들러 등록
   - 로컬 리소스 접근 허용 설정
   - 원격/로컬 모드에 따라 웹 로딩 분기

7. `Coordinator`
   - 로딩 완료/실패 로그 처리
   - 웹에서 보낸 명령 문자열 해석
   - Google 인증 흐름 실행

#### 구조적 특징

장점:

1. 작은 프로젝트에서는 흐름 추적이 쉽습니다.
2. 웹뷰 관련 로직이 한 파일에 있어 빠르게 수정 가능합니다.
3. 프로토타입/실험 단계에서는 생산성이 높습니다.

단점:

1. UI, 상태, 브리지, 인증, 로딩 전략이 한 파일에 혼재합니다.
2. 테스트하기 어렵습니다.
3. 향후 기능이 늘어나면 충돌 범위가 커집니다.
4. iOS 앱 코드와 웹앱 연동 코드의 경계가 흐려집니다.

### 4.3 WebViewManager.swift

이 파일에는 `WebViewManager` 클래스가 별도로 존재합니다. 그러나 현재 Xcode 프로젝트 설정상 앱 타깃의 소스 빌드 단계에는 포함되어 있지 않습니다.

즉, 현재 상태를 기준으로 보면 다음과 같이 해석할 수 있습니다.

1. 예전 분리 설계의 잔재일 가능성
2. `ContentView.swift` 내부 정의로 이동한 뒤 정리되지 않은 파일일 가능성
3. 문서상 구조와 실제 코드 구조 사이의 차이를 보여주는 사례

따라서 이 파일은 현재 실질적인 실행 경로의 일부라기보다, 정리되지 않은 보조 파일에 가깝습니다.

### 4.4 Info.plist

이 파일은 앱 런타임 정책과 외부 인증 연동 정보를 담습니다.

주요 항목은 다음과 같습니다.

1. 앱 이름: `ezReader`
2. Google Sign-In URL Scheme 등록
3. `GIDClientID` 설정
4. ATS 설정 존재
   - `NSAllowsArbitraryLoads = false`
5. 지원 회전 방향 정의
6. iPhone/iPad 씬 설정

이 설정을 보면 프로젝트는 일반 웹뷰 셸을 넘어, 외부 인증까지 네이티브에서 담당하는 구조입니다.

---

## 5. webapp 폴더 분석

`ezReader_IOS/webapp/`은 이 프로젝트의 핵심 리소스 폴더입니다.

이 폴더는 iOS 코드로 작성된 화면이 아니라, 실제 사용자 기능을 제공하는 웹 애플리케이션 정적 산출물이 들어 있는 위치입니다.

현재 확인된 규모는 다음과 같습니다.

1. 파일 수: 약 480개
2. 디렉터리 수: 약 127개

즉, `webapp/`은 단순 샘플 HTML이 아니라, 꽤 큰 규모의 실제 배포 번들입니다.

### 상위 레벨 구성

주요 항목은 다음과 같습니다.

1. `index.html`
   웹앱 진입 HTML
2. `main.js`
   메인 실행 번들
3. `polyfills.js`
   브라우저 호환성 스크립트
4. `styles.css`
   전역 스타일
5. 다수의 `chunk-*.js`
   코드 스플리팅된 번들 조각
6. `assets/`
   PDF viewer, locale, 이미지, JSON 등 부가 리소스
7. `data/`
   앱 내부 데이터 리소스
8. `fonts/`, `images/`
   정적 시각 자산
9. `android-oauth-test.html`
   테스트 또는 호환성 검증용 보조 HTML로 보임

### webapp의 의미

이 폴더가 존재한다는 것은, iOS 프로젝트가 웹 소스 자체를 포함하는 저장소가 아니라 “빌드된 웹 결과물”을 포함하는 저장소라는 뜻입니다.

즉, 현재 저장소는 다음 역할 분담을 가집니다.

1. 웹앱 소스 코드는 외부 Angular 프로젝트에 있음
2. 이 저장소에는 그 결과물만 정적 리소스로 포함됨
3. iOS 앱은 그 결과물을 로컬에서 직접 구동함

이 방식은 오프라인 실행, 심사 안정성, 배포 일관성 측면에서 장점이 있지만, 저장소 용량 증가와 산출물 갱신 관리 부담이 생깁니다.

---

## 6. 원격 로딩과 로컬 번들 로딩 구조

현재 앱은 두 가지 실행 모드를 제공합니다.

### 6.1 원격 로딩 모드

특징:

1. GitHub Pages URL을 직접 불러옴
2. 최신 웹 버전을 빠르게 확인 가능
3. 앱 재빌드 없이 웹 변경 반영 가능

현재 원격 주소는 다음 의미를 가집니다.

1. 개발/운영 중간 성격의 웹 배포본 접근점
2. SwiftUI 앱은 단순 브라우저 셸처럼 동작

### 6.2 로컬 번들 모드

특징:

1. 앱 번들 내부 `webapp/index.html` 로드
2. 오프라인 사용 가능
3. 앱 심사 시 고정된 번들 제공 가능

현재 구현은 `loadFileURL`이 아니라 다음 방식으로 로컬 번들을 로드합니다.

1. `index.html` 내용을 문자열로 읽음
2. `baseURL`을 `webapp/` 폴더로 지정
3. `loadHTMLString(_:baseURL:)`로 로드

이 방식은 상대 경로 리소스 해석을 맞추기 위한 의도가 분명합니다.

---

## 7. 네이티브-웹 브리지 구조

이 프로젝트의 핵심 통합 포인트는 JavaScript와 iOS 사이의 메시지 브리지입니다.

### 웹 -> iOS

웹은 `window.webkit.messageHandlers.iosHandler.postMessage(...)`를 통해 문자열 명령을 보냅니다.

현재 지원 명령:

1. `requestGeminiAuth`
2. `isGeminiAuthAvailable`
3. `signOut`
4. `test`

### iOS -> 웹

iOS는 `evaluateJavaScript`를 사용해 웹의 전역 콜백 `window.onIOSMessage(type, data)`를 호출합니다.

즉, 통신 구조는 이벤트 버스라기보다 “문자열 명령 + 전역 콜백” 패턴입니다.

### 브리지의 역할

브리지는 특히 Google 인증을 웹이 직접 처리하지 않고 iOS 네이티브가 처리하도록 분리합니다.

흐름은 다음과 같습니다.

1. 웹이 인증 요청 메시지 전송
2. iOS가 GoogleSignIn SDK로 로그인 수행
3. access token 및 이메일을 웹으로 전달

즉, 웹앱은 인증 UI/브라우저 연동을 직접 하지 않고, iOS 컨테이너를 신뢰하는 구조입니다.

---

## 8. Xcode 프로젝트 설정 분석

`project.pbxproj` 기준으로 확인되는 중요한 구조는 다음과 같습니다.

### 8.1 타깃 소스 파일

현재 소스 빌드 단계에 포함된 Swift 파일은 사실상 두 개입니다.

1. `ContentView.swift`
2. `ezReaderApp.swift`

즉, 실제 앱 코드는 매우 적고, 대부분의 동작이 `ContentView.swift`에 집중되어 있습니다.

### 8.2 리소스 포함 방식

`webapp` 폴더가 Resources Build Phase에 포함되어 있습니다.

이 의미는 다음과 같습니다.

1. 앱 빌드 시 `webapp/` 디렉터리가 번들 안으로 복사됨
2. 런타임에 `Bundle.main`으로 접근 가능
3. 로컬 오프라인 웹앱 실행이 가능해짐

또한 `PBXFileReference`에서 `webapp`이 폴더 단위 참조로 등록되어 있어, 문서에서 안내한 “folder reference” 방식과 일치합니다.

### 8.3 외부 의존성

Swift Package Manager를 통해 다음 패키지가 연결되어 있습니다.

1. `GoogleSignIn`
2. `GoogleSignInSwift`

즉, 인증 관련 기능은 CocoaPods가 아니라 Xcode의 패키지 의존성으로 관리됩니다.

---

## 9. 문서와 실제 구현의 차이

현재 저장소는 문서가 풍부하지만, 일부는 설계안 또는 이전 구조를 반영하고 있고, 실제 구현은 그보다 단순화되어 있습니다.

대표적인 차이는 다음과 같습니다.

1. 설계 문서에는 `WebViewConfig.swift`, `Config/`, `Resources/` 같은 분리 구조가 제안되어 있음
2. 실제 구현은 대부분 `ContentView.swift`에 집중되어 있음
3. 문서상 `WebViewManager.swift` 분리 구조가 보이지만, 실제 실행 경로는 인라인 정의에 가까움
4. 문서에는 Angular 설정/배포 절차가 자세하지만, Angular 소스 저장소 자체는 현재 워크스페이스에 없음

따라서 이 저장소를 읽을 때는 “문서가 설명하는 이상적인 구조”와 “현재 실제 코드 구조”를 구분해서 이해해야 합니다.

---

## 10. 유지보수 관점에서의 해석

현재 구조는 다음 상황에 적합합니다.

1. iOS 컨테이너 앱을 빠르게 운영해야 하는 경우
2. 핵심 기능 대부분이 웹에 있는 경우
3. 네이티브는 인증, 브리지, 배포 패키징만 담당하는 경우

반대로 다음 측면에서는 구조 개선 여지가 큽니다.

### 개선 필요 포인트

1. `ContentView.swift` 책임 과다
   - 모드 선택 UI
   - 웹뷰 구성
   - 브리지 처리
   - 인증 처리
   를 분리할 수 있음

2. 미사용 파일 정리 필요
   - `WebViewManager.swift`는 현재 기준으로 중복 또는 잔존 파일 가능성이 높음

3. 문서와 코드의 정합성 관리 필요
   - 현재 문서는 설계/운영 가이드로는 유용하지만, 실제 구현과 1:1 대응되지는 않음

4. webapp 산출물 관리 정책 필요
   - 어느 시점에 어떤 Angular 빌드 결과를 반영했는지 추적 체계가 필요함

---

## 11. 이 프로젝트를 한 문장으로 정의하면

이 저장소는 “Google 인증과 WebView 브리지를 제공하는 SwiftUI 기반 iOS 셸 앱 위에, Angular 빌드 결과물을 원격 또는 로컬 번들로 구동하는 하이브리드 앱 프로젝트”입니다.

---

## 12. 빠른 참조

구조를 처음 파악할 때는 다음 순서로 보면 이해가 가장 빠릅니다.

1. `ezReader_IOS/ezReaderApp.swift`
   앱 시작점 확인
2. `ezReader_IOS/ContentView.swift`
   실제 동작 대부분 확인
3. `ezReader_IOS/Info.plist`
   인증/앱 설정 확인
4. `ezReader_IOS/webapp/index.html`
   로컬 웹앱 진입점 확인
5. `ezReader_IOS.xcodeproj/project.pbxproj`
   리소스 포함 및 패키지 의존성 확인
6. 루트 Markdown 문서들
   설계 의도와 운영 절차 확인

이 순서대로 보면 “실제 동작”, “배포 리소스”, “운영 가이드”를 각각 분리해서 이해할 수 있습니다.