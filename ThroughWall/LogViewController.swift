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

    var filePaths = [String]()
    var shouldAddLogLevelAction = true
    var fileLogger = DDFileLogger()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        loadLog()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func loadLog() {
//        DDLog.add(DDTTYLogger.sharedInstance)
        let fileManager = FileManager.default
//        var url = fileManager.containerURL(forSecurityApplicationGroupIdentifier: groupName)!
//        url.appendPathComponent(PacketTunnelProviderLogFolderName)
//
//        let logFileManager = DDLogFileManagerDefault(logsDirectory: url.path)
//        let fileLogger: DDFileLogger = DDFileLogger(logFileManager: logFileManager) // File Logger

        var content = ""

        for filePath in filePaths {
            if fileManager.fileExists(atPath: filePath) {
                do {
                    let temp = try String(contentsOfFile: filePath, encoding: String.Encoding.utf8)
                    content = temp + content

                } catch {
                    DDLogError("\(error)")
                }
            }
        }
        DispatchQueue.main.async {
            self.logTextView.text = content
        }
    }

    @IBAction func actions(_ sender: UIBarButtonItem) {

        let listController = UIAlertController(title: "Log Actions", message: nil, preferredStyle: .actionSheet)

        if shouldAddLogLevelAction {
            for logLevel in logLevels {
                let logLevelAction = UIAlertAction(title: "\(logLevel)", style: .default) { (_) in
                    let defaults = UserDefaults.init(suiteName: groupName)
                    defaults?.set(logLevel, forKey: klogLevel)
                    defaults?.synchronize()
                }
                listController.addAction(logLevelAction)
            }
        }

        let shareAction = UIAlertAction(title: "SHARE", style: .default) { (_) in
            let activityViewController = UIActivityViewController(activityItems: [self.logTextView.text], applicationActivities: nil)
            if let popoverPresentationController = activityViewController.popoverPresentationController {
                popoverPresentationController.barButtonItem = sender
            }
            self.present(activityViewController, animated: true, completion: nil)
        }
        listController.addAction(shareAction)

        let clearLog = UIAlertAction(title: "Clear Log", style: .destructive) { (_) in
//            if self.shouldAddLogLevelAction {
                let fileManager = FileManager.default
//                var url = fileManager.containerURL(forSecurityApplicationGroupIdentifier: groupName)!
//                url.appendPathComponent(PacketTunnelProviderLogFolderName)
//
//                let logFileManager = DDLogFileManagerDefault(logsDirectory: url.path)
//                let fileLogger: DDFileLogger = DDFileLogger(logFileManager: logFileManager) // File Logger

                self.fileLogger?.rollLogFile {
                    do {
                        for filePath in self.filePaths {
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
//            } else {
//
//            }
        }

        let cancelItem = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)

        listController.addAction(clearLog)
        listController.addAction(cancelItem)

        if let popoverPresentationController = listController.popoverPresentationController {
            popoverPresentationController.barButtonItem = sender
//            popoverController.sourceView = sender
//            popoverController.sourceRect = sender.bounds
        }

        present(listController, animated: true, completion: nil)


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
