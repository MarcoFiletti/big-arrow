//
//  Constants.swift
//  Telemetry
//
//  Created by Marco Filetti on 05/11/2016.
//  Copyright © 2016 Marco Filetti. All rights reserved.
//

import Foundation
#if WatchApp
    import WatchKit
#else
    import UIKit
#endif

class Constants {
    
    /// Sorting preferences
    enum SortBy: UInt8 {
        case lastUsed
        case distance
        case manual
        
        static func currentSetting() -> SortBy {
            let val = UserDefaults.standard.object(forKey: Constants.Defs.sortDestinationsBy) as! UInt8
            if let set = SortBy(rawValue: val) {
                return set
            } else {
                return .lastUsed
            }
        }
        
        func setDefault() {
            UserDefaults.standard.set(self.rawValue, forKey: Constants.Defs.sortDestinationsBy)
        }
    }
    
    /// If a not good FuzzyAccuracy was received this much time after
    /// a good FuzzyAccuracy reading, the reading should be ignored
    static let goodAccuracyDuration: TimeInterval = 7.5
    
    /// Enabled relaxed mode if we have been running in background
    /// for this amount of time
    static let relaxEnableTime: TimeInterval = 60 * 2
    
    /// Time that needs to elapse before we report signal lost
    static let signalLostTime: TimeInterval = 20
    
    /// Time that needs to elapse before we thing we are standing still
    static let standingStillTime: TimeInterval = 30
    
    /// If standingStillTime passes and we have always been within this distance,
    /// we are officially standing still
    static let standingStillDistance: TimeInterval = 10
    
    /// Maximum difference in accuracy between locations for comparisons between them
    static let maxAccuracyDifference: Double = 10
    
    /// How often we ask for a review days * hours * minutes * seconds
    static let reviewInterval: TimeInterval = 3 * 24 * 60 * 60
    
    /// Minimum speed for direction updates
    static let minSpeed: Double = 0.4  // 0.4 m/s = 1.44 km/h
    
    /// Minimum number of location updates needed to start updating indications.
    /// This is multiplied by 2 for ETA calculations.
    static let minNoOfLocations: UInt = 5
    
    /// Maximum proportional difference between to indications for ETA calculation when in relaxed mode
    static let maxEtaAccuracyPropDiffRelaxed: Double = 0.1
    
    /// Size of speed running buffer for eta calculations
    static let etaBufferSize: Int = 120
    
    /// Size of angle buffer for angle smoothing
    static let angleBufferSize: Int = 4
    
    /// Time (only time) DateFormatter
    static let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "HH'.'mm'.'ss"
        return df
    }()
    
    /// Date formatter
    static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.doesRelativeDateFormatting = true
        df.dateStyle = .short
        df.timeStyle = .medium
        return df
    }()
    
    /// App group ID
    static let groupId = "group.com.marcofiletti.ios.Big-Arrow"
    
    /// User activity type for opening a destination
    static let userActivityType = "com.marcofiletti.ios.Big-Arrow.gotodestination"
    
    /// Max destination name length
    static let maxNameLength = 50
    
    /// hash "salt"
    static let hashSalt: Int = 9967
    
    // MARK: - Location
    
    // MARK: - UI
    
    /// Alpha of arrow when a notification is shown
    static let fadedArrowAlpha: CGFloat = 0.3
    
    static let arrowColor = #colorLiteral(red: 1, green: 0.4826301336, blue: 0.001281457138, alpha: 1)
    static let compassColor = #colorLiteral(red: 0.9995550513, green: 0.004675073549, blue: 0.006291651633, alpha: 1)
    static let strokeColor = #colorLiteral(red: 0.8865163536, green: 0.4336975823, blue: 0.01020714189, alpha: 1)
    static let crosshairColor = #colorLiteral(red: 0.8980392157, green: 0.8980392157, blue: 0.8980392157, alpha: 1)
    
    // MARK: - UserDefault keys
    
    class Defs {
        static let destinations = "destinations"
        static let iPhoneArrowSize = "iPhoneArrowSize"
        static let watchArrowSize = "watchArrowSize"
        static let showProgressBar = "showProgressBar"
        static let runInBackground = "runInBackground"
        static let sortDestinationsBy = "sortDestinationsBy"
        static let nearNotificationsOn = "nearNotificationsOn"
        static let nearNotificationMeters = "nearNotificationMeters"
        static let notificationsStopTracking = "notificationsStopTracking"
        static let notificationsETA = "notificationsETA"
        /// Battery saving enables LocationMaster relaxedMode
        static let batterySaving = "batterySaving"
        static let compassIsRelative = "compassIsRelative"
        static let measurements = "measurements"
        static let waterLockOption = "water_lock_option"
    }
        
    // MARK: - User activity keys
    
    class UserActivity {
        static let destinationNameKey = "useractivity.keys.destinationName"
    }

}

