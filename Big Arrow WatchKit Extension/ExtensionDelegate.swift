//
//  ExtensionDelegate.swift
//  Big Arrow WatchKit Extension
//
//  Created by Marco Filetti on 15/06/2017.
//  Copyright © 2017 Marco Filetti. All rights reserved.
//

import WatchKit
import WatchConnectivity
import os.log
import UserNotifications

class ExtensionDelegate: NSObject, WKExtensionDelegate, WCSessionDelegate, UNUserNotificationCenterDelegate {

    var session: WCSession?
    var activity: NSUserActivity?
    var presentedNotifications = Set<String>()
    
    func applicationDidFinishLaunching() {
        UserDefaults.standard.register(defaults: Constants.initialDefaults)
        Formatters.updateFormatters()
        
        DestinationMaster.load()
        
        WCSession.default.delegate = self
        WCSession.default.activate()
        
        UNUserNotificationCenter.current().delegate = self
        NotificationHelper.registerCategories()
    }
    
    func applicationDidBecomeActive() {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillResignActive() {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, etc.
    }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        // Sent when the system needs to launch the application in the background to process tasks. Tasks arrive in a set, so loop through and process each one.
        for task in backgroundTasks {
            // Use a switch statement to check the task type
            switch task {
            case let backgroundTask as WKApplicationRefreshBackgroundTask:
                
                // Be sure to complete the background task once you’re done.
                backgroundTask.setTaskCompletedWithSnapshot(false)
                
            case let snapshotTask as WKSnapshotRefreshBackgroundTask:
                // Snapshot tasks have a unique completion call, make sure to set your expiration date
                snapshotTask.setTaskCompleted(restoredDefaultState: true, estimatedSnapshotExpiration: Date.distantFuture, userInfo: nil)
            case let connectivityTask as WKWatchConnectivityRefreshBackgroundTask:
                
                // Be sure to complete the connectivity task once you’re done.
                connectivityTask.setTaskCompletedWithSnapshot(false)
                
            case let urlSessionTask as WKURLSessionRefreshBackgroundTask:
                // Be sure to complete the URL session task once you’re done.
                urlSessionTask.setTaskCompletedWithSnapshot(false)
            default:
                // make sure to complete unhandled task types
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }
    
    // MARK: - Communication
    
    /// Sends a new destination to phone
    func sendNewDestination(_ dest: Destination) {
        guard session?.activationState ?? .notActivated == .activated else {
            return
        }
        
        session?.transferUserInfo([SessionKeys.newDestination: dest.toDict()])
    }
    
    /// Sends a new water lock otpion to phone
    func sendWaterLockPref(_ newValue: UInt8) {
        guard session?.activationState ?? .notActivated == .activated else {
            return
        }
        
        session?.transferUserInfo([SessionKeys.prefWaterLock: newValue])
    }
    
    /// Sends a new used time (or times) to phone
    func sendNewUsedTime(_ times: [String: Date]) {
        guard session?.activationState ?? .notActivated == .activated else {
            return
        }
        
        session?.transferUserInfo([SessionKeys.updateTime: times])
    }
    
    /// Requests all destinations from counterpart
    func requestAllDestinations() {
        guard session?.activationState ?? .notActivated == .activated else {
            return
        }
        
        session?.transferUserInfo([SessionKeys.requestAllDestinations: true])
    }
    
    // MARK: - Session

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        guard error == nil else {
            os_log("Error while activating: %@", type: .error, error?.localizedDescription ?? "N/A")
            return
        }
        
        self.session = session
        
        // on first connect, send our destination last update time and ask for all preferences
        if activationState == .activated {
            var uInfo = [String: Any]()
            uInfo[SessionKeys.allDestinationsLastUpdate] = DestinationMaster.lastUpdate
            uInfo[SessionKeys.requestAllPreferences] = true
            uInfo[SessionKeys.numberOfDestinations] = DestinationMaster.destinations.count
            session.transferUserInfo(uInfo)
        }
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {

        // if we received a delete, do it
        if let name = userInfo[SessionKeys.deleteDestination] as? String {
            DestinationMaster.deleteDestination(name: name)
        }
        
        // if we received a destination, add it
        if let destDict = userInfo[SessionKeys.newDestination] as? [String: Any] {
            DestinationMaster.addDestination(dest: Destination(fromDict: destDict), imported: true)
        }
        
        // if we received a last used time, add it
        if let utimeDict = userInfo[SessionKeys.updateTime] as? [String: Date] {
            DestinationMaster.updateTimes(newTimes: utimeDict)
        }
        
        // if we received a rename, enact it
        if let renameDict = userInfo[SessionKeys.renameDestination] as? [String: String],
            let newName = renameDict["newName"], let oldName = renameDict["oldName"] {
            
            let renameDestI = DestinationMaster.destinations.firstIndex(where: {$0.name == oldName})
            
            if renameDestI == nil {
                os_log("Could not find renamed destination got from session", type: .fault)
            } else {
                let dest = DestinationMaster.destinations[renameDestI!]
                DestinationMaster.renameDestination(dest, newName: newName)
            }
        }

        // if we received all destinations, replace them
        if let allDestinations = userInfo[SessionKeys.allDestinations] as? [[String: Any]] {
            
            DestinationMaster.replaceDestinations(newDestinations: allDestinations.map({Destination(fromDict: $0)}))
            
        }
        
        // if we received a progress bar preference change, set and send notification
        if let newPBvalue = userInfo[SessionKeys.prefProgressBar] as? Bool {
            UserDefaults.standard.set(newPBvalue, forKey: Constants.Defs.showProgressBar)
            NotificationCenter.default.post(name: Constants.Notifications.changedProgressBarPreference, object: self)
        }
        
        // if we received a run in background preference change, set and send notification
        if let newRBvalue = userInfo[SessionKeys.prefRunInBackground] as? Bool {
            UserDefaults.standard.set(newRBvalue, forKey: Constants.Defs.runInBackground)
            NotificationCenter.default.post(name: Constants.Notifications.changedRunInBackgroundPreference, object: self)
        }
        
        // if we received a compass relative preference, set it
        if let newCompassValue = userInfo[SessionKeys.prefCompassIsRelative] as? Bool {
            UserDefaults.standard.set(newCompassValue, forKey: Constants.Defs.compassIsRelative)
        }
        
        // if we received a new use magnetometer preference, set it
        if let newMagnetometerValue = userInfo[SessionKeys.prefUseMagnetometer] as? Bool {
            UserDefaults.standard.set(newMagnetometerValue, forKey: Constants.Defs.useMagnetometer)
            LocationMaster.shared.magnetometerPref = newMagnetometerValue
        }
        
        // if we received a new arrow size preference, set it and send notification
        if let newArrowSizeValue = userInfo[SessionKeys.prefWatchArrowSize] as? Float {
            UserDefaults.standard.set(newArrowSizeValue, forKey: Constants.Defs.watchArrowSize)
            NotificationCenter.default.post(name: Constants.Notifications.arrowSizeChanged, object: self)
        }
        
        // if we received a measurements preference, set it and send notification
        if let newMeasurementsPref = userInfo[SessionKeys.prefMeasurements] as? UInt8 {
            UserDefaults.standard.set(newMeasurementsPref, forKey: Constants.Defs.measurements)
            Formatters.updateFormatters()
            NotificationCenter.default.post(name: Constants.Notifications.updatedDestination, object: self)
        }
        
        // if we received a new water lock preference, set it
        if let newWaterLockPref = userInfo[SessionKeys.prefWaterLock] as? UInt8 {
            UserDefaults.standard.set(newWaterLockPref, forKey: Constants.Defs.waterLockOption)
        }

        // if we received a sort by date preference change, set and send notification if different
        if let newSBvalue = userInfo[SessionKeys.prefSortBy] as? UInt8 {
            let oldValue = UserDefaults.standard.object(forKey: Constants.Defs.sortDestinationsBy) as! UInt8
            if newSBvalue != oldValue {
                UserDefaults.standard.set(newSBvalue, forKey: Constants.Defs.sortDestinationsBy)
                NotificationCenter.default.post(name: Constants.Notifications.updatedDestination, object: self)
            }
        }
        
        // if we received a moved destination, tell destination master and
        // root controller (if visible)
        if let swapDict = userInfo[SessionKeys.swappedDestinations] as? [String: String],
           let one = swapDict["one"],
           let two = swapDict["two"],
           let ixs = DestinationMaster.swapDestinations(one, two),
           let rootController = WKExtension.shared().rootInterfaceController as? RootController {
                rootController.moveDestination(fromRow: ixs.0, toRow: ixs.1)
        }
        
        // if we received a new value for near notifications, set it
        if let newNearNotifOn = userInfo[SessionKeys.prefNearNotificationsOn] as? Bool {
            UserDefaults.standard.set(newNearNotifOn, forKey: Constants.Defs.nearNotificationsOn)
        }
        
        // if we received a new value for near notification distance, set it
        if let newNearNotifDistance = userInfo[SessionKeys.prefNearNotificationMeters] as? Double {
            UserDefaults.standard.set(newNearNotifDistance, forKey: Constants.Defs.nearNotificationMeters)
            NotificationCenter.default.post(name: Constants.Notifications.changedNearDistanceNotificationMeters, object: self)
        }
        
        // if we received a new value for notifications stop tracking, set it
        if let newNotifStopTrack = userInfo[SessionKeys.prefNotificationsStopTracking] as? Bool {
            UserDefaults.standard.set(newNotifStopTrack, forKey: Constants.Defs.notificationsStopTracking)
        }
        
        // if we received a new value for battery save, set it
        if let newBatterySave = userInfo[SessionKeys.prefBatterySaving] as? Bool {
            UserDefaults.standard.set(newBatterySave, forKey: Constants.Defs.batterySaving)
        }
        
        // if we received a new value for eta seconds, set it
        if let newSeconds = userInfo[SessionKeys.prefETANotificationSeconds] as? Double {
            UserDefaults.standard.set(newSeconds, forKey: Constants.Defs.notificationsETA)
        }

    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        
        guard session.activationState == .activated else {
            return
        }
        
    }
    
    func sessionErrorHandler(error: Error) {
        os_log("Error while sending message: %@", type: .error, error.localizedDescription)
    }
    
    // MARK: - User Notification Center Delegate

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier == NotificationHelper.Identifiers.stopTrackingAction {
            NotificationCenter.default.post(name: Constants.Notifications.nearDistanceNotificationStopTracking, object: nil)
        }
        completionHandler()
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if !presentedNotifications.contains(notification.request.identifier) {
            presentedNotifications.insert(notification.request.identifier)
            NotificationHelper.dispatchNotificationInternally(categoryIdentifier: notification.request.content.categoryIdentifier)
        }
        completionHandler(.sound)
    }
}
