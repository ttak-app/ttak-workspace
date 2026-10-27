# 작업 명세: Swift 테스트 타깃 및 실행 환경 세팅

## 연결 정보

- 이슈: #13 / https://github.com/ttak-app/ttak-workspace/issues/13
- 브랜치: feat/swift-test-target/#13
- specRevision: 3
- 기준: origin/develop @ bc43d29a4d739158a6e40de7d0c4afd297bffd05

## 목적

기존 macOS 앱에 실제 실행 가능한 단위 테스트 타깃을 마련한다.
향후 기능별 테스트를 같은 타깃에 추가하고, 로컬과 CI에서 같은 명령으로 검증할 수 있게 한다.
사용자의 후속 진행 요청에 따라 아래 설계를 구현하고 로컬에서 검증한다. 게시와 원격 실행은 별도 요청 이후 확인한다.

## 구현 전 상태

- Xcode 프로젝트에는 `Ttak` 앱 타깃만 있고 `TtakTests`에는 안내 문서만 있다.
- 공유 `Ttak.xcscheme`의 TestAction에는 실행할 TestableReference가 없다.
- `npm run macos:test`와 실행 도구는 이미 있다. 타깃이 없으면 실패하도록 구현되어 있다.
- 앱에는 메뉴바 입력 화면만 있으며 테스트할 날짜 해석이나 저장 로직은 아직 없다.
- CI의 `macOS Build` job은 Swift 포맷 확인 후 unsigned Debug 앱 빌드만 수행한다.

## 작업 범위

### 포함

- Swift Testing을 사용하는 macOS 단위 테스트 타깃 `TtakTests` 추가.
- 기존 앱을 테스트 호스트로 연결하고 공유 스킴의 테스트 실행 대상에 등록.
- 앱 모듈 접근과 올바른 호스트 실행을 확인하는 최소 테스트 1개.
- 기존 `macos:test` 명령 재사용과 테스트 실패의 non-zero 종료 확인.
- 기존 macOS CI job에서 앱 빌드를 포함하는 테스트 실행, 관련 회귀 검사와 안내 문서 갱신.

### 제외

- 날짜 해석, 입력 검증 등 미구현 기능이나 테스트를 위한 제품 로직 신설.
- UI 자동화, 스냅샷 테스트, 실제 EventKit 및 온디바이스 모델 호출.
- 외부 테스트 패키지, 새 프레임워크나 아키텍처, 커버리지 기준.
- 웹 테스트 환경, 별도 CI job 및 runner, GitHub 보호 규칙 변경.
- 커밋, push 및 PR 게시.

## 설계 결정

### 타깃과 파일 구성

- `Ttak.xcodeproj/project.pbxproj`에 macOS unit-testing bundle인 `TtakTests`를 추가한다.
- 앱과 같은 Swift 6 언어 모드 및 macOS 26 최소 버전을 사용한다.
- 앱 타깃 의존성과 Debug 테스트 접근을 연결해 `@testable import Ttak`이 가능하도록 한다.
- 테스트는 기존 `apps/macos/TtakTests/`에 둔다. 앱 소스 파일을 테스트 타깃에 복사하거나 중복 컴파일하지 않는다.
- Swift Testing은 도구 체인에 포함된 `Testing` 모듈을 사용하며 외부 패키지로 추가하지 않는다.
- 기존 공유 스킴의 TestAction에 `TtakTests`를 등록한다. 단일 타깃에 별도 테스트 플랜은 우선 추가하지 않는다.

### 첫 테스트의 목적

- 첫 파일은 `TtakTests/TestEnvironmentTests.swift`로 두고 `@Test`로 최소 1개 테스트를 실행한다.
- 기존 앱 모듈의 실제 타입을 참조할 수 있고, 앱 호스트의 Bundle Identifier가 현재 앱 설정과 일치하는지 확인한다.
- 이 테스트는 타깃, 모듈 연결 및 실행 경로 확인용이다. 앱 UI나 자연어 분석 기능의 품질 검증으로 보고하지 않는다.
- `#expect(true)` 같은 무조건 성공 테스트나 가상의 날짜 계산 로직을 만들지 않는다.
- 실제 기능 테스트는 해당 기능 구현 시 같은 타깃에 추가한다.

### 실행 명령과 CI

- 로컬은 기존 `npm run macos:test`를 그대로 사용한다. Xcode의 Test 실행도 같은 공유 스킴을 사용한다.
- 실행 도구는 현재 `xcodebuild test`, macOS destination과 `.tmp` DerivedData 경로를 재사용한다.
- 테스트가 실제로 1개 이상 실행된 로그를 확인한다. 타깃 존재나 빌드 성공만으로 테스트 성공을 판정하지 않는다.
- Debug 정보는 앱과 테스트 모두 `dwarf-with-dsym`으로 생성한다. 로컬 고의 실패 검증에서 기존 `dwarf` 설정은 Xcode의 심볼 조회 단계에서 대기했고, dSYM 생성 후에는 실제 assertion 실패가 종료 코드 65로 정상 전달됐다.
- 기존 `macOS Build` job 이름과 변경 감지 플래그, `CI Result` 연결을 유지한다.
- 해당 job은 Swift 포맷 검사 후 `macos:test`를 실행하도록 제안한다. test action이 앱과 테스트를 빌드하므로 CI에서 별도 `macos:build`를 먼저 반복하지 않는다. 로컬 빌드 명령은 유지한다.
- 후속 Swift 변경에서는 macOS 검사만, 웹 전용 변경에서는 웹 검사만 실행하는 기존 선택 정책을 유지한다.
- 이번 구현 PR은 공통 `ci.yml`을 바꾸므로 기존 정책에 따라 전체 검사가 선택될 수 있다. 이를 앱 간 의존성으로 해석하거나 감지 정책을 변경하지 않는다.
- 테스트 실패는 기존 job 실패를 통해 `CI Result` 실패로 전달된다. 필수 검사 이름이나 ruleset은 추가로 변경하지 않는다.

