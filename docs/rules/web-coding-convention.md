# React·TypeScript 코딩 컨벤션

적용 대상은 `apps/web`다. [공통 컨벤션](coding-convention.md)을 함께 적용한다.
현재 React·TypeScript·Vite·기본 CSS·Oxlint 구성에서 출발한다.

## 이름·폴더·형식

- 컴포넌트와 그 파일은 `PascalCase`: `App.tsx`, `DownloadButton.tsx`.
- 훅은 `use` 접두사, props 인터페이스는 `Props` 접미사: `useDownload`, `DownloadButtonProps`.
- 일반 변수·함수는 `camelCase`, 고정된 전역 구성 상수는 필요한 경우 `UPPER_SNAKE_CASE`.
- Bool은 `isVisible`, `hasError`, `canSubmit`처럼 의미가 드러나게 짓는다.
- 폴더는 소문자·kebab-case를 기본으로 하되 복수형을 기계적으로 강제하지 않는다. 현재 src 구조를 의미 없이 이동하지 않는다.
- 들여쓰기 2칸, 문자열은 single quote, 문장 끝 세미콜론은 현재 코드처럼 생략한다.
  JSX 속성은 double quote, 여러 줄 리터럴은 기존 trailing comma 스타일을 따른다.
- 이 문서 때문에 기존 파일을 일괄 재포맷하지 않는다. 포맷터 도입 시 문서와 설정을 함께 맞춘다.

## TypeScript·함수

- 재할당이 없으면 `const`, 필요하면 `let`; JavaScript `var`는 사용하지 않는다.
- 객체 계약은 `interface`, union·tuple·literal·조합 타입은 `type`을 우선한다. 타입 표현에 필요한 type alias를 금지하지 않는다.
- React 타입은 `import type { ReactNode } from 'react'`처럼 개별 type import를 사용한다.
- 현재 코드와 맞춰 이름 있는 컴포넌트는 `function` 선언을 사용하고, 짧은 콜백은 화살표 함수를 사용한다.
  기존 헬퍼의 선언 형식을 수정 목적 없이 바꾸지 않는다.
- 이벤트 핸들러는 `handleSubmit`처럼 handle 접두사를 기본으로 하고 일반 계산·변환에는 목적에 맞는 이름을 사용한다.
- 문자열 값 삽입은 템플릿 리터럴을 우선한다. const → let 순서만을 위한 무관한 선언 재배치는 하지 않는다.

## React·UI

- 자식이 없으면 self-closing JSX를 사용한다. 의미 없는 wrapper는 피하고, 레이아웃이나 시맨틱 역할이 있으면 적절한 요소를 사용한다.
- HTML의 의미와 기본 접근성을 유지한다. 상호작용은 button·a·input 등 적합한 기본 요소를 사용한다.
- 컴포넌트의 상태와 부작용 소유자를 명확히 한다. 공유 컴포넌트에 특정 기능의 저장·분석 로직을 억지로 넣지 않는다.
- 수정·정렬·필터링되는 목록의 key는 안정적인 항목 ID를 사용한다. 렌더마다 난수·UUID를 만들지 않는다.
  인덱스는 항목의 위치와 정체성이 실제로 고정된 목록에서만 근거를 두고 사용한다.
- React Compiler는 현재 도입됐다고 가정하지 않는다. useMemo/useCallback은 실제 필요에 따라 사용하며 일괄 추가·제거하지 않는다.
- Context를 도입하면 `Context` 접미사를 사용하되, 현재 필요 없는 HOC·전역 상태·디자인 시스템 패키지를 새로 만들지 않는다.
- API 서버가 없는 현재 범위에 React Query·Axios·OpenAPI 생성 규칙을 의무로 추가하지 않는다.

## 검증

`npm run lint:web`, `npm run check-types:web`, `npm run build:web`와 변경된 UI의 실제 동작을 확인한다.
Oxlint가 이 문서의 모든 스타일 규칙을 자동 강제한다고 주장하지 않는다.
Swift·SwiftUI 파일에는 이 문서의 var·const·JSX·Props 규칙을 적용하지 않는다.

## 참고

[Keeply 코딩 컨벤션](https://github.com/Project-Keeply/Keeply-Client/blob/999cb6e930a4a1289a4025a03b7c615bba0afc8b/docs/rules/coding-convention.md)을
Ttak의 실제 기술 구성과 코드 스타일에 맞췄다.
