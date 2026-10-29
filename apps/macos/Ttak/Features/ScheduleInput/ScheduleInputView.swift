import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ScheduleInputView: View {
    @State private var model = ScheduleInputModel()
    @State private var attachmentError = ""
    @FocusState private var isInputFocused: Bool
    #if DEBUG
        @Environment(\.openWindow) private var openWindow
    #endif

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Ttak 기술 검증")
                    .font(.headline)
                Text(model.modelDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField(
                    "일정을 말하듯 적어주세요",
                    text: Binding(
                        get: { model.input },
                        set: {
                            model.input = $0
                            model.inputDidChange()
                        }
                    ), axis: .vertical
                )
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)
                .focused($isInputFocused)
                .disabled(model.isBusy || model.hasAttemptedSave)
                .onPasteCommand(of: [.image]) { _ in pasteImage() }
                HStack {
                    Button("이미지 선택", action: selectImage)
                    Button("이미지 붙여넣기", action: pasteImage)
                }
                .disabled(model.isBusy || model.hasAttemptedSave)
                if let data = model.imageData, let image = NSImage(data: data) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 130)
                    HStack {
                        Text(model.imageName).font(.caption).lineLimit(1)
                        Spacer()
                        Button("이미지 삭제") { model.removeImage() }
                            .disabled(model.isBusy || model.hasAttemptedSave)
                    }
                }
                if !attachmentError.isEmpty {
                    Text(attachmentError).font(.caption).foregroundStyle(.red)
                }
                Text("날짜 생략은 분석일 기준 오늘이에요. 확인할 수 없는 숫자 시각은 다시 입력해야 해요.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("분석 시 입력한 텍스트와 이미지에서 인식한 글자, 보조 설명이 Google Gemini로 전송돼요.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("분석") { model.startAnalysis() }
                        .disabled(!model.canAnalyze)
                    if model.isAnalyzing {
                        ProgressView().controlSize(.small)
                        Button("분석 취소") { model.cancelAnalysis() }
                    }
                    Spacer()
                    Button("환경 새로 확인") { model.refreshAvailability() }
                }
                Divider()
                Text(model.accessDescription).font(.caption)
                Button(model.isLoadingLists ? "목록 조회 중..." : "미리 알림 접근 및 목록 조회") {
                    Task { await model.loadLists() }
                }
                .disabled(model.isBusy || model.hasAttemptedSave)
                Text("등록은 실제 미리 알림을 생성해요. 검증에 사용할 목록을 직접 확인하고 선택하세요.")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach($model.drafts) { $draft in
                    draftEditor($draft)
                        .disabled(model.isBusy || model.hasAttemptedSave)
                }
                if !model.drafts.isEmpty && !model.hasAttemptedSave {
                    HStack {
                        Button("\(model.includedDrafts.count)개 등록") { model.saveConfirmedDrafts() }
                            .disabled(!model.canSave)
                        Button("결과 취소") { model.cancelPreview() }
                            .disabled(model.isBusy)
                    }
                }
                if !model.message.isEmpty {
                    ScheduleMessageView(message: model.message)
                }
                if !model.saveOutcomes.isEmpty {
                    ForEach(model.saveOutcomes) { outcome in
                        Text("\(outcome.title): \(outcome.message)")
                            .font(.caption)
                            .foregroundStyle(outcome.status == .saved ? Color.secondary : Color.red)
                    }
                }
                if model.hasAttemptedSave {
                    Button("미리 알림 확인 후 새 입력 시작") { model.beginNewInputAfterCheckingReminders() }
                }
                Divider()
                #if DEBUG
                    Button("개발용 컴포넌트 갤러리") {
                        openWindow(id: ComponentGalleryView.windowID)
                    }
                #endif
                Button("Ttak 종료") { NSApplication.shared.terminate(nil) }
            }
            .padding(20)
        }
        .frame(width: 440)
        .frame(maxHeight: 650)
        .onAppear {
            isInputFocused = true
            model.refreshAvailability()
        }
    }

    private func draftEditor(_ draft: Binding<ScheduleDraft>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("이 항목 제외", isOn: draft.isExcluded)
            TextField("제목", text: draft.title)
            HStack {
                TextField("yyyy-MM-dd", text: draft.dateText)
                TextField("HH:mm 또는 빈칸", text: draft.timeText)
            }
            if draft.wrappedValue.dateNeedsConfirmation {
                Button("원문 확인 후 입력한 날짜로 확정") {
                    draft.wrappedValue.dateNeedsConfirmation = false
                }
            }
            Picker("저장 목록", selection: draft.listID) {
                Text("직접 선택").tag(String?.none)
                ForEach(model.lists) { list in Text(list.title).tag(Optional(list.id)) }
            }
            TextField("장소와 메모, 종료 정보", text: draft.notes, axis: .vertical)
                .lineLimit(2...5)
            if !draft.wrappedValue.isExcluded,
                let error = draft.wrappedValue.validationMessage(
                    lists: model.lists, calendar: model.analysisCalendar)
            {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
        .textFieldStyle(.roundedBorder)
        .padding(10)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
    }

    private func selectImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            guard NSImage(data: data) != nil else {
                attachmentError = "읽을 수 있는 이미지 파일을 선택하세요."
                return
            }
            attachmentError = ""
            model.attachImage(data, name: url.lastPathComponent)
        } catch {
            attachmentError = "이미지 파일을 읽지 못했어요: \(error.localizedDescription)"
        }
    }

    private func pasteImage() {
        guard let image = NSImage(pasteboard: .general), let data = image.tiffRepresentation else {
            attachmentError = "클립보드에 이미지가 없어요."
            return
        }
        attachmentError = ""
        model.attachImage(data, name: "붙여넣은 이미지")
    }
}
