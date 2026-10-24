# 개발 기준

- 저장소: macOS 앱과 React 랜딩 페이지를 함께 관리하는 모노레포
- macOS: Swift 6 언어 모드, SwiftUI, macOS 26 이상
- 웹: React, TypeScript, Vite, npm, Node.js 24
- 온디바이스 분석: Foundation Models (실기기 검증 후 연결)
- 미리 알림: EventKit (권한 및 저장 연동은 후속 작업)
- 별도 서버 및 Turborepo 없음

## 작업 규칙

- [공통 코딩 컨벤션](rules/coding-convention.md): 경로별 적용 기준
- [Swift·SwiftUI 컨벤션](rules/swift-coding-convention.md): macOS 앱
- [React·TypeScript 컨벤션](rules/web-coding-convention.md): 랜딩 페이지
- [Git·커밋·PR 컨벤션](rules/git-convention.md): 브랜치·커밋·라벨의 기준 문서
- [Codex 작업 흐름](rules/ai-workflow.md): 이슈·명세·검증·리뷰·게시

## 작업 시작 예시

```sh
git switch develop
git pull --ff-only origin develop
git switch -c 'feat/작업명/#이슈번호'
```

이름의 이슈 번호는 실제 번호로 바꿉니다. 사용자가 지정한 현재 작업 브랜치
`chore/agent-harness-setting/#4`는 그대로 사용합니다.
규칙을 이 문서와 스킬에 중복 정의하지 않고 연결된 기준 문서를 갱신합니다.

하네스 사용법은 [사용 안내](ai-workflow/user-guide.md)를 참고합니다.
