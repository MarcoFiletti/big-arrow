//
//  LocationBuffer.swift
//  Big Arrow
//
//  Created by Marco Filetti on 18/03/2018.
//  Copyright © 2018 Marco Filetti. All rights reserved.
//

import Foundation
import CoreLocation

/// Stores a number of locations for a given amount of time to perform operations on them (e.g. to check if we are standing still)
class LocationBuffer {
    
    // MARK: - Properties
    
    var locations = [CLLocation]()
    let maxDuration: TimeInterval
    
    init(maxLocationDuration: TimeInterval) {
        self.maxDuration = maxLocationDuration
    }
    
    func reset() {
        locations.removeAll()
    }
    
    func addLocation(newLocation: CLLocation) {
        locations.append(newLocation)
        filterLocations()
    }
    
    private func filterLocations() {
        locations = locations.filter({$0.timestamp.addingTimeInterval(maxDuration) > Date()})
    }
    
    func standing() -> Bool {
        filterLocations()
        
        guard locations.count >= 2, let last = locations.last, let first = locations.first else {
            return false
        }

        // make sure the first location was at least (max time - 5 seconds) away from the lastest
        guard last.timestamp.timeIntervalSince(first.timestamp) > maxDuration - 5 else {
            return false
        }
        
        for i in 0..<locations.count-1 {
            for j in (1..<locations.count).reversed() {
                if locations[i].distance(from: locations[j]) > Constants.standingStillDistance {
                    return false
                }
            }
        }
        
        return true
    }
}
