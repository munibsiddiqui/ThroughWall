//
//  SelectionFieldCell.swift
//  ThroughWall
//
//  Created by Bin on 17/11/2016.
//  Copyright © 2016 Wu Bin. All rights reserved.
//

import UIKit

class SelectionFieldCell: UITableViewCell {
    
    @IBOutlet weak var item: UILabel!
    @IBOutlet weak var selection: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
