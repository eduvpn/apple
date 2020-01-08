//
//  NotificationsService.swift
//  EduVPN
//
//  Created by Aleksandr Poddubny on 05/06/2019.
//  Copyright © 2019 SURFNet. All rights reserved.
//

import Foundation
import UserNotifications

struct NotificationsService {
    
    struct Notification {
        
        let title: String
        let body: String?
    }
    
    static func makeNotification(title: String, body: String?) -> Notification {
        return Notification(title: title, body: body)
    }
    
    #if os(iOS)
    
    static func sendNotification(_ notification: Notification,
                                 withIdentifier identifier: String,
                                 at triggerDate: DateComponents,
                                 repeats: Bool = false,
                                 callback: ((Error?) -> Void)? = nil) {
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: repeats)
        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = notification.title
        if let body = notification.body {
            notificationContent.body = body
        }
        let request = UNNotificationRequest(identifier: identifier, content: notificationContent, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: callback)
    }
    
    #elseif os(macOS)
    
    static func sendNotification(_ notification: Notification,
                                 withIdentifier identifier: String,
                                 at triggerDate: DateComponents,
                                 repeats: Bool = false,
                                 callback: ((Error?) -> Void)? = nil) {
        
        if #available(OSX 10.14, *) {
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: repeats)
            let notificationContent = UNMutableNotificationContent()
            notificationContent.title = notification.title
            if let body = notification.body {
                notificationContent.body = body
            }
            let request = UNNotificationRequest(identifier: identifier, content: notificationContent, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request, withCompletionHandler: callback)
        } else {
            let payload = NSUserNotification()
            payload.title = notification.title
            payload.informativeText = notification.body
            payload.deliveryDate = NSCalendar.current.date(from: triggerDate)

            NSUserNotificationCenter.default.scheduleNotification(payload)
            
            callback?(nil)
        }
    }
    
    #endif
    
    static func permissionGranted(callback: @escaping (Bool) -> Void) {
        #if os(iOS)
        
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            callback(settings.authorizationStatus == UNAuthorizationStatus.authorized)
        }
        
        #elseif os(macOS)
        
        if #available(OSX 10.14, *) {
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                callback(settings.authorizationStatus == UNAuthorizationStatus.authorized)
            }
        } else {
            callback(true)
        }
        
        #endif
    }
}
