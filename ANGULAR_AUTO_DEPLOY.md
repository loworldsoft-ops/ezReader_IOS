# Angular → iOS 자동 배포 설정 가이드

Angular 빌드 결과물을 iOS webapp 폴더로 자동 복사하는 설정입니다.

---

## 📍 타겟 경로

**iOS webapp 폴더:**
```
/Users/ansanghyun/Documents/IOS/ezReader_IOS/ezReader_IOS/webapp/
```

---

## 🚀 빠른 시작

### 1단계: 복사 스크립트 생성

Angular 프로젝트 루트에 `scripts/copy-to-ios.js` 파일을 생성하세요.

**파일 위치:**
```
your-angular-project/
├── src/
├── angular.json
├── package.json
└── scripts/              ← 이 폴더 생성
    └── copy-to-ios.js   ← 이 파일 생성
```

**scripts/copy-to-ios.js 내용:**

```javascript
const fs = require('fs');
const path = require('path');

// ========================================
// 설정 (프로젝트에 맞게 수정)
// ========================================
const config = {
  // Angular 빌드 결과물 경로
  // ⚠️ 'ezReader-web'를 실제 프로젝트명으로 변경하세요
  source: path.join(__dirname, '../dist/ezReader-web/browser'),
  
  // iOS webapp 폴더 경로 (고정)
  target: '/Users/ansanghyun/Documents/IOS/ezReader_IOS/ezReader_IOS/webapp',
  
  // 복사 제외 파일
  exclude: ['.DS_Store', 'Thumbs.db', '.gitkeep']
};

// ========================================
// 복사 로직 (수정 불필요)
// ========================================

console.log('\n🚀 Angular → iOS 자동 배포 시작\n');
console.log('=' .repeat(50));

// 1. 소스 폴더 확인
if (!fs.existsSync(config.source)) {
  console.error('\n❌ 빌드 결과물을 찾을 수 없습니다!');
  console.error(`   경로: ${config.source}`);
  console.error('\n💡 해결 방법:');
  console.error('   1. npm run build:ios 먼저 실행');
  console.error('   2. config.source 경로가 올바른지 확인');
  console.error('      (프로젝트명 확인 필요)\n');
  process.exit(1);
}

// 2. 타겟 폴더 확인
if (!fs.existsSync(config.target)) {
  console.error('\n❌ iOS webapp 폴더를 찾을 수 없습니다!');
  console.error(`   경로: ${config.target}\n`);
  process.exit(1);
}

// 3. 기존 파일 삭제
console.log('\n🗑️  기존 파일 정리 중...');
const files = fs.readdirSync(config.target);
let deletedCount = 0;

files.forEach(file => {
  const filePath = path.join(config.target, file);
  const stat = fs.statSync(filePath);
  
  try {
    if (stat.isFile()) {
      fs.unlinkSync(filePath);
      deletedCount++;
    } else if (stat.isDirectory()) {
      fs.rmSync(filePath, { recursive: true, force: true });
      deletedCount++;
    }
  } catch (err) {
    console.warn(`   ⚠️  삭제 실패: ${file}`);
  }
});

console.log(`   ✓ ${deletedCount}개 항목 삭제됨`);

// 4. 파일 복사
console.log('\n📦 파일 복사 중...');
console.log(`   FROM: ${config.source}`);
console.log(`   TO:   ${config.target}`);

function copyRecursive(src, dest) {
  const stats = fs.statSync(src);
  
  if (stats.isDirectory()) {
    // 디렉토리 생성
    if (!fs.existsSync(dest)) {
      fs.mkdirSync(dest, { recursive: true });
    }
    
    // 하위 항목 복사
    const items = fs.readdirSync(src);
    items.forEach(item => {
      // 제외 파일 체크
      if (config.exclude.includes(item)) {
        return;
      }
      
      copyRecursive(
        path.join(src, item),
        path.join(dest, item)
      );
    });
  } else {
    // 파일 복사
    fs.copyFileSync(src, dest);
  }
}

let copyStartTime = Date.now();
copyRecursive(config.source, config.target);
let copyDuration = Date.now() - copyStartTime;

// 5. 결과 확인 및 출력
console.log(`   ✓ 복사 완료 (${copyDuration}ms)\n`);
console.log('=' .repeat(50));

const copiedFiles = fs.readdirSync(config.target);
console.log('\n✅ 복사된 파일 목록:\n');

copiedFiles.forEach(file => {
  const filePath = path.join(config.target, file);
  const stat = fs.statSync(filePath);
  
  if (stat.isDirectory()) {
    const subFiles = fs.readdirSync(filePath);
    console.log(`   📁 ${file}/ (${subFiles.length}개 파일)`);
  } else {
    const size = (stat.size / 1024).toFixed(2);
    console.log(`   📄 ${file} (${size} KB)`);
  }
});

console.log('\n' + '=' .repeat(50));
console.log('\n🎉 배포 완료!');
console.log('\n다음 단계:');
console.log('   1. Xcode에서 앱 실행');
console.log('   2. "로컬 번들 (오프라인)" 모드 선택');
console.log('   3. 웹앱 테스트\n');
```

