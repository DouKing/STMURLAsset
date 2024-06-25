//
//  AppDelegate.swift
//  iOS Example
//
//  Created by DouKing on 2020/11/18.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

	var window: UIWindow?

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        self.window = UIWindow(frame: UIScreen.main.bounds)
        self.window?.backgroundColor = .white
        self.window?.rootViewController = UINavigationController(rootViewController: PlayerTransitionViewController())
        self.window?.makeKeyAndVisible()
		return true
	}

}

