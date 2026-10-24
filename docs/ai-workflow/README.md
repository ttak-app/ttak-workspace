# 작업 명세와 로컬 증적

[작업 흐름](../rules/ai-workflow.md)의 구현 도구다.
공유 명세는 `docs/ai-workflow/tasks/번호/spec.md`, 실제 검사·리뷰 기록은
Git에서 제외한 `.tmp/ai-workflow/tasks/번호/`에 저장한다.
새 clone은 로컬 증적을 이어받지 않는다. 기록이 없으면 실행 결과를 다시 확보한다.

## 명령

저장소 루트에서 실행한다. Node 24·npm 11을 사용하며 하네스 자체는 Node 기본 모듈로 동작한다.

```sh
npm run workflow:resume -- --issue 4 --base origin/develop
npm run workflow:harness-check
npm run workflow:test
npm run workflow:check -- --issue 4 --script workflow:harness-check
npm run workflow:check -- --issue 4 --script workflow:test
npm run workflow:review -- --issue 4 --start
# 실제 patch·파일을 검토한 뒤 생성된 input.json을 작성
npm run workflow:review -- --issue 4 --input .tmp/ai-workflow/tasks/4/reviews/세션/input.json
npm run workflow:pr-check -- --issue 4 --base origin/develop --json
```

- `resume`, `pr-check`, `harness-check`: 읽기 전용. 자동 fetch·커밋·수정·게시 없음.
- `check`: 허용된 실제 npm 명령을 실행하고 종료 코드·출력·대상 지문을 기록한다.
- `review --start`: 커밋·staged·unstaged·새 파일 patch와 input.json을 생성한다.
- `review --input`: 실제 검토 결과를 저장한다. 시작 대상·범위 변경이나 미해결 지적 누락을 거부한다.
- `review:scope`: 명세 없는 리뷰를 위해 `.tmp/branch-review`에 범위만 수집한다. 명시적 읽기 전용 요청이면 Git을 직접 읽는다.

검사 기록은 한 번에 하나씩 실행한다. 실행 중 lock이 남았으면 실제 실행 중인지 확인한 후 정리한다.
`.tmp`와 그 하위 기록 경로를 심볼릭 링크로 외부에 연결하지 않는다.

## 상태와 수동 판단

[명세 템플릿](templates/spec.md), [상태 템플릿](templates/status.json)을 사용한다.
명세에 `- 이슈: #번호 / URL`, `- 브랜치: 브랜치명`, `- specRevision: 양의정수`,
`## 완료 조건` 아래 `- AC-N: 내용`을 정확히 기록한다.

검사가 성공해도 `acceptance`는 자동 met가 되지 않는다. Codex가 실제 결과를 검토한 후
로컬 status.json의 수동 판단에 대상 subject와 근거 파일을 남긴다. 예:

```json
{
  "id": "AC-1",
  "status": "met",
  "freshness": "current",
  "subject": "실제 resume JSON의 subject 객체로 교체",
  "evidence": [".tmp/ai-workflow/tasks/4/observations.log"]
}
```

이 예시를 그대로 통과 기록으로 복사하지 않는다. `subject`는 실제 객체이고 근거 파일은
실제 관측·명령 결과여야 한다. `docs-review`는 checks에 result=passed, exitCode=0,
checkedAt=실제 ISO 시간, subject, freshness, command, evidence(.log)를 기록한다.
하네스 변경은 `readinessEvidence`에 kind=`harness-validation`, 앱 변경은 kind=`behavior`로
result, checkedAt, reason, subject, freshness, evidence를 기록한다.
문서 전용 앱 검사 N/A는 checks에 result=`not-applicable`, 실제 reason, subject,
checkedAt, freshness를 기록한다. Xcode가 없다는 이유로 Swift 변경의 macos:build를 N/A 통과시킬 수 없다.

리뷰 input에는 result, focusPoints, findings, unverified, nextActions를 채운다.
지적은 id·severity(High/Medium/Low)·file·line·description·status(open/resolved/accepted)·resolution을 포함한다.
High/Medium 미해결은 게시 준비를 막는다. Low도 처리 이유를 남기고 이전 지적을 삭제하지 않는다.
미검증이 AC와 무관하면 `unverifiedAssessment`에 acceptanceImpact=`none`, reason, evidence를 남긴다.
완료 조건에 영향을 주는 미검증은 영향 없음으로 처리하지 않는다.

## 준비 검사와 한계

- 지문은 HEAD·index·작업 트리 전체(새 파일 포함), 기준 ref SHA, 명세 버전,
  Node/npm/설치 잠금 파일과 Swift·Xcode·선택된 developer directory를 비교한다.
- 파일·명세·기준 ref·환경이 달라지면 오래된 기록을 통과로 재사용하지 않는다.
  커밋으로 HEAD/index가 바뀌어도 재확인이 필요하다. phase 값만으로 완료 판정하지 않는다.
- PR 준비 검사는 커밋된 변경, 깨끗한 작업 트리, 현재 AC·검사 로그·리뷰 근거를 요구한다.
  미커밋 상태의 blocked는 정상이며 이 도구가 자동 커밋하지 않는다.
- macOS 변경은 macos:build, 테스트 소스 변경은 macos:test가 필수다.
  기존 테스트가 있으면 실제 작업 영향에 따라 별도로 실행하며 그 미실행은 리뷰에서 밝힌다.
- 웹/공유 package 설정 변경은 lint:web·check-types:web·build:web, 하네스 코드는 workflow:test,
  모든 변경은 workflow:harness-check, 문서는 docs-review를 요구한다.
- 구조 검사는 파일·링크·스킬 front matter·npm 명령의 유효한 연결만 본다.
  코딩 규칙의 의미, 자연어 설계의 적절성, 모델 품질·사용자 권한·실기기 동작을 자동 검증하지 않는다.
- CI, Git 훅, 자동 라벨링, 코딩 컨벤션 설치·강제는 포함하지 않는다. 이 하네스는 로컬 도구다.
- 로컬 기록은 위조 방지 증명이나 GitHub 리뷰 승인이 아니다. Codex가 기록을 검토하고 실제 한계를 보고한다.

## 참고 원본

Keeply의 체크리스트·5개 스킬·명세/로컬 증적/리뷰/재개/PR 준비 흐름을 참고했다.
증적 엔진과 관련 회귀 테스트는 다음 커밋을 기반으로 npm 및 macOS 환경에 맞췄다.

[Keeply 999cb6e](https://github.com/Project-Keeply/Keeply-Client/tree/999cb6e930a4a1289a4025a03b7c615bba0afc8b)

React 전용 설계·pnpm·Claude 연결·원본 CI 검사·별도 코딩 컨벤션은 이식하지 않았다.
