import SwiftUI

/// Edits one draft. The owner handles exclusion and all service calls.
struct ScheduleResultItem: View {
    @Binding var draft: ScheduleDraft
    let lists: [ReminderList]
    let calendar: Calendar
    let onExclude: (UUID) -> Void

    @State private var isNotesExpanded = false
    @State private var isDatePickerPresented = false
    @State private var isTimePickerPresented = false
    @State private var selectedDate = Date()
    @State private var selectedHour = 0
    @State private var selectedMinute = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                TextField("일정 제목", text: $draft.title, axis: .vertical)
                    .font(.headline)
                    .textFieldStyle(.plain)
                    .accessibilityLabel("일정 제목")
                Button("제외") { onExclude(draft.id) }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("\(draft.title) 항목 제외")
            }
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    dateField.frame(minWidth: 140)
                    timeField.frame(minWidth: 120)
                    listField.frame(minWidth: 140)
                }
                VStack(alignment: .leading, spacing: 12) {
                    dateField
                    timeField
                    listField
                }
            }
            if draft.validationMessage(lists: lists, calendar: calendar) != nil {
                VStack(alignment: .leading, spacing: 6) {
                    if draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        confirmation("제목을 입력하세요.")
                    }
                    if draft.dateNeedsConfirmation {
                        VStack(alignment: .leading, spacing: 8) {
                            confirmation("날짜 원문을 메모에서 확인하고 날짜를 직접 확정하세요.")
                            Button("입력한 날짜로 확정") { draft.dateNeedsConfirmation = false }
                                .disabled(!hasValidDate)
                        }
                    } else if !hasValidDate {
                        confirmation("달력에서 유효한 날짜를 선택하세요.")
                    }
                    if !draft.timeText.isEmpty,
                        ScheduleDateParser.components(
                            date: draft.dateText, time: draft.timeText, calendar: calendar) == nil
                            && hasValidDate
                    {
                        confirmation("시각을 다시 선택하거나 시각 미지정으로 변경하세요.")
                    }
                    if !lists.contains(where: { $0.id == draft.listID }) {
                        confirmation("저장할 목록을 선택하세요.")
                    }
                }
            }
            DisclosureGroup("메모", isExpanded: $isNotesExpanded) {
                TextField("메모를 입력하세요", text: $draft.notes, axis: .vertical)
                    .lineLimit(3...8)
                    .textFieldStyle(.plain)
                    .accessibilityLabel("메모")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(
                        Color(nsColor: .textBackgroundColor).opacity(0.9),
                        in: RoundedRectangle(cornerRadius: 10)
                    )
                    .padding(.top, 8)
            }
            .font(.callout)
        }
        .padding(20)
        .frame(maxWidth: 500)
        .glassEffect(
            .regular.tint(Color(nsColor: .windowBackgroundColor).opacity(0.35)),
            in: RoundedRectangle(cornerRadius: 24)
        )
    }

    private var hasValidDate: Bool {
        ScheduleDateParser.components(date: draft.dateText, time: "", calendar: calendar) != nil
    }

    private var dateField: some View {
        field("날짜") {
            Button {
                selectedDate =
                    ScheduleDateParser.components(
                        date: draft.dateText, time: "", calendar: calendar
                    ).flatMap { calendar.date(from: $0) } ?? Date()
                isDatePickerPresented = true
            } label: {
                selectionLabel(draft.dateText.isEmpty ? "날짜 선택" : draft.dateText)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $isDatePickerPresented) {
                VStack(alignment: .trailing, spacing: 12) {
                    DatePicker("날짜 선택", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .environment(\.calendar, calendar)
                        .environment(\.timeZone, calendar.timeZone)
                    Button("선택한 날짜 적용") {
                        draft.dateText = ScheduleDateParser.dateText(
                            selectedDate, calendar: calendar)
                        isDatePickerPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(16)
            }
        }
    }

    private var timeField: some View {
        field("시각 (선택)") {
            Button {
                let parts = ScheduleDateParser.components(
                    date: "2000-01-01", time: draft.timeText, calendar: calendar)
                selectedHour = parts?.hour ?? 0
                selectedMinute = parts?.minute ?? 0
                isTimePickerPresented = true
            } label: {
                selectionLabel(draft.timeText.isEmpty ? "시각 미지정" : draft.timeText)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $isTimePickerPresented) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("시각 선택").font(.headline)
                    HStack {
                        Picker("시", selection: $selectedHour) {
                            ForEach(0..<24, id: \.self) { hour in
                                Text(String(format: "%02d시", hour)).tag(hour)
                            }
                        }
                        Picker("분", selection: $selectedMinute) {
                            ForEach(0..<60, id: \.self) { minute in
                                Text(String(format: "%02d분", minute)).tag(minute)
                            }
                        }
                    }
                    HStack {
                        Button("시각 미지정") {
                            draft.timeText = ""
                            isTimePickerPresented = false
                        }
                        Spacer()
                        Button("적용") {
                            draft.timeText = String(
                                format: "%02d:%02d", selectedHour, selectedMinute)
                            isTimePickerPresented = false
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(16)
                .frame(width: 300)
            }
        }
    }

    private func selectionLabel(_ value: String) -> some View {
        HStack {
            Text(value)
            Spacer(minLength: 8)
            Image(systemName: "chevron.down")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: 24)
        .contentShape(Rectangle())
    }

    private var listField: some View {
        field("미리 알림 목록") {
            Picker("미리 알림 목록", selection: $draft.listID) {
                Text("목록 선택").tag(String?.none)
                if let id = draft.listID, !lists.contains(where: { $0.id == id }) {
                    Text("사용할 수 없는 목록").tag(Optional(id))
                }
                ForEach(lists) { list in
                    Text(ScheduleResultItem.listLabel(list, in: lists)).tag(Optional(list.id))
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 20)
            .overlay(alignment: .trailing) {
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
            }
        }
    }

    private func field<Content: View>(
        _ title: String, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            content()
                .textFieldStyle(.plain)
                .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
                .padding(10)
                .background(
                    Color(nsColor: .textBackgroundColor).opacity(0.9),
                    in: RoundedRectangle(cornerRadius: 10)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1)
                        .allowsHitTesting(false)
                }
        }
    }

    private func confirmation(_ message: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Image(systemName: "exclamationmark.circle")
                .accessibilityHidden(true)
            Text(message)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.caption)
        .foregroundStyle(TtakTokens.Colors.brandStrong)
    }

    nonisolated static func listLabel(_ list: ReminderList, in lists: [ReminderList]) -> String {
        lists.filter { $0.title == list.title }.count > 1
            ? "\(list.title) (\(list.id))" : list.title
    }
}
