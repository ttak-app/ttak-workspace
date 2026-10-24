# Swift·SwiftUI 코딩 컨벤션

적용 대상은 `apps/macos`다. [공통 컨벤션](coding-convention.md)과
[macOS 개발 기준](macos-development.md)을 함께 적용한다.
Swift 6 언어 모드·macOS 26+의 네이티브 메뉴바 앱이며 iOS 앱 규칙을 자동 이식하지 않는다.

## 이름·파일·폴더

- 타입·프로토콜은 `UpperCamelCase`: `ScheduleDraft`, `ReminderStore`.
- 프로퍼티·변수·상수·enum case·함수는 `lowerCamelCase`: `selectedListID`, `maximumInputLength`, `analyzing`.
  상수를 `UPPER_SNAKE_CASE`로 만들지 않는다. 타입 소속 상수는 필요에 따라 `static let`을 사용한다.
- Bool은 `isAnalyzing`, `hasPermission`, `canRegister`처럼 참·거짓이 자연스럽게 읽히도록 이름 짓는다.
  `is` 하나만 강제하거나 모든 Bool 함수를 `has`로 시작하게 하지 않는다.
- 함수는 호출문 전체가 자연스럽도록 동작과 인자 레이블을 정한다: `analyze(input:)`, `save(drafts:to:)`.
  `get`, `handle`, `Click` 접두사·접미사를 모든 함수에 일괄 적용하지 않는다.
- 주요 타입 파일은 타입 이름과 맞춘다: `ScheduleInputView.swift`, `ScheduleDraft.swift`.
  새 보조 파일은 관련 타입·기능과 역할이 드러나게 이름 짓는다.
- 현재 `App`, `Features`, `Models`, `Services`, `Resources` 구조를 유지한다.
  폴더 전체에 소문자·복수형·kebab-case를 강제하지 않는다. 기능 내부 폴더는 해당 기능 이름을 사용한다.

## 선언과 타입

- 재할당하지 않는 저장 값은 `let`, 변경되는 값은 `var`를 사용한다.
- `@State private var input`, `var body: some View` 등 SwiftUI에 필요한 `var`를 금지하지 않는다.
- 역할에 맞는 `struct`, `enum`, `class`, `protocol`을 선택한다. TypeScript의 interface 우선 규칙을 옮기지 않는다.
- 값 데이터와 상태 선택지는 `struct`·`enum`을 우선 검토하고, 참조 정체성·공유 관찰·상속 등 근거가 있을 때 `class`를 사용한다.
- 프로토콜은 실제 경계·대체 구현·테스트 필요가 있을 때 도입한다. 모든 타입에 Protocol이나 ViewModel을 자동 생성하지 않는다.
- 구현 내부 상태·헬퍼는 `private`를 우선 검토한다. 같은 모듈에서 필요한 선언은 기본 internal로 충분하며 무조건 public으로 열지 않는다.
- 읽기와 쓰기 권한이 다르면 `private(set)` 등 적절한 접근 범위를 사용한다.

## 함수·컬렉션·문자열

- 이름 있는 동작은 `func`, 동작을 전달하거나 짧은 액션을 표현할 때는 클로저를 사용한다.
- 컬렉션 변환에는 `map`·`filter`·`compactMap` 등을 사용하되 `break`, `continue`, 순서 있는 부작용에는 `for`를 사용할 수 있다.
- 배열 복사는 일반 대입과 Swift 값 의미론을 사용한다. JavaScript spread/destructuring 문법을 흉내 내지 않는다.
- 값 삽입은 `"\(count)개 등록"`처럼 문자열 보간을 사용한다. String의 `+` 자체를 언어 오류처럼 금지하지 않는다.
- 변환·순회 선택은 명확성을 기준으로 한다. 가장 짧은 표현이나 함수형 문법 자체가 목적은 아니다.

## SwiftUI 상태·목록

- View가 소유하는 로컬 상태는 `@State`, 외부 소유 상태를 수정해야 할 때는 `@Binding`을 검토한다.
- 관찰 모델이 필요하면 현재 지원 OS에 맞는 Observation(`@Observable`, 필요 시 `@Bindable`)과 소유 수명을 명확히 한다.
  모든 View를 관찰 모델로 만들거나 상태 래퍼를 기계적으로 치환하지 않는다.
- 여러 View가 같은 상태를 사용할 때는 단일 소유자를 정하고 명시적인 전달 또는 환경 주입을 선택한다.
  모든 모델을 전역 싱글턴으로 두지 않는다.
- View의 body는 UI 구성을 중심으로 유지한다. 모델 분석·저장·권한 요청 같은 부작용을 body 계산 자체에서 실행하지 않는다.
- 수정·제외되는 일정 목록은 `Identifiable` 또는 명시적인 안정 ID를 사용한다. 배열 인덱스를 기본 항목 ID로 사용하지 않는다.
- UUID는 초안 생성 시 한 번 만들고 유지할 수 있다. body 계산이나 id getter에서 매번 UUID를 생성하지 않는다.

## Optional·오류·비동기

- `guard let`, `if let` 등 명시적인 Optional 처리를 우선한다. `!`, `try!`, 오류를 버리는 `try?`는 안전성과 의도에 대한 근거가 있을 때만 사용한다.
- 도메인 오류는 원인과 호출부의 처리 방식이 드러나도록 표현한다. 저장 실패를 빈 성공 결과로 바꾸지 않는다.
- 비동기는 `async/await`를 사용하고 작업의 소유자·취소·재실행·종료 시점을 정한다.
- UI 상태의 actor 격리를 확인한다. 필요한 경계에 `@MainActor`를 적용하고 모든 서비스나 무거운 처리를 일괄 MainActor로 옮기지 않는다.
- `async`라는 이유만으로 무거운 연산이 자동으로 UI 실행 영역을 벗어났다고 가정하지 않는다.
- actor 간 전달 데이터의 `Sendable` 조건을 확인한다. 경고를 숨기기 위한 `@unchecked Sendable`을 근거 없이 추가하지 않는다.
- 취소나 새 입력 이후 오래된 분석 결과가 현재 입력을 덮어쓰지 않도록 한다.

## 형식·확인

- 들여쓰기 4칸, 중괄호는 선언과 같은 줄, 타입·함수 사이의 구분은 기존 Swift 파일과 맞춘다.
- 임의의 줄 길이 제한이나 새 포맷터 규칙을 추가하지 않는다. 도구를 선정하면 이 문서와 함께 맞춘다.
- 빌드·테스트·실기기 검증은 [macOS 개발 기준](macos-development.md)을 따른다.

## 공식 근거

- [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
- [Swift 기본 문법](https://docs.swift.org/swift-book/LanguageGuide/TheBasics.html)
- [SwiftUI 모델 데이터](https://developer.apple.com/documentation/swiftui/model-data)
- [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
