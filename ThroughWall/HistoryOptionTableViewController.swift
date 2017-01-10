//
//  HistoryOptionTableViewController.swift
//  ThroughWall
//
//  Created by Bin on 28/12/2016.
//  Copyright © 2016 Wu Bin. All rights reserved.
//

import UIKit

class HistoryOptionTableViewController: UITableViewController {

    let notificaiton = CFNotificationCenterGetDarwinNotifyCenter()
    var observer: UnsafeRawPointer!
    var totalCount = 0
    let logRequestSwitch = UISwitch()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
        
        logRequestSwitch.addTarget(self, action: #selector(HistoryOptionTableViewController.trigerLogFunction), for: .valueChanged)
        
        let defaults = UserDefaults.init(suiteName: groupName)
        if let keyValue = defaults?.value(forKey: shouldParseTrafficKey) as? Bool {
            logRequestSwitch.isOn = keyValue
        }else{
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
    }
    
    func updateCell() {
        readProxyTrafficCount()
        DispatchQueue.main.async {
            let indexPath = IndexPath(row: 0, section: 0)
            self.tableView.reloadRows(at: [indexPath], with: .none)
        }
    }
    
    func trigerLogFunction() {
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
            fallthrough
        case 1:
            return 2
        case 2:
            return 3
        default:
            break
        }
        return 0
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case 0:
            if indexPath.row == 1 {
                performSegue(withIdentifier: "showHistoryFigure", sender: nil)
            }
        case 1:
            if indexPath.row == 1 {
                performSegue(withIdentifier: "showHistoryReqeust", sender: nil)
            }
        case 2:
            if indexPath.row == 0 {
                copyPacketTunnelProviderLogToDocument()
            }
        default:
            break
        }
    }
    
    func copyPacketTunnelProviderLogToDocument() {
        let fileManager = FileManager.default
        var logUrl = fileManager.containerURL(forSecurityApplicationGroupIdentifier: groupName)!
        logUrl.appendPathComponent(PacketTunnelProviderLogFolderName)
        var newUrl = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        newUrl.appendPathComponent(PacketTunnelProviderLogFolderName)
        
        
        do {
            if fileManager.fileExists(atPath: newUrl.path){
                try fileManager.removeItem(at: newUrl)
            }
            try fileManager.copyItem(at: logUrl, to: newUrl)
            let databaseUrl = CoreDataController.sharedInstance.getDatabaseUrl()
            try fileManager.copyItem(at: databaseUrl, to: newUrl.appendingPathComponent(CoreDataController.sharedInstance.getDatabaseName()))
        }catch{
            print(error)
        }
    
    }
    
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "Traffic Through Proxy"
        case 1:
            return "HTTP(S) Requests"
        case 2:
            return "Export Logs"
        default:
            return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "basicCell", for: indexPath)

        // Configure the cell...

        switch indexPath.section {
        case 0:
            if indexPath.row == 0 {
                let (scale,unit) = autoFitRange(maxValue: totalCount)
                cell.textLabel?.text = "\(totalCount/scale)\(unit) this month"
            }else{
                cell.textLabel?.text = "Traffic Figure"
                cell.accessoryType = .disclosureIndicator
            }
        case 1:
            if indexPath.row == 0 {
                cell.textLabel?.text = "Enable Logging Requset"
                cell.accessoryView = logRequestSwitch
            }else {
                cell.textLabel?.text = "Request Logs"
                cell.accessoryType = .disclosureIndicator
            }
        case 2:
            if indexPath.row == 0 {
                cell.textLabel?.text = "Copy to Document"
            }else if indexPath.row == 1 {
                cell.textLabel?.text = "Email"
            }else if indexPath.row   == 2 {
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
        case 1024 ..< 1024*1024:
            scale = 1024
            unit = "KB"
        case 1024*1024 ..< 1024*1024*1024:
            scale = 1024*1024
            unit = "MB"
        default:
            scale = 1024*1024*1024
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
