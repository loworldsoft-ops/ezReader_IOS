# iOS WebView 통합 가이드 (Angular)

ezReader iOS 앱과 Angular 웹 애플리케이션 간의 통신 가이드입니다.

---

## 📱 iOS와 웹 통신 방식

### iOS → 웹 (메시지 수신)

```typescript
// 글로벌 콜백 함수 정의
declare global {
  interface Window {
    onIOSMessage: (type: string, data: any) => void;
  }
}

window.onIOSMessage = function(type: string, data: any) {
  console.log('iOS 메시지:', type, data);
};
```

### 웹 → iOS (명령 전송)

```typescript
// window.webkit을 TypeScript에서 사용하기 위한 타입 정의
declare global {
  interface Window {
    webkit?: {
      messageHandlers?: {
        iosHandler?: {
          postMessage: (message: string) => void;
        };
      };
    };
  }
}

// iOS로 메시지 전송
if (window.webkit?.messageHandlers?.iosHandler) {
  window.webkit.messageHandlers.iosHandler.postMessage('requestGeminiAuth');
}
```

---

## 🎯 사용 가능한 명령

### **1. Gemini 인증 요청**

```typescript
window.webkit?.messageHandlers?.iosHandler?.postMessage('requestGeminiAuth');

// 응답 수신
window.onIOSMessage = function(type: string, data: any) {
  if (type === 'authSuccess') {
    console.log('토큰:', data.token);
    console.log('이메일:', data.email);
  } else if (type === 'authError') {
    console.error('에러:', data.error);
  }
};
```

### **2. 로그인 상태 확인**

```typescript
window.webkit?.messageHandlers?.iosHandler?.postMessage('isGeminiAuthAvailable');

// 응답 수신
window.onIOSMessage = function(type: string, data: any) {
  if (type === 'authStatus') {
    console.log('로그인 여부:', data.isAvailable);
  }
};
```

### **3. 로그아웃**

```typescript
window.webkit?.messageHandlers?.iosHandler?.postMessage('signOut');

// 응답 수신
window.onIOSMessage = function(type: string, data: any) {
  if (type === 'signOutComplete') {
    console.log('로그아웃 완료');
  }
};
```

### **4. 연결 테스트**

```typescript
window.webkit?.messageHandlers?.iosHandler?.postMessage('test');

// 응답 수신
window.onIOSMessage = function(type: string, data: any) {
  if (type === 'testResponse') {
    console.log(data.message); // "iOS Bridge is working!"
  }
};
```

---

## 🔧 Angular 서비스 구현

### **1. Platform Detection Service**

```typescript
// platform-detection.service.ts
import { Injectable } from '@angular/core';

@Injectable({
  providedIn: 'root'
})
export class PlatformDetectionService {
  isIOS(): boolean {
    return /iPhone|iPad|iPod/.test(navigator.userAgent) && 
           !!(window as any).webkit?.messageHandlers?.iosHandler;
  }

  isAndroid(): boolean {
    return /Android/.test(navigator.userAgent);
  }

  isMobileApp(): boolean {
    return this.isIOS() || this.isAndroid();
  }
}
```

### **2. iOS Bridge Service**

