//
//  Double Extensions.swift
//  Big Arrow
//
//  Created by Marco Filetti on 16/06/2017.
//  Copyright © 2017 Marco Filetti. All rights reserved.
//

import Foundation

extension FloatingPoint {
    
    /// Converts self (in degrees) to radians
    func toRad() -> Self {
        return self * Self.pi / 180
    }
    
    /// Converts self (in radians) to degrees
    func toDeg() -> Self {
        return self * 180 / Self.pi
    }
    
}
