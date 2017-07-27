//
//  PictureViewController.swift
//  ChiselLogViewer
//
//  Created by Bingo on 10/07/2017.
//  Copyright © 2017 Wu Bin. All rights reserved.
//

import Cocoa

class PictureViewController: NSViewController {

    @IBOutlet weak var imageView: NSImageView!
    
    var data: Data?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        showImage()
    }
    
    func showImage() {
        guard let _data = data else {
            return
        }
        if let image = NSImage(data: _data) {
            imageView.image = image
        }
    }
}
