# Angular → iOS 로컬 번들 빌드 가이드

## 📋 빠른 시작

### 1단계: Angular 빌드 설정

#### angular.json 수정

`projects > [프로젝트명] > architect > build > configurations`에 ios-bundle 추가:

```json
{
  "projects": {
    "ezReader-web": {
      "architect": {
        "build": {
          "configurations": {
            "production": {
              "budgets": [...],
              "outputHashing": "all"
            },
            "ios-bundle": {
              "optimization": true,
              "outputHashing": "all",
              "sourceMap": false,
              "namedChunks": false,
              "aot": true,
              "extractLicenses": true,
              "baseHref": "./",
              "deployUrl": "./"
            }
          }
        }
      }
    }
  }
}
```

#### 핵심 설정 설명

| 설정 | 값 | 설명 |
|------|-----|------|
| `baseHref` | `"./"` | HTML의 base 태그 설정 (상대 경로) |
| `deployUrl` | `"./"` | 에셋 URL 프리픽스 (상대 경로) |
| `aot` | `true` | AOT 컴파일 활성화 |
| `optimization` | `true` | 프로덕션 최적화 |

---

### 2단계: 라우팅 설정 (Hash 라우팅)

로컬 파일에서 Angular Router를 사용하려면 **Hash 라우팅**이 필요합니다.

#### app.config.ts (Standalone 방식)

```typescript
import { ApplicationConfig } from '@angular/core';
import { provideRouter, withHashLocation } from '@angular/router';
import { routes } from './app.routes';

export const appConfig: ApplicationConfig = {
  providers: [
    provideRouter(routes, withHashLocation()),  // ← Hash 라우팅 활성화
    // ... 다른 providers
  ]
};
```

#### app.module.ts (NgModule 방식)

```typescript
import { RouterModule } from '@angular/router';
import { HashLocationStrategy, LocationStrategy } from '@angular/common';

@NgModule({
  imports: [
    RouterModule.forRoot(routes, { useHash: true })
  ],
  providers: [
    { provide: LocationStrategy, useClass: HashLocationStrategy }
  ]
})
export class AppModule { }
```

---

### 3단계: 빌드 실행

#### package.json에 스크립트 추가

```json
{
  "scripts": {
    "build": "ng build",
    "build:ios": "ng build --configuration=ios-bundle",
    "build:ios:copy": "ng build --configuration=ios-bundle && npm run copy:ios"
  }
}
```

#### 빌드 명령어

```bash
# iOS 로컬 번들용 빌드
ng build --configuration=ios-bundle

# 또는
npm run build:ios
```

#### 빌드 결과물 확인

```
dist/ezReader-web/
├── browser/           # ← Angular 17+ 구조
│   ├── index.html
│   ├── main-[hash].js
│   ├── polyfills-[hash].js
│   ├── styles-[hash].css
│   └── assets/
│       └── ...
```

---

### 4단계: iOS 프로젝트에 복사

#### 방법 A: 수동 복사

1. `dist/ezReader-web/browser/` 폴더 전체를 복사
2. `ezReader_IOS/ezReader_IOS/webapp/` 위치에 붙여넣기
3. 기존 샘플 파일 덮어쓰기

```bash
# 터미널에서 실행 (경로는 실제 환경에 맞게 수정)
rm -rf /path/to/ezReader_IOS/ezReader_IOS/webapp/*
cp -R /path/to/angular-project/dist/ezReader-web/browser/* /path/to/ezReader_IOS/ezReader_IOS/webapp/
```

#### 방법 B: 빌드 스크립트 자동화

`package.json`에 복사 스크립트 추가:

```json
{
  "scripts": {
    "copy:ios": "rm -rf ../ezReader_IOS/ezReader_IOS/webapp/* && cp -R dist/ezReader-web/browser/* ../ezReader_IOS/ezReader_IOS/webapp/",
    "build:ios:deploy": "npm run build:ios && npm run copy:ios"
  }
}
```

---

### 5단계: Xcode 프로젝트 설정

#### webapp 폴더를 프로젝트에 추가 (최초 1회)

1. Xcode에서 프로젝트 열기
2. `ezReader_IOS` 폴더에서 우클릭 → **Add Files to "ezReader_IOS"**
3. `webapp` 폴더 선택
4. **중요 옵션**:
   - ☑️ **Copy items if needed** (체크 해제 - 이미 프로젝트 안에 있음)
   - ☑️ **Create folder references** (반드시 선택!)
   - Target: ezReader_IOS 체크

