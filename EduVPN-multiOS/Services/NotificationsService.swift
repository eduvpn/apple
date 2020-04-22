//
//  NotificationsService.swift
//  EduVPN
//
//  Created by Aleksandr Poddubny on 05/06/2019.
//  Copyright © 2020 SURFNet. All rights reserved.
//

import Foundation
import UserNotifications
import os.log

class NotificationsService {
    
    struct Notification {
        
        let title: String
        let body: String?
    }
    
    func makeNotification(title: String, body: String?) -> Notification {
        return Notification(title: title, body: body)
    }
    
    #if os(iOS)
    
    func sendNotification(_ notification: Notification,
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
    
    func sendNotification(_ notification: Notification,
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
    
    func permissionGranted(callback: @escaping (Bool) -> Void) {
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

    func scheduleCertificateExpirationNotification(for certificate: CertificateModel, on api: Api) {
        guard let expirationDate = certificate.x509Certificate?.notAfter else { return }
        guard let identifier = certificate.uniqueIdentifier else { return }

        let notificationTitle = NSLocalizedString("VPN certificate is expiring", comment: "")

        var notificationBody: String?
        if let certificateTitle = api.instance?.displayNames?.localizedValue {
            notificationBody = String.localizedStringWithFormat("Once expired the certificate for instance %@ needs to be refreshed.", certificateTitle)
        }

        let notification = makeNotification(title: notificationTitle, body: notificationBody)

#if DEBUG
        guard let expirationWarningDate = NSCalendar.current.date(byAdding: .second, value: 10, to: Date()) else { return }
#else
        guard let expirationWarningDate = NSCalendar.current.date(byAdding: .minute, value: -15, to: expirationDate), expirationDate.timeIntervalSince(Date()) < 0 else { return }
#endif
        let expirationWarningDateComponents = NSCalendar.current.dateComponents(in: NSTimeZone.default, from: expirationWarningDate)

        os_log("Scheduling a cert expiration reminder for %{public}@ on %{public}@.", log: Log.general, type: .info, certificate.uniqueIdentifier ?? "", expirationDate.description)
        sendNotification(notification, withIdentifier: identifier, at: expirationWarningDateComponents) { error in
            if let error = error {
                os_log("Error occured when scheduling a cert expiration reminder %{public}@",
                       log: Log.general,
                       type: .info, error.localizedDescription)
            }
        }
    }
}
