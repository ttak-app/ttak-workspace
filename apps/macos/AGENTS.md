# macOS 작업

저장소 루트의 [Codex 지침](../../AGENTS.md)과
[공통 코딩 컨벤션](../../docs/rules/coding-convention.md),
[Swift·SwiftUI 컨벤션](../../docs/rules/swift-coding-convention.md),
[Git 컨벤션](../../docs/rules/git-convention.md),
[macOS 경계와 검증](../../docs/rules/macos-development.md)을 적용한다.
앱은 Swift·SwiftUI의 macOS 메뉴바 앱이다. iOS 타깃·UIKit·웹 상태 관리 라이브러리를 추가하지 않는다.
Swift의 형식·명명·상태 규칙은 연결된 Swift 컨벤션을 따른다. 새 아키텍처·테스트 도구는 기존 코드와 사용자의 결정을 기준으로 선택한다.
Swift 코드 수정 후 저장소 루트의 `npm run format:macos`로 형식을 맞추고 `npm run format:check:macos`로 검사한다.
