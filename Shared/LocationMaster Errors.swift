//
//  LocationMaster Errors.swift
//  Bladey
//
//  Created by Marco Filetti on 25/05/2017.
//  Copyright © 2017 Marco Filetti. All rights reserved.
//

import Foundation

extension LocationMaster {
    
    /// Why we failed to start sessions
    enum StartFailure: Error {
        /// Failed to get location authorization
        case locationAuthorization
        /// We already started
        case alreadyStarted
        
        /// Returns a message for the user explaining why we failed.
        /// Nil if there's no need to warn the user.
        var failureDescription: String? { get {
            switch self {
            case .locationAuthorization:
                return "please_enable_location_services".localized
            case .alreadyStarted:
                return nil
            }
        } }
    }
    
}
