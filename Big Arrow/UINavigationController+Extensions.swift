//
//  UINavigationController+Extensions.swift
//  Big Arrow
//
//  Created by Marco Filetti on 01/11/2017.
//  Copyright © 2017 Marco Filetti. All rights reserved.
//

import UIKit

extension UINavigationController {
    override open var supportedInterfaceOrientations : UIInterfaceOrientationMask     {
        return .all
    }
}

extension UITabBarController {
    override open var supportedInterfaceOrientations : UIInterfaceOrientationMask     {
        return .all
    }
}

extension UISplitViewController {
    override open var supportedInterfaceOrientations : UIInterfaceOrientationMask     {
        return .all
    }
}
