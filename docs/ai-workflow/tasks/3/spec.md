# 작업 명세: CI 세팅

## 연결 정보

- 이슈: #3 / https://github.com/ttak-app/ttak-workspace/issues/3
- 브랜치: chore/ci-setting/#3
- specRevision: 1

## 목적

Swift macOS 앱과 React 랜딩 페이지의 변경을 GitHub Actions에서 검증한다.
앱 개발과 이후 랜딩 페이지 개발에 같은 CI를 사용하고, 배포 자동화는 별도로 연결한다.
사용자 요청에 따라 설계를 서브 에이전트에게 전달해 구현 결과를 받고 주 에이전트가 리뷰한다.

## 작업 범위

### 포함

- `.github/workflows/ci.yml`에 독립된 Harness, Web, macOS Build 작업 구성.
- main, develop을 대상으로 하는 PR 생성, 재개, 추가 커밋에 세 검사 실행.
- Node 24, npm 11.3.0, 웹 의존성의 `npm ci` 및 npm 다운로드 캐시.
- macOS 26 실행 환경과 설치된 안정판 Xcode 26 버전을 명시적으로 선택.
- 동일 PR의 이전 실행 취소, 실행 시간 제한, 읽기 전용 저장소 접근 권한.
- 기존 npm 검사 명령 재사용, CI 동작과 실패 대응 및 필수 검사 연결 절차 문서화.
- 로컬에서 가능한 검사와 워크플로 정적 검사, 서브 에이전트 구현 결과에 대한 주 에이전트 리뷰.
- 후속 PR에서 실제 GitHub 실행을 확인하고 기존 main, develop 규칙에 필수 검사를 연결하는 계획.

### 제외

- 현재 요청에 포함되지 않은 커밋, push, PR 생성, merge.
- 실제 검사 실행 전에 원격 필수 검사 설정 변경 또는 통과 판정.
- Cloudflare 등 호스팅 선정, 랜딩 페이지 CD, 앱 서명, 공증, 배포.
- Swift 테스트 타깃 신설, SwiftLint 등 새 컨벤션 도구, 자동 라벨링, 브랜치 규칙 추가.
- 앱 기능, 기존 하네스 엔진, package 의존성과 잠금 파일의 무관한 변경.

## 설계 결정

- 파일 구조와 책임: CI는 `.github/workflows/ci.yml`, 운영 설명은 `docs/ci.md`, 구현 명세는 이 파일에 둔다. 기존 문서에는 필요한 링크와 현재 상태만 반영한다.
- 상태와 데이터 흐름: PR의 병합 대상이 main 또는 develop이면 세 작업을 병렬로 실행한다. 최초 구성에서는 경로 필터를 사용하지 않아 누락되거나 계속 대기하는 필수 검사를 피한다. 별도 push 트리거로 같은 커밋을 중복 실행하지 않는다.
- Harness: Ubuntu에서 `npm run workflow:harness-check`, `npm run workflow:test`를 실행한다. 하네스는 Node 기본 모듈을 사용하므로 불필요한 앱 의존성 설치는 하지 않는다.
- Web: Ubuntu에서 `npm ci` 후 `lint:web`, `check-types:web`, `build:web`를 실행한다. 루트 잠금 파일과 npm workspaces를 사용한다.
- macOS Build: macOS 26에서 선택한 Xcode 버전과 Node를 확인하고 `npm run macos:build`로 서명 없는 Debug 앱 빌드를 수행한다. Xcode 버전은 구현 시 공식 실행 환경의 설치 목록으로 확인한다.
- 재현성: 외부 Actions는 공식 저장소의 확인된 커밋 SHA를 사용하고 해당 버전을 주석으로 표시한다. Node 버전은 `.nvmrc`, npm은 현재 packageManager와 맞춘다.
- 실패 처리: 실제 명령의 non-zero 종료를 CI 실패로 유지한다. continue-on-error로 검사 실패를 숨기지 않는다. 실행 시간 제한과 PR별 동시 실행 제어를 사용한다.
- 로컬 하네스 증적과 CI: CI는 기존 npm 명령을 직접 실행한다. 개발자 컴퓨터의 `.tmp` 기록이나 수동 리뷰 결과를 요구하는 `workflow:pr-check`는 CI로 옮기지 않는다.
- Swift 테스트: 현재 공유 스킴에 테스트 타깃이 없어 `macos:test`는 실행하지 않으며 테스트 통과로 표현하지 않는다. 테스트 타깃 도입 시 연결한다.
- 운영 단계: 파일 구현 후 원격 실행 확인과 main, develop의 필수 상태 검사 연결이 남는다. 승인 0명, 직접 push 차단, Merge commit 정책은 유지한다. 이 단계가 끝나기 전 #3 전체 완료로 보고하지 않는다.

## 완료 조건

- AC-1: main, develop 대상 PR에서 Harness, Web, macOS Build가 모두 실행되도록 정의되고 PR 추가 커밋에 갱신된다.
- AC-2: Harness와 Web은 기존 검사 명령을 실행하고 앱과 웹의 CI를 한 워크플로에서 관리한다.
- AC-3: macOS Build는 macOS 26과 명시한 Xcode 26 환경에서 기존 unsigned 빌드 명령을 실행하도록 정의된다.
- AC-4: 버전 선택, 의존성 설치, 캐시, 최소 권한, 시간 제한과 이전 PR 실행 취소가 구성되고 YAML 및 Actions 정적 검증을 통과한다.
- AC-5: 문서에 CI와 CD의 경계, 로컬 검증 방법, Swift 테스트 부재, 원격 검증과 필수 검사 연결 절차 및 미완료 상태가 정확히 기록된다.
- AC-6: 게시 후 실제 GitHub의 세 검사 성공과 main, develop 필수 검사 연결을 확인한다. 현재 로컬 구현 단계에서는 대기 상태로 남긴다.

## 검증 방법

| 완료 조건 | 확인 방법 | 기대 결과 |
| --- | --- | --- |
| AC-1 | 워크플로 이벤트, 대상 브랜치와 독립 작업 정의 리뷰 및 actionlint | 두 대상 브랜치와 PR 변경 이벤트 포함, 모든 작업 실행 |
| AC-2 | workflow:harness-check, workflow:test, lint:web, check-types:web, build:web 실행 및 CI 단계 리뷰 | 명령 성공, 실제 명령과 워크플로의 일치 |
| AC-3 | 공식 runner 설치 목록, Xcode 선택 경로 및 macos:build 연결 확인 | 유효한 runner와 Xcode 사용. 로컬 Xcode 부재나 원격 미실행을 성공으로 표시하지 않음 |
| AC-4 | actionlint, diff 검사 및 버전, 권한, concurrency, timeout 리뷰 | 문법과 정적 검사 성공, 필수 옵션 존재, 실패 은폐 없음 |
| AC-5 | 문서 링크, 현재 상태, 제외 범위와 diff 리뷰 | 합의된 정책과 일치, 기존 승인 정책 유지 |
| AC-6 | 후속 PR의 실제 check runs와 원격 ruleset 조회 | 세 검사 성공, 두 대상 브랜치에서 필수 검사 적용 |

## 미결정 사항

- 없음. 원격 실행 검증과 필수 검사 연결은 게시 후 진행하는 단계이며 현재 요청은 구현 결과를 받아 로컬에서 검토하는 단계다.

## 주요 설계 변경

| specRevision | 변경한 결정 | 이유 |
| --- | --- | --- |
| 1 | 최초 설계 | 앱과 웹 CI를 함께 구성하고 사용자가 요청한 서브 에이전트 구현과 결과 검토 진행 |
