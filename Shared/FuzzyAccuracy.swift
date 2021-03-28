//
//  FuzzyAccuracy.swift
//  Big Arrow
//
//  Created by Marco Filetti on 24/10/2017.
//  Copyright © 2017 Marco Filetti. All rights reserved.
//

import Foundation
#if WatchApp
    import WatchKit
#else
    import UIKit
#endif

/// Simplifies GPS accuracy in three categories, each with an associated color
enum FuzzyAccuracy {
    case low
    case medium
    case good
    
    /// Simplies representation of accuracy.
    /// If accuracy is negative, returns nil, suggesting that this
    /// measurement is invalid.
    init?(fromAccuracy: Double) {
        guard fromAccuracy >= 0 else {
            return nil
        }
        
        if fromAccuracy >= 66 {
            self = .low
        } else if fromAccuracy < 0 {
            self = .low
        } else if fromAccuracy <= 16 {
            self = .good
        } else {
            self = .medium
        }
    }
    
    var color: UIColor { get {
        switch self {
        case .low:
            return #colorLiteral(red: 0.9254902005, green: 0.2352941185, blue: 0.1019607857, alpha: 1)
        case .medium:
            return #colorLiteral(red: 0.9764705896, green: 0.850980401, blue: 0.5490196347, alpha: 1)
        case .good:
            return #colorLiteral(red: 0.4666666687, green: 0.7647058964, blue: 0.2666666806, alpha: 1)
        }
    } }
}
