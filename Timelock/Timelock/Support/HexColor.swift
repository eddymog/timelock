import SwiftUI

enum HexColor {
    /// Parses `#RRGGBB` (the `#` is optional) into 0...1 components.
    static func rgb(_ hex: String) -> (red: Double, green: Double, blue: Double)? {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        return (Double(value >> 16 & 0xFF) / 255, Double(value >> 8 & 0xFF) / 255, Double(value & 0xFF) / 255)
    }

    static func hex(red: Double, green: Double, blue: Double) -> String {
        func byte(_ c: Double) -> Int { Int((min(max(c, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(red), byte(green), byte(blue))
    }
}

extension Color {
    init(hex: String) {
        let c = HexColor.rgb(hex) ?? (0.5, 0.5, 0.5)
        self.init(red: c.red, green: c.green, blue: c.blue)
    }
}
