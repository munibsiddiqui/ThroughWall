//
//  VPNTableViewContTableViewCell.swift
//  ThroughWall
//
//  Created by Bin on 03/05/2017.
//  Copyright © 2017 Wu Bin. All rights reserved.
//

import UIKit

class VPNTableViewContTableViewCell: UITableViewCell {
    
    @IBOutlet weak var VPNNameLabel: UILabel!
    @IBOutlet weak var VPNPingValueLabel: UILabel!

    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
//        if selected {
//            self.accessoryType = .checkmark
//        }else {
//            self.accessoryType = .none
//        }
    }

}
