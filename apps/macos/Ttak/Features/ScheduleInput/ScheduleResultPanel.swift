import SwiftUI

/// Edits temporary results and forwards actions without saving or clearing input.
struct ScheduleResultPanel: View {
    @Binding var drafts: [ScheduleDraft]
    let lists: [ReminderList]
    let calendar: Calendar
    let onCancel: () -> Void
    let onRegister: ([ScheduleDraft]) -> Void

    private var includedDrafts: [ScheduleDraft] {
        drafts.filter { !$0.isExcluded }
    }

    private var canRegister: Bool {
        !includedDrafts.isEmpty
            && includedDrafts.allSatisfy {
                $0.validationMessage(lists: lists, calendar: calendar) == nil
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("\(includedDrafts.count)개 일정")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            if includedDrafts.isEmpty {
                Text("등록할 일정이 없어요.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
            } else {
                ForEach($drafts) { $draft in
                    if !draft.isExcluded {
                        ScheduleResultItem(
                            draft: $draft, lists: lists, calendar: calendar,
                            onExclude: exclude)
                    }
                }
            }
            HStack {
                Button("취소", action: onCancel)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 16)
                Button("\(includedDrafts.count)개 등록") {
                    guard canRegister else { return }
                    onRegister(includedDrafts)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canRegister)
            }
        }
        .padding(15)
        .frame(maxWidth: 500, alignment: .leading)
        .glassEffect(
            .regular.tint(Color(nsColor: .windowBackgroundColor).opacity(0.35)),
            in: RoundedRectangle(cornerRadius: 24)
        )
    }

    private func exclude(_ id: UUID) {
        guard let index = drafts.firstIndex(where: { $0.id == id }) else { return }
        drafts[index].isExcluded = true
    }
}
