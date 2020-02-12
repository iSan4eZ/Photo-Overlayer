//
//  DocumentBrowserViewController.swift
//  Photo Overlayer
//
//  Created by Stas Panasuk on 1/31/18.
//  Copyright © 2018 iSan4eZ. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
	var window: UIWindow?
    
    static var beta = false
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        SettingsHelper.setVersionAndBuildNumber()
        AppDelegate.beta = SettingsHelper.getBetaTriggerValue()
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        let paths : [String] = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)
        let logPath = "\(paths[0])/console.txt"
        freopen(logPath, "a+", stderr)
        return true;
    }
}
