//
//  AppDelegate.swift
//  eduVPN
//
//  Created by Jeroen Leenarts on 29-07-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import UIKit
import UserNotifications
import os.log

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var appCoordinator: AppCoordinator!

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        UINavigationBar.appearance().barTintColor = UIColor(named: "barTintColor")
        UINavigationBar.appearance().tintColor = UIColor(named: "tintColor")
        UINavigationBar.appearance().titleTextAttributes = [NSAttributedString.Key.foregroundColor: #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)]

        let freshWindow = UIWindow(frame: UIScreen.main.bounds)
        window = freshWindow
        appCoordinator = AppCoordinator(window: freshWindow)
        appCoordinator.start()

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { (granted, error) in
            if !granted {
                os_log("Notifications not granted", log: Log.general, type: .info)
            }

            if let error = error {
                self.appCoordinator.showError(error)
                os_log("Error occured when requesting notification authorization. %{public}@", log: Log.general, type: .error, error.localizedDescription)
            }
        }
        UNUserNotificationCenter.current().delegate = self

        return true
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return appCoordinator.resumeAuthorizationFlow(url: url)
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {

        guard let url = userActivity.webpageURL else { return false }
        return appCoordinator.resumeAuthorizationFlow(url: url)
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .sound])
    }
}
