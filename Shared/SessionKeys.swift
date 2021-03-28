//
//  SessionKeys.swift
//  Big Arrow
//
//  Created by Marco Filetti on 30/06/2017.
//  Copyright © 2017 Marco Filetti. All rights reserved.
//

import Foundation

class SessionKeys {
    
    /// Requests the location array hash
    /// contents: a true boolean
    static let requestAllDestinations = "communication.requestAllDestinations"
    
    /// Requests all used times
    /// contents: a true boolean
//    static let requestAllUsedTimes = "communication.requestAllUsedTimes"
    
    /// Sends the last time that we updated the destination list
    /// contents: the date
    static let allDestinationsLastUpdate = "allDestinationsLastUpdate"
    
    /// Key for all destinations together
    /// contents: an array of dicts containing all destinations
    static let allDestinations = "communication.allDestinations"
    
    /// A new destination
    /// contents: a single dict containing a destination
    static let newDestination = "communication.newDestination"
    
    /// Rename destination (phone to watch only)
    /// contents: a String:String dict with newName and oldName
    static let renameDestination = "communication.renameDestination"
    
    /// Delete the given destination
    /// contents: a string identifying the name of the destination to delete
    static let deleteDestination = "communication.deleteDestination"
    
    /// A destination was moved in the main list
    /// contents: a dict with
    /// - `one` the name of the destination that was dragged (String)
    /// - `two` the name of the destination it was swapped with (String)
    static let swappedDestinations = "communication.swappedDestinations"
        
    /// Sends an update for last used times
    /// Contents: an [String: Date] dictionary containing one or more times
    static let updateTime = "communication.updateTimes"
    
    /// Tells the counterpart to send all preferences
    /// Contents: a true boolean
    static let requestAllPreferences = "communication.requestAllPreferences"
    
    /// Tells the counterpart to turn progress bar on / off
    /// Contents: a bool telling new value
    static let prefProgressBar = "communication.prefProgressBar"
    
    /// Tells the counterpart that the run in background preference
    /// was changed
    /// Contents: a bool telling new value
    static let prefRunInBackground = "communication.prefRunInBackground"
    
    /// Tells the counterpart to sort automatically by date on / off
    /// Contents: a UInt8 telling new value
    static let prefSortBy = "communication.prefSortBy"
    
    /// Tells the counterpart the number of destinations we have
    /// Contents: a UInt8 with the number of destinations
    static let numberOfDestinations = "communication.numberOfDestinations"
    
    /// Tells the counterpart to notify when distance ≤ meters
    /// Contents: a double containing the meters
    static let prefNearNotificationMeters = "communication.prefNearNotificationMeters"
    
    /// Tells the counterpart to notify when eta < this value
    /// Contents: the Double (timeinterval)
    static let prefETANotificationSeconds = "communication.prefETANotificationSeconds"
    
    /// Tells the counterpart if near notifications are on
    /// Contents: a bool telling if they are on
    static let prefNearNotificationsOn = "communication.prefNearNotificationsOn"
    
    /// Tells the counterpart if auto stop tracking after notifications is on
    /// Contents: a bool telling if enabled
    static let prefNotificationsStopTracking = "communication.prefNotificationsStopTracking"
    
    /// Tells the counterpart that the digital compass option was changed
    /// Contents: a bool telling if relative
    static let prefCompassIsRelative = "communication.prefCompassIsRelative"
    
    /// Tells the counterpart that battery saving was changed
    /// Contents: a bool telling if enabled
    static let prefBatterySaving = "communication.prefBatterySaving"
    
    /// Tells the counterpart that a new measurements type was selected
    /// Contents: a UInt8 corresponding to the Measurements enum
    static let prefMeasurements = "communication.prefMeasurements"
    
    /// Tells the counterpart that a new water lock option was selected
    /// Contents: a UInt8 corresponding to the Option.WaterLock enum
    static let prefWaterLock = "communication.prefWaterLock"
    
    /// Tells the counterpart that a new use magnetometer option selected
    /// Contents: a Bool, true if we want to use the magnetometer
    static let prefUseMagnetometer = "communication.prefUseMagnetometer"
    
    /// Tells the counterpart that a new use watch arrow size was selected
    /// Contents: a Float, referring to arrow size in pixels
    static let prefWatchArrowSize = "communication.prefWatchArrowSize"

}
