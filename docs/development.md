# 개발 기준

- 저장소: macOS 앱과 React 랜딩 페이지를 함께 관리하는 모노레포
- macOS: Swift 6 언어 모드, SwiftUI, macOS 26 이상
- 웹: React, TypeScript, Vite, npm, Node.js 24
- 온디바이스 분석: Foundation Models (실기기 검증 후 연결)
- 미리 알림: EventKit (권한 및 저장 연동은 후속 작업)
- 별도 서버 및 Turborepo 없음

## Git 협업 초안

초기 세팅 이후에는 `main`에서 `feat/macos-기능명`, `feat/web-기능명`, `fix/수정명` 브랜치를 만듭니다.
이슈 → 작업 브랜치 → PR → 검증·리뷰 → Squash Merge 순서로 진행합니다.
커밋 접두사는 `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`를 사용합니다.
브랜치 보호 설정과 CI는 아직 적용하지 않았습니다.
