# CodeRabbit PR 리뷰

[설정 파일](../.coderabbit.yaml)은 Keeply의 한국어 리뷰, chill 강도, Draft 제외와 추가 커밋 리뷰를 참고한다.
Electron 전용 지침은 가져오지 않고 Ttak의 Swift 앱, React 랜딩과 Node 도구 경로에 맞춘다.

## 리뷰 흐름

1. Codex로 구현하고 변경에 필요한 로컬 검증을 수행한다.
2. develop 또는 main 대상 PR을 열면 CodeRabbit이 리뷰한다. Draft는 자동 리뷰에서 제외한다.
3. 리뷰 후 새 커밋을 push하면 추가된 변경을 리뷰한다. CodeRabbit의 사용량 제한과 자동 일시 정지 정책이 적용된다.
4. 지적을 실제 코드와 대조해 필요한 부분만 수정하고 CI 결과를 확인한 뒤 사용자가 병합한다.

CodeRabbit은 GitHub 앱으로 동작한다. GitHub Actions 워크플로와 별개이며 CI에 새 이벤트나 작업을 추가하지 않는다.
리뷰 요약은 PR 본문 대신 walkthrough 댓글에 표시한다. 라벨 추천과 자동 적용, 리뷰어 추천과 배정,
자동 승인, 제목과 본문 검사, 주석 커버리지 검사와 이슈 기획 기능은 사용하지 않는다.
CodeRabbit 내부 SwiftLint와 ESLint도 끈다. 기존 Swift 규칙과 웹 Oxlint 구성을 리뷰 기준으로 사용한다.
리뷰의 언어별 기준은 기존 컨벤션 파일을 각 앱 경로에 연결하고, 추가 지침은 상태와 권한 및 회귀 위험에 집중한다.

생성물과 로컬 증적은 제외하되 소스, 문서, Xcode 설정과 리소스 및 잠금 파일은 리뷰 대상에 남긴다.
`.coderabbit.yaml` 자체 변경은 앱 빌드 입력이 아니므로 CI의 Changes와 CI Result만 실행한다.
같은 PR에 앱이나 실행 도구 변경이 있으면 해당 경로의 검사도 선택한다.

## GitHub 앱 연결과 실제 확인

GitHub의 ttak-app 조직에 CodeRabbit 앱 설치를 확인했다. 설치 ID는 175304869이며, 저장소 접근은 선택한 ttak-workspace로 제한했다. 실제 PR에서 설정 적용과 리뷰 동작은 후속 확인한다.

1. [CodeRabbit GitHub 앱](https://github.com/apps/coderabbitai)에서 조직 ttak-app을 선택한다.
2. 저장소 범위는 Only select repositories에서 ttak-workspace 하나로 제한하고, 설치 화면에 표시된 권한을 확인한다.
3. 설정 파일을 포함한 PR에서 리뷰 댓글과 적용 설정을 확인한다. 앱의 저장소 활성화 상태도 확인한다.
4. `@coderabbitai configuration`으로 적용된 설정을 확인하고 필요하면 `@coderabbitai review`로 리뷰를 요청한다.
5. 한국어 출력, Swift와 웹 지침 분리, Draft와 추가 커밋 동작을 실제 관측한 뒤 이슈 #7의 해당 항목을 완료 처리한다.

앱은 contents, workflows, pull requests, issues, checks와 statuses 등의 쓰기 권한을 요청할 수 있다.
리뷰 전용 설정이 앱 자체의 권한을 축소하는 것은 아니므로 설치 화면의 실제 권한과 저장소 범위를 확인해야 한다.
설치 및 실제 PR 검증 전까지 전체 설정을 완료로 표시하지 않는다.

## 참고

- [Keeply 설정 원본](https://github.com/Project-Keeply/Keeply-Client/blob/999cb6e930a4a1289a4025a03b7c615bba0afc8b/.coderabbit.yaml)
- [CodeRabbit 설정 문서](https://docs.coderabbit.ai/reference/configuration)
- [자동 리뷰 조건](https://docs.coderabbit.ai/configuration/auto-review)
- [코딩 규칙 연결](https://docs.coderabbit.ai/knowledge-base/code-guidelines)
