# CI 운영

Swift macOS 앱과 React 랜딩 페이지를 [하나의 GitHub Actions 워크플로](../.github/workflows/ci.yml)에서 검증한다.
CI는 코드 검사와 빌드를 담당한다. 웹 호스팅, PR 프리뷰 배포, 앱 서명, 공증과 배포는 후속 CD 작업이다.

## 실행 조건과 검사

`main`, `develop` 대상 PR을 생성하거나 다시 열고, 커밋을 추가하거나 리뷰 준비 상태로 바꾸면 실행한다.
초안 PR도 검사한다. 경로 필터 없이 아래 세 작업을 독립적으로 실행하고,
같은 PR에 새 실행이 시작되면 이전 실행을 취소한다. 별도 push 트리거는 두지 않는다.
기본 checkout 동작으로 PR 브랜치와 대상 브랜치의 임시 merge commit을 검사한다.

| 검사 이름 | 환경 | 실행 명령 | 제한 시간 |
| --- | --- | --- | --- |
| `Harness` | Ubuntu 24.04, Node 24, npm 11.3.0 | `workflow:harness-check`, `workflow:test` | 10분 |
| `Web` | Ubuntu 24.04, Node 24, npm 11.3.0 | `npm ci` 후 `lint:web`, `check-types:web`, `build:web` | 10분 |
| `macOS Build` | macOS 26 ARM64, Xcode 26.6, Node 24, npm 11.3.0 | `macos:build` | 20분 |

표의 검사 명령은 저장소 루트에서 `npm run 명령`으로 실행한다.
작업 간 `needs` 의존성은 없으며 한 작업이 실패해도 다른 작업에서 검증 결과를 받을 수 있다.
명령 실패는 그대로 작업 실패로 처리한다. 모든 작업은 저장소 내용 읽기 권한만 사용한다.
배포 토큰이나 인증서, 개인 일정 데이터는 필요하지 않다.

## 버전과 캐시

- Node는 [.nvmrc](../.nvmrc)의 24 계열을 사용한다. 패치 버전까지 고정하지는 않는다.
- npm은 [package.json](../package.json)의 `packageManager`에 맞춰 11.3.0을 설치한다.
  향후 이 값을 바꾸면 워크플로의 세 npm 설치 단계도 함께 갱신한다.
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

`macos:build`는 기존 Ttak 공유 스킴의 Debug 앱을 `CODE_SIGNING_ALLOWED=NO`로 빌드한다.
배포용 앱이나 설치 파일을 만들지 않는다. 현재 공유 스킴에는 테스트 타깃과 테스트 플랜이 없어
`macos:test`는 CI에 연결하지 않았다. 테스트 타깃을 도입하면 실제 테스트 실행을 추가한다.

Swift 빌드 통과는 Foundation Models의 한국어 분석 품질, 메뉴바 UI 동작,
미리 알림 권한이나 EventKit 저장 성공을 보증하지 않는다. 이 동작은 실제 Mac에서 별도로 검증한다.
로컬에 전체 Xcode 26 이상이 없으면 로컬 앱 빌드는 미검증으로 남긴다.
GitHub macOS runner의 빌드 성공과 구분해 보고한다.

## 로컬 확인과 실패 대응

```sh
npm ci
npm run workflow:harness-check
npm run workflow:test
npm run lint:web
npm run check-types:web
npm run build:web
# 전체 Xcode 26 이상이 설치된 Mac에서 실행
npm run macos:build
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

## 최초 실행과 필수 검사 연결

현재는 로컬 구현 단계다. 실제 GitHub 실행과 `main`, `develop`의 필수 검사 연결은 아직 완료하지 않았다.
이 두 단계까지 확인하기 전 [#3](https://github.com/ttak-app/ttak-workspace/issues/3)을 전체 완료로 처리하지 않는다.

1. 별도 게시 요청을 받으면 작업 브랜치를 push하고 `develop` 대상 PR을 만든다.
2. GitHub에서 `Harness`, `Web`, `macOS Build`가 모두 생성되고 성공하는지 확인한다.
   로컬 Xcode 부재나 정적 검사 통과로 원격 macOS 빌드를 대체하지 않는다.
3. 실제 check run 이름을 확인한 뒤 기존 `ttak-develop`, `ttak-main` ruleset에
   세 검사를 필수 상태 검사로 연결한다. 이름을 바꾸면 연결된 필수 검사 이름도 함께 갱신한다.
4. PR 필수, 승인 0명, 직접 push 차단과 Merge commit 정책이 유지되는지 확인한다.
5. `develop`에 워크플로가 병합되면 이후 `develop` 대상 PR에서 검사가 계속 실행되는지 확인한다.
   `main` 대상 첫 PR에도 워크플로를 포함해 세 검사가 생성되는지 확인한다.

첫 구성에서는 모든 PR에서 세 검사를 실행한다. 경로별 생략이나 검사 이름 변경은
필수 검사가 계속 대기하거나 누락되지 않는지 함께 설계한 후 도입한다.
