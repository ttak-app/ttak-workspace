# Ttak 브랜드 기준

웹과 macOS가 공유하는 최소 브랜드 토큰이다. 앱은 Apple 기본 컴포넌트를 우선 사용하며, 기본 외관을 랜딩의 고정 색상과 수치로 대체하지 않는다.

- [공통 JSON 원본](../../design-system/tokens.json)
- [웹 CSS](../../apps/web/src/styles/tokens.css), [macOS Color](../../apps/macos/Ttak/Resources/TtakTokens.swift)
- [7개 토큰 목록](tokens.md), [분석 기록](audit.md), [원본 근거](reference/README.md)
- [로컬 미리보기](http://127.0.0.1:4174), [미리보기 HTML](preview.html)

## 남기는 기준

| 토큰 | 용도 |
|---|---|
| brand.coral, brand.orange | 브랜드 표현 |
| brand.strong | 대비를 확인한 브랜드 강조와 선택적 tint 후보 |
| brand.tint | 브랜드 콘텐츠의 옅은 배경 |
| logo.coral, logo.orange | 로고 색상 |
| gradient.logo | 웹 로고 그라디언트 |

색상 토큰의 실제 JSON 이름은 `color.brand.coral` 형태다. CSS 이름은 `--ttak-color-brand-coral`, Swift 이름은 `TtakTokens.Colors.brandCoral`이다. 로고 그라디언트는 두 로고 색상을 참조한다. Swift 출력에는 6개 Color만 포함하며 웹의 그라디언트 각도를 앱 좌표로 임의 변환하지 않는다.

브랜드색을 기본 컨트롤 전체에 적용하지 않는다. 로고와 coral/orange 색상은 일반 본문용 색상으로 승인한 값이 아니다. [대비 확인 결과](audit.md)를 참고하고 실제 사용 배경에서 검토한다.

## 앱 적용 기준

| 대상 | 기본 선택 |
|---|---|
| 본문, 보조 텍스트와 폰트 | 시스템 텍스트 스타일, primary와 secondary |
| 배경, 경계선, 상태와 컨트롤 | Apple 기본 컴포넌트와 의미 색상 |
| 유리 재질과 그림자 | 시스템 외관과 Liquid Glass |
| 간격과 모서리, 모션 | 기본 컴포넌트 규격과 동작 우선 |
| Ttak 로고와 브랜드 강조 | 필요한 곳에만 브랜드 토큰 |

공통 간격과 반경은 실제 반복 사용 근거가 생길 때만 추가를 검토한다. 랜딩의 글자 크기, 반응형 배치, 그림자와 블러는 해당 웹 CSS에서 관리한다. 현재 제품 화면을 변경하거나 브랜드 토큰을 일괄 적용하지 않았다.

생성한 Color는 고정 sRGB 값이다. 시스템 적응 색상이나 다크 모드 처리를 대신하지 않는다. 실제 앱의 브랜드 tint 적용과 밝고 어두운 외관의 변형은 별도 화면 검토 대상이다.

## 수정과 확인

저장소 의존성 설치 후 루트에서 실행한다. 기존 Prettier를 사용하며 추가 라이브러리나 CI 정책은 없다.

```sh
npm run tokens:build
npm run tokens:check
node tools/design-tokens/contrast.mjs
npm run tokens:preview
```

JSON을 수정한 뒤 CSS, Swift, 목록과 미리보기를 함께 재생성한다. 생성 파일은 직접 수정하지 않는다. `tokens:check`는 참조와 이름 충돌, 생성물 일관성과 기존 회귀 검사를 확인한다. 실제 화면의 접근성 전체를 보장하는 검사는 아니다.

미리보기 서버는 [127.0.0.1:4174](http://127.0.0.1:4174)에서 실행된다. 토큰 수정 뒤 재생성하고 브라우저를 새로고침한다. 미리보기의 배치와 설명용 스타일은 제품 공통 토큰이 아니다.

Swift 파일은 기존 Xcode 앱 타깃에 연결되어 있다. 브랜드 강조를 적용하기로 한 화면에서만 `TtakTokens.Colors.brandStrong`처럼 참조한다. 기본 텍스트나 팝오버 배경을 이 값으로 일괄 대체하지 않는다.
