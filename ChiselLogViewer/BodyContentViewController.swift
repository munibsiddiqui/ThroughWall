//
//  BodyContentViewController.swift
//  ChiselLogViewer
//
//  Created by Bingo on 09/07/2017.
//  Copyright © 2017 Wu Bin. All rights reserved.
//

import Cocoa

class BodyContentViewController: NSViewController {
    
    var hostTraffic: HostTraffic?
    var isRequestBody = true
    var data: Data?
    var parseURL: URL!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        if let _hostTraffic = hostTraffic {
            if isRequestBody {
                if let fileName = _hostTraffic.requestWholeBody?.fileName {
                    
                    let url = parseURL.appendingPathComponent(fileName)
                    do {
                        data = try Data(contentsOf: url)
                    }catch{
                        print(error)
                    }
                }
            } else {
                if let fileName = _hostTraffic.responseWholeBody?.fileName {
                    
                    let url = parseURL.appendingPathComponent(fileName)
                    do {
                        data = try Data(contentsOf: url)
                    }catch{
                        print(error)
                    }
                }
            }
        }
    }
    
    @IBAction func saveDocument(_ sender: AnyObject) {
        let dialog = NSSavePanel();
        
//        dialog.title = "Choose a .txt file";
        dialog.showsResizeIndicator = true;
        dialog.showsHiddenFiles = false;
        dialog.canCreateDirectories = true;
        
        if (dialog.runModal() == NSApplication.ModalResponse.OK) {
            let result = dialog.url // Pathname of the file
            if let _data = data {
                do {
                    try _data.write(to: result!)
                } catch {
                    print(error)
                }
            }
            
        } else {
            // User clicked on "Cancel"
            return
        }
    }
    
    @IBAction func cancel(_ sender: NSButton) {
        dismiss(nil)
    }
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        guard let tabViewController = segue.destinationController as? NSTabViewController else { return }
        for controller in tabViewController.childViewControllers {
            if let _controller = controller as? HexViewController {
                _controller.data = data
            } else if let _controller = controller as? PictureViewController {
                _controller.data = data
            }
        }
    }
    
}
