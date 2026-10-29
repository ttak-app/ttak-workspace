import SwiftUI

struct ScheduleMessageView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.callout)
            .textSelection(.enabled)
    }
}
