// Generated from design-system/tokens.json. Run npm run tokens:build.
// CGFloat dimensions are logical points. Durations and delays are seconds.
// Web viewport typography, percentage radii and CSS effects are not converted.
import SwiftUI

enum TtakTokens {
    enum Colors {
        static let textPrimary = TtakTokens.color(0x191F_28FF)
        static let textBody = TtakTokens.color(0x333D_4BFF)
        static let textSecondary = TtakTokens.color(0x6B76_84FF)
        static let textMuted = TtakTokens.color(0x8B95_A1FF)
        static let textSubtle = TtakTokens.color(0xADB5_BDFF)
        static let textPlaceholder = TtakTokens.color(0x9497_A1FF)
        static let textCaption = TtakTokens.color(0x929A_A5FF)
        static let textNotice = TtakTokens.color(0x9BA3_AEFF)
        static let textOnAction = TtakTokens.color(0xFFFF_FFFF)
        static let brandCoral = TtakTokens.color(0xD75D_57FF)
        static let brandOrange = TtakTokens.color(0xE393_43FF)
        static let brandStrong = TtakTokens.color(0xA94F_27FF)
        static let brandTint = TtakTokens.color(0xFFF3_E9FF)
        static let logoCoral = TtakTokens.color(0xEF78_68FF)
        static let logoOrange = TtakTokens.color(0xF6AD_55FF)
        static let accentLegacyBlue = TtakTokens.color(0x3182_F6FF)
        static let actionPrimary = TtakTokens.color(0x2427_35FF)
        static let actionHover = TtakTokens.color(0x3539_49FF)
        static let surfaceDefault = TtakTokens.color(0xFFFF_FFFF)
        static let surfaceField = TtakTokens.color(0xF2F4_F6FF)
        static let surfaceSubtle = TtakTokens.color(0xF7F8_FAFF)
        static let borderDefault = TtakTokens.color(0xE9ED_F2FF)
        static let borderDivider = TtakTokens.color(0xEEF0_F3FF)
        static let statusSuccess = TtakTokens.color(0x3B6D_5BFF)
        static let statusError = TtakTokens.color(0xB845_38FF)
        static let statusDestructive = TtakTokens.color(0xD454_54FF)
        static let statusDestructiveSurface = TtakTokens.color(0xFFF0_F0FF)
        static let focusRing = TtakTokens.color(0xA94F_27FF)
        static let surfaceGlassPanel = TtakTokens.color(0xFFFF_FFED)
        static let surfaceGlassAttachment = TtakTokens.color(0xFFFF_FFBD)
        static let surfaceGlassMenu = TtakTokens.color(0xFFFF_FF70)
        static let surfaceGlassAction = TtakTokens.color(0xFFFF_FF99)
        static let surfaceBorderInput = TtakTokens.color(0xFFFF_FFB3)
    }

    enum Spacing {
        static let value0: CGFloat = 0
        static let value4: CGFloat = 4
        static let value5: CGFloat = 5
        static let value6: CGFloat = 6
        static let value8: CGFloat = 8
        static let value10: CGFloat = 10
        static let value11: CGFloat = 11
        static let value12: CGFloat = 12
        static let value13: CGFloat = 13
        static let value14: CGFloat = 14
        static let value15: CGFloat = 15
        static let value16: CGFloat = 16
        static let value18: CGFloat = 18
        static let value20: CGFloat = 20
        static let value22: CGFloat = 22
        static let value24: CGFloat = 24
        static let value26: CGFloat = 26
        static let value28: CGFloat = 28
        static let value30: CGFloat = 30
        static let value32: CGFloat = 32
        static let value34: CGFloat = 34
        static let value35: CGFloat = 35
        static let value36: CGFloat = 36
        static let value38: CGFloat = 38
        static let value40: CGFloat = 40
        static let value42: CGFloat = 42
        static let value46: CGFloat = 46
        static let value48: CGFloat = 48
        static let value56: CGFloat = 56
        static let value64: CGFloat = 64
        static let value80: CGFloat = 80
        static let value96: CGFloat = 96
    }

    enum Radius {
        static let value4: CGFloat = 4
        static let value5: CGFloat = 5
        static let value7: CGFloat = 7
        static let value8: CGFloat = 8
        static let value9: CGFloat = 9
        static let value10: CGFloat = 10
        static let value12: CGFloat = 12
        static let value16: CGFloat = 16
        static let value17: CGFloat = 17
        static let value18: CGFloat = 18
        static let value20: CGFloat = 20
        static let value22: CGFloat = 22
        static let value24: CGFloat = 24
        static let value28: CGFloat = 28
        static let value30: CGFloat = 30
        static let value32: CGFloat = 32
        static let value36: CGFloat = 36
        static let surfaceControl: CGFloat = 7
        static let surfaceAction: CGFloat = 12
        static let surfacePanel: CGFloat = 20
        static let surfaceDesktop: CGFloat = 24
        static let surfacePill: CGFloat = 32
    }

    enum BorderWidth {
        static let hairline: CGFloat = 1
        static let focus: CGFloat = 2
    }

    enum Opacity {
        static let disabled: Double = 0.45
        static let haloIdle: Double = 0.14
        static let haloFocused: Double = 0.3
        static let haloTyping: Double = 0.4
        static let haloAnalyzing: Double = 0.48
        static let haloReducedAnalyzing: Double = 0.3
    }

    enum FontSize {
        static let value9: CGFloat = 9
        static let value10: CGFloat = 10
        static let value11: CGFloat = 11
        static let value12: CGFloat = 12
        static let value13: CGFloat = 13
        static let value14: CGFloat = 14
        static let value15: CGFloat = 15
        static let value16: CGFloat = 16
        static let value17: CGFloat = 17
        static let value18: CGFloat = 18
        static let value20: CGFloat = 20
        static let value21: CGFloat = 21
        static let value22: CGFloat = 22
        static let value24: CGFloat = 24
        static let value27: CGFloat = 27
        static let value30: CGFloat = 30
        static let value32: CGFloat = 32
        static let value34: CGFloat = 34
        static let value37: CGFloat = 37
        static let value38: CGFloat = 38
        static let value44: CGFloat = 44
        static let value46: CGFloat = 46
        static let value48: CGFloat = 48
        static let value62: CGFloat = 62
    }

    enum Duration {
        static let hover: Double = 0.15
        static let opacity: Double = 0.8
        static let driftIdle: Double = 12
        static let driftTyping: Double = 10
        static let driftAnalyzing: Double = 6
        static let spinner: Double = 0.8
        static let panel: Double = 0.48
        static let row: Double = 0.24
    }

    enum Delay {
        static let rowStart: Double = 0.09
        static let rowStagger: Double = 0.035
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
