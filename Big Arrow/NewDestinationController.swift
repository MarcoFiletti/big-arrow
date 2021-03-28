//
//  NewDestinationController.swift
//  Big Arrow
//
//  Created by Marco Filetti on 16/06/2017.
//  Copyright © 2017 Marco Filetti. All rights reserved.
//

import Foundation
import UIKit
import MapKit
import os.log

class NewDestinationController: UIViewController, UISearchBarDelegate, UITableViewDataSource, UITableViewDelegate, MKMapViewDelegate, LocationMasterDelegate {
    
    @IBOutlet weak var nameField: UITextField!
    @IBOutlet weak var addButton: UIButton!
    
    @IBOutlet weak var useLocationButton: UIButton!
    @IBOutlet weak var segmentedMapControl: UISegmentedControl!
    
    let minNameLength = 2
    
    var manuallyEditedField = false
    
    @IBOutlet weak var charactersRemainingLabel: UILabel!
    
    var charactersRemaining = 0 { didSet {
        if charactersRemaining < 0 || charactersRemaining >= Constants.maxNameLength - minNameLength {
            charactersRemainingLabel.textColor = UIColor.red
        } else {
            charactersRemainingLabel.textColor = UIColor.darkText
        }
        DispatchQueue.main.async {
            self.charactersRemainingLabel.text = "\(self.charactersRemaining)"
        }
    } }
    
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    var lastSelectedRow: IndexPath?
    var previousSearch: MKLocalSearch?
    var annotation: MKPointAnnotation?
    var crosshair = Crosshair()
    var currentDestination: Destination?
    
