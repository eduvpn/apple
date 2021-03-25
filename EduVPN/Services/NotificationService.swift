//
//  NotificationService.swift
//  EduVPN

// Handles local user notifications delivered from/to the app

import Foundation
import UserNotifications
import PromiseKit
import os.log

protocol NotificationServiceDelegate: class {
    func notificationServiceDidReceiveRenewSessionRequest(_ notificationService: NotificationService)
}

// swiftlint:disable:next type_body_length
class NotificationService: NSObject {
    enum NotificationCategory: String {
        case certificateExpiry
    }

    enum SessionExpiryNotificationAction: String {
        case renewSession
    }

    weak var delegate: NotificationServiceDelegate?

    private static var notificationCenter: UNUserNotificationCenter {
        UNUserNotificationCenter.current()
    }

    private static var authorizationOptions: UNAuthorizationOptions = [.alert, .sound]

    override init() {
        super.init()
        Self.notificationCenter.delegate = self

        self.setNotificiationCategories()
        if UserDefaults.standard.hasAskedUserOnNotifyBeforeSessionExpiry &&
               UserDefaults.standard.shouldNotifyBeforeSessionExpiry {
            // Make sure we have permissions to show notifications.
            // Ideally, this shouldn't trigger the OS prompt.
            firstly {
                Self.requestAuthorization()
            }.done { isAuthorized in
                if !isAuthorized {
                    UserDefaults.standard.shouldNotifyBeforeSessionExpiry = false
                }
            }
        }
    }

    func attemptSchedulingSessionExpiryNotification(
        expiryDate: Date, connectionAttemptId: UUID, from viewController: ViewController) -> Guarantee<Bool> {

        let userDefaults = UserDefaults.standard

        if !userDefaults.hasAskedUserOnNotifyBeforeSessionExpiry && !userDefaults.shouldNotifyBeforeSessionExpiry {
            // We haven't shown the prompt, and user hasn't enabled
            // notifications in Preferences.
            // Ask the user with a prompt first, then if the user approves,
            // attempt to schedule notifications.
            return Self.showPrePrompt(from: viewController)
                .then { isUserWantsToBeNotified in
                    UserDefaults.standard.hasAskedUserOnNotifyBeforeSessionExpiry = true
                    if isUserWantsToBeNotified {
                        return self.scheduleSessionExpiryNotification(
                            expiryDate: expiryDate, connectionAttemptId: connectionAttemptId)
                            .map { isAuthorized in
                                UserDefaults.standard.shouldNotifyBeforeSessionExpiry = isAuthorized
                                if !isAuthorized {
                                    Self.showNotificationsDisabledAlert(from: viewController)
                                }
                                return isAuthorized
                            }
                    } else {
                        return Guarantee<Bool>.value(false)
                    }
                }
        } else if userDefaults.shouldNotifyBeforeSessionExpiry {
            // User has chosen to be notified.
            // Attempt to schedule notification.
            return scheduleSessionExpiryNotification(
                expiryDate: expiryDate, connectionAttemptId: connectionAttemptId)
        } else {
            // User has chosen to be not notified.
            // Do nothing.
            return Guarantee<Bool>.value(false)
        }
    }

    func scheduleSessionExpiryNotification(expiryDate: Date, connectionAttemptId: UUID) -> Guarantee<Bool> {
        return Self.requestAuthorization()
            .then { isAuthorized in
                if isAuthorized {
                    return Self.scheduleSessionExpiryNotification(
                        expiryDate: expiryDate, connectionAttemptId: connectionAttemptId)
                } else {
                    UserDefaults.standard.shouldNotifyBeforeSessionExpiry = false
                    return Guarantee<Bool>.value(false)
                }
            }
    }

    func descheduleSessionExpiryNotification() {
        Self.notificationCenter.removeAllPendingNotificationRequests()
        os_log("Certificate expiry notifications descheduled", log: Log.general, type: .debug)
    }

    func enableSessionExpiryNotification(from viewController: ViewController) -> Guarantee<Bool> {
        firstly {
            Self.requestAuthorization()
        }.map { isAuthorized in
            if isAuthorized {
                UserDefaults.standard.shouldNotifyBeforeSessionExpiry = true
            } else {
                UserDefaults.standard.shouldNotifyBeforeSessionExpiry = false
                Self.showNotificationsDisabledAlert(from: viewController)
            }
            return isAuthorized
        }
    }

    func disableSessionExpiryNotification() {
        UserDefaults.standard.shouldNotifyBeforeSessionExpiry = false
    }

    private func setNotificiationCategories() {
        let authorizeAction = UNNotificationAction(
            identifier: SessionExpiryNotificationAction.renewSession.rawValue,
            title: NSString.localizedUserNotificationString(forKey: "Renew Session", arguments: nil),
            options: [.authenticationRequired, .foreground])
        let notificationActions = [authorizeAction]
        let certificateExpiryCategory = UNNotificationCategory(
            identifier: NotificationCategory.certificateExpiry.rawValue,
            actions: notificationActions,
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "",
            options: [])
        Self.notificationCenter.setNotificationCategories([certificateExpiryCategory])
    }

