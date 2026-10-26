# 코드 포맷 자동화

웹은 Prettier, Swift는 Xcode 툴체인의 swift-format을 사용한다.
각 앱 폴더에 설정을 두고 언어별 범위를 분리한다. 기존 Oxlint 검사와 Swift 컴파일은 유지한다.

## 실행

저장소 루트에서 실행한다.

| 대상 | 파일 수정 | 읽기 전용 검사 |
| --- | --- | --- |
| 웹 | `npm run format:web` | `npm run format:check:web` |
| Swift 앱 | `npm run format:macos` | `npm run format:check:macos` |

수정 명령은 대상 파일을 덮어쓴다. 검사는 파일을 수정하지 않고 형식 위반이 있으면 실패한다.
작업한 대상의 수정 명령을 실행한 뒤 diff를 확인하고 검사 명령으로 마무리한다.
Git 훅이나 저장 시 자동 실행을 설치하지 않는다. CI는 읽기 전용 검사만 실행한다.

## 웹

`npm ci`로 설치한 Prettier 3.9.10을 사용한다. 정확한 버전은
[웹 package.json](../apps/web/package.json)과 루트 잠금 파일로 관리한다.
[설정](../apps/web/.prettierrc.json)은 기존 2칸 들여쓰기, 작은따옴표, JSX 큰따옴표,
세미콜론 생략과 trailing comma를 유지한다. 기타 줄바꿈은 도구 기본값을 따른다.

적용 범위는 apps/web의 JS, MJS, CJS, TS, TSX, CSS, JSON과 HTML이다.
[제외 목록](../apps/web/.prettierignore)으로 node_modules, dist, coverage와 빌드 캐시를 제외한다.
Markdown, Swift, 루트 설정과 Node 실행 도구에는 웹 포맷 명령을 적용하지 않는다.
설정 파일과 npm 명령 자체가 포맷 검사 범위에 포함된다.

## Swift

전체 Xcode 26 이상이 설치된 Mac에서 `xcrun swift format`을 실행한다.
[설정](../apps/macos/.swift-format)에서 4칸 들여쓰기를 지정하고 나머지는 도구 기본값을 사용한다.
apps/macos/Ttak과 apps/macos/TtakTests 아래의 Swift 파일만 재귀적으로 처리한다.
Xcode 프로젝트와 리소스, README 및 빌드 산출물은 대상에 포함하지 않는다.

포맷터는 `xcode-select` 또는 DEVELOPER_DIR로 선택한 Xcode를 따른다.
CI는 기존 Xcode 26.6을 사용한다. 로컬 Xcode 버전이 다르면 포맷 결과도 달라질 수 있으므로
문제를 재현할 때 `xcodebuild -version`과 `xcrun swift format --version`을 함께 확인한다.
도구 버전 출력이 main인 환경에서는 Xcode 버전도 함께 기록한다.
`format:check:macos`는 `lint --strict`를 사용해 경고도 실패로 처리한다.

## CI

기존 Web job에서 설치 후 웹 포맷을 검사하고, 기존 macOS Build job에서 빌드 전 Swift 포맷을 검사한다.
웹만 변경하면 웹 검사만, Swift만 변경하면 Swift 검사만 선택한다.
앱별 포맷 설정도 해당 앱만 선택하며, 루트 package.json과 CI 정의 변경은 기존 정책에 따라 전체 검사를 선택한다.
형식 위반으로 선택된 job이 실패하면 CI Result도 실패한다. CI가 자동 수정하거나 커밋하지 않는다.

## 참고

- [Prettier 설치와 검사](https://prettier.io/docs/install)
- [swift-format 사용](https://github.com/swiftlang/swift-format)
- [swift-format 설정](https://github.com/swiftlang/swift-format/blob/main/Documentation/Configuration.md)
