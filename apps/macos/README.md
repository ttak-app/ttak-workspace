# Ttak macOS

- Swift 6 언어 모드, SwiftUI
- 최소 지원 OS: macOS 26.0
- 개발 도구: Xcode 26 이상 (macOS 26 SDK 포함)
- 외부 패키지 없음

## 실행

1. `Ttak.xcodeproj`를 Xcode에서 엽니다.
2. `Ttak` 스킴과 `My Mac`을 선택합니다.
3. Signing & Capabilities에서 개발 팀과 Bundle Identifier를 필요에 맞게 설정합니다.
4. 실행하면 메뉴바에 체크 아이콘이 나타납니다.

현재는 메뉴바 입력 화면만 제공합니다. Foundation Models·EventKit 연결 및 권한 요청은 기능 구현 단계에서 추가합니다.
Bundle Identifier `app.ttak.Ttak`은 초기 개발용이며 배포 전에 확정합니다.
앱 샌드박스는 켜져 있으며 미리 알림 entitlement는 EventKit 연동 시 추가합니다.

## Gemini API 로컬 설정

`apps/macos/.env`는 로컬 개발용 비밀값을 보관하며 Git에서 제외합니다.
같은 폴더의 `.env.example`에는 공유 가능한 변수 이름만 기록합니다.
`.env` 파일을 열어 `GEMINI_API_KEY=` 뒤에 본인의 키를 입력합니다.

```dotenv
GEMINI_API_KEY=여기에_발급받은_키
```

파일이 없다면 `apps/macos/.env.example`을 `apps/macos/.env`로 복사하고 키를 입력합니다.
이 파일은 자동으로 읽히지 않습니다. 향후 Gemini 테스트 도구에서 환경 변수를 읽도록 연결해야 하며,
현재 앱은 이 설정만으로 Gemini API를 호출하지 않습니다. 키는 채팅이나 저장소에 공유하지 않습니다.
배포 시에는 공용 API 키를 앱에 포함하지 않고 서버의 비밀값 저장소에서 관리합니다.

## 빌드

```sh
npm run macos:build
```

저장소 루트에서 실행합니다. 앱을 서명 없이 Debug로 빌드하며 산출물은 `.tmp/xcode-derived-data`에 저장합니다.
Debug 심볼은 dSYM으로 생성해 테스트 실패 보고에서 사용할 수 있도록 합니다.

## 단위 테스트

```sh
npm run macos:test
```

공유 `Ttak` 스킴의 `TtakTests`를 실행하며 앱과 테스트를 함께 빌드합니다.
Xcode에서는 같은 스킴과 `My Mac`을 선택한 뒤 Test를 실행합니다.
기본 테스트는 앱 모듈과 테스트 호스트 연결만 확인합니다. 테스트 작성 방법은 [테스트 안내](TtakTests/README.md)를 참고하세요.
Swift Testing은 Xcode 도구 체인에 포함되어 있어 별도 패키지를 설치하지 않습니다.

실제 UI 동작, Foundation Models와 EventKit 연동은 별도 기능 검증 대상입니다.
