//
//  NotificationService.swift
//  EduVPN

// Handles local user notifications delivered from/to the app

import Foundation
import UserNotifications
import PromiseKit
import os.log

protocol NotificationServiceDelegate: AnyObject {
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

    private static let sessionAboutToExpireNotificationId = "SessionAboutToExpireNotification"
    private static let sessionHasExpiredNotificationId = "SessionHasExpiredNotification"

    private static let authorizationOptions: UNAuthorizationOptions = [.alert, .sound]

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
        expiryDate: Date, authenticationDate: Date?, connectionAttemptId: UUID, from viewController: ViewController) -> Guarantee<Bool> {

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
                            expiryDate: expiryDate, authenticationDate: authenticationDate,
                            connectionAttemptId: connectionAttemptId)
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
                expiryDate: expiryDate, authenticationDate: authenticationDate,
                connectionAttemptId: connectionAttemptId)
        } else {
            // User has chosen to be not notified.
            // Do nothing.
            return Guarantee<Bool>.value(false)
        }
    }

    func scheduleSessionExpiryNotification(
        expiryDate: Date, authenticationDate: Date?, connectionAttemptId: UUID) -> Guarantee<Bool> {
        return Self.requestAuthorization()
            .then { isAuthorized in
                if isAuthorized {
                    return Self.scheduleSessionExpiryNotification(
                        expiryDate: expiryDate, authenticationDate: authenticationDate,
                        connectionAttemptId: connectionAttemptId)
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

    private static func showPrePrompt(from viewController: ViewController) -> Guarantee<Bool> {

        #if os(macOS)

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = NSLocalizedString(
            "Would you like to be notified when the current session is about to expire?",
            comment: "alert title")
        alert.informativeText = NSLocalizedString(
            "You can change this option later in Preferences",
            comment: "alert detail")
        alert.addButton(withTitle: NSLocalizedString(
                         "Notify", comment: "alert button title"))
        alert.addButton(withTitle: NSLocalizedString(
                         "Don’t Notify", comment: "alert button title"))
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
                comment: "alert title"),
            message: NSLocalizedString(
                "You can change this option later in Settings",
                comment: "alert detail"),
            preferredStyle: .alert)
        return Guarantee<Bool> { callback in
            let refreshAction = UIAlertAction(
                title: NSLocalizedString("Notify", comment: "alert button title"),
                style: .default,
                handler: { _ in callback(true) })
            let cancelAction = UIAlertAction(
                title: NSLocalizedString("Don’t Notify", comment: "alert button title"),
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
                "Notifications are disabled for %@",
                comment: "alert title"),
            appName)
        alert.informativeText = String(
            format: NSLocalizedString(
                "Please enable notifications for ‘%@’ in System Preferences > Notifications > %@",
                comment: "alert detail"),
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
                "Notifications are disabled for %@",
                comment: "alert title"),
            appName)
        let message = String(
            format: NSLocalizedString(
                "Please enable notifications for ‘%@’ in Settings > %@ > Notifications",
                comment: "alert detail"),
            appName, appName)
        let okAction = UIAlertAction(title: "OK", style: .default)
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(okAction)
        viewController.present(alert, animated: true, completion: nil)

        #endif
    }

    private static func scheduleSessionExpiryNotification(
        expiryDate: Date, authenticationDate: Date?, connectionAttemptId: UUID) -> Guarantee<Bool> {

        os_log("Certificate expires at %{public}@", log: Log.general, type: .debug, expiryDate as NSDate)

        let minutesToExpiry = Calendar.current.dateComponents([.minute], from: Date(), to: expiryDate).minute ?? 0
        let secondsToExpiry = Calendar.current.dateComponents([.second], from: Date(), to: expiryDate).second ?? 0

        let minutesTillAboutToExpireNotification: Int = {
            if let authenticationDate = authenticationDate,
               let minutesFromAuthTime = Calendar.current.dateComponents([.minute], from: authenticationDate, to: Date()).minute {
                // 30 mins before expiry, but should be at least 32 mins since auth time
                os_log("Last authenticated %{public}d minutes back", log: Log.general, type: .debug, minutesFromAuthTime)
                return max((minutesToExpiry - 30), (32 - minutesFromAuthTime))
            } else {
                return (minutesToExpiry - 30)
            }
        }()

        let secondsTillAboutToExpireNotification: Int = {
            if minutesTillAboutToExpireNotification >= minutesToExpiry {
                os_log("Scheduling 'Session about to expire' notification to fire 5 seconds after expiry")
                return secondsToExpiry + 5 // 5 seconds after expiry
            } else if minutesTillAboutToExpireNotification < 0 {
                os_log("Scheduling 'Session about to expire' notification to fire 5 seconds from now")
                return 5 // 5 seconds from now
            } else {
                return minutesTillAboutToExpireNotification * 60
            }
        }()

        let secondsTillHasExpiredNotification = max(secondsToExpiry, 5)

        precondition(secondsTillAboutToExpireNotification > 0)
        precondition(secondsTillHasExpiredNotification > 0)

        if secondsTillHasExpiredNotification - secondsTillAboutToExpireNotification > 6 {
            // Schedule both about-to-expire and has-expired notifications
            return firstly {
                self.addSessionAboutToExpireNotificationRequest(
                    expiryDate: expiryDate,
                    secondsToNotification: secondsTillAboutToExpireNotification)
            }.then { isAddedAboutToExpireNotification in
                return self.addSessionHasExpiredNotificationRequest(
                    expiryDate: expiryDate,
                    secondsToNotification: secondsTillHasExpiredNotification)
                    .map { isAddedHasExpiredNotification in
                        return (isAddedAboutToExpireNotification && isAddedHasExpiredNotification)
                    }
            }
        } else {
            // Schedule only has-expired notification
            return self.addSessionHasExpiredNotificationRequest(
                expiryDate: expiryDate,
                secondsToNotification: secondsTillHasExpiredNotification)
        }
    }

    private static func addSessionAboutToExpireNotificationRequest(
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
            format: NSLocalizedString(
                "Session expires at %@",
                comment: "macOS user notification detail"),
            formatter.string(from: expiryDate))

        content.sound = UNNotificationSound.default

        content.categoryIdentifier = NotificationCategory.certificateExpiry.rawValue

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(secondsToNotification), repeats: false)
        let request = UNNotificationRequest(identifier: sessionAboutToExpireNotificationId, content: content, trigger: trigger)

        return Guarantee<Bool> { callback in
            notificationCenter.add(request) { error in
                if let error = error {
                    os_log("Error scheduling 'Session about to expire' notification: %{public}@", log: Log.general, type: .error, error.localizedDescription)
                } else {
                    os_log("'Session about to expire' notification scheduled to fire in %{public}d seconds", log: Log.general, type: .debug, secondsToNotification)
                }
                callback(error == nil)
            }
        }
    }

    private static func addSessionHasExpiredNotificationRequest(
        expiryDate: Date,
        secondsToNotification: Int) -> Guarantee<Bool> {

        let content = UNMutableNotificationContent()
        content.title = NSString.localizedUserNotificationString(
            forKey: "Your VPN session has expired",
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
            format: NSLocalizedString(
                "Session expired at %@",
                comment: "macOS user notification detail"),
            formatter.string(from: expiryDate))

        content.sound = UNNotificationSound.default

        content.categoryIdentifier = NotificationCategory.certificateExpiry.rawValue

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(secondsToNotification), repeats: false)
        let request = UNNotificationRequest(identifier: sessionHasExpiredNotificationId, content: content, trigger: trigger)

        return Guarantee<Bool> { callback in
            notificationCenter.add(request) { error in
                if let error = error {
                    os_log("Error scheduling 'Session has expired' notification: %{public}@", log: Log.general, type: .error, error.localizedDescription)
                } else {
                    os_log("'Session has expired' notification scheduled to fire in %{public}d seconds", log: Log.general, type: .debug, secondsToNotification)
                }
                callback(error == nil)
            }
        }
    }
}

