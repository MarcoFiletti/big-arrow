//
//  Indication.swift
//  Big Arrow
//
//  Created by Marco Filetti on 04/10/2017.
//  Copyright © 2017 Marco Filetti. All rights reserved.
//

import Foundation
import CoreLocation

/// This class represents the chunk of information provided by the master to live clients.
class Indication: NSObject {
    
    /// CLLocation representing the "endpoint" of the current movement vector
    let location: CLLocation
    
    /// Distance to location, in metres. -1 if not applicable.
    let distance: Double
    
    /// Current speed, in metres per second
    let speed: Double
    
    /// Direct line angle to destination (without taking current course into consideration)
    let toAngle: Double
    
    /// Current angle towards north
    let course: Double?
    
    /// Angle to destination, in degrees, starting from north, increasing clockwise
    /// is nil if no reliable indication could be provided
    let angle: Double?
    
    /// Weighted average of this location's angle (if any) and the previous
    let angleMean: Double?
    
    /// ETA to location (if applicable), in seconds. Can be set later.
    var eta: TimeInterval? = nil
    
    /// Accuracy of estimate in metres
    let accuracy: Double
    
    /// Simplified accuracy
    let fuzzyAccuracy: FuzzyAccuracy
    
    // MARK: - Computed properties
    
    /// Returns true if we are moving too slowly for a decent estimate
    var tooSlow: Bool { return speed < 0.5 }
    
    /// Return the distance including notification threshold (if appropriate)
    /// and accuracy. Can be less than 0 if radii intersect.
    var minimumDistance: Double { get {
        // radius of destination
        let destRadius: Double
        if UserDefaults.standard.object(forKey: Constants.Defs.nearNotificationsOn) as! Bool {
            destRadius = UserDefaults.standard.object(forKey: Constants.Defs.nearNotificationMeters) as! Double
        } else {
            // no notifications, radius is 0 (closest)
            destRadius = 0
        }
        
        // take lastIndication.accuracy into consideration
        return self.distance - self.accuracy - destRadius
    } }
    
    /// Distance including notification threshold.
    /// Does not return negative values.
    var relativeDistance: Double { get {
        // radius of destination
        let destRadius: Double
        if UserDefaults.standard.object(forKey: Constants.Defs.nearNotificationsOn) as! Bool {
            destRadius = UserDefaults.standard.object(forKey: Constants.Defs.nearNotificationMeters) as! Double
        } else {
            // no notifications, radius is 0 (closest)
            destRadius = 0
        }
        let relativeDistance = self.distance - destRadius
        return relativeDistance >= 0 ? relativeDistance : 0
    }}
    
    // MARK: - Init
    
    /// Creates an indication with a specified distance and a desired angle (the angle that directs us to the destination)
    init?(currentLocation location: CLLocation, referenceLocation: CLLocation, previousIndication: Indication?, desiredAngle: Double, distance: Double, previousBuffer: RunningBuffer) {
        
        guard let fuzzyAccuracy = FuzzyAccuracy(fromAccuracy: location.horizontalAccuracy) else {
            return nil
        }
        self.fuzzyAccuracy = fuzzyAccuracy
        
        self.distance = distance
        self.toAngle = desiredAngle
        
        self.location = location
        
        if location.speed > 0 {
            self.speed = location.speed
        } else if let previousIndication = previousIndication,
            location.similarAccuracy(previousIndication) {
            let distDiff = location.distance(from: previousIndication.location)
            let timeDiff = location.timestamp.timeIntervalSince(previousIndication.location.timestamp)
            self.speed = distDiff / timeDiff
        } else {
            // just store negative number
            self.speed = location.speed
        }
        
        var buffer = previousBuffer
        
        if location.course > 0 {
            self.course = location.course
            self.angle = self.toAngle - location.course
            buffer.addSample(self.toAngle - location.course)
        } else if self.speed >= Constants.minSpeed,
                  let previousIndication = previousIndication,
                  location.similarAccuracy(previousIndication) {
            let currentAngle = previousIndication.location.coordinate.angle(toOtherLocation: location.coordinate)
            self.course = currentAngle
            self.angle = self.toAngle - currentAngle
            buffer.addSample(self.toAngle - currentAngle)
        } else {
            self.angle = nil
            self.course = nil
        }
        
        self.angleMean = buffer.angleMean()
        self.accuracy = location.horizontalAccuracy
        
        super.init()
    }
    
    /// Creates an indication wrt a reference.
    /// Can fail if location is invalid.
    convenience init?(currentLocation location: CLLocation, referenceLocation: CLLocation, previousIndication: Indication?, previousBuffer: RunningBuffer) {
        let desiredAngle = location.coordinate.angle(toOtherLocation: referenceLocation.coordinate)
        let distance = location.distance(from: referenceLocation)
        
        self.init(currentLocation: location, referenceLocation: referenceLocation, previousIndication: previousIndication, desiredAngle: desiredAngle, distance: distance, previousBuffer: previousBuffer)
    }
    
    /// Creates an indication wrt north (for compass).
    /// Can fail is location is invalid.
    convenience init?(towardsNorthFromLocation location: CLLocation, previousIndication: Indication?, previousBuffer: RunningBuffer) {
        let desiredAngle: Double = 0
        let distance: Double = -1
        
        self.init(currentLocation: location, referenceLocation: location, previousIndication: previousIndication, desiredAngle: desiredAngle, distance: distance, previousBuffer: previousBuffer)
    }
    
    // MARK: - Helpers
    
    /// Returns true if the two indications have similar accuracies,
    /// e.g. within the limits defined by Constants.maxAccuracyDifference.
    /// Always returns false if either indication has a .low fuzzyAccuracy.
    func similarAccuracy(_ toOtherIndication: Indication) -> Bool {
        guard self.fuzzyAccuracy != .low && toOtherIndication.fuzzyAccuracy != .low else {
            return false
        }
        
        let diff = abs(toOtherIndication.accuracy - self.accuracy)
        return diff <= Constants.maxAccuracyDifference
    }
    
}

