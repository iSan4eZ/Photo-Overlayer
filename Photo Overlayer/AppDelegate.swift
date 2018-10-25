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
}
