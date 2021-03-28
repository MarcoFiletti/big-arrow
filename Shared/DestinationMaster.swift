//
//  DestinationMaster.swift
//  Big Arrow
//
//  Created by Marco Filetti on 23/06/2017.
//  Copyright © 2017 Marco Filetti. All rights reserved.
//

import Foundation
import os.log

class DestinationMaster {
    
    // MARK: - Destinations and last used times
    
    private(set) static var destinations = [Destination]()
    
    /// Last used times indexes the hash of each destination with
    /// the last time it was used
    private(set) static var lastUsedTimes = [String: Date]() { didSet {
        saveTimes()
    } }
    
    // MARK: - Other static properties
    
    /// User defaults key for last update
    static let lastUpdateKey = "lastUpdate"
    
    /// Last update date
    static var lastUpdate: Date { get {
        return UserDefaults.standard.object(forKey: lastUpdateKey) as! Date
    } }
    
    // MARK: - Private properties
    
    /// Queue on which to run async operations
    private static let queue = DispatchQueue(label: "com.marcofiletti.bigarrow.destinationmaster", qos: .default)
    
    /// User defaults key for last used dates key (string, name)
    private static let luKeys = "lastUsedTimesKeyNames"
    
    /// User defaults key for last used dates values (date)
    private static let luDates = "lastUsedTimesValueDates"
    
    // MARK: - Protected static methods
    
    /// Loads destinations and last used dates from disk, creating them if needed
    static func load() {
    
        queue.async {
            
            if let tempDestinations = UserDefaults.standard.object(forKey: Constants.Defs.destinations) as? [[String: Any]] {
                destinations = tempDestinations.map({Destination(fromDict: $0)})
            }
                        
            loadTimes()
            
            cleanTimes()
        }
        
    }
    
    /// A tuple array of dates and destinations, reflecting destinations and lastUsedTimes,
    /// sorted by date. Destinations with no date should be on top.
    static func makeTuples(callback: @escaping ([(Date?, Destination)]) -> Void) {
        queue.async {
            callback(sortedTuples())
        }
    }
    
    /// Moves a destination from one row to another.
    /// If they were previously sorted by date, re-sort destinations before moving
    /// and disable the sort by date preference.
    /// Returns the names of the two destinations
    @discardableResult
    static func moveDestination(from: Int, to: Int) -> (String, String)? {
        guard from >= 0 && to >= 0 && from != to && from < destinations.count && to < destinations.count else {
            return nil
        }
        
        if Constants.SortBy.currentSetting() != .manual {
            // we were not sorting manually before, sort then reset preference
            destinations = sortedTuples().map() {$0.1}
            
            Constants.SortBy.manual.setDefault()
        }
        
        let nameOne = destinations[from].name
        let nameTwo = destinations[to].name
        
        let moved = destinations.remove(at: from)
        destinations.insert(moved, at: to)
        
        saveDestinations()
        
        return (nameOne, nameTwo)
    }
    
    /// Swap the position of two destinations using their names
    /// Returns the two indices that were swapped
    static func swapDestinations(_ one: String, _ two: String) -> (Int, Int)? {
        guard let i1 = destinations.firstIndex(where: {$0.name == one}) else { return nil }
        guard let i2 = destinations.firstIndex(where: {$0.name == two}) else { return nil }
        moveDestination(from: i1, to: i2)
        return (i1, i2)
    }
    
    /// Returns the tuple for the destination with the given name, returns nil if name
    /// not found
    static func tuple(forDestinationName name: String) -> (Date?, Destination)? {
        guard let i = destinations.firstIndex(where: {$0.name == name}) else {
            return nil
        }
        
        let dest = destinations[i]
        let date = lastUsedTimes[name]
        return (date, dest)
    }
    
