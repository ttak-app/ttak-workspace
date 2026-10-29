# 랜딩 스타일 분석

조사일: 2026-10-29. 분석 기준은 별도 최신 랜딩 `web/index.html`, `style.css`, `app.mjs`다. 저장소의 React 준비 화면 `apps/web/src/App.tsx`와 기존 기본 CSS를 최신 디자인 근거로 혼용하지 않았다. [원본과 해시](reference/README.md), [토큰별 목록](tokens.md)을 함께 확인한다.

## 사용 중인 규칙과 남아 있는 과거 선언

현재 화면은 hero, 데스크탑 체험 영역, feature-grid, landing-footer로 구성된다. CSS의 header, nav, how-section, steps, detail-section, faq-section, closing, footer 규칙은 이전 구성의 잔존 선언이다. 그 규칙을 새 의미 토큰으로 채택하지 않았다. 숫자 원시값은 여러 선언에서 사용된 수치를 모은 것으로 신규 간격 체계를 뜻하지 않는다.

같은 셀렉터의 마지막 선언과 더 높은 specificity, 활성 media query를 함께 확인했다. 예를 들어 모바일의 이전 `.desktop` 반경 18px와 `.review-panel` 반경 17px는 후속 기본 선언의 24px와 20px로 덮어써진다. `.features-intro h2`의 자간은 작은 화면에서도 -1.8px다.

| 항목 | 기존 초안 | 최신 랜딩에서 확인한 값과 처리 |
|---|---|---|
| 로고와 브랜드 | JSON colors에 로고 키 없음. logoGradient만 별도 존재 | logo coral/orange와 brand coral/orange를 구분하고 각 그라디언트를 보존 |
| 브랜드 그라디언트 | 초안에 정의됨 | 현재 CSS에서 직접 사용하는 참조 없음. `draft-only`로 유지 |
| 파란색 | 토큰 초안에는 없고 CSS `--blue`에 존재 | 현재 전송 버튼 hover에 남아 있어 `accent.legacy-blue`로 기록. 코랄로 임의 대체하지 않음 |
| 큰 제목 | 62px 고정값 | 기본 `clamp(36px, 4.1vw, 62px)`, 태블릿과 모바일에서 다른 clamp 적용 |
| 입력 글자 | JSON 16px | 기본 15px, 761–1100px 13px, 760px 이하 12px |
| 본문 행간 | 초안 14px / 22px | 현재 기능 본문 14px / 1.9, 760px 이하 13px / 1.9 |
| 기본 폰트 | JSON native/figma 설명에 분산 | 실제 CSS의 시스템 스택을 원본으로 사용. Figma 전용 fallback 설명은 코드 폰트로 확정하지 않음 |
| 패널과 필드 | JSON에 Input, DownloadButton 등 컴포넌트 규격 포함 | 컴포넌트 정의는 이식하지 않고 반경과 글자 등 기초값만 추출 |
| 효과 | 초안에 그림자와 블러 부족 | 실제 다중 그림자, 알파 표면, 블러, 입력 광원과 상태별 opacity 추가 |
| 모션 | 초안 일부와 실제 값 일치 | JS의 480ms / 240ms, 시작 지연 90ms, 간격 35ms, index 상한 4까지 확인 |

입력 표면에는 원래 `.input-bar`의 반투명 gradient와 나중에 추가된 불투명 `::before`의 따뜻한 gradient가 함께 남아 있다. 시각적 입력 표면 토큰은 후자의 불투명 gradient를 채택했다. 실제 CSS를 후속 마이그레이션할 때 레이어 합성을 유지하는지 확인해야 한다. `gradient.brand` 이외의 정의값은 현재 사용 근거나 원시값 추출 근거를 목록에 기록했다.

## 브라우저 대조

Ego Chromium에서 원본 페이지를 열고 900px 높이에 다음 viewport 너비를 적용했다. 생성 CSS를 별도 style로 주입하되 원본 셀렉터의 스타일은 바꾸지 않았다. 별도 숨김 요소에 각 타이포그래피 토큰을 적용해 원본의 computed font-size, font-weight, line-height, letter-spacing과 비교했다.

