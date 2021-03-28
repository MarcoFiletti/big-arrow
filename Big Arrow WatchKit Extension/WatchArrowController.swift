//
//  InterfaceController.swift
//  Big Arrow WatchKit Extension
//
//  Created by Marco Filetti on 15/06/2017.
//  Copyright © 2017 Marco Filetti. All rights reserved.
//

import WatchKit
import Foundation
import SpriteKit
import os.log

import WatchConnectivity

class WatchArrowController: WKInterfaceController, LocationMasterDelegate, ProgressUpdater {

    var visible = false
    
    @IBOutlet var altitudeGroup: WKInterfaceGroup!
    
    @IBOutlet var skInterface: WKInterfaceSKScene!
    
    @IBOutlet var distanceLabel: WKInterfaceLabel!

    /// Current destination. If nil, we are in compass mode.
    var destination: Destination?
    
    weak var scene: ArrowScene!
    
    @IBOutlet var accuracyLabel: WKInterfaceLabel!
    @IBOutlet var accuracyDot: WKInterfaceLabel!
    
    @IBOutlet var speedLabel: WKInterfaceLabel!
    @IBOutlet var altitudeLabel: WKInterfaceLabel!
    @IBOutlet var etaLabel: WKInterfaceLabel!
    
    @IBOutlet var compassLabel: WKInterfaceLabel!
    
    // progress tracking
    var initialDistance: Double = -1
    
    var startTime = Date()
    
    /// Gets set to true if a notification stops us.
    var stoppedFromOutside = false
    
    /// Last direct line angle from destination received
    /// (not via Indication)
    var lastToAngle: Double?
    
    var lastIndication: Indication? { didSet {
        updateIndication()
    } }
    
    var useMagnetometer: Bool { LocationMaster.shared.useMagnetometer }
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        startTime = Date()
        
        // if context is nil, we are in compass mode
        if context == nil {
            LocationMaster.shared.destination = nil
            destination = nil
            etaLabel.setHidden(true)
        } else {
            destination = context as? Destination
            LocationMaster.shared.destination = destination
            etaLabel.setHidden(false)
        }
        
        LocationMaster.shared.masterDelegate = self
        
