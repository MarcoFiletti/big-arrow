//
//  LocationMaster.swift
//  Bladey
//
//  Created by Marco Filetti on 13/05/2017.
//  Copyright © 2017 Marco Filetti. All rights reserved.
//

import Foundation
import CoreLocation
import os.log

/// The location master delegate is notified of the distance and angle
/// from the last location received
@objc protocol LocationMasterDelegate: class {
    
    /// Gives update on how distant we are from a given point and how to get there. Gets called only if we are not standing still.
    @objc optional func locationMaster(provideIndication: Indication)
    
    /// Retrieves the last received location
    @objc optional func locationMaster(didReceiveLocation: CLLocation)
    
    /// Tells that the GPS signal has been missing for some time.
    /// May be sent repeatedly if old signals are received.
    @objc optional func locationMasterSignalLost()
    
    /// Tells that we are standing still (if not using magnetometer).
    /// Will be sent repeatedly until we start moving.
    @objc optional func locationMasterStandingStill()
    
    /// Acknowledges that the location master stopped itself
    /// (e.g. when the nearby notification was triggered and we are configured to
    /// stop once that happens)
    @objc optional func locationMasterDidStop()
    
    /// Updates the heading
    @objc optional func locationMaster(headingUpdated: Double)
}

/// The location master is the heart of both phone and watch apps.
/// It is responsible for retrieving locations, and telling us distance
/// from the given location.
class LocationMaster: NSObject, CLLocationManagerDelegate {
    
    /// The great location master itself
    static let shared = LocationMaster()

    /// Returns true if we are standing still (indication updates should
    /// not be sent in this case)
    private(set) var standingStill = false { didSet {
        if standingStill, !useMagnetometer {
            masterDelegate?.locationMasterStandingStill?()
        }
    } }
    
    /// True if signal was lost
    private(set) var signalLost = false { didSet {
        if signalLost {
            masterDelegate?.locationMasterSignalLost?()
        }
    } }
    
    /// True if we want to use magnetometer and the device has it
    var useMagnetometer: Bool {
        CLLocationManager.headingAvailable() && LocationMaster.shared.magnetometerPref
    }
    
    /// Magnetometer preference set by user.
    /// Can change this value to enable / disable magnetometer
    var magnetometerPref = UserDefaults.standard.bool(forKey: Constants.Defs.useMagnetometer) { didSet {
        if isRunning {
            if CLLocationManager.headingAvailable() {
                startHeading()
            } else {
                stopHeading()
            }
        }
    } }
    
    /// Device orientation (for magnetometer).
    /// Change this to propagate changes
    static var orientation: DeviceOrientation = .portrait { didSet {
        if shared.useMagnetometer {
            switch orientation {
            case .portrait:
                LocationMaster.shared.locManager.headingOrientation = .portrait
            #if !WatchApp
            case .landscapeLeft:
                LocationMaster.shared.locManager.headingOrientation = .landscapeLeft
            case .landscapeRight:
                LocationMaster.shared.locManager.headingOrientation = .landscapeRight
            case .portraitUpsideDown:
                // portrait upside down is perceived as upside up, since when upside down it actually appears as normal portrait
                LocationMaster.shared.locManager.headingOrientation = .portrait
            #endif
            }
        }
    }}

    // MARK: - Navigation variables
    
    /// Destination that we give directions to.
    /// If nil, gives directions towards north (compass mode).
    var destination: Destination? { didSet {
        if destination != nil {
            referenceLocation = CLLocation(latitude: destination!.latitude, longitude: destination!.longitude)
        } else {
            referenceLocation = nil
        }
    } }
    
    /// This gets set to true if we attempt to start
    /// without proper authorization
    var shouldAskForAuth = false
    
    /// True if we started
    var isRunning: Bool = false
    
    /// True if we force closed the app
    var forceClosed: Bool = false
    
    /// Speed buffer
    var speedBuffer = RunningBuffer(size: Constants.etaBufferSize)

    /// Location buffer for standing detection
    let locBuffer = LocationBuffer(maxLocationDuration: Constants.standingStillTime)
    
