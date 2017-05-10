//
//  LogViewController.swift
//  ThroughWall
//
//  Created by Bingo on 10/05/2017.
//  Copyright © 2017 Wu Bin. All rights reserved.
//

import UIKit
import CocoaLumberjack

class LogViewController: UIViewController {

    @IBOutlet weak var logTextView: UITextView!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        loadLog()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func loadLog() {
        DDLog.add(DDTTYLogger.sharedInstance)
        let fileManager = FileManager.default
        var url = fileManager.containerURL(forSecurityApplicationGroupIdentifier: groupName)!
        url.appendPathComponent(PacketTunnelProviderLogFolderName)
        
        let logFileManager = DDLogFileManagerDefault(logsDirectory: url.path)
        let fileLogger: DDFileLogger = DDFileLogger(logFileManager: logFileManager) // File Logger
        
        var content = ""
        
        for filePath in fileLogger.logFileManager.sortedLogFilePaths {
            if fileManager.fileExists(atPath: filePath) {
                do {
                    let temp = try String(contentsOfFile: filePath, encoding: String.Encoding.utf8)
                    content = temp + content
                    
                } catch {
                    print(error)
                }
            }
        }
        DispatchQueue.main.async {
            self.logTextView.text = content
        }
    }

    @IBAction func clearHistory(_ sender: UIBarButtonItem) {

        let fileManager = FileManager.default
        var url = fileManager.containerURL(forSecurityApplicationGroupIdentifier: groupName)!
        url.appendPathComponent(PacketTunnelProviderLogFolderName)

        let logFileManager = DDLogFileManagerDefault(logsDirectory: url.path)
        let fileLogger: DDFileLogger = DDFileLogger(logFileManager: logFileManager) // File Logger

        fileLogger.rollLogFile {
            do {
                for filePath in fileLogger.logFileManager.sortedLogFilePaths {
                    try fileManager.removeItem(atPath: filePath)
                }
                self.loadLog()
            }
            catch {
                let alertController = UIAlertController(title: "Error", message: "\(error)", preferredStyle: .alert)
                let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                
                alertController.addAction(okAction)
                
                self.present(alertController, animated: true, completion: nil)
            }
        }
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
