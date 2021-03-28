//
//  SubSettingsTableViewController.swift
//  Big Arrow
//
//  Created by Marco Filetti on 08/01/2018.
//  Copyright © 2018 Marco Filetti. All rights reserved.
//

import UIKit

struct OptionHolder<O: Option>: OptionHandler {
    
    private let options: [O]
    
    init(type: O.Type) {
        options = O.allCases as! [O]
    }
    
    var numberOfOptions: Int { get {
        return options.count
    } }
    
    var title: String { get {
        return O.title
    } }
    
    func selectAt(_ i: Int) {
        options[i].preview()
        options[i].save()
        
    }
    
    func nameAt(_ i: Int) -> String {
        return options[i].friendlyName
    }
    
    func subtitleAt(_ i: Int) -> String? {
        return options[i].subtitle
    }
    
}

protocol OptionHandler {
    var numberOfOptions: Int { get }
    var title: String { get }
    func selectAt(_ i: Int)
    func nameAt(_ i: Int) -> String
    func subtitleAt(_ i: Int) -> String?
}

class SubSettingsTableViewController: UITableViewController {
    
    // MARK: - To set
    
    var selectedOptionIndex: Int = -1
    weak var parentLabel: UILabel?
    var oneTimeChangeAction: (() -> Void)? = nil
    
    var handler: OptionHandler! { didSet {
        self.title = handler.title
    } }
    
    // MARK: - Private
    
    private var previouslySelected: IndexPath?
    
    override func viewWillDisappear(_ animated: Bool) {
        oneTimeChangeAction?()
        oneTimeChangeAction = nil
    }
    
    // MARK: - Table Overrides
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        handler.selectAt(indexPath.row)
        DispatchQueue.main.async {
            [unowned self] in
            self.tableView.deselectRow(at: indexPath, animated: true)
            if let prev = self.previouslySelected {
                self.tableView.cellForRow(at: prev)?.accessoryType = .none
            }
            self.tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
            self.previouslySelected = indexPath
        }
        parentLabel?.text = handler.nameAt(indexPath.row)
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return handler.numberOfOptions
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let subtitle = handler!.subtitleAt(indexPath.row) {
            let cell = tableView.dequeueReusableCell(withIdentifier: "SubtitledCell")!
            cell.textLabel?.text = handler.nameAt(indexPath.row)
            cell.detailTextLabel?.text = subtitle
            if selectedOptionIndex == indexPath.row {
                cell.accessoryType = .checkmark
                previouslySelected = indexPath
            }
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "Cell")!
            cell.textLabel?.text = handler.nameAt(indexPath.row)
            if selectedOptionIndex == indexPath.row {
                cell.accessoryType = .checkmark
                previouslySelected = indexPath
            }
            return cell
        }
    }
    
}
