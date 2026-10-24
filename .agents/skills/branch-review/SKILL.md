---
name: branch-review
description: Ttak 작업 브랜치의 커밋·staged·unstaged·새 파일을 리뷰하고 실제 발견과 미검증을 기록한다. 코드·브랜치 리뷰 또는 push 전 확인 요청에 사용한다.
---

# 브랜치 리뷰

[작업 흐름](../../../docs/rules/ai-workflow.md), [범위 수집](../../../docs/branch-review/README.md)을 따른다.
추가 관점이 없으면 기본 리뷰 기준으로 진행하고 불필요하게 질문하지 않는다.
연결 명세가 있으면 `npm run workflow:review -- --start`로 세션을 만들고 patch와 실제 관련 파일을 읽는다.
명세 없는 리뷰나 명시적 읽기 전용 요청은 Git을 직접 확인하며 상태 파일을 만들지 않는다.
Swift 변경은 [macOS 기준](../../../docs/rules/macos-development.md)으로 검토한다.
지적은 ID·심각도·파일·줄·사용자 영향·수정 방향을 적고 실제로 해결한 항목만 resolved로 기록한다.
수집만으로 리뷰 완료를 선언하지 않는다. 미검증·바이너리·실기기 한계를 알린다.
검토 후 세션 input.json의 subject와 scope를 보존해 작성하고 `workflow:review -- --input 경로`로 저장한다.
이전 미해결 지적을 누락하지 않는다. 사용자 요청 없이 별도 리뷰 에이전트를 띄우지 않는다.

## 컨벤션 적용

[공통 코딩 컨벤션](../../../docs/rules/coding-convention.md)에서 대상 경로의 언어 규칙을 읽는다.
Swift 변경에는 Swift 규칙, 랜딩 페이지에는 웹 규칙만 적용하고 컨벤션을 스킬에 중복 정의하지 않는다.
