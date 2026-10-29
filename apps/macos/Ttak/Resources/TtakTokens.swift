// Generated from design-system/tokens.json. Run npm run tokens:build.
// Brand colors only. Use system styles for native text, controls and materials.
import SwiftUI

enum TtakTokens {
    enum Colors {
        static let brandCoral = TtakTokens.color(0xD75D_57FF)
        static let brandOrange = TtakTokens.color(0xE393_43FF)
        static let brandStrong = TtakTokens.color(0xA94F_27FF)
        static let brandTint = TtakTokens.color(0xFFF3_E9FF)
        static let logoCoral = TtakTokens.color(0xEF78_68FF)
        static let logoOrange = TtakTokens.color(0xF6AD_55FF)
    }

    private static func color(_ rgba: UInt32) -> Color {
        Color(
            .sRGB,
            red: Double((rgba >> 24) & 255) / 255,
            green: Double((rgba >> 16) & 255) / 255,
            blue: Double((rgba >> 8) & 255) / 255,
            opacity: Double(rgba & 255) / 255
        )
    }
}
