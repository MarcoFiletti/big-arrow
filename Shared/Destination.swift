//
//  Destination.swift
//  Big Arrow
//
//  Created by Marco Filetti on 17/06/2017.
//  Copyright © 2017 Marco Filetti. All rights reserved.
//

import Foundation
import CoreLocation

struct Destination: Equatable, Hashable {
        
    /// Since the name is important, only change it using
    /// changeName and make sure we update our representations
    private(set) var name: String
    let latitude: Double
    let longitude: Double
    
    var coordinate: CLLocationCoordinate2D { get {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    } }
    
    init(name: String, coordinate: CLLocationCoordinate2D) {
        self.name = name
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }
    
    init(name: String, latitude: Double, longitude: Double) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
    }
    
    init(fromDict dict: [String: Any]) {
        self.name = dict["name"] as! String
        self.latitude = dict["latitude"] as! Double
        self.longitude = dict["longitude"] as! Double
    }
        
    mutating func changeName(_ newName: String) {
        self.name = newName
    }
    
    func toDict() -> [String: Any] {
        var retVal = [String: Any]()
        retVal["name"] = name
        retVal["latitude"] = latitude
        retVal["longitude"] = longitude
        return retVal
    }
    
    public static func ==(lhs: Destination, rhs: Destination) -> Bool {
        return lhs.name.caseInsensitiveCompare(rhs.name) == .orderedSame &&
               lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
    
}