---

### 2단계: package.json 스크립트 추가

Angular 프로젝트의 `package.json`에 다음 스크립트를 추가하세요:

```json
{
  "name": "your-angular-project",
  "version": "1.0.0",
  "scripts": {
    "ng": "ng",
    "start": "ng serve",
    "build": "ng build",
    
    "build:ios": "ng build --configuration=ios-bundle",
    "copy:ios": "node scripts/copy-to-ios.js",
    "deploy:ios": "npm run build:ios && npm run copy:ios"
  }
}
```

---

## 💻 사용 방법

### 기본 사용 (빌드 + 복사)

```bash
npm run deploy:ios
```

이 명령어가 실행하는 작업:
1. Angular 프로젝트를 iOS용으로 빌드
2. 빌드 결과물을 iOS webapp 폴더로 자동 복사

### 개별 명령어

```bash
# 빌드만 실행
npm run build:ios

# 복사만 실행 (이미 빌드된 경우)
npm run copy:ios
```

---

## 🔧 경로 설정 (중요!)

### Angular 프로젝트명 확인

1. `angular.json` 파일 열기
2. `"projects"` 섹션에서 프로젝트명 확인:

```json
{
  "projects": {
    "ezReader-web": {        ← 이 이름 확인
      "projectType": "application"
    }
  }
}
```

3. `scripts/copy-to-ios.js`에서 해당 이름으로 수정:

```javascript
const config = {
  source: path.join(__dirname, '../dist/YOUR-PROJECT-NAME/browser'),
  //                                    ↑ 여기를 수정
};
```

### Angular 버전별 경로 차이

| Angular 버전 | 빌드 결과물 경로 |
|--------------|------------------|
| Angular 17+ | `dist/[프로젝트명]/browser/` |
| Angular 16 이하 | `dist/[프로젝트명]/` |

Angular 16 이하를 사용하는 경우:

```javascript
source: path.join(__dirname, '../dist/ezReader-web'),  // /browser 제거
```

---

## ⚙️ angular.json 설정 확인

`ios-bundle` 설정이 있는지 확인하세요:

```json
{
  "projects": {
    "ezReader-web": {
      "architect": {
        "build": {
          "configurations": {
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

없다면 추가하세요. ([ANGULAR_BUILD_GUIDE.md](ANGULAR_BUILD_GUIDE.md) 참고)

---

## 📊 실행 예시

```bash
$ npm run deploy:ios

> ezReader-web@1.0.0 deploy:ios
> npm run build:ios && npm run copy:ios

> ng build --configuration=ios-bundle

✔ Browser application bundle generation complete.
✔ Copying assets complete.

Initial Chunk Files | Names         |  Size
main-ABCD1234.js    | main          | 245.67 kB
polyfills-EFGH5678.js| polyfills    | 90.23 kB
styles-IJKL9012.css | styles        | 12.45 kB

Build at: 2025-12-11T10:30:45.678Z
✔ Built in 8.5 seconds


> node scripts/copy-to-ios.js

🚀 Angular → iOS 자동 배포 시작

==================================================

🗑️  기존 파일 정리 중...
   ✓ 5개 항목 삭제됨

📦 파일 복사 중...
   FROM: /path/to/angular/dist/ezReader-web/browser
   TO:   /Users/ansanghyun/Documents/IOS/ezReader_IOS/ezReader_IOS/webapp
   ✓ 복사 완료 (245ms)

==================================================

✅ 복사된 파일 목록:

   📄 index.html (2.45 KB)
   📄 main-ABCD1234.js (245.67 KB)
   📄 polyfills-EFGH5678.js (90.23 KB)
   📄 styles-IJKL9012.css (12.45 KB)
   📄 3rdpartylicenses.txt (5.12 KB)
   📁 assets/ (8개 파일)

==================================================

🎉 배포 완료!