| 너비 | hero 크기 | 입력 크기 | CTA 반경 | 입력 반경 |
|---|---|---|---|---|
| 1440 | 59.04px | 15px | 12px | 32px |
| 1100 | 44px | 13px | 12px | 32px |
| 1024 | 40.96px | 13px | 12px | 32px |
| 761 | 30.44px | 13px | 12px | 32px |
| 760 | 48px | 12px | 12px | 32px |
| 641 | 44.87px | 12px | 12px | 32px |
| 640 | 44.8px | 12px | 10px | 28px |
| 390 | 34px | 12px | 10px | 28px |

hero, description, section, feature-title, input, action, notice의 비교 속성이 모두 일치했다. 761px와 760px 사이의 큰 제목 크기 변화도 현재 관찰값으로 유지했으며 새 디자인으로 보정하지 않았다. CSS.supports로 전체 기본 토큰과 override 값을 해당 CSS 속성 문법에 대조하여 오류가 없었다.

OS의 실제 렌더링 폰트는 heading에서 `Apple SD Gothic Neo`와 `.SF NS`였다. `isCustomFont: false`를 확인했다. Windows, Linux와 다른 폰트 설치 환경의 실제 렌더링은 미검증이다. fallback 순서와 별도 웹폰트 로딩 부재는 소스로 확인했으며 글리프와 굵기의 모든 플랫폼 일치를 보장하지 않는다.

`prefers-reduced-motion: reduce`를 에뮬레이션한 뒤 합성 예시를 분석했다. 원본의 반복 광원은 animation-name `none`, transition-duration `0s`, 진행 중인 animation 수는 0이었다. 생성 토큰의 panel과 row duration은 `0ms`였다. CSS 규칙과 JS의 `reducedMotion.matches` 및 변경 시 취소 처리를 함께 확인했다. 단순 duration 변경만으로 JS 분기를 대체하면 안 된다.

## 대표 컬러 대비

`node tools/design-tokens/contrast.mjs`로 불투명 sRGB 조합의 상대 휘도 대비율을 재계산할 수 있다. 아래 4.5:1 열은 일반 크기 텍스트 기준의 산술 비교이며 접근성 전체 인증이 아니다.
| 조합 | 전경 | 배경 | 대비율 | 일반 텍스트 4.5:1 |
|---|---|---|---|---|
| 본문 | #333D4B | #FFFFFF | 11.00:1 | 충족 |
| 주요 텍스트 | #191F28 | #FFFFFF | 16.56:1 | 충족 |
| 보조 텍스트 | #6B7684 | #FFFFFF | 4.62:1 | 충족 |
| 약한 텍스트 | #8B95A1 | #FFFFFF | 3.04:1 | 미달 |
| 입력 placeholder / 입력 표면의 중간 색상 | #9497A1 | #FFFAF7 | 2.82:1 | 미달 |
| 주요 액션 | #FFFFFF | #242735 | 14.82:1 | 충족 |
| 브랜드 강조 | #A94F27 | #FFFFFF | 5.48:1 | 충족 |
| 성공 | #3B6D5B | #FFFFFF | 5.96:1 | 충족 |
| 오류 | #B84538 | #FFFFFF | 5.32:1 | 충족 |
| 로고 coral 끝점 | #EF7868 | #FFFFFF | 2.78:1 | 미달 |
| 로고 orange 끝점 | #F6AD55 | #FFFFFF | 1.90:1 | 미달 |

약한 텍스트, placeholder, 로고 그라디언트는 일반 본문용으로 승인하지 않았다. 로고 색을 일반 제목 강조에 쓰는 경우도 대비를 다시 검토해야 한다. 로고 끝점 비교는 그라디언트 전 구간 또는 합성 배경의 최악 조건을 증명하지 않는다. placeholder 비교도 입력 gradient의 중간 색상에 대한 대표 측정이며 전체 gradient 최소 대비를 뜻하지 않는다. 알파, blur와 실제 합성 배경 전체는 추가 검증 대상이다.

원본 디자인을 임의로 바꾸지 않기 위해 관찰값을 보존했다. 낮은 대비 조합의 대체안, 의미 전달에 필요한 작은 글자와 실제 사용 배경의 최종 대비는 후속 적용 시 결정한다. 신규 대체 색상은 이번 토큰에 추가하지 않았다.
