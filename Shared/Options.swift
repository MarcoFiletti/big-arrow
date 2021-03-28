//
//  Constants + Sound Extensions.swift
//  Big Arrow
//
//  Created by Marco Filetti on 28/11/2017.
//  Copyright © 2017 Marco Filetti. All rights reserved.
//

import Foundation
import UIKit
import UserNotifications
#if !WatchApp
import AVFoundation
#elseif WatchApp
import WatchKit
#endif

protocol Option: CaseIterable {
    /// The title of the given option
    static var title: String { get }
    /// Saves the value of the given option
    func save()
    /// Value of option seen by the user
    var friendlyName: String { get }
    /// Something that happens when the option is selected
    func preview()
    /// Returns a subtitle, if needed
    var subtitle: String? { get }
}

class Options {
    
    // MARK: - Phone only
    
    #if !WatchApp
    enum NotificationSound: String, Option {
        
        static var title: String { get { return "notification_sound".localized } }
        
        case none
        case `default`
        case single = "Single Ding.aiff"
        case triple = "Triple Ding Medium.aiff"
        
        var unNotificationSound: UNNotificationSound? { get {
            switch self {
            case .none:
                return nil
            case .default:
                return UNNotificationSound.default
            default:
                return UNNotificationSound(named: UNNotificationSoundName(rawValue: self.rawValue))
            }
        }}
        
        static var saved: NotificationSound { get {
                let str = UserDefaults.standard.object(forKey: Constants.Defs.notificationSound) as! String
            if let snd = NotificationSound(rawValue: str) {
                return snd
            } else {
                return .default
            }
        } }
        
        func save() {
            UserDefaults.standard.set(self.rawValue, forKey: Constants.Defs.notificationSound)
        }
        
        var friendlyName: String { get {
            switch self {
            case .default:
                return "default".localized
            case .none:
                return "no_sound".localized
            case .single:
                return "single_ding".localized
            case .triple:
                return "triple_ding".localized
            }
        }}
        
        func preview() {
            let filePath = Bundle.main.path(forResource: self.rawValue, ofType: "")
            if let path = filePath {
                var soundId: SystemSoundID = 0
                let soundURL = NSURL(fileURLWithPath: path)
                AudioServicesCreateSystemSoundID(soundURL, &soundId)
                AudioServicesPlaySystemSound(soundId)
            }
        }
        
        var subtitle: String? { get { return nil } }
    }
    
    enum CompassType: String, Option {
        
        static var title: String { get { return "compass_type".localized } }
        
        case absolute
        case relative
        
        func save() {
            let previousValue = UserDefaults.standard.object(forKey: Constants.Defs.compassIsRelative) as! Bool
            let newValue: Bool
            if self == .absolute {
                newValue = false
            } else {
                newValue = true
            }
            if previousValue != newValue {
                UserDefaults.standard.set(newValue, forKey: Constants.Defs.compassIsRelative)
                DispatchQueue.main.async {
                    (UIApplication.shared.delegate as! AppDelegate).sendCompassIsRelativePref(newValue: newValue)
                }
            }
        }
        
        var friendlyName: String { get {
            switch self {
            case .absolute:
                return "absolute".localized
            case .relative:
                return "relative".localized
            }
        } }
        
        func preview() {
            // do nothing
        }
        
        static var saved: CompassType { get {
            let isRelative = UserDefaults.standard.object(forKey: Constants.Defs.compassIsRelative) as! Bool
            if isRelative {
                return .relative
            } else {
                return .absolute
            }
        } }
        
        var subtitle: String? { get {
            switch self {
            case .absolute:
                return "absolute_compass_desc".localized
            case .relative:
                return "relative_compass_desc".localized
            }
        } }
    }
    #endif
    
    // MARK: - Shared
    
    enum Measurements: UInt8, Option {
        
        static var title: String { get { return "measurements".localized } }
        
        case automatic
        case metricWithComma
        case metricWithDot
        case imperial
        
        func save() {
            let previousValue = UserDefaults.standard.object(forKey: Constants.Defs.measurements) as! UInt8
            let newValue = self.rawValue
            if previousValue != newValue {
                UserDefaults.standard.set(newValue, forKey: Constants.Defs.measurements)
                Formatters.updateFormatters()
                
                // send to watch if we are on phone
                #if !WatchApp
                DispatchQueue.main.async {
                    (UIApplication.shared.delegate as! AppDelegate).sendMeasurementsPref(newValue: newValue)
                }
                #endif
            }
        }
        
        var friendlyName: String { get {
            switch self {
            case .automatic:
                return "automatic".localized
            case .metricWithComma:
                return "metric_with_comma".localized
            case .metricWithDot:
                return "metric_with_dot".localized
            case .imperial:
                return "imperial".localized
            }
        } }
        
        func preview() {
            // do nothing
        }
        
        static var saved: Measurements { get {
            if let val = UserDefaults.standard.object(forKey: Constants.Defs.measurements) as? UInt8 {
                return Measurements(rawValue: val)!
            } else {
                return Measurements.automatic
            }
        } }
        
        var subtitle: String? { get {
            switch self {
            case .automatic:
                return "measure_desc_auto".localized
            case .metricWithComma:
                return "measure_desc_metric_comma".localized
            case .metricWithDot:
                return "measure_desc_metric_dot".localized
            case .imperial:
                return "measure_desc_imperial".localized
            }
        } }
    }
    
    enum WaterLock: UInt8, Option {
        
        static var title: String { get { return "water_lock".localized } }
        
        case manual
        case once
        case automatic
        
        func save() {
            let previousValue = UserDefaults.standard.object(forKey: Constants.Defs.waterLockOption) as! UInt8
            let newValue = self.rawValue
            if previousValue != newValue {
                UserDefaults.standard.set(newValue, forKey: Constants.Defs.waterLockOption)
                // send to Watch if we are on iPhone
                #if !WatchApp
                DispatchQueue.main.async {
                    (UIApplication.shared.delegate as! AppDelegate).sendWaterLockPref(newValue)
                }
                #elseif WatchApp
                DispatchQueue.main.async {
                    (WKExtension.shared().delegate as! ExtensionDelegate).sendWaterLockPref(newValue)
                }
                #endif
            }
        }
        
        var friendlyName: String { get {
            switch self {
            case .manual:
                return "water_lock_manual".localized
            case .once:
                return "water_lock_once".localized
            case .automatic:
                return "water_lock_automatic".localized
            }
        } }
        
        func preview() {
            // do nothing
        }
        
        static var saved: WaterLock { get {
            if let val = UserDefaults.standard.object(forKey: Constants.Defs.waterLockOption) as? UInt8 {
                return WaterLock(rawValue: val)!
            } else {
                return WaterLock.manual
            }
        } }
        
        var subtitle: String? { get {
            switch self {
            case .manual:
                return "water_lock_desc_manual".localized
            case .once:
                return "water_lock_desc_once".localized
            case .automatic:
                return "water_lock_desc_automatic".localized
            }
        } }
    }
    
}

extension Constants.Defs {
    static let notificationSound = "notificationSound"
    static let helpState = "helpState"
    static let mapViewType = "mapViewType"
    static let useMagnetometer = "useMagnetometer"
    static let keepScreenOn = "keepScreenOn"
    static let lastTimeReviewAsked = "lastTimeReviewAsked"
}
