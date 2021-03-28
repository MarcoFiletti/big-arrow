//
//  HelpSequence.swift
//  Big Arrow
//
//  Created by Marco Filetti on 22/07/2017.
//  Copyright © 2017 Marco Filetti. All rights reserved.
//

import Foundation
import UIKit

/// HelpState can be stored in UserDefaults and tells us which help
/// the user should see next. If 0, they never saw any help messages.
/// As they progress (and the app progresses) more help messages are shown.
enum HelpState: Int {
    
    /// Convenience accessor for current state.
    /// Changing it updates user defaults.
    static var currentState: HelpState = {
        
        let n = UserDefaults.standard.object(forKey: "helpState") as! Int
        return HelpState(rawValue: n)!
    
    }() { didSet {
        
        UserDefaults.standard.set(currentState.rawValue, forKey: "helpState")
        
        }}
    
    /// Next state (does nothing, if there's no next state).
    /// **Asking for the next state saves to userdefaults and sets the currentstate**.
    static func nextState() {
        if let next = HelpState(rawValue: currentState.rawValue + 1) {
            currentState = next
        }
    }
    
    /// Never saw anything, should show how to add destinations
    case nothing
    
    /// They added a destination, should show that they should tap it
    case adddedDestination
    
    /// They tapped a destination, should show help about maps
    case tappedDestination
    
    /// They already saw maps message, lets show it again
    case sawMaps
    
    /// They saw maps twice, nothing more now
    case sawMapsAgain
    
    var associatedHelp: UIImage? {
        switch self {
        case .nothing:
            return UIImage(named: "image_help_start".localized)
        case .adddedDestination:
            return UIImage(named: "image_help_direct".localized)
        case .tappedDestination:
            return UIImage(named: "image_help_maps".localized)
        case .sawMaps:
            return UIImage(named: "image_help_maps".localized)
        case .sawMapsAgain:
            return nil
        }
    }
    
    var contentMode: UIView.ContentMode {
        switch self {
        case .nothing, .adddedDestination:
            return .top
        case .tappedDestination, .sawMaps, .sawMapsAgain:
            return .center
        }
    }
    
}
