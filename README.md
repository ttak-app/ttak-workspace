# ttak-workspace

생각난 순간, 일정 정리는 딱.

Ttak macOS 메뉴바 앱과 React 랜딩 페이지를 함께 관리하는 모노레포입니다.

## 구조

```text
apps/
  macos/   Swift·SwiftUI 네이티브 앱
  web/     React·TypeScript·Vite 랜딩 페이지
docs/      개발 기준과 설계 기록
.github/   PR 템플릿과 CI 워크플로
```

## 웹 실행

Node.js 24와 npm 11이 필요합니다. `.nvmrc`를 사용하는 경우 `nvm use`로 맞춥니다.

```sh
npm ci
npm run dev:web
```

- `npm run lint:web`: 린트 검사
- `npm run build:web`: TypeScript 검사와 프로덕션 빌드
- `npm run preview:web`: 빌드 결과 미리보기

## macOS 앱 실행

Xcode 26 이상으로 `apps/macos/Ttak.xcodeproj`를 열고 `Ttak` 스킴을 실행합니다.
Swift 6 언어 모드와 macOS 26 이상을 기준으로 합니다.
서명 설정과 실행 방법은 [macOS 안내](apps/macos/README.md)를 참고하세요.

## 현재 범위

- 웹: React·TypeScript·Vite 기본 화면, npm workspaces, Oxlint
- macOS: 메뉴바 입력 화면과 공유 Xcode 스킴
- CI: 변경 감지로 앱, 웹과 하네스 검사를 선택하고 CI Result로 취합합니다. 새 선택 실행의 원격 확인과 필수 검사 연결은 남아 있습니다.
- 외부 Swift 패키지, AI 분석, EventKit 저장과 서버는 아직 추가하지 않았습니다.
- Swift Testing 테스트 타깃은 핵심 로직 구현 시 추가할 예정입니다.
- 기본 unsigned 앱 빌드는 GitHub에서 성공했습니다. 실제 앱 동작과 새 선택 CI의 원격 실행은 미검증입니다.
- 각 폴더의 `.gitkeep`을 유지합니다.

## 협업

기본 브랜치는 `develop`입니다. 작업은 `develop`에서 `feat/*`로 분기하고,
`feat/*` → `develop` → `main` 순서로 PR을 통해 병합합니다.
`main`과 `develop` 직접 푸시는 차단되어 있으며, 필수 승인 인원은 0명입니다.
병합 방식은 Merge commit을 사용합니다.

[개발 기준과 Git Flow](docs/development.md)

[CI 운영](docs/ci.md)에서 검사 범위와 최초 실행 절차를 확인합니다.

[코드 포맷 자동화](docs/formatting.md)에서 웹과 Swift의 포맷 수정 및 검사 명령을 확인합니다.

## Codex 하네스

Codex의 작업 진입점은 [AGENTS.md](AGENTS.md)입니다.
macOS Swift·SwiftUI 작업의 설계·명세·검증·리뷰·재개를 지원합니다.

```sh
npm run workflow:harness-check
npm run workflow:test
npm run workflow:resume -- --issue 4
```

[사용 안내](docs/ai-workflow/user-guide.md)와 [기록 형식](docs/ai-workflow/README.md)을 참고하세요.
실행 로그는 Git에서 제외한 `.tmp`에 보관합니다. Xcode 부재와 테스트 미실행은 성공으로 처리하지 않습니다.
