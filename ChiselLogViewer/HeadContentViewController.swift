//
//  HeadContentViewController.swift
//  ChiselLogViewer
//
//  Created by Bingo on 09/07/2017.
//  Copyright © 2017 Wu Bin. All rights reserved.
//

import Cocoa

class HeadContentViewController: NSViewController {
    
    @IBOutlet var textView: NSTextView!
    
    var content = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        textView.string = content
    }
    
}
