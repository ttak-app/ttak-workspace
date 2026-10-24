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

## 빌드

```sh
xcodebuild -project apps/macos/Ttak.xcodeproj -scheme Ttak -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

위 명령은 저장소 루트에서 실행합니다. 현재 초기 세팅 환경에는 Xcode가 없어 앱 컴파일·실행은 미검증입니다.