    #if !WatchApp
    static func loadGroup() {
        
        if let groupDefaults = UserDefaults(suiteName: Constants.groupId),
           let addedTemp = groupDefaults.array(forKey: "addedDestinations") as? [[String: Any]],
            addedTemp.count > 0 {
        
            let addedDestinations = addedTemp.map({Destination(fromDict: $0)})
            let empty: [[String: Any]] = []
            groupDefaults.set(empty, forKey: "addedDestinations")
            
            // add
            addedDestinations.forEach() {
                self.addDestination(dest: $0, replacing: false, notify: false, imported: true)
            }
            
            // save because we set imported to true
            saveDestinations()

            // stop showing help, since the user if expert
            if HelpState.currentState != .sawMapsAgain {
                HelpState.currentState = .sawMapsAgain
            }
        }
        
    }
    #endif
    
    /// Returns true if location was replaced
    /// If replacing is set to false, adds an increasing number at the end instead of replacing.
    /// Set imported to true when we don't want to acknowledge the update (e.g. when the watch imports everything)
    @discardableResult
    static func addDestination(dest: Destination, replacing: Bool = true, notify: Bool = true, imported: Bool = false) -> Bool {
        
        var retVal = false
        
        if !replacing && destinationNameExists(dest.name) {
            var newDest = dest
            newDest.changeName(newDest.name.withAddedNumber)
            destinations.insert(newDest, at: 0)
        } else {
            if let di = destinations.firstIndex(where: {$0.name == dest.name}) {
                destinations.remove(at: di)
                retVal = true
            }
            destinations.insert(dest, at: 0)
        }
        
        // save
        if !imported {
            saveDestinations()
        }
        
        // update last update time
        UserDefaults.standard.set(Date(), forKey: lastUpdateKey)
        
        // send notification
        if notify {
            NotificationCenter.default.post(name: Constants.Notifications.updatedDestination, object: self)
        }
        return retVal
    }
    
    /// Quick check to see if a destination with the given name is already present
    static func destinationNameExists(_ name: String) -> Bool {
        for d in destinations {
            if d.name.caseInsensitiveCompare(name) == .orderedSame { return true }
        }
        return false
    }

    static func removeDestination(_ dest: Destination) {
        let i = destinations.firstIndex(of: dest)!
        destinations.remove(at: i)
        
        // update last update time
        UserDefaults.standard.set(Date(), forKey: lastUpdateKey)
        
        saveDestinations()
        
        NotificationCenter.default.post(name: Constants.Notifications.updatedDestination, object: self)
    }
    
