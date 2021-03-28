//
//  CLLocation Extensions.swift
//  Big Arrow
//
//  Created by Marco Filetti on 16/06/2017.
//  Copyright © 2017 Marco Filetti. All rights reserved.
//

import Foundation
import CoreLocation

extension CLLocation {
    /// Returns true if the two locations have similar horizontalAccuracy.
    /// Also see Indication.similarAccuracy
    func similarAccuracy(_ toOtherIndication: Indication) -> Bool {
        let fuzz = FuzzyAccuracy(fromAccuracy: self.horizontalAccuracy)
        
        guard fuzz != .low && toOtherIndication.fuzzyAccuracy != .low else {
            return false
        }
        
        let diff = abs(toOtherIndication.accuracy - self.horizontalAccuracy)
        return diff <= Constants.maxAccuracyDifference
    }
}

extension CLLocationCoordinate2D {
    
    /// Returns the angle between this location and another, in degrees, increasing clockwise,
    /// between 0 and 360.
    func angle(toOtherLocation loc2: CLLocationCoordinate2D) -> Double {

        // get angle in mathematical terms
        // that is, counterclockwise raising
        // from east in range -pi to +pi
        let dy = loc2.latitude - self.latitude
        let dx = cos(Double.pi/180*self.latitude)*(loc2.longitude-self.longitude)
        var angle = atan2(dy, dx)
    
        // convert to degrees, clockwise increasing from north
        angle = angle + Double.pi  // start from 0
        angle = angle + Double.pi/2  // set origin to north
        
        var deg = angle.toDeg()
        
        // invert direction
        deg = 360 - deg
        
        // return only values between 0 and 360
        deg = deg.truncatingRemainder(dividingBy: 360)
        
        if deg < 0 {
            deg += 360
        }
        
        return deg
    }
    
}