        if #available(watchOSApplicationExtension 4.0, *) {
            WKExtension.shared().isFrontmostTimeoutExtended = true
        }
        
        if !LocationMaster.shared.isRunning {
            do {
                try LocationMaster.shared.start()
                
                if Options.WaterLock.saved == .automatic || Options.WaterLock.saved == .once {
                    DispatchQueue.main.async {
                        WKExtension.shared().enableWaterLock()
                    }
                }
                if Options.WaterLock.saved == .once {
                    Options.WaterLock.manual.save()
                }
            } catch {
                os_log("Error while starting LocationMaster: %@", type: .error, error.localizedDescription)
            }
        }
        
        if destination == nil {
            self.setTitle("compass".localized)
            DispatchQueue.main.async {
                self.distanceLabel.setHidden(true)
            }
        } else {
            self.setTitle(destination!.name)
        }
        
        if let scene = ArrowScene(fileNamed: "ArrowScene") {
            
            // Set the scale mode to scale to fit the window
            scene.scaleMode = .aspectFill
            
            // Present the scene
            self.skInterface.presentScene(scene)
            
            // Use a value that will maintain a consistent frame rate
            self.skInterface.preferredFramesPerSecond = 30
            
            self.scene = scene
            
            self.scene.compassMode = self.destination == nil
            self.scene.makeWaitDots()
            self.scene.showWaitLabel()
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(nearbyNotificationReceived(_:)), name: Constants.Notifications.nearbyNotificationTriggered, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(etaNotificationReceived(_:)), name: Constants.Notifications.etaNotificationTriggered, object: nil)
        
        makeUserActivity()
    }
    
    override func willActivate() {
        self.skInterface.isPaused = false
        self.visible = true
        scene.isVisible = true
        scene.animQueue.isSuspended = false
        if !stoppedFromOutside {
            updateIndication()
            LocationMaster.shared.increaseAccuracy()
        } else {
            NotificationHelper.clearAllNotifications()
        }
    }
    
    override func didDeactivate() {
        self.visible = false
        scene.isVisible = false
        scene.animQueue.isSuspended = true
        LocationMaster.shared.relaxAccuracy()
    }
    
    private func makeUserActivity() {
        guard let currentDestination = self.destination else {
            return
        }
        
        DispatchQueue.main.async {
            self.invalidateUserActivity()
            if #available(watchOSApplicationExtension 5.0, *) {
                let act = currentDestination.makeUserActivity()
                act.becomeCurrent()
                (WKExtension.shared().delegate as? ExtensionDelegate)?.activity = act
            } else {
                let uinfo = [Constants.UserActivity.destinationNameKey: currentDestination.name]
                self.updateUserActivity(Constants.userActivityType, userInfo: uinfo, webpageURL: nil)
            }
        }
    }
    
    /// Update all views acknowledging the last received indication
    private func updateIndication() {
        guard visible, let indication = lastIndication, !stoppedFromOutside else {
            return
        }
        
        if !useMagnetometer, let weightedAngle = indication.angleMean, indication.fuzzyAccuracy != .low {
            scene.setArrowAngle(locationAngle: CGFloat(weightedAngle))
            scene.showArrowIfNotShown()
        }
        
        // progress stuff
        updateProgress(indication: indication)

        let distString = Formatters.format(distance: indication.distance)
        let etaString: String?
        if let eta = indication.eta {
            etaString = Formatters.format(abbreviatedTime: eta)
        } else {
            etaString = nil
        }
        self.scene.setDistance(distString)
        self.scene.setAccuracy(indication.fuzzyAccuracy)
        self.scene.setETA(etaString)
        
        var compassNumber: Double?
        
        // force relative compass when destination is nil (compass mode)
        if destination != nil && UserDefaults.standard.object(forKey: Constants.Defs.compassIsRelative) as! Bool {
            // relative compass
            compassNumber = indication.toAngle
        } else if !useMagnetometer {
            // absolute compass
            if let course = indication.course {
                compassNumber = course
            } else {
                compassNumber = nil
            }
        }
        
        if let cn = compassNumber {
            updateCompass(cn)
        }
                
        DispatchQueue.main.async {
            self.distanceLabel.setText(distString)
            self.accuracyLabel.setText(Formatters.format(accuracy: indication.accuracy))
            self.speedLabel.setText(Formatters.format(speed: indication.speed))
            self.accuracyDot.setTextColor(indication.fuzzyAccuracy.color)
            self.altitudeLabel.setText(Formatters.format(distance: indication.location.altitude))
            if let etaString = etaString {
                self.etaLabel.setText(etaString)
            }
        }
    }
    
    private func updateCompass(_ angle: Double) {
        let compassString: String?
        let cs = angleToCompass(angle)
        compassString = "\(Int(round(angle))) (\(cs))"
        DispatchQueue.main.async {
            self.compassLabel.setText(compassString)
        }
    }
    
    // MARK: - Notification callbacks
    
    @objc func etaNotificationReceived(_ notification: Notification) {
        scene?.enqueueNotification(type: .eta)
    }
    
    @objc func nearbyNotificationReceived(_ notification: Notification) {
        scene?.enqueueNotification(type: .nearby)
    }
    
    // MARK: - Delegation
    
    @IBAction func waterLock() {
        DispatchQueue.main.async {
            WKExtension.shared().enableWaterLock()
        }
    }
    
    // MARK: - Delegation
    
    func locationMaster(provideIndication indication: Indication) {
        lastIndication = indication
    }
    
    func locationMaster(didReceiveLocation: CLLocation) {
        if let destination = self.destination {
            self.lastToAngle = didReceiveLocation.coordinate.angle(toOtherLocation: destination.coordinate)
        }
    }
    
    func locationMasterDidStop() {
        stoppedFromOutside = true
        
        scene.terminated = true
        scene.hideArrowAndFriends()
        scene.hideWaitDots()
        scene.hideWaitLabel()
        
        let elapsed = Date().timeIntervalSince(self.startTime)
        DispatchQueue.main.async {
            self.distanceLabel.setText(Formatters.format(briefTime: elapsed))
            self.compassLabel.setText("-")
        }
        scene.enqueueTickFadeIn()
    }

    func locationMasterSignalLost() {
        scene.hideArrowAndDisplayWaitMessage(messageText: "signal_lost".localized)
    }
    
    func locationMasterStandingStill() {
        scene.hideArrowAndDisplayWaitMessage(messageText: "keep moving".localized)
    }
    
    func locationMaster(headingUpdated heading: Double) {
        guard !stoppedFromOutside, UserDefaults.standard.bool(forKey: Constants.Defs.useMagnetometer) else {
            return
        }
        
        let angle: Double
        if let toAngle = self.lastToAngle {
            angle = toAngle - heading
        } else {
            angle = heading
        }
        
        scene.setArrowAngle(locationAngle: CGFloat(angle))
        scene.showArrowIfNotShown()
        
        if !(UserDefaults.standard.object(forKey: Constants.Defs.compassIsRelative) as! Bool) {
            // absolute compass
            updateCompass(heading)
        }
    }

}
