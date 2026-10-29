# 디자인 시스템 기초 토큰

이슈 [#17](https://github.com/ttak-app/ttak-workspace/issues/17)의 결과물이다. 최신 랜딩에서 관찰한 디자인 기초를 코드에서 참조할 수 있도록 정리했다. UI 컴포넌트나 새 디자인 시스템 패키지는 포함하지 않는다.

- [관리 원본 JSON](../../design-system/tokens.json)
- [생성 CSS](../../apps/web/src/styles/tokens.css)
- [전체 토큰 목록](tokens.md): 이름, 값, 종류, 용도, 출처와 상태
- [랜딩 분석과 확인 결과](audit.md), [분석 근거](reference/README.md)

## 수정과 사용

저장소 루트에서 실행한다. 기존 웹 개발 의존성의 Prettier를 재사용하므로 먼저 저장소 의존성이 설치되어 있어야 한다.

```sh
npm run tokens:build
npm run tokens:check
node tools/design-tokens/contrast.mjs
npm run tokens:preview
```

공통 `design-system/tokens.json`을 수정한 뒤 플랫폼 출력과 목록을 함께 재생성한다. `tokens:check`는 참조 누락, 순환, 직접 참조의 타입 불일치, 변수명 충돌, 생성물 차이와 생성 도구의 회귀 검사를 확인한다. 이 검사는 모든 CSS 문법과 접근성 또는 원본 화면 일치 여부를 자동 보장하지 않는다. 새 값의 CSS 문법과 실제 화면은 별도 확인한다. 새 CI나 자동 강제 정책은 추가하지 않았다.

후속 화면에서 사용할 때 CSS를 한 번 import하고 용도에 맞는 의미 토큰을 참조한다. 현재 React 앱은 이 CSS를 아직 import하지 않는다. 아래는 사용 방법이며 이번 작업에서 적용한 화면 변경은 아니다.

```css
@import './styles/tokens.css';

/* 소비하는 화면의 스타일에서 필요한 속성에만 연결한다. */
/* color: var(--ttak-color-text-primary); */
/* background: var(--ttak-color-surface-default); */
/* font-family: var(--ttak-font-family-system); */
/* font-size: var(--ttak-typography-hero-size); */
```

## 토큰 구조

JSON 경로의 점을 하이픈으로 바꾸고 `--ttak-`를 붙인다. 예를 들어 `color.text.primary`는 `--ttak-color-text-primary`다. 색상과 크기마다 의미가 다른 별칭을 무조건 합치지 않는다.

| 계층 | 예시 | 수정 기준 |
|---|---|---|
| 원시값 | `color.palette.ink`, `font.size.14`, `space.24`, `radius.12` | 근거가 있는 실제 색상과 수치. 스케일 재설계는 별도 논의 |
| 의미 | `color.text.primary`, `typography.hero.size`, `radius.surface.panel` | 화면의 역할. 같은 값이어도 용도가 다르면 독립적으로 유지 |
| 복합 효과 | `gradient.logo`, `elevation.input` | 각도와 stop, 다중 그림자를 한 값으로 보존 |
| 환경별 재정의 | JSON의 `overrides` | 원본의 media query와 순서를 보존 |

`{color.palette.ink}` 같은 참조는 CSS에서 `var(--ttak-color-palette-ink)`로 출력된다. CSS에는 값만 정의하며 셀렉터, 컴포넌트, keyframe, 폰트 로딩은 포함하지 않는다.

`observed`는 조사 시점 원본에서 확인했다는 뜻이며 접근성이 승인됐다는 뜻은 아니다. 원시 스케일은 관찰한 수치의 재사용 후보이고 각 숫자마다 별도 UI 규격을 약속하지 않는다. `draft-only`는 초안에만 남아 있는 값이다. 신규 제안값은 이번에 추가하지 않았다.

## 적용 시 제약

- `color.text.muted`, placeholder, 로고 그라디언트는 현재 대비 제한이 있다. [분석 기록](audit.md)의 용도 제한을 먼저 확인한다. 일반 본문에는 검증한 primary, body, secondary를 우선 검토한다.
- 시스템 폰트 스택을 유지했다. Noto Sans KR을 다운로드하지 않는다. OS에 없는 글꼴은 다음 fallback으로 넘어가며 650, 750 같은 굵기의 실제 표현도 설치 폰트에 따라 달라진다.
- `typography.*`는 size, weight, line-height, letter-spacing을 함께 참조한다. font-size만 연결하면 원래 타이포그래피를 재현할 수 없다. `normal` 행간은 폰트와 브라우저에 의존한다.
- 641–760px와 640px 이하는 일부 반경과 행간이 다르다. 상위 반응형 규칙을 합치거나 breakpoint를 새로 정하지 않았다. `clamp()`는 그대로 유지한다.
- CSS 변수는 일반 `@media` 조건에서 사용할 수 없다. `layout.breakpoint.*`는 문서화된 경계값이며 `@media (max-width: var(...))`로 사용하지 않는다. 필요한 media query는 목록의 리터럴 조건을 사용하고 경계를 변경할 때 JSON과 소비 스타일을 함께 검토한다.
- reduced-motion override는 지속 시간과 이동량을 줄인다. 반복 애니메이션의 `0ms`만으로 중단을 보장하지 않으므로 소비 화면은 `animation: none`, 필요한 `transition: none`, JavaScript `matchMedia` 분기를 함께 적용해야 한다. 원본도 CSS 반복 애니메이션과 Web Animations API를 각각 중단한다.
- 유리 효과와 알파 색상은 배경에 따라 합성된다. 그림자, 블러, 그라디언트의 픽셀 결과는 별도 화면 검증이 필요하다.

다크 모드, 새 폰트 채택, Figma 변환, 낮은 대비 색상의 대체안과 기존 화면 마이그레이션은 미확정 후속 항목이다.

## 시각적 확인

`npm run tokens:preview`를 실행하고 [로컬 미리보기](http://127.0.0.1:4174)를 연다. [HTML 파일](preview.html)을 직접 열어도 된다. 관리 원본에서 자동 생성하므로 토큰 변경 뒤에는 `tokens:build`를 실행하고 새로고침한다. 컬러, 그라디언트, 타이포그래피, 간격, 반경, 그림자와 모션 수치를 확인할 수 있다. 미리보기의 레이아웃 스타일은 문서용이며 제품 컴포넌트가 아니다.

## macOS에서 사용

동일 원본에서 [TtakTokens.swift](../../apps/macos/Ttak/Resources/TtakTokens.swift)를 생성하며 Xcode 앱 타깃에 연결했다. 파일을 직접 수정하지 않고 `tokens:build`를 실행한다.

```swift
// 후속 화면에서 필요한 속성에 연결하는 예시
// .foregroundStyle(TtakTokens.Colors.textPrimary)
// .padding(TtakTokens.Spacing.value24)
// .font(.system(size: TtakTokens.FontSize.value14))
```

| 공유 항목 | macOS 출력 | 단위와 제한 |
|---|---|---|
| 의미 컬러와 알파 표면 | `TtakTokens.Colors` | sRGB RGBA. dark mode 자동 적응 색상 아님 |
| 간격, 수치 반경, 경계선 | `Spacing`, `Radius`, `BorderWidth` | 동일 수치를 논리 point로 제공. 웹 CSS px와 물리 픽셀 동등성을 뜻하지 않음 |
| 원시 폰트 크기 스케일 | `FontSize` | point. 화면별 typography 역할을 자동 매핑하지 않음 |
| 투명도 | `Opacity` | 0–1 |
| 지속 시간과 지연 | `Duration`, `Delay` | 원본 ms를 초로 변환 |

CSS 폰트 스택, `vw`, `clamp`, 웹 breakpoint, 퍼센트 반경, CSS 다중 그림자와 블러, 그라디언트 각도 및 easing은 SwiftUI로 자동 변환하지 않았다. 플랫폼의 폰트 weight와 행간, 그라디언트 좌표, material 및 모션 적용은 실제 앱 화면에 맞춰 검토한다. 특히 앱은 `accessibilityReduceMotion`을 확인해 반복 및 공간 이동을 중단해야 하며 Swift 상수 자체가 OS 설정을 자동 반영하지 않는다. 기존 앱 화면에 토큰을 연결하는 작업은 후속 범위다.
