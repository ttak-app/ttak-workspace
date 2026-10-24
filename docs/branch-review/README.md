# 로컬 브랜치 리뷰

`npm run review:scope -- origin/develop`은 커밋·staged·unstaged·새 파일을
`.tmp/branch-review`의 개별 patch와 파일 목록으로 모은다. 원격을 조회하지 않는다.
연결 명세가 있으면 `npm run workflow:review -- --start`가 이슈별 세션을 만들므로 이를 사용한다.

수집한 patch, 실제 파일, 필요한 호출부를 읽은 후 지적과 미검증을 기록한다.
수집만으로 리뷰가 끝나지 않는다. 바이너리와 실제 UI·권한 동작은 별도 확인이 필요하다.
작업 트리가 바뀌면 freshness를 다시 확인한다.

[작업 흐름](../rules/ai-workflow.md)과 [기록 형식](../ai-workflow/README.md)을 따른다.
