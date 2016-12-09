//
//  InputTextFieldCell.swift
//  ZzzVPN
//
//  Created by Bin on 6/2/16.
//  Copyright © 2016 BinWu. All rights reserved.
//

import UIKit

class InputTextFieldCell: UITableViewCell, UITextFieldDelegate {

    @IBOutlet weak var item: UILabel!
    @IBOutlet weak var itemDetail: UITextField!
    
    var valueChanged: ((Void) -> Void)?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        itemDetail.delegate = self
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        valueChanged?()
    }
}
