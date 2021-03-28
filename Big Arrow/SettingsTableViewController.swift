//
//  SettingsTableViewController.swift
//  Big Arrow
//
//  Created by Marco Filetti on 06/01/2018.
//  Copyright © 2018 Marco Filetti. All rights reserved.
//

import UIKit
import UserNotifications
import WatchConnectivity

class SettingsTableViewController: UITableViewController {

    // MARK: - Private fields
    
    /// Near notification distances (edges of scale)
    private var minNearDistance: Double = log(15.0)
    private var maxNearDistance: Double = log(12000.0)
    /// Near notification current set distance
    private var nearNotificationDistance: Double = 25
    /// ETA notification time
    private var etaNotificationSeconds: TimeInterval = 0
    
    // MARK: - Setup
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        waterLockTableViewCell.isHidden = !AppDelegate.thereIsAPairedWatch
        watchArrowSizeTableViewCell.isHidden = !AppDelegate.thereIsAPairedWatch

        if !(UserDefaults.standard.object(forKey: Constants.Defs.showProgressBar) as! Bool) {
            self.progBarSwitch.setOn(false, animated: false)
        }
        if !(UserDefaults.standard.object(forKey: Constants.Defs.runInBackground) as! Bool) {
            self.runInBackgroundSwitch.setOn(false, animated: false)
            self.runInBackgroundLabel.isEnabled = false
        }
        if !(UserDefaults.standard.object(forKey: Constants.Defs.notificationsStopTracking) as! Bool) {
            self.notificationsStopTrackingSwitch.setOn(false, animated: false)
        }
        if (UserDefaults.standard.object(forKey: Constants.Defs.batterySaving) as! Bool) {
            self.batterySavingSwitch.setOn(true, animated: false)
            self.batterySavingLabel.isEnabled = true
        }
        if (UserDefaults.standard.object(forKey: Constants.Defs.keepScreenOn) as! Bool) {
            self.keepScreenOnSwitch.setOn(true, animated: false)
            self.keepScreenOnLabel.isEnabled = true
        }
        
        if let val = UserDefaults.standard.object(forKey: Constants.Defs.iPhoneArrowSize) as? Float {
            iPhoneArrowSizeSlider.setValue(val, animated: false)
        }
        
        if let val = UserDefaults.standard.object(forKey: Constants.Defs.watchArrowSize) as? Float {
            watchArrowSizeSlider.setValue(val, animated: false)
        }
        
        etaNotificationSeconds = UserDefaults.standard.object(forKey: Constants.Defs.notificationsETA) as! Double
        setETASliderToTime(seconds: etaNotificationSeconds)
        
        // get near notification distance and set slider, text
        nearNotificationDistance = UserDefaults.standard.object(forKey: Constants.Defs.nearNotificationMeters) as! Double
        updateNotificationDistanceSlider()
        
        // check if user has notifications enabled. If not disable button
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings() {
            settings in
            if settings.authorizationStatus != .authorized {
                DispatchQueue.main.async {
                    self.nearNotificationsSwitch.setOn(false, animated: false)
                    UserDefaults.standard.set(false, forKey: Constants.Defs.nearNotificationsOn)
                }
                self.setNearbyNotificationDisplay(to: false)
            } else {
                let notifAreOn = UserDefaults.standard.object(forKey: Constants.Defs.nearNotificationsOn) as! Bool
                DispatchQueue.main.async {
                    self.nearNotificationsSwitch.setOn(notifAreOn, animated: false)
                }
                self.setNearbyNotificationDisplay(to: notifAreOn)
            }
        }
        
