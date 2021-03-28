//
//  DetailViewController.swift
//  Big Arrow
//
//  Created by Marco Filetti on 15/06/2017.
//  Copyright © 2017 Marco Filetti. All rights reserved.
//

import UIKit
import SpriteKit
import os.log
import CoreLocation

class ArrowController: UIViewController, LocationMasterDelegate, ProgressUpdater {
    
    @IBOutlet weak var skView: SKView!
    weak var scene: ArrowScene!
    
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var distanceTitleLabel: UILabel!
    
    @IBOutlet weak var destinationLabel: UILabel!
    
    @IBOutlet weak var speedLabel: UILabel!
    
    @IBOutlet weak var accuracyLabel: UILabel!
    @IBOutlet weak var accuracyDot: UILabel!
    @IBOutlet weak var altitudeLabel: UILabel?
    @IBOutlet weak var etaLabel: UILabel!
    
    @IBOutlet weak var compassHeader: UILabel!
    @IBOutlet weak var compassLabel: UILabel!
    @IBOutlet weak var compassLabel2: UILabel!
    
    @IBOutlet weak var stopButton: UIButton!
    
    var manuallyStopped = true
    var stoppedFromOutside = false
    var useMagnetometer: Bool { LocationMaster.shared.useMagnetometer }
    var startTime = Date()
    
    var activity: NSUserActivity?
    
    // progress tracking
    var initialDistance: Double = -1
    
    /// Last direct line angle from destination received
    /// (not via Indication)
    var lastToAngle: Double?
    
    var destination: Destination? {
        didSet {
            LocationMaster.shared.destination = destination
            manuallyStopped = false
        }
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .all
    }
    
    // MARK: - Setup

    func configureView() {
        
        DispatchQueue.main.async {
            self.destinationLabel.text = self.destination?.name ?? "        "
        }
        
        startTime = Date()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if (UserDefaults.standard.object(forKey: Constants.Defs.keepScreenOn) as! Bool) {
            UIApplication.shared.isIdleTimerDisabled = true
        }

        LocationMaster.shared.masterDelegate = self
        
        updateButton()
        
        if useMagnetometer {
            LocationMaster.orientation = DeviceOrientation(orientation: UIDevice.current.orientation)
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(orientationChanged(_:)), name: UIDevice.orientationDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(nearbyNotificationReceived(_:)), name: Constants.Notifications.nearbyNotificationTriggered, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(etaNotificationReceived(_:)), name: Constants.Notifications.etaNotificationTriggered, object: nil)

        
        if destination != nil && !manuallyStopped {
            do {
                try LocationMaster.shared.start()
                if (UserDefaults.standard.object(forKey: Constants.Defs.keepScreenOn) as! Bool) {
                    UIApplication.shared.isIdleTimerDisabled = true
                }
            } catch {
                os_log("Error while starting location master: %@", type: .error)
            }
        }
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        UIApplication.shared.isIdleTimerDisabled = false
        activity?.invalidate()
        LocationMaster.shared.stop()
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: Constants.Notifications.nearbyNotificationTriggered, object: nil)
        NotificationCenter.default.removeObserver(self, name: Constants.Notifications.etaNotificationTriggered, object: nil)
        LocationMaster.shared.masterDelegate = nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureView()
        
        NotificationCenter.default.addObserver(self, selector: #selector(changedKeepScreenOnPreference(_:)), name: Constants.Notifications.changedKeepScreenOnPreference, object: nil)
                
        if let skView = self.skView as SKView? {
            // Load the SKScene from 'GameScene.sks'
            if let scene = SKScene(fileNamed: "ArrowScene") as? ArrowScene {
                // Set the scale mode to scale to fit the window
                scene.scaleMode = .aspectFill
                
                // Present the scene
                skView.presentScene(scene)
                
                self.scene = scene
            }
            
            skView.ignoresSiblingOrder = true
            
            if self.destination != nil {
                self.scene.makeWaitDots()
                self.scene.showWaitLabel()
            }

        }
        
        makeUserActivity()

    }
    
    // MARK: - Actions

    @IBAction func stopPressed(_ sender: Any) {
        
        if manuallyStopped {
            do {
                try LocationMaster.shared.start()
                manuallyStopped = false
                self.scene.waitDots?.speed = 1  // animate waitdots
                
                if (UserDefaults.standard.object(forKey: Constants.Defs.keepScreenOn) as! Bool) {
                    UIApplication.shared.isIdleTimerDisabled = true
                }
            } catch {
                os_log("Error while starting location master: %@", type: .error)
            }
        } else {
            UIApplication.shared.isIdleTimerDisabled = false
            
            LocationMaster.shared.stop()
            self.scene.waitDots?.speed = 0  // stop animating waitdots
            manuallyStopped = true
        }
        updateButton()
    }
    
    @IBAction func showInAppleMaps(_ sender: Any) {
        guard let dest = destination else {
            return
        }
        
        let q = dest.name.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "destination".localized
        let urlString = "http://maps.apple.com/?q=\(q)&ll=\(dest.latitude),\(dest.longitude)"
        let _url = URL(string: urlString)
        
        guard let url = _url else {
            return
        }
        
        UIApplication.shared.open(url, options: convertToUIApplicationOpenExternalURLOptionsKeyDictionary([:]), completionHandler: nil)
        
    }

    // MARK: - Notification Callbacks
    
    @objc func orientationChanged(_ notification: Notification) {
        if useMagnetometer {
            LocationMaster.orientation = DeviceOrientation(orientation: UIDevice.current.orientation)
        }
    }
    
    @objc func etaNotificationReceived(_ notification: Notification) {
        scene?.enqueueNotification(type: .eta)
    }
    
