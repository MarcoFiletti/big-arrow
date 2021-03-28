//
//  MasterViewController.swift
//  Big Arrow
//
//  Created by Marco Filetti on 15/06/2017.
//  Copyright © 2017 Marco Filetti. All rights reserved.
//

import UIKit
import os.log
import StoreKit
import CoreLocation

class MasterViewController: UITableViewController, LocationMasterDelegate {
    
    var detailViewController: ArrowController? = nil

    var tuples = [(Date?, Destination)]()
    
    /// This will be pushed to the arrow controller
    /// If nothing is selected in the table
    var nextDestination: Destination?
    
    var newDestinationButton: UIBarButtonItem!
    
    @IBOutlet weak var helpImageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.leftBarButtonItem = editButtonItem
        
        NotificationCenter.default.addObserver(self, selector: #selector(destinationsUpdated(_:)), name: Constants.Notifications.updatedDestination, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(timesUpdated(_:)), name: Constants.Notifications.timesUpdated, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(destinationRenamed(_:)), name: Constants.Notifications.renamedDestination, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(refreshView(_:)), name: UIApplication.willEnterForegroundNotification, object: UIApplication.shared)
        
        newDestinationButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addDestination(_:)))
        newDestinationButton.accessibilityLabel = "add_new_destination".localized
        
        navigationItem.rightBarButtonItem = newDestinationButton
        if let split = splitViewController {
            let controllers = split.viewControllers
            detailViewController = (controllers[controllers.count-1] as! UINavigationController).topViewController as? ArrowController
        }
        
        // Add refreshing to table
        self.refreshControl = UIRefreshControl()
        self.refreshControl!.addTarget(self, action: #selector(refreshPulled), for: UIControl.Event.valueChanged)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        try? LocationMaster.shared.fetchLocation()
        refreshView(nil)
        // strange bug fix, the button appears disabled on back
        DispatchQueue.main.async {
            self.newDestinationButton?.isEnabled = false
            self.newDestinationButton?.isEnabled = true
        }
        DispatchQueue.main.async {
            self.navigationController?.setToolbarHidden(false, animated: true)
        }
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        LocationMaster.shared.masterDelegate = self
        try? LocationMaster.shared.fetchLocation()
        
        if DestinationMaster.destinations.count > 0 {
            LocationMaster.shared.verifyAuthorization()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        DispatchQueue.main.async {
            self.navigationController?.setToolbarHidden(true, animated: true)
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
        tuples = []
    }
    
    /// Verifies if we should ask for a review, and ask if so
    private func reviewAskCheck() {
        // if we should ask for a review, now do so and return
        if AppDelegate.askForReview {
            DispatchQueue.main.async {
                SKStoreReviewController.requestReview()
            }
            UserDefaults.standard.set(Date(), forKey: Constants.Defs.lastTimeReviewAsked)
            
            return
        }
        
        // otherwise continue making checks
        
        // Set ask for review to true if we have 4 destinations and x days passed since last
        // time
        let lastAsked = UserDefaults.standard.object(forKey: Constants.Defs.lastTimeReviewAsked) as! Date
        if tuples.count >= 4 &&
            lastAsked.addingTimeInterval(Constants.reviewInterval) < Date() {
            AppDelegate.timeToAskForReview = true
        }
    }
    
    private func renameDestination(_ targetDestination: Destination) {
        let alView = UIAlertController(title: "rename_destination".localized, message: "enter_new_name".localized + " \"" + targetDestination.name + "\"", preferredStyle: UIAlertController.Style.alert)
        alView.addTextField() {$0.text = targetDestination.name}
        let cancelAction = UIAlertAction(title: "cancel".localized, style: .cancel, handler: nil)
        let okAction = UIAlertAction(title: "ok".localized, style: .default) {
            _ in
            let textField = alView.textFields![0]
            if let text = textField.text, text.count > 0 {
                DestinationMaster.renameDestination(targetDestination, newName: text)
            }
        }
        
        alView.addAction(cancelAction)
        alView.addAction(okAction)
        
        self.present(alView, animated: true, completion: nil)
    }
    
    private func repositionDestination(_ targetDestination: Destination) {
        let newDestinationVC = Storyboards.main.instantiateViewController(withIdentifier: "NewDestinationController") as! NewDestinationController
        
        newDestinationVC.editingDestination = true
        newDestinationVC.currentDestination = targetDestination
        newDestinationVC.currentName = targetDestination.name
        
        DispatchQueue.main.async {
            self.navigationController?.pushViewController(newDestinationVC, animated: true)
        }
    }
    
    @objc func addDestination(_ sender: Any) {
        if LocationMaster.shared.notAuthorized() {
            let alertController = UIAlertController(title: "location_not_authorized".localized, message: "please_enable_location_services".localized, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "dismiss".localized, style: .default, handler: nil))
            self.present(alertController, animated: true, completion: nil)
            
            return
        }
        
        LocationMaster.shared.verifyAuthorization()
        DispatchQueue.main.async {
            self.performSegue(withIdentifier: "pushToNewDestination", sender: self)
        }
    }
    
    @IBAction func sortPressed(_ sender: Any) {
        try? LocationMaster.shared.fetchLocation()
        
        let cString: String
        let otherButtons: [(String, Constants.SortBy)]
        switch Constants.SortBy.currentSetting() {
        case .distance:
            cString = "by_distance".localized
            otherButtons = [("date".localized, .lastUsed), ("manual".localized, .manual)]
        case .lastUsed:
            cString = "by_date".localized
            otherButtons = [("distance".localized, .distance), ("manual".localized, .manual)]
        case .manual:
            cString = "manually".localized
            otherButtons = [("distance".localized, .distance), ("date".localized, .lastUsed)]
        }
        
        let actionSheet = UIAlertController(title: "currently_sorting".localized + " " + cString, message: "change_will_be_sent".localized, preferredStyle: .actionSheet)
        
        otherButtons.forEach() {
            tuple in
            actionSheet.addAction(UIAlertAction(title: tuple.0, style: .default) {
                action in
                tuple.1.setDefault()
                NotificationCenter.default.post(name: Constants.Notifications.updatedDestination, object: self)
                (UIApplication.shared.delegate as! AppDelegate).sendSortByPref(newValue: tuple.1.rawValue)
                }
            )
        }
        
        actionSheet.addAction(UIAlertAction(title: "cancel".localized, style: .cancel))
        
        self.present(actionSheet, animated: true)
    }
    
    @objc func refreshPulled() {
        guard LocationMaster.shared.notAuthorized() == false else {
            DispatchQueue.main.async {
                self.refreshControl?.endRefreshing()
            }
            return
        }
        do {
            try LocationMaster.shared.fetchLocation()
        } catch {
            DispatchQueue.main.async {
                self.refreshControl?.endRefreshing()
            }
        }
    }
    
    // MARK: - Notification callbacks
    
    @objc func destinationsUpdated(_ notification: NSNotification?) {
        // if the table view is editing, we already removed the tuple in the delete block
        DispatchQueue.main.async {
            if !self.tableView.isEditing {
                DestinationMaster.makeTuples() {
                    self.tuples = $0
                    self.reviewAskCheck()
                    DispatchQueue.main.async {
                        self.tableView.reloadData()
                    }
                }
            }
        }
    }
    
    @objc func refreshView(_ notification: Notification?) {
        clearsSelectionOnViewWillAppear = splitViewController!.isCollapsed
        
        DestinationMaster.loadGroup()
        destinationsUpdated(nil)
        
        // if the help state has an image, show the image
        if let help = HelpState.currentState.associatedHelp {
            DispatchQueue.main.async {
                self.helpImageView.image = help
                self.helpImageView.tintColor = #colorLiteral(red: 0.2588235438, green: 0.7568627596, blue: 0.9686274529, alpha: 1)
                self.helpImageView.contentMode = HelpState.currentState.contentMode
                self.helpImageView.isHidden = false
            }
            // if we need to see maps help, or see it again, advance state
            if HelpState.currentState == .tappedDestination || HelpState.currentState == .sawMaps {
                HelpState.nextState()
            }
        } else if !helpImageView.isHidden {
            DispatchQueue.main.async {
                self.helpImageView.isHidden = true
            }
        }
    }

    @objc func timesUpdated(_ notification: Notification?) {
        guard notification?.userInfo?[Constants.Notifications.timesUpdatedNamesKey] != nil else {
            os_log("We should have the names of what was updated here", type: .error)
            return
        }
        
        destinationsUpdated(nil)
    }
    
    @objc func destinationRenamed(_ notification: Notification) {
        guard let uInfo = notification.userInfo, let oldName = uInfo["oldName"] as? String, let newName = uInfo["newName"] as? String else {
            os_log("Notification rename fail", type: .error)
            return
        }
        
        guard let oldTupleI = tuples.firstIndex(where: {$0.1.name == oldName}) else {
            os_log("Couldn't find destination with old name: %@", type: .error, oldName)
            destinationsUpdated(nil)
            return
        }
        
        guard let newTuple = DestinationMaster.tuple(forDestinationName: newName) else {
            os_log("Couldn't find tuple with name: %@", type: .error, newName)
            destinationsUpdated(nil)
            return
        }
        
        tuples[oldTupleI] = newTuple
        
        DispatchQueue.main.async {
            self.tableView.reloadRows(at: [IndexPath(row: oldTupleI, section: 0)], with: .fade)
        }
    }

    // MARK: - Segues
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "showDetail" && tableView.isEditing {
            return false
        } else {
            return true
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDetail" {
            
            let dest: Destination
            
            // if there's a row selected, use that. If not,
            // try to use next destination.
            if let ip = tableView.indexPathForSelectedRow {
                let row = ip.row
                let destination = tuples[row].1
                dest = destination
            } else if let destination = self.nextDestination {
                dest = destination
            } else {
                os_log("There is neither a table selection nor a next destination", type: .error)
                return
            }
            
            let updated = DestinationMaster.touchDestination(dest)
            let dict = [updated.0: updated.1]
            (UIApplication.shared.delegate as? AppDelegate)?.sendNewUsedTime(dict)
            let controller = (segue.destination as! UINavigationController).topViewController as! ArrowController
            controller.destination = dest
            controller.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
            controller.navigationItem.leftItemsSupplementBackButton = true
            
            // advance help state if this was the first time that the user taps
            // a destination
            if HelpState.currentState == .adddedDestination {
                HelpState.nextState()
            }
        }
    }
    
    // MARK: - LocationMasterDelegate
    
    func locationMaster(didReceiveLocation: CLLocation) {
        let visibleRows = tableView.visibleCells.compactMap() { tableView.indexPath(for: $0) }
        DispatchQueue.main.async {
            self.tableView.reloadRows(at: visibleRows, with: .fade)
            self.refreshControl?.endRefreshing()
        }
    }

    // MARK: - Table View
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tuples.count
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView.isEditing {
            // rename destination
            let targetDestination = tuples[indexPath.row].1
            
            let alView = UIAlertController(title: "edit_destination".localized, message: "what_would_you_like_to_do".localized, preferredStyle: UIAlertController.Style.alert)
            
            let cancelAction = UIAlertAction(title: "nothing".localized, style: .cancel) {
                _ in
                tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
            }
            let renameAction = UIAlertAction(title: "rename_destination".localized, style: .default) {
                _ in
                self.renameDestination(targetDestination)
            }
            let repositionAction = UIAlertAction(title: "reposition_destination".localized, style: .default) {
                _ in
                self.isEditing = false
                self.repositionDestination(targetDestination)
            }
            
            alView.addAction(cancelAction)
            alView.addAction(renameAction)
            alView.addAction(repositionAction)
            
            self.present(alView, animated: true, completion: nil)
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LocationCell", for: indexPath) as! LocationTableCell

        let row = indexPath.row
        
        let dest = tuples[row].1
        cell.destinationLabel!.text = dest.name
        
        if let date = tuples[row].0 {
            cell.lastUsedLabel!.text = Constants.dateFormatter.string(from: date)
        } else {
            cell.lastUsedLabel!.text = "new".localized
        }
        
        if let dist = dest.distanceFromLastLocation() {
            cell.distanceLabel.text = Formatters.format(distance: dist)
        } else {
            cell.distanceLabel.text = ""
        }
        
        return cell
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let row = indexPath.row
            let dest = tuples[row].1
            self.tableView.beginUpdates()
            DestinationMaster.removeDestination(dest)
            (UIApplication.shared.delegate as? AppDelegate)?.sendDeleteDestination(dest)
            self.tableView.deleteRows(at: [indexPath], with: .automatic)
            self.tuples.remove(at: indexPath.row)
            self.tableView.endUpdates()
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view.
        }
    }
    
    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        
        let moved = tuples.remove(at: sourceIndexPath.row)
        tuples.insert(moved, at: destinationIndexPath.row)
        
        if let names = DestinationMaster.moveDestination(from: sourceIndexPath.row, to: destinationIndexPath.row) {
            (UIApplication.shared.delegate as! AppDelegate).swappedDestinations(names.0, names.1)
            
        }
        
    }
    
    
    /// We can move rows if there is more than one row
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return tableView.numberOfRows(inSection: 0) > 1
    }

}

