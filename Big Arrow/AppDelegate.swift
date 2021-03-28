//
//  AppDelegate.swift
//  Big Arrow
//
//  Created by Marco Filetti on 15/06/2017.
//  Copyright © 2017 Marco Filetti. All rights reserved.
//

import UIKit
import WatchConnectivity
import os.log
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate, WCSessionDelegate, UNUserNotificationCenterDelegate {

    // if we should ask for a review next time main table is shown
    static var askForReview = false
    
    // if it's time to ask for a review (3 days since last time it was asked)
    static var timeToAskForReview = false
    
    var window: UIWindow?
    
    var splitViewController: UISplitViewController!
    
    var session: WCSession?
    var presentedNotifications = Set<String>()
    
    static var thereIsAPairedWatch: Bool {
        guard let session = (UIApplication.shared.delegate as? AppDelegate)?.session else {
            return false
        }
        return session.isPaired
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        var defaults = Constants.initialDefaults
        defaults[Constants.Defs.helpState] = 0
        defaults[Constants.Defs.mapViewType] = -1  // using -1 to specify unset
        defaults[Constants.Defs.keepScreenOn] = false
        defaults[Constants.Defs.notificationSound] = Options.NotificationSound.single.rawValue
        defaults[Constants.Defs.lastTimeReviewAsked] = Date.distantPast
        UserDefaults.standard.register(defaults: defaults)
        Formatters.updateFormatters()
        
        DestinationMaster.load()
                
        activateSession()
        
        // Set split view controller and navigation controller
        splitViewController = window!.rootViewController as? UISplitViewController
        let navigationController = splitViewController.viewControllers[splitViewController.viewControllers.count-1] as! UINavigationController
        navigationController.topViewController!.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem
        splitViewController.delegate = self
        
        // Register notifications and delegate
        UNUserNotificationCenter.current().delegate = self
        NotificationHelper.registerCategories()
        
        // observe renames to contact watch session
        NotificationCenter.default.addObserver(self, selector: #selector(destinationRenamed(_:)), name: Constants.Notifications.renamedDestination, object: nil)
        
        return true
    }
        
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        LocationMaster.shared.relaxAccuracy()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        LocationMaster.shared.increaseAccuracy()
        NotificationHelper.clearAllNotifications()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:
        LocationMaster.shared.stop(final: true)
    }
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        
        guard let name = userActivity.userInfo?[Constants.UserActivity.destinationNameKey] as? String else {
            return false
        }
        
        guard let destNo = DestinationMaster.destinations.firstIndex(where: {$0.name == name}) else {
            os_log("Could not find destination with name: %@", type: .error, name)
            return false
        }

        var waitTime: TimeInterval = 0
        
        guard let navigationController = splitViewController.viewControllers.first as? UINavigationController else {
            os_log("Could not find a nagivation controller", type: .error)
            return false
        }
        
        // pop view controller and wait if root is different than expected
        if !(navigationController.visibleViewController is MasterViewController) {
            waitTime = 2
            navigationController.popToRootViewController(animated: true)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + waitTime) {
            
            guard let mast = navigationController.visibleViewController as? MasterViewController else {
                let typeDef = type(of: navigationController.visibleViewController)
                let s = String(describing: typeDef)
                os_log("Could not find a master view controller, found %@", type: .error, s)
                return
            }
            
            let destination = DestinationMaster.destinations[destNo]
            mast.nextDestination = destination
            mast.performSegue(withIdentifier: "showDetail", sender: self)
        }
        
        return true
        
    }

    // MARK: - Split view

    func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController:UIViewController, onto primaryViewController:UIViewController) -> Bool {
        guard let secondaryAsNavController = secondaryViewController as? UINavigationController else { return false }
        guard let topAsDetailController = secondaryAsNavController.topViewController as? ArrowController else { return false }
        if topAsDetailController.destination == nil {
            // Return true to indicate that we have handled the collapse by doing nothing; the secondary controller will be discarded.
            return true
        }
        return false
    }
    
    // MARK: - Notification callbacks
    
    @objc func destinationRenamed(_ notification: Notification) {
        guard let uInfo = notification.userInfo, let newName = uInfo["newName"] as? String, let oldName = uInfo["oldName"] as? String else {
            os_log("Notification rename fail for", type: .error)
            return
        }
        
        let dict: [String: String] = ["newName": newName, "oldName": oldName]
        session?.transferUserInfo([SessionKeys.renameDestination: dict])
    }
    
    // MARK: - Watch communication
    
    func sendDeleteDestination(_ destination: Destination) {
        guard session?.activationState ?? .notActivated == .activated else {
            return
        }
        
        session?.transferUserInfo([SessionKeys.deleteDestination: destination.name])
    }
    
    /// Sends a new destination to watch
    func sendNewDestination(_ dest: Destination) {
        guard session?.activationState ?? .notActivated == .activated else {
            return
        }
        
        session?.transferUserInfo([SessionKeys.newDestination: dest.toDict()])
    }
    
    /// Sends a new used time (or times) to watch
    func sendNewUsedTime(_ times: [String: Date]) {
        guard session?.activationState ?? .notActivated == .activated else {
            return
        }
        
        session?.transferUserInfo([SessionKeys.updateTime: times])
    }
    
    /// Sends the progress bar preference to watch
    func sendProgressBarPref(newValue: Bool) {
        guard session?.activationState ?? .notActivated == .activated else {
            return
        }
        
        session?.transferUserInfo([SessionKeys.prefProgressBar: newValue])
    }
    
    /// Sends the run in background preference to watch
    func sendRunInBackgroundPref(newValue: Bool) {
        guard session?.activationState ?? .notActivated == .activated else {
            return
        }
        
        session?.transferUserInfo([SessionKeys.prefRunInBackground: newValue])
    }
    
    /// Sends the sort by date preference to watch
    func sendSortByPref(newValue: UInt8) {
        guard session?.activationState ?? .notActivated == .activated else {
            return
        }
        
        session?.transferUserInfo([SessionKeys.prefSortBy: newValue])
    }
    
    /// Sends the compass is relative preference to watch
    func sendCompassIsRelativePref(newValue: Bool) {
        guard session?.activationState ?? .notActivated == .activated else {
            return
        }
        
        session?.transferUserInfo([SessionKeys.prefCompassIsRelative: newValue])
    }
    
    /// Sends the use magnetometer preference to watch
    func sendMagnetometerToggle(newValue: Bool) {
        guard session?.activationState ?? .notActivated == .activated else {
            return
        }
        
        session?.transferUserInfo([SessionKeys.prefUseMagnetometer: newValue])
    }
    
    /// Sends the arrow size preference to watch
    func sendWatchArrowSize(newValue: Float) {
        guard session?.activationState ?? .notActivated == .activated else {
            return
        }
        
        session?.transferUserInfo([SessionKeys.prefWatchArrowSize: newValue])
    }
    
    /// Sends the measurements preference to watch
    func sendMeasurementsPref(newValue: UInt8) {
        guard session?.activationState ?? .notActivated == .activated else {
            return
        }
        
        session?.transferUserInfo([SessionKeys.prefMeasurements: newValue])
    }
    
    /// Sends the water lock preference to watch
    func sendWaterLockPref(_ newValue: UInt8) {
        guard session?.activationState ?? .notActivated == .activated else {
            return
        }
        
        session?.transferUserInfo([SessionKeys.prefWaterLock: newValue])
    }
    
    /// Tells the counterpart that a destination was moved from one row to another
    func swappedDestinations(_ one: String, _ two: String) {
        guard session?.activationState ?? .notActivated == .activated else {
            return
        }
        
        let uInfo: [String: String] = ["one": one, "two": two]
        session?.transferUserInfo([SessionKeys.swappedDestinations: uInfo])
    }
    
    /// Sends the notification near distance meters preference
    func sendNearNotificationDistanceMeters(newValue: Double) {
        guard session?.activationState ?? .notActivated == .activated else {
            return
        }
        
        session?.transferUserInfo([SessionKeys.prefNearNotificationMeters: newValue])
    }
    
    /// Sends the notification near distance notify on changed preference
    func sendNearNotificationsToggle(newValue: Bool) {
        guard session?.activationState ?? .notActivated == .activated else {
            return
        }
        
        session?.transferUserInfo([SessionKeys.prefNearNotificationsOn: newValue])
    }
    
    /// Sends the notifications stop tracking preference
    func sendNotificationsStopTrackingToggle(newValue: Bool) {
        guard session?.activationState ?? .notActivated == .activated else {
            return
        }
        
        session?.transferUserInfo([SessionKeys.prefNotificationsStopTracking: newValue])
    }
    
    /// Sends the battery save preference
    func sendBatterySaveToggle(newValue: Bool) {
        guard session?.activationState ?? .notActivated == .activated else {
            return
        }
        
        session?.transferUserInfo([SessionKeys.prefBatterySaving: newValue])
    }
    
    /// Sends the ETA notification seconds
    func sendETANotificationSeconds(newValue: Double) {
        guard session?.activationState ?? .notActivated == .activated else {
            return
        }
        
        session?.transferUserInfo([SessionKeys.prefETANotificationSeconds: newValue])
    }
    
    func activateSession() {
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        guard error == nil else {
            os_log("Error while activating session: %@", type: .error, error?.localizedDescription ?? "N/A")
            self.session = nil
            return
        }
        
        
        if activationState == .activated {
            self.session = session
        } else {
            self.session = nil
        }
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        
        // if we received a destination, add it
        if let destDict = userInfo[SessionKeys.newDestination] as? [String: Any] {
            DestinationMaster.addDestination(dest: Destination(fromDict: destDict))
        }
        
        // if we received a last used time, add it
        if let utimeDict = userInfo[SessionKeys.updateTime] as? [String: Date] {
            DestinationMaster.updateTimes(newTimes: utimeDict)
        }
        
        // if we received a new water lock option, save it
        if let newWaterLockPref = userInfo[SessionKeys.prefWaterLock] as? UInt8 {
            UserDefaults.standard.set(newWaterLockPref, forKey: Constants.Defs.waterLockOption)
        }
        
        // we may need to send stuff now, so check session status
        guard session.activationState == .activated else {
            return
        }
        
        // if we received all destinations date, check if it's older than our
        // If so, send all destinations and times.
        // do the same if we received a requestAllDestinations
        
        let mustUpdateAll: Bool
        
        if let lastUpdate = userInfo[SessionKeys.allDestinationsLastUpdate] as? Date,
               lastUpdate.compare(DestinationMaster.lastUpdate) == .orderedAscending {
            
            mustUpdateAll = true
        
        } else if let theirNumber = userInfo[SessionKeys.numberOfDestinations] as? UInt8,
                      theirNumber != DestinationMaster.destinations.count {
            mustUpdateAll = true
        } else if let requested = userInfo[SessionKeys.requestAllDestinations] as? Bool,
                      requested == true {
            
            mustUpdateAll = true
        
        } else {
            mustUpdateAll = false
        }
        
        if mustUpdateAll {
            session.transferUserInfo([SessionKeys.allDestinations: DestinationMaster.destinations.map({$0.toDict()})])
            session.transferUserInfo([SessionKeys.updateTime: DestinationMaster.lastUsedTimes])
        }
        
        // send all preferences if requested
        
        if let sendAllPrefs = userInfo[SessionKeys.requestAllPreferences] as? Bool,
               sendAllPrefs == true {
            let progBarOn = UserDefaults.standard.object(forKey: Constants.Defs.showProgressBar) as! Bool
            let sortBy = UserDefaults.standard.object(forKey: Constants.Defs.sortDestinationsBy) as! UInt8
            let nearNotifOn = UserDefaults.standard.object(forKey: Constants.Defs.nearNotificationsOn) as! Bool
            let nearNotifMeters = UserDefaults.standard.object(forKey: Constants.Defs.nearNotificationMeters) as! Double
            let notifStopTrackOn = UserDefaults.standard.object(forKey: Constants.Defs.notificationsStopTracking) as! Bool
            let batterySaveOn = UserDefaults.standard.object(forKey: Constants.Defs.batterySaving) as! Bool
            let etaNotificationSecs = UserDefaults.standard.object(forKey: Constants.Defs.notificationsETA) as! Double
            let runInBackground = UserDefaults.standard.object(forKey: Constants.Defs.runInBackground) as! Bool
            let compassIsRelative = UserDefaults.standard.object(forKey: Constants.Defs.compassIsRelative) as! Bool
            let measurements = UserDefaults.standard.object(forKey: Constants.Defs.measurements) as! UInt8
            let uInfo: [String: Any] = [SessionKeys.prefProgressBar: progBarOn,
                SessionKeys.prefNearNotificationsOn: nearNotifOn,
                SessionKeys.prefSortBy: sortBy,
                SessionKeys.prefNearNotificationMeters: nearNotifMeters,
                SessionKeys.prefNotificationsStopTracking: notifStopTrackOn,
                SessionKeys.prefBatterySaving: batterySaveOn,
                SessionKeys.prefETANotificationSeconds: etaNotificationSecs,
                SessionKeys.prefRunInBackground: runInBackground,
                SessionKeys.prefCompassIsRelative: compassIsRelative,
                SessionKeys.prefMeasurements: measurements ]
            session.transferUserInfo(uInfo)
        }
        
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        os_log("AppDelegate.sessionDidBecomeInactive", type: .debug)
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        self.session = nil
        activateSession()
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