    var justStartedSearching = false { didSet {
        if justStartedSearching {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.justStartedSearching = false
            }
        }
    } }
    
    /// Name of current location. Updating this updates text field.
    var currentName: String = "N/A" { didSet {
        checkName(newName: currentName)
        if let nameField = self.nameField, nameField.text != currentName {
            DispatchQueue.main.async {
                nameField.text = self.currentName
            }
        }
    } }
    
    /// True if we want to edit a destination instead of creating a new one
    var editingDestination = false
    
    /// Become true as soon as the map made its first move (when the view is loaded)
    private var mapDidMove = false
    
    /// Is true if we do a search, false if we didn't search or search was cleared
    var enteredSearch = false
    
    @IBOutlet weak var mapView: MKMapView!
    
    @IBOutlet weak var searchResultsTable: UITableView!
    var results = [MKMapItem]()
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        
        if let s = previousSearch {
            s.cancel()
        }
        
        guard searchText.count > 0 else {
            showTable = false
            return
        }
        
        if !showTable { showTable = true }
        
        let completion = MKLocalSearchCompletion()
        let request = MKLocalSearch.Request(completion: completion)
        request.naturalLanguageQuery = searchText
        let search = MKLocalSearch(request: request)
        previousSearch = search
        self.searchBar = searchBar
        self.enteredSearch = true
        search.start() {
            response, error in
            self.previousSearch = nil
            if let response = response {
                if !self.manuallyEditedField && !self.editingDestination {
                    self.currentName = searchText
                }
                self.results = response.mapItems
                DispatchQueue.main.async {
                    if let ip = self.lastSelectedRow {
                        self.searchResultsTable.deselectRow(at: ip, animated: true)
                        self.lastSelectedRow = nil
                    }
                    self.searchResultsTable.reloadData()
                }
            }
            
        }
    }
    
    // MARK: - Setup
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "pushToNewDestination" {
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if editingDestination, let destination = currentDestination {
            centerMap(onCoordinate: destination.coordinate)
            currentName = destination.name
        } else if let location = LocationMaster.shared.getConvenienceLocation() {
            if !enteredSearch {
                centerMap(onCoordinate: location.coordinate)
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        mapObserveToken = mapView.observe(\.bounds) {
            _, _ in
            self.crosshair.recenter(self.mapView.frame)
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        LocationMaster.shared.masterDelegate = nil
        mapObserveToken.invalidate()
        mapObserveToken = nil
    }

    private var mapObserveToken: NSKeyValueObservation!
    
    override func viewDidLoad() {
        relayout(enact: false)
        mapView.delegate = self
        
        mapView.layer.addSublayer(self.crosshair)
        
        DispatchQueue.main.async {
            self.crosshair.isHidden = true
        }
        
        if let savedMapType = UserDefaults.standard.object(forKey: "mapViewType") as? Int,
               savedMapType != -1,
           let convertedMapType = MKMapType(rawValue: UInt(savedMapType)) {
            mapView.mapType = convertedMapType
            switch mapView.mapType {
            case .satellite:
                DispatchQueue.main.async {
                    self.segmentedMapControl.selectedSegmentIndex = 1
                }
            case .hybrid:
                DispatchQueue.main.async {
                    self.segmentedMapControl.selectedSegmentIndex = 2
                }
            default:
                break
            }
        }
        
        // oberve keyboard appearing
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    // MARK: - Layout handling
    
    weak var searchBar: UISearchBar? { willSet {
        if newValue == nil, let sb = self.searchBar {
            DispatchQueue.main.async {
                sb.resignFirstResponder()
            }
        }
    } }
    
    @IBOutlet weak var tableViewConstraint: NSLayoutConstraint!
    
    @IBOutlet var bottomConstraint: NSLayoutConstraint!
    
    let bottomConstant: CGFloat = 30
    
    var keyboardHeight: CGFloat = 0
    
    var tableViewHeight: CGFloat { get {
        if !showTable { return 0 }
        let isCompact = self.traitCollection.verticalSizeClass == .compact
        return isCompact ? 100 : 200
        } }
    
    var showTable: Bool = false { didSet {
        relayout()
        } }
    
    var keyboardVisible: Bool = false { didSet {
        if keyboardVisible == true && nameField.isEditing {
            bottomConstraint.constant = keyboardHeight + bottomConstant
        } else {
            bottomConstraint.constant = bottomConstant
        }
        relayout()
    } }
    
    @objc func keyboardWillShow(_ notification: NSNotification) {
        let info = notification.userInfo!
        let keyboardFrame: CGRect = (info[UIResponder.keyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
        keyboardHeight = keyboardFrame.height
        keyboardVisible = true
    }
    
    @objc func keyboardWillHide(_ notification: NSNotification) {
        keyboardVisible = false
    }
    
    private func relayout(enact: Bool = true) {
        tableViewConstraint.constant = tableViewHeight
        
        if enact {
            UIView.animate(withDuration: 0.5) {self.view.layoutIfNeeded()}
        }
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        if searchBar.text == "" {
            self.searchBar = nil
            self.enteredSearch = false
        }
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        self.searchBar = nil
        showTable = false
        self.enteredSearch = false
    }
    
    func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
        justStartedSearching = true
        self.searchBar = searchBar
        showTable = true
        return true
    }
    
    func showSpinner() {
        self.spinner.alpha = 0
        self.spinner.startAnimating()
        UIView.animate(withDuration: 0.5, animations: { self.spinner.alpha = 1 })
    }
    
    func hideSpinner() {
        UIView.animate(withDuration: 0.5, animations: { self.spinner.alpha = 0 }, completion: { _ in self.spinner.stopAnimating() })
    }
    
    /// Finds the name for the given location and updates fields
    func reverseGeoCode(location: CLLocation) {
        LocationMaster.shared.getInfo(forLocation: location) {
            tf in
            
            if let tf = tf {
                DispatchQueue.main.async {
                    self.currentName = tf
                }
            }
        }
    }
    
    // MARK: - Map
    
    @IBAction func mapTapped(_ sender: UITapGestureRecognizer) {
        if keyboardVisible || showTable {
            keyboardVisible = false
            showTable = false
            searchBar = nil
        }
    }
    
    @IBAction func mapTypeChanged(_ sender: UISegmentedControl) {
        let mapType: MKMapType
        switch sender.selectedSegmentIndex {
        case 0:
            mapType = .standard
        case 1:
            mapType = .satellite
        case 2:
            mapType = .hybrid
        default:
            return
        }
        UserDefaults.standard.set(Int(mapType.rawValue), forKey: "mapViewType")
        mapView.mapType = mapType
    }
    
    func centerMap(onCoordinate: CLLocationCoordinate2D) {
        DispatchQueue.main.async {
            let span = MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
            let reg = MKCoordinateRegion(center: onCoordinate, span: span)
            self.mapView.setRegion(reg, animated: true)
            self.showTable = false
        }
    }
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        updateDestination(newRegion: mapView.region)
        DispatchQueue.main.async {
            self.crosshair.isHidden = true
            self.mapDidMove = true
        }
    }
    
    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        DispatchQueue.main.async {
            self.crosshair.isHidden = false
        }
    }

    func locationMaster(didReceiveLocation location: CLLocation) {
        LocationMaster.shared.masterDelegate = nil
        centerMap(onCoordinate: location.coordinate)
        hideSpinner()
        DispatchQueue.main.async {
            self.useLocationButton.isEnabled = true
        }
    }
    
    @IBAction func useCurrentLocationPress(_ sender: UIButton) {
        LocationMaster.shared.masterDelegate = self
        self.manuallyEditedField = false
        self.enteredSearch = false
        do {
            try LocationMaster.shared.fetchLocation()
            showSpinner()
            DispatchQueue.main.async {
                self.useLocationButton.isEnabled = false
            }
        } catch {
            os_log("Failed to use current location: %@", type: .error, error.localizedDescription)
        }
    }
    
    func updateDestination(newRegion: MKCoordinateRegion) {
        
        if !justStartedSearching {
            searchBar = nil  // clear search
            showTable = false
        }
        
        // reverse geocode if user did not enter text or didn't do a search
        if !manuallyEditedField, !enteredSearch, !editingDestination {
            self.reverseGeoCode(location: CLLocation(latitude: newRegion.center.latitude, longitude: newRegion.center.longitude))
        }
        
        DispatchQueue.main.async {
            guard self.mapDidMove || !self.editingDestination else {
                return
            }
            
            if let ann = self.annotation {
                self.mapView.removeAnnotation(ann)
            }
            self.annotation = MKPointAnnotation()
            self.annotation!.coordinate = newRegion.center
            self.mapView.addAnnotation(self.annotation!)
            self.currentDestination = Destination(name: self.currentName, coordinate: newRegion.center)
        }
    }
    
    // MARK: - Buttons, etc
    
    @IBAction func touchedField(_ sender: Any) {
        showTable = false
    }
    
    @IBAction func editedField(_ sender: UITextField) {
        guard let newName = sender.text else {
            return
        }
        self.manuallyEditedField = true
        checkName(newName: newName)
    }
    
    @IBAction func applyName(_ sender: UITextField) {
        guard let newName = sender.text else {
            return
        }
        checkName(newName: newName)
    }
    
    func checkName(newName: String) {
        guard currentDestination != nil, charactersRemainingLabel != nil else {
            self.addButton?.isEnabled = false
            return
        }
        
        var newName = newName
        newName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        newName = newName.replacingOccurrences(of: "\n", with: " ")
        
        charactersRemaining = Constants.maxNameLength - newName.count
        
        guard newName.count > minNameLength, newName.count <= Constants.maxNameLength else {
            DispatchQueue.main.async {
                self.addButton.isEnabled = false
            }
            return
        }
        
        self.currentDestination?.changeName(newName)
        if DestinationMaster.destinationNameExists(newName) {
            DispatchQueue.main.async {
                self.addButton.setTitle("replace".localized, for: UIControl.State.normal)
                self.addButton.isEnabled = true
            }
        } else {
            DispatchQueue.main.async {
                self.addButton.setTitle("add".localized, for: UIControl.State.normal)
                self.addButton.isEnabled = true
            }
        }
    }
    
    @IBAction func addPress(_ sender: UIButton) {
        self.manuallyEditedField = false
        self.enteredSearch = false
        
        if let dest = currentDestination {
            (UIApplication.shared.delegate as? AppDelegate)?.sendNewDestination(dest)
            
            // advances help if this is the first time a destination is added
            if HelpState.currentState == .nothing {
                HelpState.nextState()
            }
            
            let replaced = DestinationMaster.addDestination(dest: dest)
            if replaced {
                DispatchQueue.main.async {
                    self.addButton.setTitle("replaced".localized, for: UIControl.State.normal)
                    self.addButton.isEnabled = false
                }
            } else {
                DispatchQueue.main.async {
                    self.addButton.setTitle("added".localized, for: UIControl.State.normal)
                    self.addButton.isEnabled = false
                }
            }
        }
    }
    
    // MARK: - Table view (for search results)
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return results.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        
        if indexPath.row < results.count {
            cell.textLabel!.text = results[indexPath.row].placemark.locality
            cell.detailTextLabel!.text = results[indexPath.row].placemark.title
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row > -1 {
            self.lastSelectedRow = indexPath
            let result = results[indexPath.row].placemark
            if !enteredSearch, !manuallyEditedField, let n = result.thoroughfare ?? result.locality {
                DispatchQueue.main.async {
                    self.currentName = n
                }
            }
            centerMap(onCoordinate: result.coordinate)
        }
    }
    
}
