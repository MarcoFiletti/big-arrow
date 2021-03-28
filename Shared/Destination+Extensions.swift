//
//  Destination+Extensions.swift
//  Big Arrow
//
//  Created by Marco Filetti on 07/06/2018.
//  Copyright © 2018 Marco Filetti. All rights reserved.
//

import Foundation
import CoreLocation

extension Destination {
    func distanceFromLastLocation() -> Double? {
        // get convenience location should get both locations and return the most recent
        guard let loc = LocationMaster.shared.getConvenienceLocation() else {
            return nil
        }
        let loc2 = CLLocation(latitude: self.latitude, longitude: self.longitude)
        return loc.distance(from: loc2)
    }
}

@available(iOS 12.0, *)
@available(watchOSApplicationExtension 5.0, *)
extension Destination {
    func makeUserActivity() -> NSUserActivity {
        let uinfo = [Constants.UserActivity.destinationNameKey: self.name]
        let act = NSUserActivity(activityType: Constants.userActivityType)
        act.userInfo = uinfo
        act.persistentIdentifier = self.persistentActivityIdentifier
        act.title = "navigate_to".localized + " \(self.name)"
        act.keywords = Set<String>()
        act.keywords.insert(self.name)
        act.isEligibleForSearch = true
        act.isEligibleForPublicIndexing = false
        act.isEligibleForPrediction = true
        return act
    }
    
    var persistentActivityIdentifier: String { get {
        return Constants.userActivityType + "." + self.name
    } }
}
