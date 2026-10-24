---
name: logic-architecture
description: Ttak macOS의 SwiftUI 상태 수명, 비동기 경계, 모델 추출과 EventKit 저장 책임을 검토한다. 복잡한 로직 설계나 구조 검토 요청에 사용하며 단순 변경에 패턴을 강제하지 않는다.
---

# Swift·SwiftUI 구조 검토

[macOS 경계](../../../docs/rules/macos-development.md)와 [작업 흐름](../../../docs/rules/ai-workflow.md)을 읽는다.
현재 파일·호출부와 이슈 AC를 근거로 입력·분석·수정·저장의 상태 수명과 책임을 확인한다.
필요한 actor 격리, cancellation, 메뉴바 창 재진입, 모델 출력 검증, EventKit 권한·부분 실패를 검토한다.
기존의 단순한 방식과 분리 대안을 비교하고 실제 문제를 해결할 때만 패턴·프로토콜을 제안한다.
MVVM/TCA/Repository나 새 외부 패키지를 일괄 도입하지 않는다. Apple API는 사용 SDK 공식 문서로 확인한다.
설계 요청만으로 앱 코드를 수정하지 않는다. 합의한 결정만 작업 명세에 반영한다.