    @objc func nearbyNotificationReceived(_ notification: Notification) {
        scene?.enqueueNotification(type: .nearby)
    }
    
    @objc func changedKeepScreenOnPreference(_ notification: Notification) {
        if !manuallyStopped {
            let newVal = (UserDefaults.standard.object(forKey: Constants.Defs.keepScreenOn) as! Bool)
            UIApplication.shared.isIdleTimerDisabled = newVal
        }
    }
    
    // MARK: - Private
    
    private func updateCompass(_ angle: Double) {
        let cs = angleToCompass(angle)
        DispatchQueue.main.async {
            self.compassLabel.text = "\(Int(round(angle)))"
            self.compassLabel2.text = "(\(cs))"
        }
    }
    
    private func updateButton() {
        guard self.destination != nil else {
            return
        }
        
        DispatchQueue.main.async {
            self.stopButton.isEnabled = true
        }
        if !manuallyStopped {
            DispatchQueue.main.async {
                self.stopButton.setTitle("stop".localized, for: UIControl.State.normal)
                self.stopButton.setTitleColor(Constants.arrowColor, for: UIControl.State.normal)
            }
        } else {
            DispatchQueue.main.async {
                self.stopButton.setTitle("start".localized, for: UIControl.State.normal)
                self.stopButton.setTitleColor(#colorLiteral(red: 0.4745098054, green: 0.8392156959, blue: 0.9764705896, alpha: 1), for: UIControl.State.normal)
            }
        }
    }
    
    // MARK: - LocationMaster
    
    func locationMaster(provideIndication indication: Indication) {
        
        guard !stoppedFromOutside else { return }
        
        if !useMagnetometer, let angleMean = indication.angleMean, indication.fuzzyAccuracy != .low {
            scene.setArrowAngle(locationAngle: CGFloat(angleMean))
            scene.showArrowIfNotShown()
        }
        
        let prog = updateProgress(indication: indication)
        // use progress to know if we should ask for a review,
        // and check if at least two passed from start
        if AppDelegate.timeToAskForReview &&
           startTime.addingTimeInterval(120) < Date() &&
           prog > 0.8 {
            AppDelegate.askForReview = true
        }
        
        let distString = Formatters.format(distance: indication.distance)
        var etaString: String?
        if let eta = indication.eta {
            etaString = Formatters.format(briefTime: eta)
        }
        self.scene.setDistance(distString)
        self.scene.setAccuracy(indication.fuzzyAccuracy)
        self.scene.setETA(etaString)
        
        DispatchQueue.main.async {
            self.distanceLabel.text = Formatters.format(distance: indication.distance)
            self.accuracyLabel.text = Formatters.format(accuracy: indication.accuracy)
            self.speedLabel.text = Formatters.format(speed: indication.speed)
            self.accuracyDot.textColor = indication.fuzzyAccuracy.color
            self.altitudeLabel?.text = Formatters.format(distance: indication.location.altitude)
            if let etaString = etaString {
                self.etaLabel.text = etaString
            }
        }
        
        if UserDefaults.standard.object(forKey: Constants.Defs.compassIsRelative) as! Bool {
            // relative compass
            updateCompass(indication.toAngle)
        } else if !useMagnetometer, let course = indication.course {
            // absolute compass
            updateCompass(course)
        }

    }
    
    func locationMaster(headingUpdated heading: Double) {
        guard !stoppedFromOutside, useMagnetometer, let toAngle = self.lastToAngle else {
            return
        }
        
        let angle = toAngle - heading
        scene.setArrowAngle(locationAngle: CGFloat(angle))
        scene.showArrowIfNotShown()
        
        if !(UserDefaults.standard.object(forKey: Constants.Defs.compassIsRelative) as! Bool) {
            // absolute compass
            updateCompass(heading)
        } 
    }
    
    func locationMaster(didReceiveLocation: CLLocation) {
        if let destination = self.destination {
            self.lastToAngle = didReceiveLocation.coordinate.angle(toOtherLocation: destination.coordinate)
        }
    }

    func locationMasterDidStop() {
        stoppedFromOutside = true
        // calculate time since start
        let elapsed = Date().timeIntervalSince(self.startTime)
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .brief
        formatter.maximumUnitCount = 2
        // turn off labels and buttons
        DispatchQueue.main.async {
            if !self.stopButton.isHidden {
                self.stopButton.isHidden = true
            }
            self.distanceTitleLabel.text = "total_time".localized
            self.compassLabel.text = ""
            self.compassLabel2.text = ""
            self.distanceLabel.text = formatter.string(from: elapsed)
        }
        scene.terminated = true
        scene.hideArrowAndFriends()
        scene.hideWaitDots()
        scene.hideWaitLabel()
        scene.enqueueTickFadeIn()
    }
    
    func locationMasterSignalLost() {
        scene.hideArrowAndDisplayWaitMessage(messageText: "signal_lost".localized)
    }
    
    func locationMasterStandingStill() {
        scene.hideArrowAndDisplayWaitMessage(messageText: "keep_moving".localized)
    }
    
    private func makeUserActivity() {
        guard let currentDestination = self.destination else {
            return
        }
        
        DispatchQueue.main.async {
            if #available(iOS 12.0, *) {
                let act = currentDestination.makeUserActivity()
                act.becomeCurrent()
                self.activity = act
            }
        }
    }

}


// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToUIApplicationOpenExternalURLOptionsKeyDictionary(_ input: [String: Any]) -> [UIApplication.OpenExternalURLOptionsKey: Any] {
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (UIApplication.OpenExternalURLOptionsKey(rawValue: key), value)})
}
