//
//  MyLocationController.swift
//  Big Arrow
//
//  Created by Marco Filetti on 22/06/2017.
//  Copyright © 2017 Marco Filetti. All rights reserved.
//

import WatchKit
import Foundation
import SpriteKit
import CoreLocation

class MyLocationController: WKInterfaceController, LocationMasterDelegate {
    
    @IBOutlet var skInterface: WKInterfaceSKScene!
    
    weak var scene: ArrowScene!
    
    @IBOutlet var topLabel: WKInterfaceLabel!
    @IBOutlet var bottomLabel: WKInterfaceLabel!
    
    var askedToReverse = false
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        if let scene = ArrowScene(fileNamed: "ArrowScene") {
            
            // Set the scale mode to scale to fit the window
            scene.scaleMode = .aspectFill
            
            // Present the scene
            self.skInterface.presentScene(scene)
            
            // Use a value that will maintain a consistent frame rate
            self.skInterface.preferredFramesPerSecond = 30
            
            self.scene = scene
            self.scene.makeWaitDots()
        }
 
        LocationMaster.shared.masterDelegate = self
        do { try LocationMaster.shared.fetchLocation() }
        catch {
            self.scene.showCross()
        }
        
    }
    
    func locationMaster(didReceiveLocation: CLLocation) {
        scene.moveWaitDotsTogether()
        let str = String(format: "%.2f , %.2f", didReceiveLocation.coordinate.latitude, didReceiveLocation.coordinate.longitude)
        DispatchQueue.main.async {
            self.topLabel.setText(str)
        }
        guard !askedToReverse else { return }
        askedToReverse = true
        LocationMaster.shared.getInfo(forLocation: didReceiveLocation) {
            result in
            let destination: Destination
            if let result = result {
            DispatchQueue.main.async {
                    self.bottomLabel.setText(result)
                }
                destination = Destination(name: result, coordinate: didReceiveLocation.coordinate)
            } else {
                destination = Destination(name: str, coordinate: didReceiveLocation.coordinate)
            }
            (WKExtension.shared().delegate as? ExtensionDelegate)?.sendNewDestination(destination)
            DestinationMaster.addDestination(dest: destination, replacing: false)
            
            self.scene.hideWaitDots()
            self.scene.enqueueTickFadeIn()
        }
    }
    
}
