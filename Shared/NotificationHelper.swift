//
//  NotificationHelper.swift
//  Big Arrow
//
//  Created by Marco Filetti on 19/11/2017.
//  Copyright © 2017 Marco Filetti. All rights reserved.
//

import Foundation
import UserNotifications

/// Contains code for the delivery of notifications
class NotificationHelper {
    
    /// Identifiers
    class Identifiers {
        // category identifiers
        
        static let autoStoppedNearbyNotification = "com.marcofiletti.autoStoppedNearbyNotification"
        static let stoppableNearbyNotification = "com.marcofiletti.stoppableNearbyNotification"
        static let stopTrackingAction = "com.marcofiletti.stoppableNearbyAction"
        
        // action identifiers
        static let etaNotification = "com.marcofiletti.etaNotification"
    }
    
    // MARK: - Internal properties
    
    /// Returns the notification categories we support.
    /// Two categories:
    /// - autoStoppedNearbyTrigger: we reached a destination and stopped ourselves.
    /// - stoppableNearbyTrigger: we reached a destination but didn't stop ourselves.
    ///    The notification includes a button to stop tracking.
    /// - etaTrigger: eta is less than a given value.
    static let categories: Set<UNNotificationCategory> = {
        let hiddenPlaceholder = "destination_reached".localized
        let autoStoppedCategory = createNotificationCategory(identifier: Identifiers.autoStoppedNearbyNotification, hiddenPlaceholder: hiddenPlaceholder)
        let stopAction = UNNotificationAction(identifier: Identifiers.stopTrackingAction, title: "stop".localized, options: [])
        let stoppableCategory = createNotificationCategory(identifier: Identifiers.stoppableNearbyNotification, actions: [stopAction], hiddenPlaceholder: hiddenPlaceholder)
        let etaCategory = createNotificationCategory(identifier: Identifiers.etaNotification, hiddenPlaceholder: "approaching_destination".localized)
        return [autoStoppedCategory, stoppableCategory, etaCategory]
    }()
    
    /// Stores whether we sent notification (we want to do it only once).
    /// Set to false every time location master starts.
    static var sentNearDistanceNotification = false { didSet {
        if sentNearDistanceNotification == false {
            nextNearbyIdString = UUID().uuidString
        }
    }}
    
    /// Stores whether we sent an eta notification.
    static var sentETANotification = false { didSet {
        if sentETANotification == false {
            nextETAIdString = UUID().uuidString
            lastSentETANotification = Date.distantPast
        } else {
            lastSentETANotification = Date()
        }
    }}
    
    // MARK: - Private propertied
    
    /// Last time an eta notification was sent.
    /// Reset by sentETANotification
    static private(set) var lastSentETANotification = Date.distantPast
    
    /// Stores uuid string for next notification (reset every time sentNearDistanceNotification is set to false)
    private static var nextNearbyIdString = UUID().uuidString
    
    /// Stores uuid string for next notification (reset every time sentETANotification is set to false)
    private static var nextETAIdString = UUID().uuidString

    // MARK: - Static functions
    
    /// Registers supported notification categories.
    /// Do this during app launch.
    static func registerCategories() {
        let center = UNUserNotificationCenter.current()
        center.setNotificationCategories(categories)
    }
    
