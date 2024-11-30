import Foundation
import UserNotifications
import UIKit

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    private var lastReminderDate: Date?
    private let reminderInterval: TimeInterval = 3600 // 1 Stunde
    private let repeatInterval: TimeInterval = 300 // 5 Minuten
    
    init() {
        checkNotificationSettings()
    }
    
    private func checkNotificationSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("Notification Settings:")
            print("Authorization Status: \(settings.authorizationStatus.rawValue)")
            print("Alert Setting: \(settings.alertSetting.rawValue)")
            print("Sound Setting: \(settings.soundSetting.rawValue)")
            print("Badge Setting: \(settings.badgeSetting.rawValue)")
            print("Notification Center Setting: \(settings.notificationCenterSetting.rawValue)")
            
            if settings.authorizationStatus == .authorized {
                print("Notifications are authorized")
            } else {
                print("Notifications are not authorized")
                self.requestAuthorization()
            }
        }
    }
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { success, error in
            if success {
                print("NotificationManager: Authorization granted")
                DispatchQueue.main.async {
                    self.scheduleRepeatReminder()
                    UNUserNotificationCenter.current().setBadgeCount(0) { error in
                        if let error = error {
                            print("NotificationManager: Error resetting badge count: \(error)")
                        }
                    }
                }
            } else if let error = error {
                print("NotificationManager: Error requesting authorization: \(error)")
            }
        }
        
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("Current Notification Settings:")
            print("Authorization Status: \(settings.authorizationStatus.rawValue)")
            print("Alert Setting: \(settings.alertSetting.rawValue)")
            print("Sound Setting: \(settings.soundSetting.rawValue)")
            print("Badge Setting: \(settings.badgeSetting.rawValue)")
            print("Notification Center Setting: \(settings.notificationCenterSetting.rawValue)")
        }
    }
    
    func scheduleLogReminder(after lastLogDate: Date) {
        print("Scheduling reminder for: \(lastLogDate)")
        cancelPendingNotifications()
        
        let nextReminderDate = lastLogDate.addingTimeInterval(reminderInterval)
        print("Next reminder scheduled for: \(nextReminderDate)")
        
        if nextReminderDate > Date() {
            scheduleNotification(for: nextReminderDate)
            lastReminderDate = nextReminderDate
        }
    }
    
    private func scheduleNotification(for date: Date) {
        print("NotificationManager: Creating notification content")
        let content = UNMutableNotificationContent()
        content.title = "⚓️ Time to Log"
        content.body = "Create a new log entry now to maintain your hourly log."
        content.sound = UNNotificationSound(named: UNNotificationSoundName("ship-bell.wav"))
        content.userInfo = ["action": "newEntry"]
        
        // Erste Notification nach einer Stunde
        let firstTrigger = UNTimeIntervalNotificationTrigger(
            timeInterval: reminderInterval,
            repeats: false
        )
        
        let firstRequest = UNNotificationRequest(
            identifier: "firstReminder",
            content: content,
            trigger: firstTrigger
        )
        
        print("NotificationManager: Removing old notifications")
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        print("NotificationManager: Adding first notification")
        UNUserNotificationCenter.current().add(firstRequest) { error in
            if let error = error {
                print("NotificationManager: Error scheduling first notification: \(error)")
            } else {
                print("NotificationManager: First notification scheduled for: \(date)")
                
                // Plane die Repeat-Notification nur, wenn die erste Notification erfolgreich geplant wurde
                DispatchQueue.main.asyncAfter(deadline: .now() + self.reminderInterval) {
                    // Prüfe, ob seit der letzten Erinnerung ein neuer Log erstellt wurde
                    if let lastReminder = self.lastReminderDate,
                       Date() >= lastReminder,
                       !self.hasNewLogSinceLastReminder(lastReminder) {
                        // Wenn kein neuer Log erstellt wurde, plane die Repeat-Notification
                        let repeatContent = UNMutableNotificationContent()
                        repeatContent.title = "⚓️ Reminder: Log Entry Needed"
                        repeatContent.body = "You haven't created a log entry yet. Please log now."
                        repeatContent.sound = UNNotificationSound(named: UNNotificationSoundName("ship-bell.wav"))
                        repeatContent.userInfo = ["action": "newEntry"]
                        
                        let repeatTrigger = UNTimeIntervalNotificationTrigger(
                            timeInterval: self.repeatInterval,
                            repeats: false
                        )
                        
                        let repeatRequest = UNNotificationRequest(
                            identifier: "repeatReminder",
                            content: repeatContent,
                            trigger: repeatTrigger
                        )
                        
                        UNUserNotificationCenter.current().add(repeatRequest) { error in
                            if let error = error {
                                print("NotificationManager: Error scheduling repeat notification: \(error)")
                            } else {
                                print("NotificationManager: Repeat notification scheduled")
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Neue Methode zur Prüfung, ob ein neuer Log erstellt wurde
    private func hasNewLogSinceLastReminder(_ lastReminder: Date) -> Bool {
        // Diese Methode muss mit dem LogStore verbunden werden
        // Hier die Logik einfügen, die prüft, ob seit lastReminder ein neuer Log erstellt wurde
        // Zum Beispiel:
        // return logStore.entries.contains { $0.timestamp > lastReminder }
        return false // Placeholder
    }
    
    func scheduleRepeatReminder() {
        print("NotificationManager: Scheduling next notification")
        let now = Date()
        
        print("NotificationManager: Scheduling new notification")
        lastReminderDate = now
        scheduleNotification(for: now.addingTimeInterval(reminderInterval))
    }
    
    func cancelPendingNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
} 
