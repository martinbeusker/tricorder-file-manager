import SwiftUI

// MARK: - LCARS palette (lifted from the Design source)
enum LC {
    static let amber        = Color(hex: 0xE8A159)
    static let salmon       = Color(hex: 0xE27F6C)
    static let cream        = Color(hex: 0xEFD3A0)
    static let orange       = Color(hex: 0xD96C2A)
    static let plum         = Color(hex: 0xA390C9)
    static let red          = Color(hex: 0xD8443C)
    static let txt          = Color(hex: 0xF5E3C8)   // primary readable text on black
    static let dim          = Color(hex: 0xB7A585)   // secondary text
    static let brownFill    = Color(hex: 0x4A3A26)   // dark decorative fill
    static let brownButton  = Color(hex: 0x8A6B45)   // inactive header buttons / scrollbar
    static let crumbHover   = Color(hex: 0x241A0E)
    static let panelDim     = Color(hex: 0x5A4630)
    static let black        = Color.black

    // decorative reference codes used around the frame
    static let railCodes = ["44-8017", "02-1163", "71-5520", "09-4482"]
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(.sRGB,
                  red:   Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8)  & 0xFF) / 255,
                  blue:  Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

// MARK: - Antonio type ramp
enum AntonioWeight {
    case regular, medium, semibold, bold
    var psName: String {
        switch self {
        case .regular:  return "Antonio-Regular"
        case .medium:   return "Antonio-Medium"
        case .semibold: return "Antonio-SemiBold"
        case .bold:     return "Antonio-Bold"
        }
    }
}

extension Font {
    /// Antonio at an explicit weight. Falls back to a condensed system face if the
    /// bundled font failed to register.
    static func antonio(_ size: CGFloat, _ weight: AntonioWeight = .regular) -> Font {
        .custom(weight.psName, size: size)
    }
}

extension Text {
    /// LCARS labels are set in Antonio with generous tracking.
    func lcars(_ size: CGFloat, _ weight: AntonioWeight = .regular,
               tracking: CGFloat = 0, color: Color = LC.txt) -> some View {
        self.font(.antonio(size, weight))
            .tracking(tracking)
            .foregroundColor(color)
    }
}

// MARK: - Font registration (bundled Antonio statics)
enum Fonts {
    static func register() {
        let names = ["Antonio-Regular", "Antonio-Medium", "Antonio-SemiBold", "Antonio-Bold"]
        for name in names {
            let url = Bundle.main.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts")
                   ?? Bundle.main.url(forResource: name, withExtension: "ttf")
            guard let url else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

// MARK: - Sizing constants mirrored from the design
enum Metric {
    static let outerGap: CGFloat        = 6
    static let elbowWidth: CGFloat      = 236
    static let topFrameHeight: CGFloat  = 92
    static let headerBarHeight: CGFloat = 52
    static let statusWidth: CGFloat     = 330
    static let railWidth: CGFloat       = 172
    static let bottomFrameHeight: CGFloat = 64
    static let bottomBarHeight: CGFloat = 36
    static let capWidth: CGFloat        = 46
}
