//
//  formulas.swift
//  Big Arrow
//
//  Created by Marco Filetti on 11/12/2017.
//  Copyright © 2017 Marco Filetti. All rights reserved.
//

import Foundation

/// Returns true if the two values are within the given proportion (i.e. proportional range) of each other.
func withinProportion(_ n1: Double, _ n2: Double, p: Double) -> Bool {
    let diff = abs(n1-n2)
    let meanProp = ((n1+n2)/2)*p
    return diff < meanProp
}

/// Returns a string from a course (angle towards north)
/// in the format N, NW, etc
func angleToCompass(_ course: Double) -> String {
    
    // every time we step 22.5 * odd number we go one step clockwise
    
    if course >= 0 && course <= 22.5 {
        return "N".localized
    } else if course > 22.5 && course <= 67.5 {
        return "NE".localized
    } else if course > 67.5 && course <= 112.5 {
        return "E".localized
    } else if course > 112.5 && course <= 157.5 {
        return "SE".localized
    } else if course > 157.5 && course <= 202.5 {
        return "S".localized
    } else if course > 202.5 && course <= 247.5 {
        return "SW".localized
    } else if course > 247.5 && course <= 292.5 {
        return "W".localized
    }  else if course > 292.5 && course <= 337.5 {
        return "NW".localized
    } else if course > 337.5 && course <= 360 {
        return "N".localized
    } else {
        return "?"  // should never happen
    }
}

func rad2deg(_ x :Double) -> Double {
    return x * 180 / Double.pi
}

func deg2rad(_ x :Double) -> Double {
    return x * Double.pi / 180
}
