//
//  SettingsHelper.swift
//  Photo Overlayer
//
//  Created by Stas on 8/6/18.
//  Copyright © 2018 iSan4eZ. All rights reserved.
//

import UIKit

class SettingsHelper {
    struct SettingsBundleKeys {
        static let BetaTrigger = "beta_preference"
        static let BuildVersionKey = "build_preference"
        static let AppVersionKey = "version_preference"
        static let GyroFrequency = "gyro_preference"
    }
    
    static func setVersionAndBuildNumber() {
        let version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        UserDefaults.standard.set(version, forKey: SettingsBundleKeys.AppVersionKey)
        let build: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
        UserDefaults.standard.set(build, forKey: SettingsBundleKeys.BuildVersionKey)
    }
    
    static func getGyroFrequency() -> Double {
        return UserDefaults.standard.double(forKey: SettingsBundleKeys.GyroFrequency)
    }
    
    static func getBetaTriggerValue() -> Bool {
        return UserDefaults.standard.bool(forKey: SettingsBundleKeys.BetaTrigger)
    }

}
