---
name: create-pr
description: Ttak 작업 브랜치의 실제 검증·리뷰와 게시 권한을 확인해 PR을 준비·생성·수정한다. PR 작성·게시 요청에 사용하며 merge 권한을 추정하지 않는다.
---

# PR 준비와 게시

[작업 흐름](../../../docs/rules/ai-workflow.md)과 [기록 형식](../../../docs/ai-workflow/README.md)을 따른다.
기준 ref·연결 이슈·커밋/미커밋·검사/리뷰 기록과 같은 head/base의 기존 PR을 확인한다.
`npm run workflow:pr-check -- --base origin/develop`로 준비 상태와 오래된 증적을 확인한다.
실패·Xcode 부재·미검증은 숨기지 않는다. 필요한 검증을 보완하고 환경 예외는 사용자 지시를 받아 구체적으로 밝힌다.
[PR 템플릿](../../../.github/pull_request_template.md)에 실제 최종 변경과 검증 결과를 작성한다.
사용자 지정 `chore/*/#번호` 등 작업 브랜치도 실제 경로대로 설명하고 feat 체크를 허위로 표시하지 않는다.
권한이 없는 push/게시를 대신 수행하지 않는다. 권한이 있으면 반복 승인 없이 요청 범위에서 진행한다.
본문 파일과 `gh pr create/edit --body-file`을 사용하며 기존 설명을 의미 없이 덮어쓰지 않는다.
생성 PR은 사용 가능한 Codex artifact 연결 도구로 연결하고 실제 URL을 보고한다. PR 요청만으로 merge하지 않는다.
