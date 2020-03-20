//
//  AppDelegate.swift
//  eduVPN
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