다음 단계:
   1. Xcode에서 앱 실행
   2. "로컬 번들 (오프라인)" 모드 선택
   3. 웹앱 테스트
```

---

## ❓ 문제 해결

### "빌드 결과물을 찾을 수 없습니다" 오류

**원인:** config.source 경로가 잘못됨

**해결:**
1. 실제 빌드 결과물 위치 확인:
   ```bash
   ls -la dist/
   ```
2. 폴더명이 다르면 `copy-to-ios.js`에서 수정

### "iOS webapp 폴더를 찾을 수 없습니다" 오류

**원인:** iOS 프로젝트 경로가 잘못됨

**해결:**
1. iOS 프로젝트 위치 확인:
   ```bash
   ls -la /Users/ansanghyun/Documents/IOS/ezReader_IOS/ezReader_IOS/
   ```
2. webapp 폴더가 없으면 생성:
   ```bash
   mkdir -p /Users/ansanghyun/Documents/IOS/ezReader_IOS/ezReader_IOS/webapp
   ```

### 복사는 되는데 앱에서 로드 안 됨

**원인:** Xcode에 webapp 폴더가 추가되지 않음

**해결:**
1. Xcode 열기
2. webapp 폴더를 프로젝트에 추가
3. **중요:** "Create folder references" 선택 (파란색 아이콘)

---

## 🎯 전체 워크플로우

```
┌─────────────────────────────────────────────┐
│  Angular 프로젝트 (개발)                     │
│  - 코드 수정                                 │
│  - npm run deploy:ios ← 실행                │
└─────────────────┬───────────────────────────┘
                  │
                  ▼
          ┌───────────────┐
          │ ng build:ios  │  빌드
          └───────┬───────┘
                  │
                  ▼
     ┌────────────────────────┐
     │ dist/[프로젝트]/browser │
     └────────┬───────────────┘
              │
              ▼
      ┌────────────────┐
      │ copy-to-ios.js │  복사
      └────────┬───────┘
               │
               ▼
┌──────────────────────────────────────────────┐
│  iOS 프로젝트                                 │
│  ezReader_IOS/webapp/                        │
│  - index.html                                │
│  - main.js, styles.css, etc.                 │
└──────────────┬───────────────────────────────┘
               │
               ▼
        ┌─────────────┐
        │ Xcode 실행  │
        └─────┬───────┘
              │
              ▼
    ┌──────────────────┐
    │ 로컬 번들 모드 선택│
    └──────┬───────────┘
           │
           ▼
      ┌─────────┐
      │  테스트  │
      └─────────┘
```

---

## 📋 체크리스트

### 최초 설정 (1회)
- [ ] `scripts/copy-to-ios.js` 파일 생성
- [ ] `package.json`에 스크립트 추가
- [ ] `angular.json`에 ios-bundle 설정 추가
- [ ] 프로젝트명 확인 및 경로 수정
- [ ] Xcode에 webapp 폴더 추가 (folder references)

### 매 배포 시
- [ ] `npm run deploy:ios` 실행
- [ ] 복사 완료 메시지 확인
- [ ] Xcode에서 앱 실행
- [ ] "로컬 번들" 모드 선택
- [ ] 웹앱 동작 확인

---

## 💡 팁

### 개발 효율 높이기

1. **빌드 + 복사 + Xcode 실행 자동화**

   `package.json`:
   ```json
   "scripts": {
     "deploy:ios:run": "npm run deploy:ios && open -a Xcode ../../ezReader_IOS.xcodeproj"
   }
   ```

2. **Watch 모드로 자동 재빌드**

   파일 변경 시 자동 빌드 (별도 도구 필요):
   ```bash
   npm install -D nodemon
   ```
   
   `package.json`:
   ```json
   "scripts": {
     "watch:ios": "nodemon --watch src --ext ts,html,css,scss --exec 'npm run deploy:ios'"
   }
   ```

### Git 설정

`.gitignore`에 추가:
```
# Angular
dist/

# iOS
*.xcuserstate
*.xcworkspace/xcuserdata/
```

---

## 📚 관련 문서

- [ANGULAR_BUILD_GUIDE.md](ANGULAR_BUILD_GUIDE.md) - Angular 빌드 상세 가이드
- [WEBVIEW_LOADING_STRATEGY.md](WEBVIEW_LOADING_STRATEGY.md) - 로딩 전략 설계
- [IOS_WEB_INTEGRATION_GUIDE.md](IOS_WEB_INTEGRATION_GUIDE.md) - iOS 웹 통합 가이드
