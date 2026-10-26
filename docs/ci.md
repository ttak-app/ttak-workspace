# CI 운영

Swift macOS 앱과 React 랜딩 페이지를 [하나의 GitHub Actions 워크플로](../.github/workflows/ci.yml)에서 검증한다.
CI는 코드 검사와 빌드를 담당한다. 웹 호스팅, PR 프리뷰 배포, 앱 서명, 공증과 배포는 후속 CD 작업이다.

## 실행 조건과 검사

[Kareer PR #15의 설정](https://github.com/team-kareer/kareer-client/blob/0714c0e72a407552b03b72135fbd3b375d8bccdf/.github/workflows/ci.yml)처럼
`pull_request`에 `types`를 지정하지 않는다. `main`, `develop` 대상 PR 생성, 추가 커밋과 다시 열기에서 실행한다.
제목이나 본문 수정과 Draft 해제는 워크플로를 호출하지 않으므로 별도 스킵 기록도 만들지 않는다.
PR 대상 브랜치만 변경해도 자동 재검사하지 않는다. 새 대상 검증이 필요하면 PR을 닫았다 다시 열거나
새 커밋을 push해 현재 대상 기준으로 검사한다. 과거 실행을 단순 재실행하는 방식은 새 대상 검증으로 간주하지 않는다.
초안 PR도 검사한다. 같은 PR의 새 검증은 이전 검증을 취소하며 별도 push 트리거는 두지 않는다.
작업 이름은 고정하고 concurrency 그룹은 PR 번호를 사용한다.
검사 작업은 기본 checkout 동작으로 PR 브랜치와 대상 브랜치의 임시 merge commit을 검사한다.

| 검사 이름 | 환경 | 실행 내용 | 제한 시간 |
| --- | --- | --- | --- |
| `Changes` | Ubuntu 24.04, Node 24 | PR 전체 변경 감지와 대상 선택 | 5분 |
| `Harness` | Ubuntu 24.04, Node 24, npm 11.3.0 | 선택된 구조 검사 또는 도구 테스트 | 10분 |
| `Web` | Ubuntu 24.04, Node 24, npm 11.3.0 | `npm ci` 후 `format:check:web`, `lint:web`, `check-types:web`, `build:web` | 10분 |
| `macOS Build` | macOS 26 ARM64, Xcode 26.6, Node 24, npm 11.3.0 | `format:check:macos` 후 `macos:test`로 앱 빌드와 테스트 | 20분 |
| `CI Result` | Ubuntu 24.04, Node 24 | 감지 출력과 선택된 검사 결과 취합 | 5분 |

표의 npm 검사 명령은 저장소 루트에서 `npm run 명령`으로 실행한다.
Changes 성공 뒤 선택된 세 검사 작업을 병렬로 실행하고, CI Result는 감지 실패나 선행 작업의 실패와 생략에도 실행한다.
선택되지 않은 앱 job에는 runner를 할당하지 않으며 웹 설치나 Xcode 실행도 생략한다.
포맷 검사는 [코드 포맷 자동화](formatting.md)를 따른다. 앱별 포맷 설정 변경도 해당 앱만 선택하고,
선택한 포맷 검사 실패는 기존 job 실패와 CI Result 판정으로 전파한다. CI는 파일을 수정하지 않는다.
모든 작업은 저장소 내용 읽기 권한만 사용한다. 배포 토큰이나 인증서, 개인 일정 데이터는 필요하지 않다.

## 변경 감지와 영향 범위

[changes.mjs](../tools/ci/changes.mjs)에 분류를 모아 관리한다. Changes만 전체 Git 이력을 checkout하고,
이벤트의 base SHA와 head SHA의 merge-base부터 head까지 비교한다. 마지막 커밋만 보지 않고 PR 전체의 변경을 확인한다.
Git 인자를 배열로 전달하고 NUL 구분 경로를 읽는다. rename 감지를 꺼 삭제와 추가 경로를 모두 분류하므로 앱 사이 이동의 양쪽 영향이 유지된다.
파일 개수가 많은 PR도 REST 목록 제한 없이 처리한다. Git 실패, 누락된 이력과 불완전한 출력은 감지 실패다.
알 수 없는 코드나 실행 설정은 자동 생략하지 않고 분류 오류로 알려 영향표를 갱신하게 한다.

| 변경 대상 | 실행할 검사 |
| --- | --- |
| `apps/macos` 코드, Xcode 설정과 앱 리소스 | macOS Build |
| `apps/web` 코드, 설정과 앱 리소스 | Web |
| 루트 `package-lock.json` | Web |
| `tools/macos` | macOS Build, Harness 구조와 도구 테스트 |
| `tools/ai-workflow`, `tools/branch-review` | Harness 구조와 도구 테스트 |
| `AGENTS.md`, 앱별 루트 `AGENTS.md`, `.agents`, `docs/rules`, `docs/ai-workflow`, `docs/branch-review` | Harness 구조 |
| `docs/ai-workflow/templates/status.json` | Harness 구조와 도구 테스트 |
| 루트 `.gitignore`, `.editorconfig`, 연결된 개발과 CI 문서, GitHub 템플릿 | Harness 구조 |
| 루트 `package.json`, `.nvmrc`, `ci.yml`, `tools/ci` | 전체 |
| 일반 설명 문서와 `.gitkeep` | 앱 빌드와 도구 테스트 생략 |
| `.coderabbit.yaml` | 리뷰 앱 설정이므로 앱 빌드와 도구 테스트 생략 |

여러 대상 변경은 합집합을 실행한다. 하네스 문서와 `.gitkeep`은 앱 코드 패턴보다 먼저 구분한다.
`Harness`는 구조만 선택되면 `workflow:harness-check`만 실행한다. 도구 테스트가 선택되면
기존 `workflow:test`와 `node --test tools/ci/*.test.mjs`를 실행하며 두 단계의 실제 outcome을 별도로 출력한다.

보조 경로도 실제 소비 관계를 기준으로 분류한다.
루트 `.editorconfig`, `docs/development.md`, `docs/ci.md`와 GitHub 이슈 및 PR 템플릿은
기존 하네스가 필수 파일이나 문서 링크로 확인하므로 구조 검사만 실행한다.
이 파일들을 삭제해 링크가 깨진 경우도 잡으며 앱 빌드와 도구 회귀 테스트는 생략한다.
루트 README, 앱 루트 README와 현재 `TtakTests/README.md`는 설명 문서로 생략한다.
반면 앱 source, public, Resources 안의 README나 Markdown은 앱 리소스일 수 있어 앱 검사에 포함한다.
`docs`의 일반 Markdown은 생략하지만 하네스 연결 문서는 구조 검사를 실행한다.
하네스 상태 JSON 템플릿은 기존 회귀 테스트가 실제 읽는 입력이므로 구조와 도구 테스트를 함께 실행한다.
루트 잠금 파일은 현재 웹 의존성만 관리한다. 루트 package와 Node 버전은 공통 실행 환경이라 전체를 검사한다.
`.gitignore`는 기존 구조 검사가 `.tmp/` 제외를 확인하는 입력이므로 단독 변경에도 구조 검사를 실행한다.

각 대상의 선택과 생략 이유는 Actions step summary에 남긴다.

## 최종 결과와 병합 판정

[result.mjs](../tools/ci/result.mjs)는 `toJSON(needs)`를 환경 변수 JSON으로 읽는다.
감지 성공, 버전과 완료 표식, 정확한 `true`/`false` 플래그를 먼저 확인한 뒤 각 job 상태를 대조한다.

- 선택된 작업은 `success`여야 한다. 실패, 취소, 예상 밖 생략과 결과 누락은 실패다.
- 선택되지 않은 작업은 `skipped`여야 한다. 의도된 생략은 통과한다.
- Harness가 실행되면 선택된 내부 단계는 `success`, 선택되지 않은 단계는 `skipped`여야 한다.
- 일반 설명 문서만 변경해 모든 검사 job을 생략해도 감지 성공과 의도된 생략을 확인한 후 통과한다.
- 감지 실패, 누락된 출력이나 잘못된 플래그는 실패한다. 실패를 변경 없음으로 바꾸지 않는다.

워크플로 전체에 경로 필터를 두지 않고 job을 조건부 실행해 필수 검사 대기를 방지한다.
main과 develop의 필수 상태 검사는 GitHub Actions가 제공하는 `CI Result` 하나다.
결과 취합은 설치나 빌드를 반복하지 않고 종료 상태만 검사한다.

## 버전과 캐시

- Node는 [.nvmrc](../.nvmrc)의 24 계열을 사용한다. 패치 버전까지 고정하지는 않는다.
- npm은 [package.json](../package.json)의 `packageManager`에 맞춰 11.3.0을 설치한다.
  향후 이 값을 바꾸면 워크플로의 Harness, Web, macOS Build npm 설치 단계도 함께 갱신한다.
- Web만 루트 `package-lock.json`을 키로 npm 다운로드 캐시를 사용한다.
  `node_modules`는 캐시하지 않고 매번 `npm ci`로 잠금 파일 기준 설치를 한다.
- Harness와 macOS Build는 Node 기본 모듈만 사용하므로 앱 의존성을 설치하지 않고 npm 자동 캐시를 끈다.
- Xcode는 `DEVELOPER_DIR=/Applications/Xcode_26.6.app/Contents/Developer`로 선택한다.
  runner의 기본 Xcode가 바뀌어도 이 경로를 사용하며, 설치 목록에서 제거되면 환경 확인 단계가 실패한다.
- 공식 `actions/checkout` v7.0.1과 `actions/setup-node` v7.1.0을 검증한 전체 커밋 SHA로 고정한다.
  업데이트 시 공식 태그, 변경 내용과 입력 옵션을 확인하고 SHA와 버전 주석을 함께 바꾼다.

macOS runner 이미지는 계속 갱신된다. [공식 runner 목록](https://github.com/actions/runner-images#available-images)과
[macOS 26 ARM64 설치 목록](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md)을 확인한다.
Actions 입력은 [checkout](https://github.com/actions/checkout/blob/3d3c42e5aac5ba805825da76410c181273ba90b1/action.yml)과
[setup-node](https://github.com/actions/setup-node/blob/949feb2413d6458794dcd2491c4babbbce0c15c1/action.yml)를 기준으로 했다.

## macOS 검증 범위

`macos:test`는 공유 Ttak 스킴의 Debug 앱과 `TtakTests`를 `CODE_SIGNING_ALLOWED=NO`로 빌드하고
Swift Testing 테스트를 실행한다. 테스트 실패는 job 실패와 `CI Result` 실패로 전달된다.
같은 job에서 별도 `macos:build`를 먼저 반복하지 않는다. 로컬에서 빌드만 확인할 때는 해당 명령을 사용할 수 있다.
배포용 앱이나 설치 파일을 만들지 않는다.

기본 테스트는 앱 모듈과 테스트 호스트 연결을 확인하며 실제 실행 수를 Swift Testing 요약에서 확인한다.
XCTest의 `Executed 0 tests` 출력만으로 Swift Testing 테스트 실행 여부를 판단하지 않는다.
앱이나 테스트 코드 변경 시 기존 macOS job을 선택하며, 웹 전용 변경에서는 이 job을 실행하지 않는다.
공통 CI 정의 자체를 변경한 PR은 기존 영향표에 따라 전체 검사를 실행한다.

테스트 타깃은 로컬 Xcode 27.1에서 실행을 확인했다. 이 변경의 GitHub Xcode 26.6 실행은 게시 후 확인한다.

Swift 빌드 통과는 Foundation Models의 한국어 분석 품질, 메뉴바 UI 동작,
미리 알림 권한이나 EventKit 저장 성공을 보증하지 않는다. 이 동작은 실제 Mac에서 별도로 검증한다.
로컬에 전체 Xcode 26 이상이 없으면 로컬 앱 빌드는 미검증으로 남긴다.
GitHub macOS runner의 빌드 성공과 구분해 보고한다.

## 로컬 확인과 실패 대응

```sh
npm ci
npm run workflow:harness-check
npm run workflow:test
node --test tools/ci/*.test.mjs
npm run format:check:web
npm run lint:web
npm run check-types:web
npm run build:web
# 전체 Xcode 26 이상이 설치된 Mac에서 실행
npm run format:check:macos
npm run macos:build
npm run macos:test
```

워크플로 파일은 `actionlint .github/workflows/ci.yml`로 정적 검사한다.
actionlint는 이 저장소의 앱 의존성이 아니며 검사한 버전은 로컬 증적에 남긴다.
실제 GitHub runner의 실행은 별도로 확인해야 한다.

PR의 실패한 검사 상세 로그에서 실패 단계와 종료 코드를 먼저 확인한다.
Web 설치 실패는 Node와 npm 버전, 잠금 파일과 설치 로그를 확인하고,
macOS 환경 실패는 선택한 Xcode의 실제 설치 경로와 버전을 확인한다.
코드 문제는 수정 커밋으로 다시 검사한다. 일시적인 runner 장애만 재실행하며 실패를 무시하는 설정으로 우회하지 않는다.

로컬 [하네스 증적](ai-workflow/README.md)은 `.tmp`에 저장하는 개발 기록이다.
CI에서는 로컬 status나 수동 리뷰에 의존하는 `workflow:pr-check`를 실행하지 않는다.
하네스 구조 검사와 도구 회귀 테스트는 실제 npm 명령으로 실행한다.

## 원격 실행과 필수 검사 연결 현황

커밋 `6cfe93c`의 [GitHub 실행 40261505763](https://github.com/ttak-app/ttak-workspace/actions/runs/40261505763)에서
Changes, Harness, Web, macOS Build와 CI Result가 모두 성공했다. 웹과 Swift 포맷 검사도 해당 job에서 통과했다.
이는 해당 실행의 성공 기록이며, 웹 전용, Swift 전용과 문서 전용 PR의 선택 실행을 모두 실증했다는 뜻은 아니다.

[#11](https://github.com/ttak-app/ttak-workspace/issues/11)에서 기존 활성 ruleset에 다음 필수 검사를 연결하고,
각 브랜치의 실제 적용 규칙을 GitHub API로 재조회했다.

| 대상 | 기존 ruleset | 필수 검사와 제공자 |
| --- | --- | --- |
| main | [ttak-main / 25779102](https://github.com/ttak-app/ttak-workspace/rules/25779102) | `CI Result`, GitHub Actions (App ID `15368`) |
| develop | [ttak-develop / 25779101](https://github.com/ttak-app/ttak-workspace/rules/25779101) | `CI Result`, GitHub Actions (App ID `15368`) |

필수 검사 추가 외 대상 브랜치, 활성 상태, 우회 없음, PR 필수, 승인 0명, Merge commit,
삭제 및 force push 차단 설정은 변경 전후 비교로 유지됨을 확인했다.
최신 대상 브랜치 반영 강제(`strict_required_status_checks_policy`)는 추가하지 않았다.

이 규칙은 `CI Result`가 실패하거나 결과를 기다리는 PR의 병합을 제한한다.
확인 시점에 열린 PR이 없어 설정 변경 후 실패 또는 대기 상태의 실제 병합 차단과
성공한 PR의 병합 가능 상태는 관찰하지 않았다. 후속 PR에서 확인하며 검증을 위한 PR 생성이나 실제 merge는 수행하지 않았다.
규칙 의미와 API 항목은 [GitHub 필수 상태 검사 문서](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets#require-status-checks-to-pass-before-merging)와
[GitHub ruleset API](https://docs.github.com/en/rest/repos/rules#update-a-repository-ruleset)를 따른다.

과거 [#3 명세](ai-workflow/tasks/3/spec.md)는 당시 작업 기록으로 유지한다.
현재 누락 보완 범위와 검증 방법은 [#11 명세](ai-workflow/tasks/11/spec.md)에 기록한다.
후속 CD는 main에 실제 반영된 변경으로 배포 대상을 다시 판별한다.
PR의 임시 플래그를 그대로 재사용하지 않으며 Swift만 변경하면 웹을 배포하지 않는다.
