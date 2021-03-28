//
//  DeviceOrientation.swift
//  Big Arrow
//
//  Created by Marco Filetti on 01/11/2017.
//  Copyright © 2017 Marco Filetti. All rights reserved.
//

import UIKit

/// Use to bridge UIDeviceOrientation with CLDeviceOrientation
enum DeviceOrientation {
    case portrait
    #if !WatchApp
    case portraitUpsideDown
    case landscapeLeft
    case landscapeRight
    
    init(orientation: UIDeviceOrientation) {
        switch orientation {
        case .portrait:
            self = .portrait
        case .landscapeLeft:
            self = .landscapeLeft
        case .landscapeRight:
            self = .landscapeRight
        case .portraitUpsideDown:
            self = .portraitUpsideDown
        default:
            self = .portrait
        }
    }
    #endif
}
