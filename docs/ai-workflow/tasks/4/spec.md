# 작업 명세: AI Agent 하네스 세팅

## 연결 정보

- 이슈: #4 / https://github.com/ttak-app/ttak-workspace/issues/4
- 브랜치: chore/agent-harness-setting/#4
- specRevision: 1

## 목적

Keeply 하네스를 바탕으로 Codex가 Ttak macOS 앱의 합의 범위를 설계·구현·검증·리뷰하고 다음 대화에서 재개하도록 한다.
사용자의 ‘iOS’ 표현은 현재 macOS 앱용 Swift·SwiftUI 하네스로 확인됐다.

## 작업 범위

### 포함

- Codex 진입점·5개 스킬·시작/완료/보고 체크리스트
- 이슈별 공유 명세, 로컬 검증·리뷰 증적, 작업 재개와 PR 준비 검사
- 기존 증적 엔진의 npm 변환과 macOS 검증·환경 지문 추가
- 현재 Xcode/테스트 타깃 부재를 성공으로 처리하지 않는 빌드·테스트 명령
- 로컬 도구 정상·실패·오래된 증적 회귀 검사와 사용 안내

### 제외

- Claude, iOS 타깃, 앱 기능 구현, 새 코딩·명명·커밋 컨벤션
- CI #3 구현·GitHub 보호 규칙 변경·새 이슈 생성
- 요청하지 않은 커밋·push·PR·merge

## 설계 결정

- 파일 구조와 로직의 책임: AGENTS.md는 라우터, docs는 정책/명세, .agents는 Codex 스킬, tools는 실제 로컬 검증/증적 도구.
- 상태·데이터 흐름: 명세는 Git 공유, 실행 로그·리뷰·상태는 .tmp에 로컬 저장.
- 선택한 방식과 이유: Keeply의 증적/재개/리뷰/준비 엔진을 재사용하고 웹 전용/Claude 의존성은 제거.
- 예외 처리: Xcode·테스트 타깃 없음, 검사 실패, 명세 변경, 미해결 리뷰, 지문 불일치를 통과시키지 않음.

## 완료 조건

- AC-1: Codex 진입점·5개 스킬·참조 문서가 유효하게 연결되고 Claude 설정을 요구하지 않는다.
- AC-2: 실제 검사 실패와 로그가 기록되고 변경·명세·환경이 바뀌면 이전 증적을 재확인 대상으로 구분한다.
- AC-3: macOS 전용 빌드·테스트 명령이 Xcode/테스트 타깃 부재를 non-zero로 보고하고 웹 검사로 대체하지 않는다.
- AC-4: 이슈 #4에서 재개·리뷰 범위 수집·PR 준비 도구를 실행할 수 있고 미커밋 상태를 ready로 표시하지 않는다.
- AC-5: CI·제품 코드·컨벤션·외부 저장소 설정은 이번 작업으로 변경하지 않는다.

## 검증 방법

| 완료 조건 | 확인 방법 | 기대 결과 |
| --- | --- | --- |
| AC-1 | workflow:harness-check, skill validator, 참조 링크 검토 | 유효한 Codex 하네스 |
| AC-2 | workflow:test의 임시 저장소 회귀 테스트 | 성공·실패·변경 무효화 구분 |
| AC-3 | mock Xcode 테스트와 현 환경 macos:build/test | 현재 Xcode 부재는 실패, mock은 실제 명령/타깃 분기 검사 |
| AC-4 | resume/check/review 시작/pr-check와 로컬 로그 | 대상 #4 복원, 실제 로그, 미커밋 blocked |
| AC-5 | 전체 Git diff와 새 파일 범위 검토 | 하네스·설명·npm 명령·ignore만 변경 |

## 미결정 사항

- 실제 Xcode 빌드·테스트와 사용자 미리 알림·온디바이스 모델 동작은 Xcode 설치 및 기능 구현 후 검증한다. 하네스 도구 검증과 구분한다.

## 주요 설계 변경

| specRevision | 변경한 결정 | 이유 |
| --- | --- | --- |
| 1 | Keeply 기반 Codex·macOS 전용 하네스 | 사용자 요청과 플랫폼 확인 |
