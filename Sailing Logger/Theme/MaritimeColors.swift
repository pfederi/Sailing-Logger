import SwiftUI

struct MaritimeColors {
    static let navy = Color(red: 0/255, green: 51/255, blue: 84/255) // Orange-and-Blue-Corporate-1
    static let oceanBlue = Color(red: 144/255, green: 189/255, blue: 212/255) // Orange-and-Blue-Corporate-2
    static let seafoam = Color(red: 216/255, green: 232/255, blue: 244/255) // Orange-and-Blue-Corporate-3
    static let sand = Color.white // Orange-and-Blue-Corporate-4
    static let coral = Color(red: 242/255, green: 96/255, blue: 1/255) // Orange-and-Blue-Corporate-5
    
    static func primary(for colorScheme: ColorScheme) -> Color {
        return navy // Setze die primäre Farbe auf Navy (#003354)
    }
    
    static func background(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .black : .white
    }
    
    static func secondary(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .gray : .gray
    }
    
    static func accent(for colorScheme: ColorScheme) -> Color {
        return navy // Änderung von .blue zu navy
    }
    
    static func cardBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(.systemGray6) : .white
    }
    
    static func sectionBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray6)
    }
} 