```typescript
// ios-bridge.service.ts
import { Injectable } from '@angular/core';
import { Subject, Observable } from 'rxjs';
import { PlatformDetectionService } from './platform-detection.service';

export interface IOSMessage {
  type: string;
  data: any;
}

declare global {
  interface Window {
    webkit?: {
      messageHandlers?: {
        iosHandler?: {
          postMessage: (message: string) => void;
        };
      };
    };
    onIOSMessage?: (type: string, data: any) => void;
  }
}

@Injectable({
  providedIn: 'root'
})
export class IOSBridgeService {
  private messageSubject = new Subject<IOSMessage>();
  public message$: Observable<IOSMessage> = this.messageSubject.asObservable();

  constructor(private platform: PlatformDetectionService) {
    this.initializeMessageHandler();
  }

  private initializeMessageHandler(): void {
    // iOS에서 메시지 수신 핸들러 등록
    window.onIOSMessage = (type: string, data: any) => {
      console.log('📩 iOS 메시지 수신:', type, data);
      this.messageSubject.next({ type, data });
    };
  }

  /**
   * iOS로 메시지 전송
   */
  private sendToIOS(command: string): void {
    if (!this.platform.isIOS()) {
      console.warn('iOS 환경이 아닙니다');
      return;
    }

    if (window.webkit?.messageHandlers?.iosHandler) {
      window.webkit.messageHandlers.iosHandler.postMessage(command);
      console.log('📤 iOS로 메시지 전송:', command);
    } else {
      console.error('iOS Bridge를 사용할 수 없습니다');
    }
  }

  /**
   * Gemini 인증 요청
   */
  requestAuth(): void {
    this.sendToIOS('requestGeminiAuth');
  }

  /**
   * 로그인 상태 확인
   */
  checkLoginStatus(): void {
    this.sendToIOS('isGeminiAuthAvailable');
  }

  /**
   * 로그아웃
   */
  signOut(): void {
    this.sendToIOS('signOut');
  }

  /**
   * 연결 테스트
   */
  test(): void {
    this.sendToIOS('test');
  }
}
```

### **3. Native Bridge Service (통합)**

안드로이드와 iOS를 통합 관리:

```typescript
// native-bridge.service.ts
import { Injectable } from '@angular/core';
import { Observable, merge } from 'rxjs';
import { IOSBridgeService } from './ios-bridge.service';
import { AndroidBridgeService } from './android-bridge.service'; // 기존 안드로이드 서비스
import { PlatformDetectionService } from './platform-detection.service';

export interface NativeMessage {
  type: string;
  data: any;
}

@Injectable({
  providedIn: 'root'
})
export class NativeBridgeService {
  public message$: Observable<NativeMessage>;

  constructor(
    private iosBridge: IOSBridgeService,
    private androidBridge: AndroidBridgeService,
    private platform: PlatformDetectionService
  ) {
    // iOS와 Android 메시지를 하나로 통합
    this.message$ = merge(
      this.iosBridge.message$,
      this.androidBridge.message$
    );
  }

  /**
   * Gemini 인증 요청
   */
  requestAuth(): void {
    if (this.platform.isIOS()) {
      this.iosBridge.requestAuth();
    } else if (this.platform.isAndroid()) {
      this.androidBridge.requestAuth();
    } else {
      console.warn('모바일 앱 환경이 아닙니다');
    }
  }

  /**
   * 로그인 상태 확인
   */
  checkLoginStatus(): void {
    if (this.platform.isIOS()) {
      this.iosBridge.checkLoginStatus();
    } else if (this.platform.isAndroid()) {
      this.androidBridge.checkLoginStatus();
    }
  }

  /**
   * 로그아웃
   */
  signOut(): void {
    if (this.platform.isIOS()) {
      this.iosBridge.signOut();
    } else if (this.platform.isAndroid()) {
      this.androidBridge.signOut();
    }
  }

  /**
   * 연결 테스트
   */
  test(): void {
    if (this.platform.isIOS()) {
      this.iosBridge.test();
    } else if (this.platform.isAndroid()) {
      this.androidBridge.test();
    }
  }

  /**
   * 모바일 앱 여부 확인
   */
  isMobileApp(): boolean {
    return this.platform.isMobileApp();
  }
}
```

---

## 🎨 Component 예제

### **로그인 컴포넌트**

