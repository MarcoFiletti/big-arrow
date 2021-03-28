//
//  FuzzyDistance.swift
//  Big Arrow
//
//  Created by Marco Filetti on 22/11/2017.
//  Copyright © 2017 Marco Filetti. All rights reserved.
//

import Foundation

/// Fuzzily reprents a distance, so we can think of it in terms
/// of how great it is without thinking about locale.
/// It correponds to whether we think about metres or km, or 10s of kms, and so on
/// (same for miles).
enum FuzzyDistance {
    
    /// A short distance, e.g. 12 metres or 12 yards
    case unimetric
    /// A medium distance e.g. 1 or 2 km
    case kilometric
    /// A medium distance above 5 km or miles
    case fivekilometric
    /// A long distance (between 10 and 100 km or miles)
    case tenkilometric
    /// A verylong distance, above 100km or miles
    case hundredkilometric
    
    /// Creates itself from a distance in metres
    init(fromMetres distance: Double) {
        let k: Double
        let w: Double  // the threshold between yd and mile or m and km
        if LocationMaster.usesMetric {
            k = 1000
            w = 1
        } else {
            k = 1609.34709
            w = 0.5
        }
        if distance >= k * 10 && distance < k * 100 {
            self = .tenkilometric
        } else if distance > k * w && distance < k * 10 {
            if distance > k * 5 {
                self = .fivekilometric
            } else {
                self = .kilometric
            }
        } else if distance >= k * 100 {
            self = .hundredkilometric
        } else {
            self = .unimetric
        }
    }
    
}
