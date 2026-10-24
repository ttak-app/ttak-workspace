# 개발 기준

- 저장소: macOS 앱과 React 랜딩 페이지를 함께 관리하는 모노레포
- macOS: Swift 6 언어 모드, SwiftUI, macOS 26 이상
- 웹: React, TypeScript, Vite, npm, Node.js 24
- 온디바이스 분석: Foundation Models (실기기 검증 후 연결)
- 미리 알림: EventKit (권한 및 저장 연동은 후속 작업)
- 별도 서버 및 Turborepo 없음

## Git Flow

`main`, `develop`, `feat/*` 브랜치로 협업합니다.

| 브랜치 | 역할 | 병합 경로 |
| --- | --- | --- |
| `main` | 배포 기준 | `develop`에서 PR |
| `develop` | 개발 통합·기본 브랜치 | `feat/*`에서 PR |
| `feat/*` | 기능·수정·문서 등 개별 작업 | `develop`에서 분기 |

### 작업 순서

```sh
git switch develop
git pull --ff-only origin develop
git switch -c 'feat/macos-기능명/#이슈번호'
# 작업 후 커밋
git push -u origin 'feat/macos-기능명/#이슈번호'
```

1. 공통 이슈 템플릿으로 작업 목적과 완료 기준을 기록합니다.
2. `develop`의 최신 커밋에서 `feat/작업명/#이슈번호`를 생성합니다. 웹 작업은 `feat/web-기능명/#이슈번호`처럼 구분합니다.
3. 작업 브랜치에서 커밋·푸시하고 `develop`을 대상으로 PR을 엽니다. PR에 관련 이슈를 연결하고 검증 결과를 기록합니다.
4. 변경 내용과 검증 결과를 확인한 후 Merge commit으로 병합합니다.
5. 배포할 때 `develop` → `main` PR을 열고 Merge commit으로 병합합니다.
6. 다음 개발 주기 전에 `main`의 병합 커밋을 `develop`으로 동기화해야 할 때는 `main` → `develop` PR을 사용합니다.

수정·문서 작업도 `feat/*`에서 진행하고 커밋 접두사로 구분합니다.
커밋 접두사는 `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`를 사용합니다.

### GitHub 적용 설정

- 기본 브랜치: `develop`
- `main`, `develop`: 활성 보호 규칙 적용
- 직접 푸시 금지, 모든 변경은 PR로 병합
- 필수 승인 인원: 0명 (별도 승인 없이 PR 작성자가 병합 가능)
- 관리자·팀·앱의 우회 목록 없음
- 브랜치 삭제와 force push 차단
- Merge commit만 허용, Squash/Rebase merge 비활성화
- 자동 브랜치 삭제 비활성화 (`develop`을 보존하고 완료한 `feat/*`만 수동 삭제)
- 필수 CI 검사는 아직 없음

PR의 출발 브랜치와 대상 브랜치 조합은 위 협업 규칙으로 준수합니다.
현재 GitHub 보호 규칙은 PR 필수 여부를 검사하며 `feat/*` → `develop` 등의 출발 브랜치 이름까지 강제하지 않습니다.

### 이슈·PR 템플릿

- 이슈: `.github/ISSUE_TEMPLATE/issue_template.md`의 Tasks, Description, ETC를 작성합니다.
- PR: Summary, Tasks, Validation, Git Flow를 작성하고 선택적으로 To Reviewer와 Screenshot을 남깁니다.
- 이슈 제목의 `[Type]`은 `[Feat]`, `[Fix]`, `[Chore]`, `[Docs]` 등으로 바꿉니다.
- 이슈를 완료하는 PR은 `Closes #번호`, 부분 작업은 `Refs #번호`로 연결합니다.
- 이슈 생성은 팀의 작업 기록 규칙이며, GitHub 브랜치 보호 자체가 이슈를 요구하는 것은 아닙니다.
- 템플릿이 기본 브랜치 `develop`에 병합되어야 GitHub 작성 화면에 기본으로 표시됩니다.
- 템플릿 구성 참고: https://github.com/team-kareer/kareer-client/tree/HEAD/.github

### Codex 작업 하네스

[AGENTS.md](../AGENTS.md)와 [작업 흐름](rules/ai-workflow.md)을 사용합니다.
사용자가 기존 브랜치를 직접 지정하면 그 브랜치를 유지합니다.
현재 #4의 `chore/agent-harness-setting/#4`도 이 경우이며 새 브랜치 규칙을 일괄 변경하지 않습니다.