extension NotificationService {
    #if os(macOS)
    func showSessionExpiryAlertOnDeviceWakeUp(connectionVC: ConnectionViewController) {
        Self.notificationCenter.getPendingNotificationRequests { requests in

            guard let expiryDate = connectionVC.sessionExpiresAt else {
                // Maybe there's no active eduVPN server VPN connection.
                // Nothing to do.
                return
            }

            if !UserDefaults.standard.shouldNotifyBeforeSessionExpiry {
                // Notifications are turned off.
                // Nothing to do.
                return
            }

            if requests.contains(where: { $0.identifier == Self.sessionAboutToExpireNotificationId }) {
                // Notification is yet to appear.
                // No need to show any alert on device wakeup.
                return
            }

            if expiryDate.timeIntervalSinceNow > 30 * 60 {
                // There's more than 30 minutes to expiry.
                // This is unexpected, so we don't show an alert.
                return
            }

            let alertAfterSeconds = 5
            let alertTime = Date().addingTimeInterval(TimeInterval(alertAfterSeconds))

            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(alertAfterSeconds)) {
                let formatter = DateFormatter()
                formatter.dateStyle = .none
                formatter.timeStyle = .short

                let alert = NSAlert()
                if alertTime > expiryDate {
                    alert.messageText = NSLocalizedString("Your VPN session has expired", comment: "macOS alert title")
                    alert.informativeText = String(
                        format: NSLocalizedString(
                            "Session expired at %@",
                            comment: "macOS alert detail"),
                        formatter.string(from: expiryDate))
                } else {
                    alert.messageText = NSLocalizedString("Your VPN session is expiring", comment: "macOS alert title")
                    alert.informativeText = String(
                        format: NSLocalizedString(
                            "Session expires at %@",
                            comment: "macOS alert detail"),
                        formatter.string(from: expiryDate))
                }

                alert.addButton(withTitle: NSLocalizedString("Renew Session", comment: "alert button title"))
                alert.addButton(withTitle: NSLocalizedString("Ignore", comment: "button title"))

                NSApp.activate(ignoringOtherApps: true)
                if let window = connectionVC.view.window {
                    alert.beginSheetModal(for: window) { result in
                        if case .alertFirstButtonReturn = result {
                            connectionVC.renewSession()
                        }
                    }
                }
            }
        }
    }
    #endif
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
