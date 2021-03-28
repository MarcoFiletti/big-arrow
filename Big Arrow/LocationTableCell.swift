//
//  LocationTableCell.swift
//  Big Arrow
//
//  Created by Marco Filetti on 07/06/2018.
//  Copyright © 2018 Marco Filetti. All rights reserved.
//

import UIKit

class LocationTableCell: UITableViewCell {
    
    @IBOutlet weak var destinationLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var lastUsedLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
