# 브랜드 토큰 선정 근거

이슈 [#17](https://github.com/ttak-app/ttak-workspace/issues/17)의 최초 조사에서는 랜딩의 세부 스타일을 241개 토큰으로 추출했다. 사용자가 Apple 기본 컴포넌트를 활용하는 앱에 비해 불필요한 값이 많다고 판단하여, 명세 버전 3에서 공통 기준을 브랜드 중심의 7개로 축소했다.

## 채택한 값

[원본 스냅샷](reference/README.md)의 `legacy-tokens.css`에서 브랜드와 로고 색상을 확인했다. `landing.css`의 `.hero-accent`는 로고 그라디언트를 사용한다. 브랜드 그라디언트는 초안에만 존재하여 활성 토큰에서 제외했다.

| 항목 | 값 | 근거 |
|---|---|---|
| brand.coral | #D75D57 | --brand-coral |
| brand.orange | #E39343 | --brand-orange |
| brand.strong | #A94F27 | --brand-strong |
| brand.tint | #FFF3E9 | --brand-tint |
| logo.coral | #EF7868 | --logo-coral |
| logo.orange | #F6AD55 | --logo-orange |
| gradient.logo | 115deg, coral 10%, orange 90% | --logo-gradient와 .hero-accent |

## 공통 토큰에서 제외한 값

기본 텍스트, 배경, 상태색, 수치별 간격과 반경, 폰트 스택과 타이포그래피, breakpoint, 그림자, 블러, 투명도 및 모션을 제거했다. 앱의 기본 외관은 시스템 스타일을 우선하고 웹의 개별 표현은 해당 CSS에서 관리한다. 실제 반복 사용이 확인되지 않은 수치 스케일을 공통 규격으로 확정하지 않는다.

원본 스냅샷은 분석 근거로 유지했다. 그 안의 이전 토큰과 컴포넌트 규격은 현재 채택한 디자인 시스템이 아니다. 기존 241개 토큰이나 과거 브라우저 대조 결과가 현재 활성 토큰 검증을 의미하지 않는다.

## 브랜드 대비

`node tools/design-tokens/contrast.mjs`는 흰 배경에 대한 불투명 sRGB 상대 휘도 대비율을 계산한다. 흰색은 측정 조건이며 새 공통 배경 토큰이 아니다. 아래는 일반 텍스트 4.5:1 기준의 산술 비교다.
| 조합 | 전경 | 배경 | 대비율 | 일반 텍스트 4.5:1 |
|---|---|---|---|---|
| 브랜드 coral | #D75D57 | #FFFFFF | 3.75:1 | 미달 |
| 브랜드 orange | #E39343 | #FFFFFF | 2.46:1 | 미달 |
| 브랜드 강조 | #A94F27 | #FFFFFF | 5.48:1 | 충족 |
| 로고 coral 끝점 | #EF7868 | #FFFFFF | 2.78:1 | 미달 |
| 로고 orange 끝점 | #F6AD55 | #FFFFFF | 1.90:1 | 미달 |

coral, orange와 로고 컬러는 일반 본문용으로 사용하지 않는다. strong도 실제 배경과 외관에서 다시 검토한다. 그라디언트의 끝점 비교는 전체 영역의 최소 대비 또는 앱 접근성 승인을 증명하지 않는다. 앱의 밝고 어두운 외관에서 브랜드를 적용하는 방법은 후속 화면 검토 대상이다.

## 현재 확인 범위

공통 JSON에서 7개 CSS 토큰과 6개 Swift Color, 목록과 미리보기를 생성한다. 앱은 공유 브랜드 색상만 참조할 수 있고 원래 화면의 텍스트, 간격과 재질은 변경하지 않는다. 미리보기는 브랜드 시각 확인용이며 네이티브 Liquid Glass의 재현 화면이 아니다.