```typescript
// auth.component.ts
import { Component, OnInit, OnDestroy } from '@angular/core';
import { Subscription } from 'rxjs';
import { NativeBridgeService } from './services/native-bridge.service';

@Component({
  selector: 'app-auth',
  templateUrl: './auth.component.html',
  styleUrls: ['./auth.component.scss']
})
export class AuthComponent implements OnInit, OnDestroy {
  isLoading = false;
  isLoggedIn = false;
  userEmail = '';
  token = '';
  errorMessage = '';
  
  private subscription = new Subscription();

  constructor(private nativeBridge: NativeBridgeService) {}

  ngOnInit(): void {
    // 네이티브 메시지 구독
    this.subscription.add(
      this.nativeBridge.message$.subscribe(({ type, data }) => {
        this.handleNativeMessage(type, data);
      })
    );

    // 초기 로그인 상태 확인
    if (this.nativeBridge.isMobileApp()) {
      this.checkLoginStatus();
    }
  }

  ngOnDestroy(): void {
    this.subscription.unsubscribe();
  }

  /**
   * 네이티브 메시지 처리
   */
  private handleNativeMessage(type: string, data: any): void {
    console.log('메시지 수신:', type, data);

    switch(type) {
      case 'authSuccess':
        this.handleAuthSuccess(data);
        break;
      case 'authError':
        this.handleAuthError(data);
        break;
      case 'authStatus':
        this.handleAuthStatus(data);
        break;
      case 'signOutComplete':
        this.handleSignOutComplete();
        break;
      case 'testResponse':
        console.log('✅ 브릿지 테스트:', data.message);
        break;
    }
  }

  /**
   * 로그인 성공 처리
   */
  private handleAuthSuccess(data: any): void {
    this.isLoading = false;
    this.isLoggedIn = true;
    this.token = data.token;
    this.userEmail = data.email || '';
    this.errorMessage = '';

    console.log('✅ 로그인 성공');
    
    // 토큰을 세션에 저장
    sessionStorage.setItem('gemini_token', data.token);
    sessionStorage.setItem('gemini_token_time', Date.now().toString());

    // Gemini API 호출
    this.callGeminiAPI(data.token);
  }

  /**
   * 로그인 실패 처리
   */
  private handleAuthError(data: any): void {
    this.isLoading = false;
    this.errorMessage = data.error || '로그인에 실패했습니다';
    console.error('❌ 로그인 실패:', data.error);
  }

  /**
   * 로그인 상태 처리
   */
  private handleAuthStatus(data: any): void {
    this.isLoggedIn = data.isAvailable;
    console.log('로그인 상태:', data.isAvailable ? '로그인됨' : '로그인 안 됨');
  }

  /**
   * 로그아웃 완료 처리
   */
  private handleSignOutComplete(): void {
    this.isLoggedIn = false;
    this.token = '';
    this.userEmail = '';
    this.errorMessage = '';
    sessionStorage.removeItem('gemini_token');
    sessionStorage.removeItem('gemini_token_time');
    console.log('✅ 로그아웃 완료');
  }

  /**
   * 로그인 시작
   */
  login(): void {
    this.isLoading = true;
    this.errorMessage = '';
    this.nativeBridge.requestAuth();
  }

  /**
   * 로그인 상태 확인
   */
  checkLoginStatus(): void {
    this.nativeBridge.checkLoginStatus();
  }

  /**
   * 로그아웃
   */
  logout(): void {
    this.nativeBridge.signOut();
  }

  /**
   * 브릿지 테스트
   */
  testBridge(): void {
    this.nativeBridge.test();
  }

  /**
   * Gemini API 호출
   */
  private async callGeminiAPI(token: string): Promise<void> {
    try {
      const response = await fetch(
        'https://generativelanguage.googleapis.com/v1beta/models',
        {
          headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json'
          }
        }
      );

      if (response.ok) {
        const data = await response.json();
        console.log('✅ Gemini API 호출 성공:', data);
      } else {
        console.error('❌ API 오류:', response.status);
      }
    } catch (error) {
      console.error('❌ 네트워크 오류:', error);
    }
  }
}
```

### **HTML 템플릿**

```html
<!-- auth.component.html -->
<div class="auth-container">
  <h2>🚀 ezReader Gemini 인증</h2>

  <!-- 로딩 상태 -->
  <div *ngIf="isLoading" class="loading">
    <p>🔄 인증 진행 중...</p>
  </div>

  <!-- 에러 메시지 -->
  <div *ngIf="errorMessage" class="error">
    <p>❌ {{ errorMessage }}</p>
  </div>

  <!-- 로그인 상태 -->
  <div class="status" *ngIf="!isLoading">
    <p *ngIf="isLoggedIn">✅ 로그인되어 있습니다</p>
    <p *ngIf="!isLoggedIn">ℹ️ 로그인이 필요합니다</p>
    <p *ngIf="userEmail">사용자: {{ userEmail }}</p>
  </div>

  <!-- 버튼 -->
  <div class="buttons">
    <button 
      (click)="login()" 
      [disabled]="isLoading || isLoggedIn"
      class="btn-primary">
      🔐 Gemini 로그인
    </button>

    <button 
      (click)="checkLoginStatus()"
      [disabled]="isLoading"
      class="btn-secondary">
      ✓ 로그인 상태 확인
    </button>

    <button 
      (click)="logout()"
      [disabled]="isLoading || !isLoggedIn"
      class="btn-secondary">
      🚪 로그아웃
    </button>

    <button 
      (click)="testBridge()"
      [disabled]="isLoading"
      class="btn-secondary">
      🧪 연결 테스트
    </button>
  </div>
</div>
```