    /// Angle buffer for angle smoothing
    var angleBuffer = RunningBuffer(size: Constants.angleBufferSize)
    
    // MARK: - Stable properties
    
    /// To be notified of new information
    /// set to nil to stop communication, or set to a new delegate.
    weak var masterDelegate: LocationMasterDelegate?
    
    /// Core location informing us about new locations
    let locManager: CLLocationManager
    
    /// Geocoder to reverse location info
    let geocoder = CLGeocoder()
    
    /// Wheter we should use km or miles
    static var usesMetric: Bool { get {
        switch Options.Measurements.saved {
        case .automatic:
            if Locale.current.usesMetricSystem && Locale.current.identifier != "en_GB" {
                return true
            } else {
                return false
            }
        case .metricWithComma, .metricWithDot:
            return true
        case .imperial:
            return false
        }
    } }
    
    // MARK: - Private variables
    
    /// Number of location updates collected so far (start() resets this)
    private(set) var nOfLocationUpdates: UInt = 0
    
    /// Last time an indication with good FuzzyAccuracy was sent to delegate
    private(set) var lastGoodIndicationDate = Date.distantPast
    
    /// Last indication sent
    private(set) var lastIndication: Indication?
    
    /// Last location received from CLLocationManager
    private(set) var lastLocation: CLLocation?
    
    /// Reference location (updated when destination changes).
    /// If nil, gives indications towards north (compass mode).
    private var referenceLocation: CLLocation?
    
    /// Gets set to the current date when we ask for relaxation. If
    /// enough time passed (relaxEnableTime), reduce GPS accuracy
    private(set) var relaxedModeEngaged: Date? = nil
    
    /// Become true once we are actively reducing GPS accuracy.
    private(set) var relaxedMode: Bool = false
    
    /// Time for signal lost (should be nil when not running)
    private var signalLostTimer: Timer?
    
    // MARK: - Initialization
    
    /// Creates a new instance.
    /// Only itself can create itself, therefore make use of shared.
    private override init() {
        locManager = CLLocationManager()
        
        super.init()
        
        NotificationCenter.default.addObserver(self, selector: #selector(nearbyNotificationTriggeredStop(_:)), name: Constants.Notifications.nearDistanceNotificationStopTracking, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(runInBackgroundToggled(_:)), name: Constants.Notifications.changedRunInBackgroundPreference, object: nil)
        
        locManager.delegate = self
    }
    
    // MARK: - Notification callbacks

    @objc private func nearbyNotificationTriggeredStop(_ notification: Notification) {
        // if we are asked to stop ourselves, do so
        if isRunning {
            stop()
            masterDelegate?.locationMasterDidStop?()
        }
    }
    
    @objc private func runInBackgroundToggled(_ notification: Notification) {
        #if WatchApp
        if #available(watchOSApplicationExtension 4.0, *) {
            let runInBackground = UserDefaults.standard.object(forKey: Constants.Defs.runInBackground) as! Bool
            locManager.allowsBackgroundLocationUpdates = runInBackground
        }
        #else
        let runInBackground = UserDefaults.standard.object(forKey: Constants.Defs.runInBackground) as! Bool
        locManager.allowsBackgroundLocationUpdates = runInBackground
        #endif
    }
    
    // MARK: - Timer callbacks
    
    @objc private func signalLostCheck(_ timer: Timer) {
        guard isRunning, let lastLoc = lastLocation, !signalLost else { return }
        
        if lastLoc.timestamp.addingTimeInterval(Constants.signalLostTime) < Date() {
            signalLost = true
        }
    }
    
    // MARK: - Internal Methods
    
