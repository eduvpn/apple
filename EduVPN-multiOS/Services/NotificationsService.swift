//
//  NotificationsService.swift
//  EduVPN
//

import Foundation
import UserNotifications
import os.log

import PromiseKit

// Handles local user notifications delivered from/to the app

class NotificationsService: NSObject {
    enum NotificationCategory: String {
        case certificateExpiry
    }

    enum CertificateExpiryNotificationAction: String {
        case refreshCertificate
        case ignore
    }

    // If user clicks on the 'Authorize' button or the notification itself,
    // this block shall be called.
    var onCertificateExpiryNotificationClicked: (() -> Void)?

    static var notificationCenter: UNUserNotificationCenter {
        UNUserNotificationCenter.current()
    }

    static var authorizationOptions: UNAuthorizationOptions = [.alert, .sound]

    override init() {
        super.init()
        Self.notificationCenter.delegate = self
        self.registerActionableNotifications()
    }

    func registerActionableNotifications() {
        let authorizeAction = UNNotificationAction(
            identifier: CertificateExpiryNotificationAction.refreshCertificate.rawValue,
            title: NSString.localizedUserNotificationString(forKey: "Renew Session", arguments: nil),
            options: [.authenticationRequired, .foreground])
        #if os(macOS)
        let ignoreAction = UNNotificationAction(
            identifier: CertificateExpiryNotificationAction.ignore.rawValue,
            title: NSString.localizedUserNotificationString(forKey: "Ignore", arguments: nil),
            options: [])
        let notificationActions = [authorizeAction, ignoreAction]
        #elseif os(iOS)
        let notificationActions = [authorizeAction]
        #endif
        let certificateExpiryCategory = UNNotificationCategory(
            identifier: NotificationCategory.certificateExpiry.rawValue,
            actions: notificationActions,
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "",
            options: [])
        Self.notificationCenter.setNotificationCategories([certificateExpiryCategory])
    }

    static func requestAuthorization() -> Guarantee<Bool> {
        return Guarantee<Bool> { callback in
            notificationCenter.requestAuthorization(options: authorizationOptions) { (granted, error) in
                if granted {
                    os_log("Notifications authorized", log: Log.general, type: .info)
                } else {
                    os_log("Notifications not authorized", log: Log.general, type: .info)
                }

                if let error = error {
                    os_log("Error occured when requesting notification authorization. %{public}@", log: Log.general, type: .error, error.localizedDescription)
                }
                callback(granted)
            }
        }
    }

    static func isNotificationAllowed() -> Guarantee<Bool> {
        return Guarantee<Bool> { callback in
            notificationCenter.getNotificationSettings { settings in
                callback((settings.authorizationStatus == .authorized) &&
                    (settings.alertSetting == .enabled))
            }
        }
    }

    static func scheduleCertificateExpiryNotification(for profile: Profile) -> Guarantee<Bool> {
        guard let expiryDate = profile.api?.certificateModel?.x509Certificate?.notAfter else {
            return Guarantee.value(false)
        }

        os_log("Certificate expires at %{public}@", log: Log.general, type: .debug, expiryDate as NSDate)

        return requestAuthorization()
            .then { isAuthorized -> Guarantee<Bool> in
                guard isAuthorized else { return Guarantee.value(false) }
                return isNotificationAllowed()
            }.then { canAddNotificationRequest -> Guarantee<Bool> in
                guard canAddNotificationRequest else { return Guarantee.value(false) }

                let minutesToExpiry = Calendar.current.dateComponents([.minute], from: Date(), to: expiryDate).minute ?? 0
                guard minutesToExpiry > 0 else { // Certificate has already expired
                    return Guarantee.value(false)
                }

                // Normally, fire the notification 30 mins before expiry. If we're already past
                // that time, fire it 2 seconds from now.
                let maxMinutesFromNotificationToExpiry = 30
                let minSecondsToNotification = 2
                let secondsToNotification = (minutesToExpiry > maxMinutesFromNotificationToExpiry) ?
                    ((minutesToExpiry - maxMinutesFromNotificationToExpiry) * 60) : minSecondsToNotification
                precondition(secondsToNotification > 0)

                let notificationId = getOrCreateProfileID(on: profile)
                return addCertificateExpiryNotificationRequest(
                    notificationId: notificationId.uuidString,
                    expiryDate: expiryDate,
                    secondsToNotification: secondsToNotification)
            }
    }

    static func descheduleCertificateExpiryNotification(for profile: Profile) {
        if let notificationId = profile.uuid {
            notificationCenter.removePendingNotificationRequests(
                withIdentifiers: [notificationId.uuidString])
        }
    }

    private static func addCertificateExpiryNotificationRequest(
        notificationId: String,
        expiryDate: Date,
        secondsToNotification: Int) -> Guarantee<Bool> {

        let content = UNMutableNotificationContent()
        content.title = NSString.localizedUserNotificationString(
            forKey: "Your VPN session is expiring",
            arguments: nil)

        // We're not using localizedUserNotificationString below becuse:
        //   - we need the timestamp to be as per the current locale and
        //     consistent with language of the body string
        //   - when arguments: is not nil, the notifications don't seem to fire.
        //     See: https://openradar.appspot.com/43007245
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        content.body = String(
            format: NSLocalizedString("Session expires at %@", comment: ""),
            formatter.string(from: expiryDate))

        content.sound = UNNotificationSound.default

        content.categoryIdentifier = NotificationCategory.certificateExpiry.rawValue

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(secondsToNotification), repeats: false)
        let request = UNNotificationRequest(identifier: notificationId, content: content, trigger: trigger)

        return Guarantee<Bool> { callback in
            notificationCenter.add(request) { error in
                if let error = error {
                    os_log("Error scheduling certificate expiry notification: %{public}@", log: Log.general, type: .error, error.localizedDescription)
                } else {
                    os_log("Certificate expiry notification scheduled to fire in %{public}d seconds", log: Log.general, type: .debug, secondsToNotification)
                }
                callback(error == nil)
            }
        }
    }
}

extension NotificationsService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let actionId = response.actionIdentifier
        let categoryId = response.notification.request.content.categoryIdentifier
        if categoryId == NotificationCategory.certificateExpiry.rawValue {
            // User clicked on 'Authorize' in the notification
            if actionId == CertificateExpiryNotificationAction.refreshCertificate.rawValue ||
                // User clicked on the notification itself
                actionId == UNNotificationDefaultActionIdentifier {
                onCertificateExpiryNotificationClicked?()
            }
        }
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .sound])
    }
}

/// If `profile` already has an uuid, return it
/// Else, set a uuid on `profile` and return it.
private func getOrCreateProfileID(on profile: Profile) -> UUID {
    if let existingUUID = profile.uuid {
        return existingUUID
    } else {
        let newUUID = UUID()
        profile.uuid = newUUID
        profile.managedObjectContext?.saveContext()
        return newUUID
    }
}
