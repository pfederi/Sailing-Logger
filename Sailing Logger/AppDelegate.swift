import UIKit
import UserNotifications

// Definition der Custom Notification
extension NSNotification.Name {
    static let openNewLogEntry = NSNotification.Name("openNewLogEntry")
}

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.notification.request.content.userInfo["action"] as? String == "newEntry" {
            NotificationCenter.default.post(name: NSNotification.Name.openNewLogEntry, object: nil)
        }
        
        // Reset badge count using the new API
        UNUserNotificationCenter.current().setBadgeCount(0) { error in
            if let error = error {
                print("AppDelegate: Error resetting badge count: \(error)")
            }
        }
        
        completionHandler()
    }
} 