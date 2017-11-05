//
//  AppDelegate.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 29-07-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import UIKit

import Fabric
import Crashlytics

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var appCoordinator: AppCoordinator!

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        Fabric.with([Crashlytics.self])

        UINavigationBar.appearance().barTintColor = #colorLiteral(red: 0, green: 0.7509453893, blue: 0.8513121009, alpha: 1)
        UINavigationBar.appearance().tintColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
        UINavigationBar.appearance().titleTextAttributes = [NSAttributedStringKey.foregroundColor: #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)]

        self.window = UIWindow(frame: UIScreen.main.bounds)
        self.appCoordinator = AppCoordinator(window: self.window!)
        self.appCoordinator.start()

        return true
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey: Any] = [:]) -> Bool {
        return appCoordinator.resumeAuthorizationFlow(url: url) == true
    }

}
