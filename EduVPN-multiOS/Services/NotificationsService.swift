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
        let request = UNNotificationRequest(identifier: identifier, content: UNMutableNotificationContent().with {
            $0.title = notification.title
            if let body = notification.body {
                $0.body = body
            }
        }, trigger: trigger)
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
            let request = UNNotificationRequest(identifier: identifier, content: UNMutableNotificationContent().with {
                $0.title = notification.title
                if let body = notification.body {
                    $0.body = body
                }
            }, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request, withCompletionHandler: callback)
        } else {
            NSUserNotificationCenter.default.scheduleNotification(NSUserNotification().with {
                $0.title = notification.title
                $0.informativeText = notification.body
                $0.deliveryDate = NSCalendar.current.date(from: triggerDate)
                // TODO: support `repeats` for notification
            })
            
            callback?(nil)
        }
    }
    
    #endif
    
    static func permissionGranted(callback: @escaping (Bool) -> ()) {
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
