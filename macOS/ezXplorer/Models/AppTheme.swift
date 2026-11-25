import SwiftUI

/// Visual themes combining native macOS Explorer aesthetics with classic Norton Commander styling.
enum AppThemeMode: String, CaseIterable, Identifiable {
    case system = "macOS Native"
    case classicCommander = "Norton Classic Blue"
    case midnightCommander = "Midnight Dark"

    var id: String { rawValue }

    var palette: ThemePalette {
        switch self {
        case .system:
            return ThemePalette(
                isClassicTUI: false,
                paneBackground: Color(nsColor: .controlBackgroundColor),
                inactivePaneBackground: Color(nsColor: .windowBackgroundColor),
                headerBackground: Color(nsColor: .underPageBackgroundColor),
                activeHeaderAccent: Color.accentColor,
                rowText: Color.primary,
                directoryText: Color.primary,
                hiddenText: Color.secondary,
                cursorBackground: Color.accentColor.opacity(0.22),
                cursorText: Color.primary,
                selectedRowBackground: Color.orange.opacity(0.18),
                selectedRowText: Color.orange,
                compareUniqueBackground: Color.green.opacity(0.14),
                compareNewerBackground: Color.blue.opacity(0.14),
                functionBarBackground: Color(nsColor: .windowBackgroundColor),
                functionKeyBadge: Color.accentColor.opacity(0.18),
                functionKeyText: Color.primary,
                borderColor: Color(nsColor: .separatorColor),
                fontDesign: .default
            )

        case .classicCommander:
            return ThemePalette(
                isClassicTUI: true,
                paneBackground: Color(red: 0.00, green: 0.00, blue: 0.50),
                inactivePaneBackground: Color(red: 0.00, green: 0.00, blue: 0.38),
                headerBackground: Color(red: 0.00, green: 0.45, blue: 0.55),
                activeHeaderAccent: Color(red: 0.00, green: 0.72, blue: 0.78),
                rowText: Color(red: 0.55, green: 0.92, blue: 0.95),
                directoryText: Color.white,
                hiddenText: Color(red: 0.48, green: 0.65, blue: 0.78),
                cursorBackground: Color(red: 0.00, green: 0.65, blue: 0.68),
                cursorText: Color(red: 0.02, green: 0.02, blue: 0.12),
                selectedRowBackground: Color(red: 0.00, green: 0.00, blue: 0.62),
                selectedRowText: Color(red: 1.00, green: 0.96, blue: 0.32),
                compareUniqueBackground: Color(red: 0.00, green: 0.32, blue: 0.25),
                compareNewerBackground: Color(red: 0.16, green: 0.18, blue: 0.62),
                functionBarBackground: Color(red: 0.02, green: 0.04, blue: 0.14),
                functionKeyBadge: Color(red: 0.00, green: 0.65, blue: 0.68),
                functionKeyText: Color.black,
                borderColor: Color(red: 0.30, green: 0.75, blue: 0.85),
                fontDesign: .monospaced
            )

        case .midnightCommander:
            return ThemePalette(
                isClassicTUI: true,
                paneBackground: Color(red: 0.09, green: 0.11, blue: 0.15),
                inactivePaneBackground: Color(red: 0.07, green: 0.08, blue: 0.11),
                headerBackground: Color(red: 0.14, green: 0.17, blue: 0.23),
                activeHeaderAccent: Color(red: 0.26, green: 0.64, blue: 0.95),
                rowText: Color(red: 0.86, green: 0.90, blue: 0.95),
                directoryText: Color(red: 0.45, green: 0.80, blue: 1.00),
                hiddenText: Color(red: 0.50, green: 0.56, blue: 0.64),
                cursorBackground: Color(red: 0.18, green: 0.38, blue: 0.62),
                cursorText: Color.white,
                selectedRowBackground: Color(red: 0.28, green: 0.22, blue: 0.08),
                selectedRowText: Color(red: 1.00, green: 0.82, blue: 0.32),
                compareUniqueBackground: Color(red: 0.10, green: 0.26, blue: 0.18),
                compareNewerBackground: Color(red: 0.14, green: 0.22, blue: 0.36),
                functionBarBackground: Color(red: 0.06, green: 0.07, blue: 0.10),
                functionKeyBadge: Color(red: 0.22, green: 0.45, blue: 0.72),
                functionKeyText: Color.white,
                borderColor: Color(red: 0.22, green: 0.26, blue: 0.34),
                fontDesign: .monospaced
            )
        }
    }
}

struct ThemePalette {
    let isClassicTUI: Bool
    let paneBackground: Color
    let inactivePaneBackground: Color
    let headerBackground: Color
    let activeHeaderAccent: Color
    let rowText: Color
    let directoryText: Color
    let hiddenText: Color
    let cursorBackground: Color
    let cursorText: Color
    let selectedRowBackground: Color
    let selectedRowText: Color
    let compareUniqueBackground: Color
    let compareNewerBackground: Color
    let functionBarBackground: Color
    let functionKeyBadge: Color
    let functionKeyText: Color
    let borderColor: Color
    let fontDesign: Font.Design
}