    /// Starts location updates and initiates location data collection.
    /// Must make sure that we have proper location authorizations beforehand.
    /// Can throw a `StartFailure`
    func start() throws {
        guard !forceClosed else {
            return
        }
        
        nOfLocationUpdates = 0
        speedBuffer = RunningBuffer(size: Constants.etaBufferSize)
        angleBuffer = RunningBuffer(size: Constants.angleBufferSize)
        shouldAskForAuth = false
        lastGoodIndicationDate = Date.distantPast
        lastIndication = nil
        lastLocation = nil
        relaxedMode = false
        locBuffer.reset()
        standingStill = false
        relaxedModeEngaged = nil
        NotificationHelper.sentNearDistanceNotification = false
        NotificationHelper.sentETANotification = false
        
        let locAuthStatus = CLLocationManager.authorizationStatus()
        guard locAuthStatus == .authorizedWhenInUse || locAuthStatus == .authorizedAlways else {
            shouldAskForAuth = true
            throw StartFailure.locationAuthorization
        }
        
        guard !isRunning else {
            throw StartFailure.alreadyStarted
        }
        self.isRunning = true
        
        signalLostTimer = Timer(timeInterval: 2.5, target: self, selector: #selector(signalLostCheck), userInfo: nil, repeats: true)
        RunLoop.current.add(signalLostTimer!, forMode: .common)
        
        locManager.desiredAccuracy = kCLLocationAccuracyBest
        locManager.distanceFilter = kCLDistanceFilterNone
        
        #if WatchApp
            if #available(watchOSApplicationExtension 4.0, *) {
                locManager.activityType = .other
                locManager.allowsBackgroundLocationUpdates = UserDefaults.standard.object(forKey: Constants.Defs.runInBackground) as! Bool
            }
        #else
            locManager.allowsBackgroundLocationUpdates = UserDefaults.standard.object(forKey: Constants.Defs.runInBackground) as! Bool
            locManager.pausesLocationUpdatesAutomatically = false
            locManager.activityType = .other
        #endif
        
        locManager.startUpdatingLocation()
        startHeading()
    }
    
