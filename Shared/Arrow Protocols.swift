//
//  Arrow Protocols.swift
//  Big Arrow
//
//  Created by Marco Filetti on 26/11/2017.
//  Copyright © 2017 Marco Filetti. All rights reserved.
//

import Foundation
import SpriteKit

protocol ProgressUpdater: class {
    /// Reference to sprite kit scene
    var scene: ArrowScene! { get }
    
    /// First distance found from destination. Best to initialise this to a negative value.
    var initialDistance: Double { get set }
}

extension ProgressUpdater {
    
    /// Returns progress towards reaching the given destination (-1 if invalid)
    @discardableResult
    func updateProgress(indication: Indication) -> CGFloat {
        if UserDefaults.standard.object(forKey: Constants.Defs.showProgressBar) as! Bool {
            let relativeDistance = indication.relativeDistance
            if indication.fuzzyAccuracy == .good {
                if self.initialDistance < relativeDistance {
                    self.initialDistance = relativeDistance
                }
            }
            if initialDistance >= 0, relativeDistance >= 0 {
                let progress = CGFloat(1 - relativeDistance / initialDistance)
                scene?.setProgress(to: progress)
                return progress
            } else {
                return -1
            }
        } else {
            return -1
        }
    }
    
}