    private static func requestAuthorization() -> Guarantee<Bool> {
        os_log("Requesting authorization for notifications", log: Log.general, type: .info)
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

    // swiftlint:disable:next function_body_length
    private static func showPrePrompt(from viewController: ViewController) -> Guarantee<Bool> {

        #if os(macOS)

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = NSLocalizedString(
            "Would you like to be notified when the current session is about to expire?",
            comment: "")
        alert.informativeText = NSLocalizedString(
            "You can change this option later in Preferences",
            comment: "")
        alert.addButton(withTitle: NSLocalizedString("Notify", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Don’t Notify", comment: ""))
        if let window = viewController.view.window {
            return Guarantee<Bool> { callback in
                alert.beginSheetModal(for: window) { result in
                    if case .alertFirstButtonReturn = result {
                        NSLog("Callback true")
                        callback(true)
                    } else {
                        NSLog("Callback false")
                        callback(false)
                    }
                }
            }
        } else {
            return Guarantee<Bool>.value(false)
        }

        #elseif os(iOS)

        let alert = UIAlertController(
            title: NSLocalizedString(
                "Would you like to be notified when the current session is about to expire?",
                comment: ""),
            message: NSLocalizedString(
                "You can change this option later in Settings",
                comment: ""),
            preferredStyle: .alert)
        return Guarantee<Bool> { callback in
            let refreshAction = UIAlertAction(title: NSLocalizedString("Notify", comment: ""),
                                              style: .default,
                                              handler: { _ in callback(true) })
            let cancelAction = UIAlertAction(title: NSLocalizedString("Don’t Notify", comment: ""),
                                             style: .cancel,
                                             handler: { _ in callback(false) })
            alert.addAction(refreshAction)
            alert.addAction(cancelAction)
            viewController.present(alert, animated: true, completion: nil)
        }

        #endif
    }

    private static func showNotificationsDisabledAlert(from viewController: ViewController) {

        let appName = Config.shared.appName

        #if os(macOS)

        let alert = NSAlert()
        alert.messageText = String(
            format: NSLocalizedString(
                "Notifications are disabled for %@", comment: ""),
            appName)
        alert.informativeText = String(
            format: NSLocalizedString(
                "Please enable notifications for ‘%@’ in System Preferences > Notifications > %@",
                comment: ""),
            appName, appName)
        NSApp.activate(ignoringOtherApps: true)
        if let window = viewController.view.window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }

        #elseif os(iOS)

        let title = String(
            format: NSLocalizedString(
                "Notifications are disabled for %@", comment: ""),
            appName)
        let message = String(
            format: NSLocalizedString(
                "Please enable notifications for ‘%@’ in Settings > %@ > Notifications",
                comment: ""),
            appName, appName)
        let okAction = UIAlertAction(title: "OK", style: .default)
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(okAction)
        viewController.present(alert, animated: true, completion: nil)

        #endif
    }

    private static func scheduleSessionExpiryNotification(
        expiryDate: Date, connectionAttemptId: UUID) -> Guarantee<Bool> {

        os_log("Certificate expires at %{public}@", log: Log.general, type: .debug, expiryDate as NSDate)

        let minutesToExpiry = Calendar.current.dateComponents([.minute], from: Date(), to: expiryDate).minute ?? 0

        // Normally, fire the notification 30 mins before expiry. If we're already past
        // that time, fire it 5 seconds from now.
        let maxMinutesFromNotificationToExpiry = 30
        let minSecondsToNotification = 5
        let secondsToNotification = (minutesToExpiry > maxMinutesFromNotificationToExpiry) ?
            ((minutesToExpiry - maxMinutesFromNotificationToExpiry) * 60) : minSecondsToNotification
        precondition(secondsToNotification > 0)

        return addSessionExpiryNotificationRequest(
            notificationId: connectionAttemptId.uuidString,
            expiryDate: expiryDate,
            secondsToNotification: secondsToNotification)
    }

    private static func addSessionExpiryNotificationRequest(
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
                    os_log("Error scheduling session expiry notification: %{public}@", log: Log.general, type: .error, error.localizedDescription)
                } else {
                    os_log("Session expiry notification scheduled to fire in %{public}d seconds", log: Log.general, type: .debug, secondsToNotification)
                }
                callback(error == nil)
            }
        }
    }
}

extension NotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let actionId = response.actionIdentifier
        let categoryId = response.notification.request.content.categoryIdentifier
        if categoryId == NotificationCategory.certificateExpiry.rawValue {
            // User clicked on 'Renew Session' in the notification
            if actionId == SessionExpiryNotificationAction.renewSession.rawValue ||
                // User clicked on the notification itself
                actionId == UNNotificationDefaultActionIdentifier {
                self.delegate?.notificationServiceDidReceiveRenewSessionRequest(self)
            }
        }
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .sound])
    }
}