    static func deleteDestination(name: String) {
        let dests = destinations.filter({$0.name == name})
        guard let dest = dests.first else {
            return
        }
        removeDestination(dest)
        #if WatchApp
        if #available(watchOSApplicationExtension 5.0, *) {
            NSUserActivity.deleteSavedUserActivities(withPersistentIdentifiers: [dest.persistentActivityIdentifier], completionHandler: {})
        }
        #else
        if #available(iOS 12.0, *) {
            NSUserActivity.deleteSavedUserActivities(withPersistentIdentifiers: [dest.persistentActivityIdentifier], completionHandler: {})
        }
        #endif
    }
    
    /// updates the used time for a destination and returns the result
    static func touchDestination(_ dest: Destination) -> (String, Date) {
        let date = Date()
        let name = dest.name
        lastUsedTimes[name] = date
        NotificationCenter.default.post(name: Constants.Notifications.timesUpdated, object: self, userInfo: [Constants.Notifications.timesUpdatedNamesKey: [dest.name]])
        return (name, date)
    }
    
    /// Renames a destination and saves new data.
    /// If the name already exists, appends "2" in front of it.
    ///
    static func renameDestination(_ dest: Destination, newName: String) {
        var assignedName: String
        if destinationNameExists(newName) {
            assignedName = newName.withAddedNumber
        } else {
            assignedName = newName
        }
        
        guard let i = destinations.firstIndex(of: dest) else {
            os_log("Could not find destination with name: %@", type: .error, dest.name)
            return
        }
        
        queue.sync {
            destinations[i].changeName(assignedName)
            
            if lastUsedTimes[dest.name] != nil {
                let val = lastUsedTimes.removeValue(forKey: dest.name)
                lastUsedTimes[assignedName] = val
            }
        }
        
        
        saveTimes()
        saveDestinations()
        
        let uInfo: [String: Any] = ["newName": assignedName, "oldName": dest.name]
        NotificationCenter.default.post(name: Constants.Notifications.renamedDestination, object: self, userInfo: uInfo)
    }
    
    static func replaceDestinations(newDestinations: [Destination]) {
        guard self.destinations != newDestinations else {
            return
        }
        
        queue.async {
            self.destinations = newDestinations
            saveDestinations()
            NotificationCenter.default.post(name: Constants.Notifications.updatedDestination, object: self)
        }
        
    }
    
    /// Merge used times with a new set of values.
    /// Only updates local times if they are newer
    static func updateTimes(newTimes: [String: Date]) {
        var times = self.lastUsedTimes
        var updatedNames = [String]()
        for s in newTimes.keys {
            if times[s] == nil {
                times[s] = newTimes[s]
                updatedNames.append(s)
            } else if times[s]!.compare(newTimes[s]!) == .orderedAscending {
                times[s] = newTimes[s]
                updatedNames.append(s)
            }
            
        }
        self.lastUsedTimes = times
        if updatedNames.count > 0 {
            let uInfo = [Constants.Notifications.timesUpdatedNamesKey: updatedNames]
            NotificationCenter.default.post(name: Constants.Notifications.timesUpdated, object: nil, userInfo: uInfo)
        }
    }
    
    // MARK: - Private methods
    
    /// Returns a sorted set of lastusedtimes and destinations,
    /// sorted by the given value.
    private static func sortedTuples() -> [(Date?, Destination)] {
        var tups = destinations.map({(lastUsedTimes[$0.name], $0)})
        
        switch Constants.SortBy.currentSetting() {
        case .lastUsed:
            tups.sort() {
                first, second in
                guard let f = first.0 else { return true }
                guard let s = second.0 else { return false }
                return f.compare(s) == .orderedDescending
            }
        case .distance:
            guard destinations.count > 0, destinations[0].distanceFromLastLocation() != nil else { break }
            tups.sort() {
                first, second in
                let f = first.1.distanceFromLastLocation()
                let s = second.1.distanceFromLastLocation()
                return f ?? 0 < s ?? 1
            }
        case .manual:
            break  // do nothing
        }
        
        return tups
    }
    
    /// Loads last used dates by zipping keys and dates
    private static func loadTimes() {
        
        guard let keys = UserDefaults.standard.object(forKey: luKeys) as? [String],
            let dates = UserDefaults.standard.object(forKey: luDates) as? [Date] else {
                return
        }
        
        guard dates.count == keys.count else {
            os_log("Error while loading last used times: counts do not match (%d vs %d)", type: .error, dates.count, keys.count)
            return
        }
        
        lastUsedTimes = [:]
        
        for i in 0..<keys.count {
            lastUsedTimes[keys[i]] = dates[i]
        }
        
    }
    
    /// Asynchronously saves last used times, by "unzipping"
    /// using two arrays
    private static func saveTimes() {
        queue.async {

            var keys = [String]()
            var dates = [Date]()
            
            self.lastUsedTimes.forEach() {
                keys.append($0.key)
                dates.append($0.value)
            }
            
            UserDefaults.standard.set(keys, forKey: luKeys)
            UserDefaults.standard.set(dates, forKey: luDates)
            
        }
    }
    
    /// Saves destinations to userdefaults
    private static func saveDestinations() {
        UserDefaults.standard.set(destinations.map({$0.toDict()}), forKey: Constants.Defs.destinations)
    }
    
    /// Removes all last used dates that are not listed in destinations
    private static func cleanTimes() {
        queue.async {
            var times = lastUsedTimes
            let keysToKeep = destinations.map({$0.name})
            let keysToRemove = times.keys.filter({!keysToKeep.contains($0)})
            keysToRemove.forEach() { times.removeValue(forKey: $0) }
            self.lastUsedTimes = times
        }
    }
    
}
