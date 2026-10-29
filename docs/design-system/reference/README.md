# 랜딩 분석 근거

2026-10-29에 최신 랜딩 `web/`에서 복사한 읽기 전용 분석 자료다. React 앱의 현재 스타일과 구분한다. 원본을 편집하거나 이 파일들을 앱에서 import하지 않는다.

| 파일 | 원본 | SHA-256 |
|---|---|---|
| landing.css | web/style.css 전체 | d57d9b3ad1f9a123e0c66b98f02e2058ca7da52f3d3fec86a2a4c295e4c59ff6 |
| legacy-tokens.css | web/design-system/tokens.css 전체 | 8aeeca53253c2b9e7a8e9927896d7ef88df2910016d3a5ad9ad0e0bc8fc1cef8 |
| legacy-tokens.json | web/design-system/tokens.json 전체 | b09b5b975cb3c1fc0d4ac6a93c6aef70bfb54068210fc32bec39f24d07476a80 |
| review-motion.txt | web/app.mjs 86–124행 발췌 | 원본 전체: ded9332699a94e933eba1845eff614f96f3ccc6092ca56b8cfb0edb4728388b8 |

CSS는 과거 섹션과 누적 덮어쓰기가 함께 들어 있다. 단일 선언만 읽어 최종 스타일로 판단하지 않는다. 모션 발췌는 실행용 모듈이 아니다.
