import SwiftUI
import UIKit

struct MaritimeColors {
    // Light Theme (Standard) Farben
    static let navy = Color(red: 0/255, green: 51/255, blue: 84/255)         // #003354
    static let oceanBlue = Color(red: 144/255, green: 189/255, blue: 212/255) // #90BDD4
    static let seafoam = Color(red: 216/255, green: 232/255, blue: 244/255)   // #D8E8F4
    static let sand = Color.white
    static let coral = Color(red: 242/255, green: 96/255, blue: 1/255)        // #F26001

    // Dark Theme Farben
    static let navyDark = Color(red: 179/255, green: 205/255, blue: 224/255)  // #B3CDE0
    static let oceanBlueDark = Color(red: 55/255, green: 94/255, blue: 151/255) // #375E97
    static let seafoamDark = Color(red: 32/255, green: 33/255, blue: 36/255)    // #202124
    static let sandDark = Color(red: 28/255, green: 28/255, blue: 30/255)       // #1C1C1E
    static let coralDark = Color(red: 255/255, green: 145/255, blue: 77/255)    // #FF914D

    // UIColor Versionen
    static let navyUI = UIColor(red: 0/255, green: 51/255, blue: 84/255, alpha: 1.0)
    static let oceanBlueUI = UIColor(red: 144/255, green: 189/255, blue: 212/255, alpha: 1.0)
    static let seafoamUI = UIColor(red: 216/255, green: 232/255, blue: 244/255, alpha: 1.0)
    static let sandUI = UIColor.white
    static let coralUI = UIColor(red: 242/255, green: 96/255, blue: 1/255, alpha: 1.0)
    
    static func primary(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? navyDark : navy
    }
    
    static func background(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .black : .white
    }
    
    static func secondary(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .gray : .gray
    }
    
    static func accent(for colorScheme: ColorScheme) -> Color {
        return navy
    }
    
    static func cardBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(.systemGray6) : .white
    }
    
    static func sectionBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray6)
    }
    
    static func navy(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? navyDark : navy
    }
    
    static func oceanBlue(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? oceanBlueDark : oceanBlue
    }
    
    static func seafoam(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? seafoamDark : seafoam
    }
    
    static func sand(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? sandDark : sand
    }
    
    static func coral(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? coralDark : coral
    }
} 