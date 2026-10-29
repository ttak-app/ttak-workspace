# 디자인 토큰 목록

자동 생성 파일. 수정은 [JSON 원본](../../design-system/tokens.json)에서 하고 `npm run tokens:build`를 실행한다.

용도와 제약은 [사용 지침](README.md), 실제 사용 근거는 [분석 기록](audit.md), 참조 파일은 [원본 목록](reference/README.md)을 확인한다.

| CSS 변수 | 종류 | 원본 값 또는 참조 | 용도 | 근거 | 상태 |
|---|---|---|---|---|---|
| `--ttak-color-brand-coral` | color | `#D75D57` | 브랜드 coral. 브랜드 표현에 사용하며 기본 컨트롤 색을 일괄 대체하지 않음 | legacy-tokens.css: --brand-coral | observed |
| `--ttak-color-brand-orange` | color | `#E39343` | 브랜드 orange. 브랜드 표현용 | legacy-tokens.css: --brand-orange | observed |
| `--ttak-color-brand-strong` | color | `#A94F27` | 강조가 필요한 브랜드 텍스트와 선택적 tint 후보 | legacy-tokens.css: --brand-strong | observed |
| `--ttak-color-brand-tint` | color | `#FFF3E9` | 브랜드 콘텐츠의 옅은 배경. 시스템 팝오버와 Liquid Glass 배경에는 기본 적용하지 않음 | legacy-tokens.css: --brand-tint | observed |
| `--ttak-color-logo-coral` | color | `#EF7868` | 로고 그라디언트의 시작 색상 | legacy-tokens.css: --logo-coral | observed |
| `--ttak-color-logo-orange` | color | `#F6AD55` | 로고 그라디언트의 끝 색상 | legacy-tokens.css: --logo-orange | observed |
| `--ttak-gradient-logo` | gradient | `linear-gradient(115deg, {color.logo.coral} 10%, {color.logo.orange} 90%)` | 웹 로고의 115도 그라디언트. 앱은 두 로고 색상을 참조하고 좌표는 별도 검토 | legacy-tokens.css: --logo-gradient; landing.css: .hero-accent | observed |