### 환경과 실패 처리

- 현재 로컬 Xcode는 27.1, CI는 Xcode 26.6이다. 구현 후 양쪽에서 실제 테스트 실행을 확인한다.
- 기존 unsigned 실행을 우선 검증하되, 앱 호스트와 테스트 번들의 로딩 및 서명 제약이 있는지 실제 실행으로 확인한다.
- 서명 제약이 확인되면 실패 원인을 기록하고 필요한 로컬 테스트용 설정만 검토한다. 배포 인증서나 비밀 값을 추가하거나 앱 샌드박스를 제거해 우회하지 않는다.
- 환경 실패, 0개 실행, 테스트 실패를 성공으로 바꾸지 않는다. 실행 도구 변경이 필요하면 해당 이유와 범위를 명세에 반영한다.
- 고의 실패 전달 검증은 로컬 임시 변경으로 수행하고 반드시 원복한다. 실패 테스트를 커밋하거나 원격 PR을 추가로 만들지 않는다.

## 예상 변경 파일

- `apps/macos/Ttak.xcodeproj/project.pbxproj`
- `apps/macos/Ttak.xcodeproj/xcshareddata/xcschemes/Ttak.xcscheme`
- `apps/macos/TtakTests/TestEnvironmentTests.swift`, `apps/macos/TtakTests/README.md`
- `.github/workflows/ci.yml`, `tools/ci/ci.test.mjs`
- `README.md`, `apps/macos/README.md`, `docs/ci.md`, `docs/rules/macos-development.md`의 테스트 부재 설명
- `tools/macos/check.mjs`와 대응 검사는 실제 실행에서 보완 필요가 확인될 때만 수정

## 완료 조건

- AC-1: Xcode에서 `TtakTests`가 macOS 단위 테스트 타깃으로 인식되고 기존 앱 실행 및 빌드 구성이 유지된다.
- AC-2: 공유 스킴과 `npm run macos:test`에서 Swift Testing 테스트가 최소 1개 실제 실행되며 앱 모듈 및 호스트 연결 확인이 통과한다.
- AC-3: 테스트 실패가 명령의 non-zero 종료로 전달되고, 임시 실패 검증을 원복한 후 다시 성공한다. 실행한 테스트가 없으면 완료로 처리하지 않는다.
- AC-4: 기존 macOS CI job에서 빌드와 테스트가 성공하고 결과가 기존 `CI Result`에 반영된다. 관련 없는 앱을 검사하는 새 조건이나 runner는 추가하지 않는다.
- AC-5: 실행 방법과 검증 범위가 문서와 일치하고 관련 구조 검사, 포맷 및 도구 회귀 검사가 통과한다. 로컬과 원격의 미실행 상태는 별도로 보고한다.

## 검증 방법

| 완료 조건 | 확인 방법 | 기대 결과 |
|---|---|---|
| AC-1 | Xcode 타깃 목록 및 공유 스킴 확인, `npm run macos:build` | 앱과 테스트 타깃 인식, 기존 앱 빌드 성공 |
| AC-2 | `npm run macos:test`, 실행 로그 또는 결과 번들의 테스트 수 확인 | 1개 이상 실제 실행, 성공 |
| AC-3 | 최소 테스트의 검증 값을 로컬에서 임시로 틀리게 한 뒤 실행, 원복 후 재실행 | 실패 시 non-zero, 원복 후 성공 |
| AC-4 | 기존 CI 도구 검사와 게시 후 실제 PR 실행 확인 | 기존 선택 정책 유지, macOS 테스트 결과와 CI Result 일치 |
| AC-5 | `format:check:macos`, `workflow:harness-check`, `workflow:test`, `node --test tools/ci/*.test.mjs`, diff 및 문서 검토 | 관련 검사 통과, 실제 관찰 및 미검증 구분 |

위 npm 명령은 저장소 루트에서 `npm run 명령`으로 실행한다.
구현 단계의 실제 검사 결과를 검토한 뒤 완료 조건을 판단한다. 원격 실행은 게시 전까지 미검증으로 남긴다.

## 미결정 사항

- 추가 제품 정책 결정은 없다.
- 로컬 Xcode 27.1에서 unsigned 앱 호스트의 테스트 실행과 고의 실패 전달을 확인했다. CI Xcode 26.6 실행은 게시 후 확인할 항목이다.
- 로컬 설정과 CI 정의를 구현하되 GitHub runner에서의 실행은 게시 후 확인한다.

## 공식 근거

- [Swift Testing 공식 저장소](https://github.com/swiftlang/swift-testing): `Testing`, `@Test`, `#expect`와 도구 체인 기본 제공 안내.
- [Apple의 Xcode 테스트 타깃 안내](https://developer.apple.com/documentation/xcode/adding-tests-to-your-xcode-project)

## 주요 설계 변경

| specRevision | 변경한 결정 | 이유 |
|---|---|---|
| 1 | 기존 앱에 단위 테스트 타깃과 공유 스킴을 연결하고 기존 macOS job에서 테스트 실행 | #13 초기 실행 환경 설계, 추가 runner와 중복 앱 빌드 방지 |
| 2 | 승인된 설계 구현과 로컬 검증 진행 | 사용자의 후속 진행 요청 반영. 게시와 원격 실행 확인은 별도 단계 |
| 3 | Debug 정보를 dSYM으로 생성 | 기존 dwarf 설정의 실패 보고 중 심볼 조회 대기를 관찰. dSYM 적용 후 실제 실패가 정상 종료됨을 확인 |
