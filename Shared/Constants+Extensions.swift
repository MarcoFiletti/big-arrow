//
//  Constants+Extensions.swift
//  Big Arrow
//
//  Created by Marco Filetti on 18/11/2017.
//  Copyright © 2017 Marco Filetti. All rights reserved.
//

import Foundation

extension Constants {
    
    /// Returns initial defaults for both watch and iphone
    static var initialDefaults: [String: Any] { get {
        var defs = [String: Any]()
        defs[Constants.Defs.destinations] = []
        defs[Constants.Defs.showProgressBar] = true
        defs[Constants.Defs.runInBackground] = true
        defs[Constants.Defs.sortDestinationsBy] = SortBy.lastUsed.rawValue
        defs[Constants.Defs.nearNotificationsOn] = false
        defs[Constants.Defs.notificationsStopTracking] = true
        defs[Constants.Defs.compassIsRelative] = false
        defs[Constants.Defs.iPhoneArrowSize] = 240
        defs[Constants.Defs.watchArrowSize] = 128
        defs[Constants.Defs.useMagnetometer] = true
        defs[Constants.Defs.measurements] = Options.Measurements.automatic.rawValue
        defs[Constants.Defs.waterLockOption] = Options.WaterLock.manual.rawValue
        defs[Constants.Defs.batterySaving] = false
        defs[Constants.Defs.notificationsETA] = 0.0
        defs[DestinationMaster.lastUpdateKey] = Date.distantPast
        if LocationMaster.usesMetric {
            defs[Constants.Defs.nearNotificationMeters] = 100.0
        } else {
            defs[Constants.Defs.nearNotificationMeters] = 109.36
        }
        return defs
    }}
    
    class Notifications {
        /// A destination was updated (added, removed)
        static let updatedDestination: Notification.Name = Notification.Name(rawValue: "com.marcofiletti.updatedDestinationNotification")
        
        /// The preference to show/hide the progress bar in the arrow was changed
        /// Look up UserDefaults to check what value it is now
        static let changedProgressBarPreference = Notification.Name(rawValue: "com.marcofiletti.changedProgressBarPreference")
        
        /// The notification indicating that the run in background preference was changed
        /// Look up UserDefaults to check what value it is now
        static let changedRunInBackgroundPreference = Notification.Name(rawValue: "com.marcofiletti.changedRunInBackgroundPreference")
        
        /// The notification indicating that keep screen on was changed
        /// Look up UserDefaults to check what value it is now
        static let changedKeepScreenOnPreference = Notification.Name(rawValue: "com.marcofiletti.changedKeepScreenOnPreference")
        
        /// The preference that stores the distance within which we should be notified has
        /// been changed
        static let changedNearDistanceNotificationMeters = Notification.Name(rawValue: "com.marcofiletti.changedNearDistanceNotificationMeters")
        
        /// A destinations was renamed
        /// userInfo keys:
        /// - "oldName": previous name of the destinations
        /// - "newName": new name assigned to it
        static let renamedDestination: Notification.Name =
            Notification.Name(rawValue: "com.marcofiletti.renamedDestinationNotification")
        
        /// A destination date was updated (the keys updated are sent sent in userinfo[Constants.timesUpdatedNotificationHashKey])
        static let timesUpdated: Notification.Name = Notification.Name(rawValue: "com.marcofiletti.updatedLastUsedTimesNotification")
        
        /// Key for timesUpdatedNotification array of updated hashes
        static let timesUpdatedNamesKey = "updatedNames"
        
        /// Sent when a user notification for nearby is triggered and the user wants
        /// to stop (or we have to stop automatically) and the app is in foreground
        static let nearDistanceNotificationStopTracking = Notification.Name(rawValue: "com.marcofiletti.nearDistanceNotificationStopTracking")
        
        /// Sent when the eta notification is triggered and the app is in foreground
        static let etaNotificationTriggered = Notification.Name(rawValue: "com.marcofiletti.etaNotificationTriggered")
        
        /// Sent when a (non-stop) nearby notification is triggered and the app is in foreground
        static let nearbyNotificationTriggered = Notification.Name(rawValue: "com.marcofiletti.nearbyNotificationTriggered")
        
        /// Sent when the arrow size was changed
        static let arrowSizeChanged = Notification.Name(rawValue: "com.marcofiletti.arrowSizeChanged")
                
    }
    
    /// Gets BigArrow Folder,
    /// creating it if necessary
    static var theDir: URL { get {
        let appSupportDir = try! FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let theDir = appSupportDir.appendingPathComponent("BigArrow")
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: theDir.path, isDirectory: &isDir) {
            if !isDir.boolValue {
                fatalError("Expected folder is not a directory")
            }
        } else {
            try! FileManager.default.createDirectory(at: theDir, withIntermediateDirectories: true, attributes: nil)
        }
        return theDir
    } }
    
}