> ⚠️ "Create groups" 대신 **"Create folder references"**를 선택해야 합니다!
> 폴더 참조로 추가하면 폴더 내용이 변경되어도 자동 반영됩니다.

#### 확인 방법

- Xcode 프로젝트 네비게이터에서 `webapp` 폴더가 **파란색 아이콘**으로 표시되어야 함
- 노란색 폴더 아이콘이면 "Create groups"로 추가된 것 → 삭제 후 다시 추가

---

## 🔧 빌드 결과물 검증

### index.html 확인

빌드된 `index.html`에서 경로가 상대 경로인지 확인:

```html
<!-- ✅ 올바른 예 (상대 경로) -->
<script src="main-XXXXX.js" type="module"></script>
<link rel="stylesheet" href="styles-XXXXX.css">

<!-- ❌ 잘못된 예 (절대 경로) -->
<script src="/main-XXXXX.js" type="module"></script>
<link rel="stylesheet" href="/styles-XXXXX.css">
```

### 앱 번들 확인 (빌드 후)

```bash
# 시뮬레이터 앱 번들 위치 찾기
find ~/Library/Developer/Xcode/DerivedData -name "ezReader_IOS.app" -type d 2>/dev/null | head -1

# webapp 폴더 확인
ls -la [위에서 찾은 경로]/webapp/
```

---

## ⚠️ 자주 발생하는 문제 & 해결

### 1. "로컬 웹앱을 찾을 수 없습니다" 오류

**원인**: webapp 폴더가 앱 번들에 포함되지 않음

**해결**:
1. Xcode에서 webapp 폴더 삭제 후 다시 추가
2. **Create folder references** 옵션 확인
3. Target Membership에서 `ezReader_IOS` 체크 확인

### 2. 스타일/이미지가 로드되지 않음

**원인**: 절대 경로 사용

**해결**:
1. `angular.json`에서 `baseHref`와 `deployUrl`이 `"./"` 인지 확인
2. 빌드 결과물의 index.html 경로 확인

### 3. 라우팅이 작동하지 않음

**원인**: HTML5 라우팅은 로컬 파일에서 작동 안 함

**해결**:
1. Hash 라우팅 사용 (`withHashLocation()`)
2. URL이 `file://...#/home` 형태로 표시됨

### 4. API 호출 실패 (CORS)

**원인**: 로컬 파일의 origin이 `null`

**해결**:
```typescript
// 환경 감지
const isLocalFile = location.protocol === 'file:';

if (isLocalFile) {
  // iOS 네이티브 브릿지를 통해 API 호출
  this.callViaIOSBridge(endpoint, data);
} else {
  // 일반 HTTP 호출
  this.http.post(endpoint, data);
}
```

---

## 📁 최종 폴더 구조

```
ezReader_IOS/
├── ezReader_IOS/
│   ├── ContentView.swift
│   ├── ezReaderApp.swift
│   ├── Info.plist
│   ├── Assets.xcassets/
│   └── webapp/                    # ← Angular 빌드 결과물
│       ├── index.html
│       ├── main-XXXXX.js
│       ├── polyfills-XXXXX.js
│       ├── styles-XXXXX.css
│       ├── 3rdpartylicenses.txt
│       └── assets/
│           ├── images/
│           └── ...
├── ezReader_IOS.xcodeproj/
└── ANGULAR_BUILD_GUIDE.md
```

---

## 🚀 전체 워크플로우 요약

```bash
# 1. Angular 프로젝트에서 빌드
cd /path/to/angular-project
npm run build:ios

# 2. iOS 프로젝트로 복사
cp -R dist/ezReader-web/browser/* ../ezReader_IOS/ezReader_IOS/webapp/

# 3. Xcode에서 빌드 & 실행
# 앱 실행 시 "로컬 번들 (오프라인)" 선택
```

---

## ✅ 체크리스트

### Angular 측
- [ ] `angular.json`에 ios-bundle 설정 추가
- [ ] `baseHref: "./"` 설정
- [ ] `deployUrl: "./"` 설정
- [ ] Hash 라우팅 활성화 (`withHashLocation()`)
- [ ] 빌드 결과물의 index.html 경로 확인 (상대 경로)

### iOS 측
- [ ] webapp 폴더가 "folder references"로 추가됨 (파란색 아이콘)
- [ ] Target Membership 확인
- [ ] 시뮬레이터에서 "로컬 번들" 모드 테스트
- [ ] 실기기에서 테스트
- [ ] 오프라인 모드 테스트 (비행기 모드)
