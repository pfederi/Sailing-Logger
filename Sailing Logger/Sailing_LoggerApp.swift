//
//  Sailing_LoggerApp.swift
//  Sailing Logger
//
//  Created by Patrick Federi on 22.11.2024.
//

import SwiftUI
import UIKit

@main
struct Sailing_LoggerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
            // Verhindert Uppercase-Darstellung
            UIButton.appearance(whenContainedInInstancesOf: [UIAlertController.self]).configuration?.buttonSize = .medium
        }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(MaritimeColors.navy)
        }
    }
}