    /// Stops location data collection.
    func stop(final: Bool = false) {
        
        guard final || self.isRunning else {
            return
        }
        self.isRunning = false
        
        if final {
            forceClosed = true
            self.masterDelegate = nil
            locManager.delegate = nil
        }
        
        signalLostTimer?.invalidate()
        signalLostTimer = nil
        
        locManager.stopUpdatingLocation()
        stopHeading()
        #if WatchApp
            if #available(watchOSApplicationExtension 4.0, *) {
                locManager.allowsBackgroundLocationUpdates = false
            }
        #else
            locManager.allowsBackgroundLocationUpdates = false
        #endif
    }
    
    func startHeading() {
        if useMagnetometer {
            locManager.startUpdatingHeading()
        }
    }
    
    func stopHeading() {
        if CLLocationManager.headingAvailable() {
            locManager.stopUpdatingHeading()
            if lastIndication == nil {
                masterDelegate?.locationMasterSignalLost?()
            }
        }
    }
    
    /// Sets to top accuracy (e.g. when entering foreground)
    func increaseAccuracy() {
        relaxedModeEngaged = nil
        relaxedMode = false
        if locManager.desiredAccuracy != kCLLocationAccuracyBest {
            locManager.desiredAccuracy = kCLLocationAccuracyBest
        }
    }
    
    /// Relaxes accuracy depending on the distance to the target and
    /// notification geofence
    func relaxAccuracy() {
        guard UserDefaults.standard.object(forKey: Constants.Defs.batterySaving) as! Bool else {
            return
        }
        
        if isRunning {
            relaxedModeEngaged = Date()
            assessAccuracy()
        }
    }
    
    /// Returns true if we don't have authorization
    func notAuthorized() -> Bool {
        if CLLocationManager.authorizationStatus() == .notDetermined {
            return false
        }
        if CLLocationManager.authorizationStatus() == .authorizedAlways {
            return false
        }
        if CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
            return false
        }
        return true
    }
    
    /// Check if authorization is not determined, and if so requests
    /// to authorize
    func verifyAuthorization() {
        if CLLocationManager.authorizationStatus() == .notDetermined {
            requestLocationAuthorization()
        }
    }
    
    /// Gets a convenience last location (if any)
    func getConvenienceLocation() -> CLLocation? {
        let locAuthStatus = CLLocationManager.authorizationStatus()
        guard locAuthStatus == .authorizedWhenInUse || locAuthStatus == .authorizedAlways else {
            return nil
        }
        guard let locManagerLoc = locManager.location else {
            return nil
        }
        // return own location if it exists and is recent, otherwise locManager's
        if let ownLoc = lastLocation, ownLoc.horizontalAccuracy > 0, ownLoc.timestamp > locManagerLoc.timestamp {
            return ownLoc
        } else if locManagerLoc.horizontalAccuracy > 0 {
            return locManagerLoc
        } else {
            return nil
        }
    }
    
    /// Reverse geocoder info to get a title
    func getInfo(forLocation: CLLocation, callback: @escaping (String?) -> Void) {
        geocoder.reverseGeocodeLocation(forLocation) {
            placemarks, error in
            
            if let error = error {
                os_log("Error while reversing geocoding info: %@", type: .error, error.localizedDescription)
                callback(nil)
            }
            
            if let pl = placemarks?.first, let tf = pl.thoroughfare {
                callback(tf)
            } else {
                callback(nil)
            }
            
        }
    }
    
    /// Gets an accurate location asynchronously.
    /// Will call locationMaster(didReceiveLocation: CLLocation) later.
    func fetchLocation() throws {
        let locAuthStatus = CLLocationManager.authorizationStatus()
        guard locAuthStatus == .authorizedWhenInUse || locAuthStatus == .authorizedAlways else {
            throw StartFailure.locationAuthorization
        }
        
        locManager.desiredAccuracy = kCLLocationAccuracyBest
        
        locManager.requestLocation()
    }
    
    // MARK: - Private methods
    
    /// Check if we need to increase / decrease GPS accuracy, based
    /// on whether notifications are on, which distance we are interested in
    /// and how far we are from destination.
    /// For relaxed mode.
    private func assessAccuracy() {
        
        guard let relaxDate = relaxedModeEngaged else {
            return
        }
        
        // fist check how long ago relaxAccuracy was called.
        // if not so long ago (e.g. 2 minutes ago) do nothing
        // enable relaxed mode after some time that it was requested
        if !relaxedMode && relaxDate.addingTimeInterval(Constants.relaxEnableTime) < Date() {
            relaxedMode = true
        }
        
        guard relaxedMode else {
            return
        }
        
        guard let lastIndication = self.lastIndication, lastIndication.distance > 0 else {
            return
        }
        
        let adjustedAccuracy: CLLocationAccuracy
        // convert numeric accuracy to a kCLAccuracy value
        if lastIndication.minimumDistance > 9000 {
            adjustedAccuracy = kCLLocationAccuracyThreeKilometers
        } else if lastIndication.minimumDistance > 3000 {
            adjustedAccuracy = kCLLocationAccuracyKilometer
        } else if lastIndication.minimumDistance > 1000 {
            adjustedAccuracy = kCLLocationAccuracyHundredMeters
        } else if lastIndication.minimumDistance > 200 {
            adjustedAccuracy = kCLLocationAccuracyNearestTenMeters
        } else {
            adjustedAccuracy = kCLLocationAccuracyBest
        }
        
        // before enacting change, check again that we should do that
        guard self.relaxedModeEngaged != nil && self.relaxedMode else {
            return
        }
        
        // if needed kCLAccuracy is different from current, set new value
        if adjustedAccuracy != locManager.desiredAccuracy {
            locManager.desiredAccuracy = adjustedAccuracy
        }
    }
    
    /// Return an ETA using the previous indication and the current indication.
    /// Manipulates the speedBuffer. If nil, no reliable value could be calculated.
    private func calculateETA(_ indication: Indication, lastIndication: Indication) -> TimeInterval? {
        
        // Fail if either distance is negative (invalid)
        guard indication.distance >= 0 && lastIndication.distance >= 0 else {
            return nil
        }
        
        // We proceed only if both accuracies are not bad, or if relaxed mode is on
        // only if the two accuracies are within a given proportion of each other
        let etaProceed: Bool
        if relaxedMode {
            // when in relaxed mode, both values' accuracies must be within a given proportion of each other
            etaProceed = withinProportion(indication.accuracy, lastIndication.accuracy, p: Constants.maxEtaAccuracyPropDiffRelaxed)
        } else {
            // when not in relaxed mode, indications accuracies must be similar
            etaProceed = lastIndication.similarAccuracy(indication)
        }
        
        guard etaProceed else {
            return nil
        }
        
        // to calculate eta, calculate difference in relative distance between this location and the last one
        let distDiff = lastIndication.relativeDistance - indication.relativeDistance
        // calculate time passed during move, get speed it and add to buffer
        let timeDiff = indication.location.timestamp.timeIntervalSince(lastIndication.location.timestamp)
        let relativeSpeed = distDiff / timeDiff
        speedBuffer.addSample(relativeSpeed)
        
        // weighted speed weights recent values more than old ones
        guard let wSpeed = speedBuffer.weightedMean(), wSpeed > 0 else {
            return nil
        }
        
        let estimate = indication.relativeDistance / wSpeed
        
        // less than 24 hours
        guard estimate >= 0, estimate < 24 * 60 * 60 else {
            return nil
        }
        
        return estimate

    }
    
    /// Request authorizations to use location (assuming
    /// authorization was not determined).
    private func requestLocationAuthorization() {
        guard CLLocationManager.authorizationStatus() == .notDetermined else {
            os_log("Authorization was already set, pointless to call this", type: .error)
            return
        }
        locManager.requestWhenInUseAuthorization()
    }
        
    // MARK: - CLLocation delegate adoption
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        guard let location = locations.last else { return }
        
        lastLocation = location
        
        guard let masterDelegate = masterDelegate else { return }
        
        guard location.horizontalAccuracy >= 0 else {
            os_log("Received invalid location", type: .fault)
            return
        }
        
        masterDelegate.locationMaster?(didReceiveLocation: location)
        
        guard isRunning else {
            return
        }
        
        nOfLocationUpdates += 1
        guard nOfLocationUpdates >= Constants.minNoOfLocations else {
            return
        }
        
        signalLost = location.timestamp.addingTimeInterval(Constants.signalLostTime) < Date()
        if signalLost {
            return
        }
        
        locBuffer.addLocation(newLocation: location)
        standingStill = locBuffer.standing()
        
        guard !standingStill || useMagnetometer else {
            return
        }
        
        let maybeIndication: Indication?
        
        // Create location using a reference or in compass mode
        if let refLoc = referenceLocation {
            maybeIndication = Indication(currentLocation: location, referenceLocation: refLoc, previousIndication: lastIndication, previousBuffer: angleBuffer)
        } else {
            maybeIndication = Indication(towardsNorthFromLocation: location, previousIndication: lastIndication, previousBuffer: angleBuffer)
        }
        
        guard let indication = maybeIndication else {
            os_log("Invalid indication created (should never happen)", type: .error)
            return
        }
        
        // add angle to buffer, if any
        if let angle = indication.angle {
            angleBuffer.addSample(angle)
        }
        
        // calculate eta
        if let lastIndication = self.lastIndication,
            nOfLocationUpdates >= Constants.minNoOfLocations * 2 {
            indication.eta = calculateETA(indication, lastIndication: lastIndication)
        }

        // send indication.
        // if we are in relaxed more, last indication was good,
        // or if last good indication was sent too long ago
        if relaxedMode ||
           indication.fuzzyAccuracy == .good ||
           lastGoodIndicationDate.addingTimeInterval(Constants.goodAccuracyDuration) < location.timestamp {
            
            masterDelegate.locationMaster?(provideIndication: indication)
            
            lastIndication = indication
            
            // send notification if that's appropriate
            NotificationHelper.sendNotificationsIfNeeded(indication, self.destination)
        }
        
        if indication.fuzzyAccuracy == .good {
            lastGoodIndicationDate = location.timestamp
        }
        
        // if we have been asked to enter relaxed mode, check if accuracy needs to be changed
        if relaxedModeEngaged != nil {
            assessAccuracy()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        os_log("Failed to retrieve location: %@", type: .error, error.localizedDescription)
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard isRunning, !signalLost, newHeading.trueHeading >= 0, let masterDelegate = self.masterDelegate else {
            return
        }
        
        masterDelegate.locationMaster?(headingUpdated: newHeading.trueHeading)
    }
        
}
