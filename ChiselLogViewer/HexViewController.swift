//
//  HexViewController.swift
//  ChiselLogViewer
//
//  Created by Bingo on 10/07/2017.
//  Copyright © 2017 Wu Bin. All rights reserved.
//

import Cocoa

class HexViewController: NSViewController {

    @IBOutlet var textView: NSTextView!
    var data: Data?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        showHex()
    }
    
    func showHex() {
        if let data = data {
            let hexes = [UInt8](data)
            var str = ""
            var text = ""
            for (index, hex) in hexes.enumerated() {
                str = str + String(format: "%02X ", hex)
                
                let scalar = UnicodeScalar(hex)
                if iswprint(Int32(scalar.value)) == 0 {
                    text = text + "."
                }else{
                    text = text + String(scalar)
                }
                
                if index % 16 == 15 {
                    str = str + " ; " + text  + "\n"
                    text = ""
                }
            }
            textView.string = str
            textView.font = NSFont(name: "Menlo", size: 13)
        }
    }
}