        if #available(iOS 11.0, *) {
            self.navigationController?.navigationBar.prefersLargeTitles = true
            self.navigationItem.largeTitleDisplayMode = .always
        } else {
            // Fallback on earlier versions
        }
        
        let useMagnetometer = UserDefaults.standard.object(forKey: "useMagnetometer") as! Bool
        magnetometerSwitch.setOn(useMagnetometer, animated: false)
        magnetometerLabel.isEnabled = useMagnetometer
        
        // set up notification sound picker
        let savedSound = Options.NotificationSound.saved
        notificationSoundLabel.text = savedSound.friendlyName
        
        // set up compass is relative picker
        let savedCompass = Options.CompassType.saved
        compassTypeLabel.text = savedCompass.friendlyName
        
        // set up measurements picker
        let savedMeasurements = Options.Measurements.saved
        measurementsLabel.text = savedMeasurements.friendlyName
        
        // set up water lock picker
        let savedWaterLock = Options.WaterLock.saved
        waterLockLabel.text = savedWaterLock.friendlyName
    }

    override func viewWillDisappear(_ animated: Bool) {
        if #available(iOS 11.0, *) {
            self.navigationItem.largeTitleDisplayMode = .automatic
            self.navigationController?.navigationBar.prefersLargeTitles = false
        }
        
        super.viewWillDisappear(animated)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        guard let destTableController = segue.destination as? SubSettingsTableViewController else { return }
        //here
        if segue.identifier == "notificationSound" {
            destTableController.handler = OptionHolder(type: Options.NotificationSound.self)
            destTableController.selectedOptionIndex = Options.NotificationSound.allCases.firstIndex(of: Options.NotificationSound.saved) ?? -1
            destTableController.parentLabel = notificationSoundLabel
        } else if segue.identifier == "compassType" {
            destTableController.handler = OptionHolder(type: Options.CompassType.self)
            destTableController.selectedOptionIndex = Options.CompassType.allCases.firstIndex(of: Options.CompassType.saved) ?? -1
            destTableController.parentLabel = compassTypeLabel
        } else if segue.identifier == "waterLock" {
            destTableController.handler = OptionHolder(type: Options.WaterLock.self)
            destTableController.selectedOptionIndex = Options.WaterLock.allCases.firstIndex(of: Options.WaterLock.saved) ?? -1
            destTableController.parentLabel = waterLockLabel
        } else if segue.identifier == "measurements" {
            destTableController.handler = OptionHolder(type: Options.Measurements.self)
            destTableController.selectedOptionIndex = Options.Measurements.allCases.firstIndex(of: Options.Measurements.saved) ?? -1
            destTableController.parentLabel = measurementsLabel
            destTableController.oneTimeChangeAction = {
                [weak self] in
                self?.updateNotificationDistanceSlider()
            }
        }
    }
    
    // MARK: - Private functions
    
    /// Sets the slider and related text to a given distance
    private func updateNotificationDistanceSlider() {
        // set min and max distance if non-metric
        if !LocationMaster.usesMetric {
            minNearDistance = log(15.24)  // 15 feet
            maxNearDistance = log(12874.8) // 8 miles
        } else {
            minNearDistance = log(15)
            maxNearDistance = log(12000)
        }
        let distance = nearNotificationDistance
        let scale = maxNearDistance - minNearDistance
        let slidVal = ( log(distance) - minNearDistance ) / scale
        DispatchQueue.main.async {
            self.nearNotificationsDistanceSlider.setValue(Float(slidVal), animated: false)
            self.nearNotificationsDistanceLabel.text = Formatters.format(distance: distance, splitAtFive: true)
        }
    }
    
    /// Sets the ETA slider and related text
    private func setETASliderToTime(seconds: Double) {
        DispatchQueue.main.async {
            self.etaNotificationsSlider.setValue(Float(seconds), animated: false)
            if seconds == 0 {
                self.etaNotificationsTimeLabel.text = "(\("disabled".localized))"
            } else {
                self.etaNotificationsTimeLabel.text = Formatters.format(shortTime: seconds)
            }
        }
    }
    
    /// Helper function to toggle all labels related to notifications and set the relevant preference
    private func setNearbyNotificationDisplay(to enabled: Bool) {
        DispatchQueue.main.async {
            [unowned self] in
            self.notificationLabels.forEach() {
                $0.isEnabled = enabled
            }
        }
    }
    
    // MARK: - Outlets
    
    /// Disabled when notifications are off
    @IBOutlet var notificationLabels: [UILabel]!
    
    @IBOutlet weak var progBarSwitch: UISwitch!
    @IBOutlet weak var runInBackgroundSwitch: UISwitch!
    @IBOutlet weak var runInBackgroundLabel: UILabel!
    @IBOutlet weak var nearNotificationsSwitch: UISwitch!
    @IBOutlet weak var nearNotificationsDistanceLabel: UILabel!
    @IBOutlet weak var nearNotificationsDistanceSlider: UISlider!
    @IBOutlet weak var notificationsStopTrackingSwitch: UISwitch!
    @IBOutlet weak var batterySavingSwitch: UISwitch!
    @IBOutlet weak var batterySavingLabel: UILabel!
    @IBOutlet weak var keepScreenOnLabel: UILabel!
    @IBOutlet weak var keepScreenOnSwitch: UISwitch!
    @IBOutlet weak var etaNotificationsTimeLabel: UILabel!
    @IBOutlet weak var etaNotificationsSlider: UISlider!
    @IBOutlet weak var notificationSoundLabel: UILabel!
    @IBOutlet weak var compassTypeLabel: UILabel!
    @IBOutlet weak var measurementsLabel: UILabel!
    @IBOutlet weak var waterLockLabel: UILabel!
    @IBOutlet weak var magnetometerSwitch: UISwitch!
    @IBOutlet weak var magnetometerLabel: UILabel!
    @IBOutlet weak var iPhoneArrowSizeSlider: UISlider!
    @IBOutlet weak var watchArrowSizeSlider: UISlider!
    
    @IBOutlet weak var waterLockTableViewCell: UITableViewCell!
    @IBOutlet weak var watchArrowSizeTableViewCell: UITableViewCell!
    
    // MARK: - Actions
    
    @IBAction func progBarToggled(_ sender: UISwitch) {
        UserDefaults.standard.set(sender.isOn, forKey: Constants.Defs.showProgressBar)
        NotificationCenter.default.post(name: Constants.Notifications.changedProgressBarPreference, object: self)
        
        DispatchQueue.main.async {
            (UIApplication.shared.delegate as! AppDelegate).sendProgressBarPref(newValue: sender.isOn)
        }
    }
    
    @IBAction func runInBackgroundToggled(_ sender: UISwitch) {
        self.setBackgroundRun(sender.isOn)
    }
    
    @IBAction func keepScreenOnToggled(_ sender: UISwitch) {
        UserDefaults.standard.set(sender.isOn, forKey: Constants.Defs.keepScreenOn)
        NotificationCenter.default.post(name: Constants.Notifications.changedKeepScreenOnPreference, object: self)
    }
    
    private func setBackgroundRun(_ newValue: Bool) {
        UserDefaults.standard.set(newValue, forKey: Constants.Defs.runInBackground)
        NotificationCenter.default.post(name: Constants.Notifications.changedRunInBackgroundPreference, object: self)
        
        DispatchQueue.main.async {
            (UIApplication.shared.delegate as! AppDelegate).sendRunInBackgroundPref(newValue: newValue)
            self.runInBackgroundLabel.isEnabled = newValue
        }
        
        let notificationsOn = UserDefaults.standard.object(forKey: Constants.Defs.nearNotificationsOn) as! Bool
        if notificationsOn && newValue == false {
            self.setNotifications(false)
            DispatchQueue.main.async {
                self.nearNotificationsSwitch.setOn(false, animated: true)
            }
        }
    }
    
    @IBAction func nearNotificationsToggled(_ sender: UISwitch) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) {
            granted, error in
            if granted {
                DispatchQueue.main.async {
                    self.setNotifications(sender.isOn)
                }
            } else {
                let alertController = UIAlertController(title: "notifications_not_authorized".localized, message: "please_enable_notifications".localized, preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "dismiss".localized, style: .default, handler: nil))
                
                self.present(alertController, animated: true) {
                    self.setNotifications(false)
                    DispatchQueue.main.async {
                        self.nearNotificationsSwitch.setOn(false, animated: true)
                    }
                }
                
            }
        }
    }
    
    private func setNotifications(_ newValue: Bool) {
        self.setNearbyNotificationDisplay(to: newValue)
        UserDefaults.standard.set(newValue, forKey: Constants.Defs.nearNotificationsOn)
        DispatchQueue.main.async {
            (UIApplication.shared.delegate as! AppDelegate).sendNearNotificationsToggle(newValue: newValue)
            if newValue == true && !self.runInBackgroundSwitch.isOn {
                self.runInBackgroundSwitch.setOn(true, animated: true)
                self.setBackgroundRun(true)
            }
        }
    }
    
    @IBAction func nearNotificationDistanceChanged(_ sender: UISlider) {
        let scale = maxNearDistance - minNearDistance
        let rawDistance = exp(minNearDistance + scale * Double(sender.value))
        
        if LocationMaster.usesMetric {
            let roundedDistance: Double
            // round distance so that we get 5s when dealing with small units,
            // .nn when dealing with bigger units, .n when dealing with tens
            switch FuzzyDistance(fromMetres: nearNotificationDistance) {
            case .unimetric:
                // round to fives
                roundedDistance = round(rawDistance) - rawDistance.remainder(dividingBy: 5.0)
            case .kilometric, .fivekilometric:
                // round to 50 metres or 100 above 5 km
                if rawDistance > 5000 {
                    roundedDistance = round(rawDistance) - rawDistance.remainder(dividingBy: 100.0)
                } else {
                    roundedDistance = round(rawDistance) - rawDistance.remainder(dividingBy: 50.0)
                }
            default:
                // round to a km
                roundedDistance = round(rawDistance) - rawDistance.remainder(dividingBy: 1000.0)
            }
            nearNotificationDistance = roundedDistance
        } else {
            let roundedDistance: Double
            let m = Measurement(value: rawDistance, unit: UnitLength.meters)
            // round distance so that we get 5s when dealing with small units,
            // .nn when dealing with bigger units, .n when dealing with tens
            switch FuzzyDistance(fromMetres: nearNotificationDistance) {
            case .unimetric:
                // round to five feet below 300 yd
                if rawDistance < 274.32 {
                    // round to five feet
                    let feet = m.converted(to: .feet).value
                    let roundedFeet = round(feet) - feet.remainder(dividingBy: 5.0)
                    let mf = Measurement(value: roundedFeet, unit: UnitLength.feet)
                    roundedDistance = mf.converted(to: .meters).value
                } else {
                    // round to five yd
                    let yards = m.converted(to: .yards).value
                    let roundedYards = round(yards) - yards.remainder(dividingBy: 5.0)
                    let my = Measurement(value: roundedYards, unit: UnitLength.yards)
                    if round(my.converted(to: .feet).value) == 899.0 {
                        // special case to forcibly output 300 yards
                        roundedDistance = 274.32
                    } else {
                        roundedDistance = my.converted(to: .meters).value
                    }
                }
            default:
                let milesHundred = m.converted(to: .miles).value * 100
                let roundedMilesHundred: Double
                // round to 0.05 miles or 0.1 above 5 miles (* 100)
                if milesHundred > 5 {
                    // round to 0.05 -> 5 when * 100
                    roundedMilesHundred = round(milesHundred) - (milesHundred).remainder(dividingBy: 5.0)
                } else {
                    // round to 0.1
                    roundedMilesHundred = round(milesHundred) - milesHundred.remainder(dividingBy: 10.0)
                }
                let mm = Measurement(value: roundedMilesHundred / 100, unit: UnitLength.miles)
                roundedDistance = mm.converted(to: .meters).value
            }
            nearNotificationDistance = roundedDistance
        }
        
        updateNotificationDistanceSlider()
    }
    
    @IBAction func nearNotificationDistanceDone(_ sender: UISlider) {
        UserDefaults.standard.set(nearNotificationDistance, forKey: Constants.Defs.nearNotificationMeters)
        NotificationCenter.default.post(name: Constants.Notifications.changedNearDistanceNotificationMeters, object: self)
        
        DispatchQueue.main.async {
            (UIApplication.shared.delegate as! AppDelegate).sendNearNotificationDistanceMeters(newValue: self.nearNotificationDistance)
        }
    }
    
    @IBAction func etaSliderChanged(_ sender: UISlider) {
        let roundedSeconds = sender.value - sender.value.remainder(dividingBy: 10.0)
        etaNotificationSeconds = TimeInterval(roundedSeconds)
        if etaNotificationSeconds != 0 {
            DispatchQueue.main.async {
                self.etaNotificationsTimeLabel.text = Formatters.format(shortTime: self.etaNotificationSeconds)
            }
        } else {
            DispatchQueue.main.async {
                self.etaNotificationsTimeLabel.text = "(\("disabled".localized))"
            }
        }
    }
    
    @IBAction func etaSliderDone(_ sender: UISlider) {
        UserDefaults.standard.set(etaNotificationSeconds as Double, forKey: Constants.Defs.notificationsETA)
        DispatchQueue.main.async {
            (UIApplication.shared.delegate as! AppDelegate).sendETANotificationSeconds(newValue: self.etaNotificationSeconds)
        }
    }
    
    @IBAction func notificationsStopTrackingToggled(_ sender: UISwitch) {
        UserDefaults.standard.set(sender.isOn, forKey: Constants.Defs.notificationsStopTracking)
        DispatchQueue.main.async {
            (UIApplication.shared.delegate as! AppDelegate).sendNotificationsStopTrackingToggle(newValue: sender.isOn)
        }
    }
    
    @IBAction func batterySavingToggled(_ sender: UISwitch) {
        UserDefaults.standard.set(sender.isOn, forKey: Constants.Defs.batterySaving)
        DispatchQueue.main.async {
            (UIApplication.shared.delegate as! AppDelegate).sendBatterySaveToggle(newValue: sender.isOn)
            self.batterySavingLabel.isEnabled = sender.isOn
        }
    }
    
    @IBAction func magnetometerToggled(_ sender: UISwitch) {
        UserDefaults.standard.set(sender.isOn, forKey: Constants.Defs.useMagnetometer)
        DispatchQueue.main.async {
            (UIApplication.shared.delegate as! AppDelegate).sendMagnetometerToggle(newValue: sender.isOn)
            self.magnetometerLabel.isEnabled = sender.isOn
            LocationMaster.shared.magnetometerPref = sender.isOn
        }
    }
    
    @IBAction func iPhoneArrowSizeSliderChanged(_ sender: UISlider) {
        UserDefaults.standard.set(sender.value, forKey: Constants.Defs.iPhoneArrowSize)
        NotificationCenter.default.post(name: Constants.Notifications.arrowSizeChanged, object: self)
    }
    
    @IBAction func watchArrowSizeSliderChanged(_ sender: UISlider) {
        UserDefaults.standard.set(sender.value, forKey: Constants.Defs.watchArrowSize)
        DispatchQueue.main.async {
            (UIApplication.shared.delegate as! AppDelegate).sendWatchArrowSize(newValue: sender.value)
        }
    }
    
    @IBAction func showSupportPress(_ sender: UIButton) {
        UIApplication.shared.open(URL(string: "https://www.marcofiletti.com/support/")!)
    }
    
    // MARK: - TableView overrides
    
    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        let identifier = tableView.cellForRow(at: indexPath)?.reuseIdentifier
        if identifier == "notificationSoundCell" || identifier == "compassTypeCell" || identifier == "measurementsTypeCell" || identifier == "waterLockTypeCell" {
            return true
        } else {
            return false
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // segues are doing all the work for now
    }
    
}