### **CSS 스타일**

```scss
// auth.component.scss
.auth-container {
  max-width: 600px;
  margin: 0 auto;
  padding: 20px;
  font-family: Arial, sans-serif;

  h2 {
    text-align: center;
    margin-bottom: 20px;
  }

  .loading, .error, .status {
    padding: 15px;
    margin: 20px 0;
    border-radius: 8px;
    text-align: center;
  }

  .loading {
    background: #e3f2fd;
    color: #1976d2;
  }

  .error {
    background: #ffebee;
    color: #c62828;
  }

  .status {
    background: #f5f5f5;
    color: #333;
  }

  .buttons {
    display: flex;
    flex-direction: column;
    gap: 10px;
    margin-top: 20px;

    button {
      padding: 12px 24px;
      font-size: 16px;
      border: none;
      border-radius: 8px;
      cursor: pointer;
      transition: all 0.3s;

      &:disabled {
        opacity: 0.5;
        cursor: not-allowed;
      }

      &.btn-primary {
        background: #4285f4;
        color: white;

        &:hover:not(:disabled) {
          background: #3367d6;
        }
      }

      &.btn-secondary {
        background: #f5f5f5;
        color: #333;

        &:hover:not(:disabled) {
          background: #e0e0e0;
        }
      }
    }
  }
}
```

---

## 🔧 Module 설정

```typescript
// app.module.ts
import { NgModule } from '@angular/core';
import { BrowserModule } from '@angular/platform-browser';

import { AppComponent } from './app.component';
import { AuthComponent } from './auth/auth.component';

// Services
import { PlatformDetectionService } from './services/platform-detection.service';
import { IOSBridgeService } from './services/ios-bridge.service';
import { AndroidBridgeService } from './services/android-bridge.service';
import { NativeBridgeService } from './services/native-bridge.service';

@NgModule({
  declarations: [
    AppComponent,
    AuthComponent
  ],
  imports: [
    BrowserModule
  ],
  providers: [
    PlatformDetectionService,
    IOSBridgeService,
    AndroidBridgeService,
    NativeBridgeService
  ],
  bootstrap: [AppComponent]
})
export class AppModule { }
```

---

## 🎓 토큰 관리

### **세션 스토리지 활용**

```typescript
// token.service.ts
import { Injectable } from '@angular/core';

@Injectable({
  providedIn: 'root'
})
export class TokenService {
  private readonly TOKEN_KEY = 'gemini_token';
  private readonly TOKEN_TIME_KEY = 'gemini_token_time';
  private readonly TOKEN_EXPIRY = 3600000; // 1시간 (ms)

  /**
   * 토큰 저장
   */
  saveToken(token: string): void {
    sessionStorage.setItem(this.TOKEN_KEY, token);
    sessionStorage.setItem(this.TOKEN_TIME_KEY, Date.now().toString());
  }

  /**
   * 토큰 가져오기
   */
  getToken(): string | null {
    const token = sessionStorage.getItem(this.TOKEN_KEY);
    const time = sessionStorage.getItem(this.TOKEN_TIME_KEY);

    if (!token || !time) {
      return null;
    }

    // 토큰 만료 확인 (1시간)
    const elapsed = Date.now() - parseInt(time, 10);
    if (elapsed > this.TOKEN_EXPIRY) {
      this.clearToken();
      return null;
    }

    return token;
  }

  /**
   * 토큰 삭제
   */
  clearToken(): void {
    sessionStorage.removeItem(this.TOKEN_KEY);
    sessionStorage.removeItem(this.TOKEN_TIME_KEY);
  }

  /**
   * 토큰 유효성 확인
   */
  isTokenValid(): boolean {
    return this.getToken() !== null;
  }
}
```

