---
name: logic-design
description: Ttak의 구현 계획과 완료 조건을 정리해 이슈별 명세를 작성·갱신한다. 설계나 구현 계획 요청에 사용하며 일반 설명을 확정 요구사항으로 저장하지 않는다.
---

# 구현 설계

[작업 흐름](../../../docs/rules/ai-workflow.md)과 [기록 형식](../../../docs/ai-workflow/README.md)을 읽는다.
관련 이슈·코드·기존 명세·사용자 변경을 확인하고 목적·포함/제외·AC·검증 방법을 정리한다.
macOS 작업은 [macOS 경계](../../../docs/rules/macos-development.md)를 읽는다.
이미 합의된 범위는 재사용하고 불분명한 제품 동작만 논의한다.
복잡한 상태·비동기·책임 혼재가 있으면 [구조 검토](../logic-architecture/SKILL.md)를 참고한다.
연결 이슈가 있으면 [템플릿](../../../docs/ai-workflow/templates/spec.md)으로 실제 명세를 작성한다.
읽기 전용이면 대화에만 정리하고, 미연결 설계에서는 임의의 이슈 폴더를 만들지 않는다.
합의 변경은 specRevision·AC·검증 영향을 갱신한다. 새 아키텍처·컨벤션을 자동 확정하지 않는다.

## 컨벤션 적용

[공통 코딩 컨벤션](../../../docs/rules/coding-convention.md)에서 대상 경로의 언어 규칙을 읽는다.
Swift 변경에는 Swift 규칙, 랜딩 페이지에는 웹 규칙만 적용하고 컨벤션을 스킬에 중복 정의하지 않는다.
