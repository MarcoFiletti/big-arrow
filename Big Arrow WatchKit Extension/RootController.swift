//
//  RootController.swift
//  Big Arrow
//
//  Created by Marco Filetti on 18/06/2017.
//  Copyright © 2017 Marco Filetti. All rights reserved.
//

import Foundation
import WatchKit
import os.log

class RootController: WKInterfaceController {
    
    @IBOutlet var topTable: WKInterfaceTable!
    
    var tuples = [(Date?, Destination)]()
    
    var mustUpdateTable = false
    
    /// Set this to true if we want to ask the user to use location
    /// information
    var askForLocation = false
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        NotificationCenter.default.addObserver(self, selector: #selector(destinationsUpdated(_:)), name: Constants.Notifications.updatedDestination, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(destinationsUpdated(_:)), name: Constants.Notifications.timesUpdated, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(destinationRenamed(_:)), name: Constants.Notifications.renamedDestination, object: nil)
        
        mustUpdateTable = true
    }
    
    override func didAppear() {
        // as soon as we appear, stop the location master, just in case
        if LocationMaster.shared.isRunning {
            LocationMaster.shared.stop()
            
            if #available(watchOSApplicationExtension 4.0, *) {
                WKExtension.shared().isFrontmostTimeoutExtended = false
            }
            
            // also send updated list of locations to phone
        }
        
        LocationMaster.shared.masterDelegate = nil
        
        if mustUpdateTable {
            mustUpdateTable = false
            destinationsUpdated(nil)
        }
        
        NotificationHelper.clearAllNotifications()
        (WKExtension.shared().delegate as? ExtensionDelegate)?.activity?.invalidate()
        (WKExtension.shared().delegate as? ExtensionDelegate)?.activity = nil
    }
    
    @IBAction func importAll() {
        (WKExtension.shared().delegate as? ExtensionDelegate)?.requestAllDestinations()
    }
    
    func moveDestination(fromRow from: Int, toRow to: Int) {
        guard from >= 0 && to >= 0 && from != to && from < tuples.count && to < tuples.count else {
            return
        }
        
        let removed = tuples.remove(at: from)
        tuples.insert(removed, at: to)
        DispatchQueue.main.async {
            self.topTable.removeRows(at: IndexSet(integer: from))
            self.createAndInsertRow(tuple: removed, at: to)
        }
    }
    
    override func contextForSegue(withIdentifier segueIdentifier: String, in table: WKInterfaceTable, rowIndex: Int) -> Any? {
        let retVal = tuples[rowIndex].1
        let updated = DestinationMaster.touchDestination(tuples[rowIndex].1)
        let dict = [updated.0: updated.1]
        (WKExtension.shared().delegate as? ExtensionDelegate)?.sendNewUsedTime(dict)
        return retVal
    }
    
    // MARK: - Private
    
    /// Creates a row using the given index from destination master list and
    /// puts it at that place in the table
    private func createAndInsertRow(tuple: (Date?, Destination), at: Int) {
        topTable.insertRows(at: IndexSet(integer: at), withRowType: "DestinationRow")
        (topTable.rowController(at: at) as! DestinationRow).nameLabel.setText(tuple.1.name)
        // we show distance, unless it is not available. In that case, we show the date
        if let dist = tuple.1.distanceFromLastLocation() {
            let distString = Formatters.format(distance: dist)
            (topTable.rowController(at: at) as! DestinationRow).secondaryLabel.setText(distString)
        } else if let date = tuple.0 {
            (topTable.rowController(at: at) as! DestinationRow).secondaryLabel.setText(Constants.dateFormatter.string(from: date))
        }
    }
    
    // MARK: - Notifications
    
    @objc func destinationRenamed(_ notification: Notification?) {
        guard let uInfo = notification?.userInfo, let oldName = uInfo["oldName"] as? String, let newName = uInfo["newName"] as? String else {
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

        DispatchQueue.main.async {
            self.topTable.removeRows(at: IndexSet(integer: oldTupleI))
            self.createAndInsertRow(tuple: newTuple, at: oldTupleI)
        }
    }
    
    @objc func destinationsUpdated(_ notification: NSNotification?) {
        DestinationMaster.makeTuples() {
            
            tuples in
            
            self.tuples = tuples
            DispatchQueue.main.async {
                if self.topTable.numberOfRows > 0 {
                    self.topTable.removeRows(at: IndexSet(integersIn: 0..<self.topTable.numberOfRows))
                }
                
                for (i, tuple) in tuples.enumerated() {
                    self.createAndInsertRow(tuple: tuple, at: i)
                }
            }
        }
        
    }
    
}