---

## 🐛 디버깅

### **Safari Remote Debugging**

1. iPhone에서:
   - **설정 → Safari → 고급 → 웹 속성 점검** 활성화

2. Mac에서:
   - **Safari → 개발자 메뉴 → [기기 이름] → [웹페이지]** 선택

3. Console에서 테스트:
   ```javascript
   // 브릿지 확인
   console.log(window.webkit);
   
   // 메시지 전송 테스트
   window.webkit.messageHandlers.iosHandler.postMessage('test');
   ```

### **로그 확인**

```typescript
// 개발 모드에서만 로그 출력
if (!environment.production) {
  console.log('iOS Bridge:', window.webkit);
}
```

---

## ⚠️ 주의사항

### **1. 타입 안정성**

```typescript
// window 객체 확장 시 타입 선언 필수
declare global {
  interface Window {
    webkit?: {
      messageHandlers?: {
        iosHandler?: {
          postMessage: (message: string) => void;
        };
      };
    };
  }
}
```

### **2. 플랫폼 감지**

```typescript
// iOS 앱 내부인지 확인
const isIOSApp = () => {
  return /iPhone|iPad|iPod/.test(navigator.userAgent) && 
         !!(window as any).webkit?.messageHandlers?.iosHandler;
};
```

### **3. 에러 처리**

```typescript
try {
  window.webkit?.messageHandlers?.iosHandler?.postMessage('test');
} catch (error) {
  console.error('iOS 브릿지 오류:', error);
}
```

### **4. 보안**

- ✅ 토큰은 `sessionStorage`에 저장 (탭 닫으면 삭제)
- ❌ `localStorage`는 사용 금지 (보안 위험)
- ✅ 프로덕션에서는 토큰 로그 출력 금지

---

## 📚 API 레퍼런스

### **명령어 목록**

| 명령 | 파라미터 | 응답 타입 | 응답 데이터 |
|------|----------|-----------|-------------|
| `requestGeminiAuth` | 없음 | `authSuccess` / `authError` | `{token: string, email: string}` / `{error: string}` |
| `isGeminiAuthAvailable` | 없음 | `authStatus` | `{isAvailable: boolean}` |
| `signOut` | 없음 | `signOutComplete` | `{}` |
| `test` | 없음 | `testResponse` | `{message: string}` |

### **메시지 타입**

```typescript
type IOSMessageType = 
  | 'authSuccess'
  | 'authError'
  | 'authStatus'
  | 'signOutComplete'
  | 'testResponse';

interface AuthSuccessData {
  token: string;
  email: string;
}

interface AuthErrorData {
  error: string;
}

interface AuthStatusData {
  isAvailable: boolean;
}

interface TestResponseData {
  message: string;
}
```

---

## 🔄 안드로이드와의 차이점

| 항목 | 안드로이드 | iOS |
|------|-----------|-----|
| **웹→앱** | `console.log('ANDROID_MESSAGE:...')` | `window.webkit.messageHandlers.iosHandler.postMessage(...)` |
| **앱→웹** | `window.onAndroidMessage(type, data)` | `window.onIOSMessage(type, data)` |
| **플랫폼 감지** | `console.log` 가능 여부 | `window.webkit` 존재 여부 |

---

## 🚀 Quick Start

1. **서비스 생성:**
   - `platform-detection.service.ts`
   - `ios-bridge.service.ts`
   - `native-bridge.service.ts`

2. **컴포넌트 작성:**
   - `auth.component.ts`
   - `auth.component.html`
   - `auth.component.scss`

3. **모듈 등록:**
   - `app.module.ts`에 서비스 추가

4. **테스트:**
   - iOS 시뮬레이터 또는 실제 기기에서 실행
   - Safari 개발자 도구로 디버깅

---

**ezReader iOS Integration v1.0** | 2025.12.03