    /// Sends user notifications if appropriate, and sends an internal notification
    /// indicating that this was done
    static func sendNotificationsIfNeeded(_ indication: Indication, _ destination: Destination?) {
        
        // first of all, check if notifications are on, otherwise leave
        guard UserDefaults.standard.object(forKey: Constants.Defs.nearNotificationsOn) as! Bool else {
            return
        }
        
        // if the eta notification was not sent and preference is set, send that
        if !sentETANotification, let destination = destination {
            let requestedEta = UserDefaults.standard.object(forKey: Constants.Defs.notificationsETA) as! Double
            if requestedEta > 0, let actualETA = indication.eta, actualETA < requestedEta, actualETA > 0 {
                self.sentETANotification = true
                let title = "approaching".localized + " " + destination.name
                let body = "ETA: \(Formatters.format(briefTime: actualETA))"
                let content = makeNotificationContent(title: title, body: body, categoryIdentifier: Identifiers.etaNotification)
                requestNotification(content: content, idString: nextETAIdString)
            }
        } else if sentETANotification {
            // if a minute has passed since last time a eta notification was set,
            // and current eta is > requested eta, reset sentETANotification
            
            if lastSentETANotification.addingTimeInterval(60) < Date(),
               let requestedEta = UserDefaults.standard.object(forKey: Constants.Defs.notificationsETA) as? Double,
               let actualEta = indication.eta,
               requestedEta < actualEta {
                sentETANotification = false
            }
        }
        
        // continue only if we didn't send nearby notification
        guard !sentNearDistanceNotification else {
                return
        }

        // do nothing if there's no destination
        guard let destination = destination else {
            return
        }
        
        // notification raduis
        let radius = UserDefaults.standard.object(forKey: Constants.Defs.nearNotificationMeters) as! Double
        
        /*
        OLD WAY, DISABLED FOR NOW
        // trigger notification if nearby, making sure that 1) accuracy is less than radius
        // or that 2) distance is less than half accuracy and radius is bigger than half dist
        guard indication.minimumDistance <= 0 &&
            
              (indication.accuracy <= radius ||
               indication.distance <= indication.accuracy / 2 && radius >= indication.distance / 2 ) else {
            return
        }
        */
        
        guard indication.distance <= radius else {
            return
        }
        
        sentNearDistanceNotification = true
        
        let content: UNNotificationContent
        let title = String(format: "reached_%@".localized, destination.name)
        let body = "distance".localized + ": \(Formatters.format(distance: indication.distance))"
        if UserDefaults.standard.object(forKey: Constants.Defs.notificationsStopTracking) as! Bool {
            content = makeNotificationContent(title: title, body: body, categoryIdentifier: Identifiers.autoStoppedNearbyNotification)
        } else {
            content = makeNotificationContent(title: title, body: body, categoryIdentifier: Identifiers.stoppableNearbyNotification)
        }
        
        requestNotification(content: content, idString: nextNearbyIdString) {
            error in
            if error == nil && UserDefaults.standard.object(forKey: Constants.Defs.notificationsStopTracking) as! Bool {
                NotificationCenter.default.post(name: Constants.Notifications.nearDistanceNotificationStopTracking, object: nil)
            }
        }
    }
    
    /// Clear all notifications (e.g. when opening arrow view)
    static func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
    
    /// Helper function to convert a notification received in foreground to an internal notification
    static func dispatchNotificationInternally(categoryIdentifier: String) {
        switch categoryIdentifier {
        case Identifiers.etaNotification:
            NotificationCenter.default.post(name: Constants.Notifications.etaNotificationTriggered, object: nil)
        case Identifiers.stoppableNearbyNotification:
            NotificationCenter.default.post(name: Constants.Notifications.nearbyNotificationTriggered, object: nil)
        case Identifiers.autoStoppedNearbyNotification:
             // sendNotificationsIfNeeded already does send an internal notification, and does so regardless of fore or back ground
            return
        default:
            return
        }
    }
    
    // MARK: - Private functions
    
    /// Helper function to submit a notification
    private static func requestNotification(content: UNNotificationContent, idString: String, completionHandler: ((Error?) -> Void)? = nil) {
        
        let center = UNUserNotificationCenter.current()
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: idString, content: content, trigger: trigger)
        
        center.add(request, withCompletionHandler: completionHandler)
    }
    
    /// Helper function to convert an indication > destination pair into content for a notification
    private static func makeNotificationContent(title: String, body: String, categoryIdentifier: String) -> UNNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if categoryIdentifier == Identifiers.autoStoppedNearbyNotification {
            content.subtitle = "stopped_automatically".localized
        }
        content.categoryIdentifier = categoryIdentifier
        #if !WatchApp
            content.sound = Options.NotificationSound.saved.unNotificationSound
        #else
            content.sound = UNNotificationSound.default
        #endif
        return content
    }
    
    /// Helper function to build a notification category
    private static func createNotificationCategory(identifier: String, actions: [UNNotificationAction] = [], hiddenPlaceholder: String) -> UNNotificationCategory {
        let category: UNNotificationCategory
        #if !WatchApp
            if #available(iOS 11.0, *) {
                category = UNNotificationCategory(identifier: identifier, actions: actions, intentIdentifiers: [], hiddenPreviewsBodyPlaceholder: hiddenPlaceholder)
            } else {
                category = UNNotificationCategory(identifier: identifier, actions: actions, intentIdentifiers: [], options: [])
            }
        #else
            category = UNNotificationCategory(identifier: identifier, actions: actions, intentIdentifiers: [], options: [])
        #endif
        return category
    }
}
