import SwiftUI

struct MaritimeColors {
    static let navy = Color.blue
    static let oceanBlue = Color.blue
    static let seafoam = Color.blue
    static let sand = Color.white
    static let coral = Color.red
    
    static func primary(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .white : .primary
    }
    
    static func background(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .black : .white
    }
    
    static func secondary(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .gray : .gray
    }
    
    static func accent(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .blue : .blue
    }
    
    static func cardBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(.systemGray6) : .white
    }
    
    static func sectionBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray6)
    }
} 