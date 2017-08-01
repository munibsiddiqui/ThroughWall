//
//  HistoryOptionTableViewController.swift
//  ThroughWall
//
//  Created by Bin on 28/12/2016.
//  Copyright © 2016 Wu Bin. All rights reserved.
//

import UIKit
import CocoaLumberjack
class HistoryOptionTableViewController: UITableViewController {

    let notificaiton = CFNotificationCenterGetDarwinNotifyCenter()
    var observer: UnsafeRawPointer!
    var totalCount = 0
    var date = ""
    let logRequestSwitch = UISwitch()
    var backgroundView = UIView()
    var downloadIndicator = UIActivityIndicatorView()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()

        tableView.tableFooterView = UIView()
        tableView.backgroundColor = veryLightGrayUIColor

        setTopArear()

        logRequestSwitch.addTarget(self, action: #selector(HistoryOptionTableViewController.trigerLogFunction), for: .valueChanged)

        let defaults = UserDefaults.init(suiteName: groupName)
        if let keyValue = defaults?.value(forKey: shouldParseTrafficKey) as? Bool {
            logRequestSwitch.isOn = keyValue
        } else {
            logRequestSwitch.isOn = false
            defaults?.set(false, forKey: shouldParseTrafficKey)
            defaults?.synchronize()
        }

        readProxyTrafficCount()

        observer = UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let name = DarwinNotifications.updateWidget.rawValue

        CFNotificationCenterAddObserver(notificaiton, observer, { (_, observer, name, _, _) in
            if let observer = observer, let name = name {

                // Extract pointer to `self` from void pointer:
                let mySelf = Unmanaged<HistoryOptionTableViewController>.fromOpaque(observer).takeUnretainedValue()
                // Call instance method:
                mySelf.darwinNotification(name: name.rawValue as String)
            }
        }, name as CFString, nil, .deliverImmediately)


        backgroundView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        backgroundView.center = CGPoint(x: view.bounds.width / 2, y: view.bounds.height / 2)
        backgroundView.backgroundColor = UIColor.darkGray
        backgroundView.layer.cornerRadius = 10
        backgroundView.clipsToBounds = true

        downloadIndicator = UIActivityIndicatorView(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        downloadIndicator.center = CGPoint(x: 50, y: 50)
        downloadIndicator.activityIndicatorViewStyle = .whiteLarge
        backgroundView.addSubview(downloadIndicator)
        downloadIndicator.startAnimating()

        backgroundView.isHidden = true

        #if DEBUG
            PAirSandbox.sharedInstance().enableSwipe()
        #endif
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !view.subviews.contains(backgroundView) {
            view.addSubview(backgroundView)
        }
        backgroundView.center = CGPoint(x: view.bounds.width / 2, y: view.bounds.height / 2)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    func setTopArear() {
        navigationController?.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName: UIColor.white]
        navigationController?.navigationBar.tintColor = UIColor.white
        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.setBackgroundImage(image(fromColor: topUIColor), for: .any, barMetrics: .default)
        navigationController?.navigationBar.shadowImage = UIImage()
        self.navigationItem.title = "History"
    }

    func image(fromColor color: UIColor) -> UIImage {
        let rect = CGRect(x: 0, y: 0, width: view.frame.size.width, height: view.frame.size.height)
        UIGraphicsBeginImageContext(rect.size)
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(color.cgColor)
        context?.fill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsGetCurrentContext()
        return image!
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


    func darwinNotification(name: String) {
        switch name {
        case DarwinNotifications.updateWidget.rawValue:
            updateCell()
        default:
            break
        }
    }

    func readProxyTrafficCount() {
        let defaults = UserDefaults(suiteName: groupName)
        if let downloadCount = defaults?.value(forKey: proxyDownloadCountKey) as? Int {
            if let uploadCount = defaults?.value(forKey: proxyUploadCountKey) as? Int {
                totalCount = downloadCount + uploadCount
            }
        }
        if let recordingDate = defaults?.value(forKey: recordingDateKey) as? String {
            date = recordingDate
        }
    }

    func updateCell() {
        readProxyTrafficCount()
        DispatchQueue.main.async {
            let indexPath = IndexPath(row: 0, section: 0)
            self.tableView.reloadRows(at: [indexPath], with: .none)
        }
    }

    func trigerLogFunction() {
        if logRequestSwitch.isOn {
            let alertController = UIAlertController(title: "Caution", message: "Logs will NOT be deleted automatically. You should delete logs manually.", preferredStyle: .alert)

            let dismissAction = UIAlertAction(title: "Dismmiss", style: .default, handler: { (_) in

            })

            alertController.addAction(dismissAction)

            self.present(alertController, animated: true, completion: nil)
        }

        let defaults = UserDefaults(suiteName: groupName)
        defaults?.set(logRequestSwitch.isOn, forKey: shouldParseTrafficKey)
        defaults?.synchronize()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 3
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        switch section {
        case 0:
            return 3
        case 1:
            return 2
        case 2:
            return 1
        default:
            break
        }
        return 0
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let rect = tableView.rectForRow(at: indexPath)
        switch indexPath.section {
        case 0:
            if indexPath.row == 1 {
                performSegue(withIdentifier: "showHistoryFigure", sender: nil)
            } else if indexPath.row == 2 {
                performSegue(withIdentifier: "showArchivedHistory", sender: nil)
            }
        case 1:
            if indexPath.row == 1 {
                performSegue(withIdentifier: "showHistoryReqeust", sender: nil)
            }
        case 2:
            if indexPath.row == 0 {
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                let vc = storyboard.instantiateViewController(withIdentifier: "LogTXTView") as! LogViewController

                let fileManager = FileManager.default
                var url = fileManager.containerURL(forSecurityApplicationGroupIdentifier: groupName)!
                url.appendPathComponent(PacketTunnelProviderLogFolderName)

                let logFileManager = DDLogFileManagerDefault(logsDirectory: url.path)
                let fileLogger: DDFileLogger = DDFileLogger(logFileManager: logFileManager) // File Logger
                vc.filePaths = fileLogger.logFileManager.sortedLogFilePaths
                vc.shouldAddLogLevelAction = true
                vc.fileLogger = fileLogger

                self.navigationController?.pushViewController(vc, animated: true)
            } else if indexPath.row == 1 {
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                let vc = storyboard.instantiateViewController(withIdentifier: "LogTXTView") as! LogViewController

                vc.filePaths = DDFileLogger().logFileManager.sortedLogFilePaths
                vc.shouldAddLogLevelAction = false

                self.navigationController?.pushViewController(vc, animated: true)
            } else if indexPath.row == 2 {
                backgroundView.isHidden = false
                copyPacketTunnelProviderLogToTempDir(withCompletion: {
                    self.shareExported(withRect: rect)
                })
            }
        default:
            break
        }
    }

    func copyPacketTunnelProviderLogToTempDir(withCompletion completion: @escaping (() -> Void)) {
        DispatchQueue.global().async {
            let fileManager = FileManager.default
            var logUrl = fileManager.containerURL(forSecurityApplicationGroupIdentifier: groupName)!
            logUrl.appendPathComponent(PacketTunnelProviderLogFolderName)

            let tmpurl = URL(fileURLWithPath: NSTemporaryDirectory())
            var newUrl = tmpurl.appendingPathComponent(PacketTunnelProviderLogFolderName)

            do {
                if fileManager.fileExists(atPath: newUrl.path) {
                    try fileManager.removeItem(at: newUrl)
                }
                try fileManager.copyItem(at: logUrl, to: newUrl)

                newUrl.appendPathComponent(databaseFolderName)

                let databaseUrl = CoreDataController.sharedInstance.getDatabaseUrl()

                try fileManager.copyItem(at: databaseUrl, to: newUrl)
                //            CoreDataController.sharedInstance.backupDatabase(toURL: newUrl)

                DispatchQueue.main.sync {
                    completion()
                }
            } catch {
                DDLogError("\(error)")
            }
        }
    }

    func shareExported(withRect rect: CGRect) {
        let tmpurl = URL(fileURLWithPath: NSTemporaryDirectory())
        let newUrl = tmpurl.appendingPathComponent(PacketTunnelProviderLogFolderName)

        let activityViewController = UIActivityViewController(activityItems: [newUrl], applicationActivities: nil)
        if let popoverPresentationController = activityViewController.popoverPresentationController {
            popoverPresentationController.sourceView = view
            popoverPresentationController.sourceRect = rect
        }
        DispatchQueue.main.async {
            self.present(activityViewController, animated: true, completion: nil)
            self.backgroundView.isHidden = true
        }
    }


    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "Traffic Through Proxy"
        case 1:
            return "HTTP(S) Requests"
        case 2:
            return "Logs"
        default:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if let _ = self.tableView(tableView, titleForHeaderInSection: section) {
            return 60
        }
        return 40
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if let header = self.tableView(tableView, titleForHeaderInSection: section) {
            //global mode section
            let view = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: 18))
            let label = UILabel(frame: CGRect(x: 10, y: 35, width: tableView.frame.width, height: 20))
            label.text = header
            label.textColor = UIColor.gray
            label.font = UIFont.boldSystemFont(ofSize: 16)
            view.backgroundColor = veryLightGrayUIColor
            view.addSubview(label)
            return view
        } else {
            let view = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: 18))
            view.backgroundColor = veryLightGrayUIColor
            return view
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "basicCell", for: indexPath)

        // Configure the cell...

        switch indexPath.section {
        case 0:
            if indexPath.row == 0 {
                let (scale, unit) = autoFitRange(maxValue: totalCount)
                if date == "" {
                    cell.textLabel?.text = "No traffic record now"
                } else {
                    cell.textLabel?.text = "\(date): \(String(format: "%.2f", Double(totalCount) / Double(scale))) \(unit)"
                }

            } else if indexPath.row == 1 {
                cell.textLabel?.text = "Traffic Figure"
                cell.accessoryType = .disclosureIndicator
            } else {
                cell.textLabel?.text = "Archive"
                cell.accessoryType = .disclosureIndicator
            }
        case 1:
            if indexPath.row == 0 {
                cell.textLabel?.text = "Enable Logging"
                cell.accessoryView = logRequestSwitch
            } else {
                cell.textLabel?.text = "Requests' Log"
                cell.accessoryType = .disclosureIndicator
            }
        case 2:
            if indexPath.row == 0 {
                cell.textLabel?.text = "Network's Log"
            } else if indexPath.row == 1 {
                cell.textLabel?.text = "App's Log"
            } else if indexPath.row == 2 {
                cell.textLabel?.text = "Export All Logs"
            } else if indexPath.row == -3 {
                cell.textLabel?.text = "Merge to Document"
            } else if indexPath.row == -2 {
                cell.textLabel?.text = "AirDrop"
            }
        default:
            break
        }

        return cell
    }


    func autoFitRange(maxValue: Int) -> (Int, String) {
        var scale = 1
        var unit = "B"
        switch maxValue {
        case 0 ..< 1024:
            break
        case 1024 ..< 1024 * 1024:
            scale = 1024
            unit = "KB"
        case 1024 * 1024 ..< 1024 * 1024 * 1024:
            scale = 1024 * 1024
            unit = "MB"
        default:
            scale = 1024 * 1024 * 1024
            unit = "GB"
        }
        return (scale, unit)
    }

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
