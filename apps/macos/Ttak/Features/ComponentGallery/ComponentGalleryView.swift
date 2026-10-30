#if DEBUG
    import SwiftUI

    struct ComponentGalleryView: View {
        static let windowID = "component-gallery"

        @State private var selectedSample: GallerySample? = .brand
        @State private var sampleState: GalleryState = .normal
        @State private var actionCount = 0

        var body: some View {
            NavigationSplitView {
                List(GallerySample.allCases, selection: $selectedSample) { sample in
                    Text(sample.rawValue).tag(sample)
                }
                .navigationTitle("샘플 목록")
                .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 260)
            } detail: {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text((selectedSample ?? .brand).rawValue).font(.largeTitle)
                        Text("개발용 샘플입니다. 실제 분석, 권한 요청과 미리 알림 저장은 실행하지 않아요.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Divider()
                        sampleContent
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(minWidth: 760, minHeight: 520)
        }

        @ViewBuilder
        private var sampleContent: some View {
            switch selectedSample ?? .brand {
            case .brand:
                brandSample
            case .typography:
                typographySample
            case .controls:
                controlsSample
            case .message:
                messageSample
            case .prototype:
                SchedulePrototypeView()
            case .resultPanel:
                ScheduleResultPanelSampleView()
            case .resultItem:
                ScheduleResultItemSampleView()
            case .composer:
                ScheduleComposerSampleView()
            }
        }

        private var brandSample: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text("TtakTokens의 기존 브랜드 색상").font(.headline)
                Text("색상 이름과 스와치를 함께 확인하세요. 본문과 기본 컨트롤은 시스템 스타일을 유지합니다.")
                    .foregroundStyle(.secondary)
                colorRow("brandCoral", color: TtakTokens.Colors.brandCoral)
                colorRow("brandOrange", color: TtakTokens.Colors.brandOrange)
                colorRow("brandStrong", color: TtakTokens.Colors.brandStrong)
                colorRow("brandTint", color: TtakTokens.Colors.brandTint)
                colorRow("logoCoral", color: TtakTokens.Colors.logoCoral)
                colorRow("logoOrange", color: TtakTokens.Colors.logoOrange)
            }
        }

        private func colorRow(_ name: String, color: Color) -> some View {
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.3)))
                    .frame(width: 64, height: 36)
                    .accessibilityHidden(true)
                Text(name).font(.body.monospaced())
            }
        }

        private var typographySample: some View {
            VStack(alignment: .leading, spacing: 20) {
                Text("시스템 텍스트 스타일").font(.headline)
                Text("제목 예시 / title").font(.title)
                Text("섹션 제목 / headline").font(.headline)
                Text("일정과 안내를 읽는 본문 / body").font(.body)
                Text("공통 메시지 / callout").font(.callout)
                Text("보조 설명 / caption, secondary").font(.caption).foregroundStyle(.secondary)
                Divider()
                Text("아래 간격은 갤러리 배치 예시이며 새 공통 토큰이 아닙니다.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack(alignment: .top, spacing: 32) {
                    spacingSample(8)
                    spacingSample(12)
                    spacingSample(20)
                }
            }
        }

        private func spacingSample(_ spacing: CGFloat) -> some View {
            VStack(alignment: .leading, spacing: spacing) {
                Text("간격 \(Int(spacing))pt").font(.caption)
                Text("첫 번째 항목")
                Text("두 번째 항목")
            }
            .padding(12)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }

        private var statePicker: some View {
            Picker("샘플 상태", selection: $sampleState) {
                ForEach(GalleryState.allCases) { state in
                    Text(state.rawValue).tag(state)
                }
            }
            .pickerStyle(.segmented)
        }

        private var controlsSample: some View {
            VStack(alignment: .leading, spacing: 20) {
                Text("Apple 기본 컨트롤의 사용 예시").font(.headline)
                statePicker
                HStack {
                    Button("샘플 동작") { actionCount += 1 }
                        .buttonStyle(.borderedProminent)
                        .disabled(sampleState == .disabled || sampleState == .loading)
                    Button("횟수 초기화") { actionCount = 0 }
                        .buttonStyle(.bordered)
                }
                Text("샘플 버튼 실행 횟수: \(actionCount)")
                if sampleState == .loading {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text("진행 중 표현 샘플입니다. 상태를 바꾸면 종료됩니다.")
                    }
                }
                if sampleState == .error {
                    Text("오류 표현 샘플입니다. 실제 요청은 발생하지 않았어요.")
                        .foregroundStyle(.red)
                }
                Text("이 화면은 새 버튼 컴포넌트가 아니라 네이티브 스타일의 조합 예시입니다.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }

        private var messageSample: some View {
            VStack(alignment: .leading, spacing: 20) {
                Text("실제 앱과 공유하는 ScheduleMessageView").font(.headline)
                statePicker
                ScheduleMessageView(message: sampleState.message)
                Text("입력 화면의 모델 안내 메시지와 같은 View입니다. 갤러리는 메시지 문자열만 전달합니다.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private enum GallerySample: String, CaseIterable, Identifiable {
        case brand = "브랜드 색상"
        case typography = "글자와 간격"
        case controls = "컨트롤 상태"
        case message = "공통 안내 메시지"
        case prototype = "입력부터 등록까지 프로토타입"
        case resultPanel = "일정 결과 패널"
        case resultItem = "일정 결과 항목과 편집"
        case composer = "일정 입력과 이미지 첨부"

        var id: String { rawValue }
    }

    private enum GalleryState: String, CaseIterable, Identifiable {
        case normal = "기본"
        case disabled = "비활성"
        case loading = "진행"
        case error = "오류"

        var id: String { rawValue }

        var message: String {
            switch self {
            case .normal: "샘플 안내: 입력한 일정을 확인해 주세요."
            case .disabled: "샘플 안내: 실행할 수 있는 입력이 없어요."
            case .loading: "샘플 안내: 분석 진행을 표현하고 있어요. 실제 분석은 실행하지 않습니다."
            case .error: "샘플 안내: 분석 실패를 표현하고 있어요. 입력은 유지됩니다."
            }
        }
    }
#endif
