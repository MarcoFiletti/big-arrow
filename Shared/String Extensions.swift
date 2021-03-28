//
//  String Extensions.swift
//  Big Arrow
//
//  Created by Marco Filetti on 23/06/2017.
//  Copyright © 2017 Marco Filetti. All rights reserved.
//

import Foundation

extension String {
    
    var localized: String {
        return NSLocalizedString(self, tableName: nil, bundle: Bundle.main, value: "", comment: "")
    }

    // Adds " 2" at the end of this string, or a larger number
    // if 2 is already present
    var withAddedNumber: String { get {
        
        var num = 2
        
        if let lastS = components(separatedBy: " ").last {
            if let lastNum = Int(lastS) {
                num = lastNum + 1
            }
        }

        return self + " \(num)"
        
        } }
    
}
