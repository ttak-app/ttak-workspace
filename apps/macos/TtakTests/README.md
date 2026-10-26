# TtakTests

Swift Testing 기반 macOS 단위 테스트 타깃입니다. 앱 모듈은 `@testable import Ttak`으로 가져옵니다.
테스트 파일은 이 폴더에 추가하고 Xcode에서 `TtakTests` 타깃의 소스로 등록합니다.

저장소 루트에서 실행합니다.

```sh
npm run macos:test
```

Xcode에서는 공유 `Ttak` 스킴과 `My Mac`을 선택하고 Test를 실행합니다.
별도 테스트 플랜이나 외부 테스트 패키지는 사용하지 않습니다.

`TestEnvironmentTests`는 앱 모듈과 테스트 호스트의 연결을 확인합니다.
앱의 Bundle Identifier를 변경하면 이 테스트의 기대값도 함께 갱신합니다.
이 테스트의 성공이 메뉴바 UI, 날짜 해석이나 미리 알림 저장의 정상 동작을 보증하지 않습니다.
실제 기능 테스트는 해당 기능을 구현할 때 추가하며 사용자 미리 알림을 생성하거나 삭제하지 않습니다.

XCTest가 출력하는 `Executed 0 tests`와 Swift Testing의 실행 결과는 구분합니다.
최종 Swift Testing 요약에서 실제 테스트 수와 성공 여부를 확인합니다.
