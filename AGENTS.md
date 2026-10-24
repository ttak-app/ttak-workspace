# Ttak — Codex 작업 진입점

Ttak은 자연어 입력을 Apple 미리 알림에 등록하는 macOS 메뉴바 앱이다.
주 개발 대상은 `apps/macos`의 Swift·SwiftUI 앱이며 `apps/web`은 React 랜딩이다.
Codex만 사용한다. Claude 설정이나 웹 앱 아키텍처를 macOS 앱에 추가하지 않는다.

## 필요한 문서만 읽기

- 코드 변경·리뷰: [공통 코딩 컨벤션](docs/rules/coding-convention.md)을 읽고 작업 경로의 Swift 또는 웹 규칙만 적용한다.
- 브랜치·커밋·PR·라벨: [Git 컨벤션](docs/rules/git-convention.md)을 기준으로 작성한다.

- 작업 시작·재개·검증·게시: [작업 흐름](docs/rules/ai-workflow.md)
- macOS 구현·설계·리뷰: [macOS 경계와 검증](docs/rules/macos-development.md)
- 이슈별 명세·로컬 기록·명령: [작업 기록](docs/ai-workflow/README.md)
- 사용자용 요청 예시: [사용 안내](docs/ai-workflow/user-guide.md)
- 기존 GitHub 운영 기준: [개발 기준](docs/development.md)

연결 이슈가 있으면 `npm run workflow:resume -- --issue 번호`와 해당 명세를 읽는다.
명시적 읽기 전용 요청에서는 기록을 수정하지 않는다. 원격 ref를 자동 fetch하지 않는다.

## 스킬 라우팅

| 요청 | 스킬 |
| --- | --- |
| GitHub 이슈 생성 | [create-issue](.agents/skills/create-issue/SKILL.md) |
| 구현 설계·명세 | [logic-design](.agents/skills/logic-design/SKILL.md) |
| 복잡한 Swift 상태·책임·비동기 구조 설계 | [logic-architecture](.agents/skills/logic-architecture/SKILL.md) |
| 브랜치 변경 리뷰 | [branch-review](.agents/skills/branch-review/SKILL.md) |
| PR 준비·생성·수정 | [create-pr](.agents/skills/create-pr/SKILL.md) |

스킬은 작업 방법을 제공하며 실행 권한을 늘리지 않는다. 위임·서브에이전트는 요청 없이 실행하지 않는다.
[시작 확인](.agents/checklists/preflight.md) → 해당 작업 →
[완료 확인](.agents/checklists/postflight.md) → [보고](.agents/checklists/debrief.md)를 필요한 범위에 적용한다.

## 작업 범위

- 사용자와 합의한 요구사항만 명세·구현으로 확정한다. 제안·일반 질문은 결정이 아니다.
- 이미 제공된 정보와 권한은 재사용한다. 필요한 범위가 분명하면 반복 승인받지 않는다.
- 현재 컨벤션 문서에 없는 정책, 라이브러리, 이슈, CI, 하네스 규칙을 새로 정할 필요가 있으면 사용자와 논의한다.
- 기본 브랜치에 직접 구현·푸시하지 않는다. 사용자가 지정한 브랜치는 유지한다.
- 새 브랜치의 합의된 기본 형식은 `feat/작업명/#이슈번호`다. 이 작업의 `chore/agent-harness-setting/#4`는 사용자가 지정한 기존 브랜치다.
- 명세의 합의 내용이 바뀌면 이유와 완료 조건·검증 영향을 갱신한다. 다른 사용자의 변경을 덮어쓰지 않는다.
- 실제 실패·미실행·환경 제약을 성공으로 보고하지 않는다. Xcode가 없으면 macOS 빌드는 미검증이다.
- 커밋·push·PR·merge는 각각 요청 범위의 권한을 확인한다. PR 요청 자체로 merge하지 않는다.
- 한국어로 결과와 한계를 보고한다.
