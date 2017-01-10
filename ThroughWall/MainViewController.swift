//
//  MainViewController.swift
//  ZzzVPN
//
//  Created by Bin on 6/2/16.
//  Copyright © 2016 BinWu. All rights reserved.
//

import UIKit
import NetworkExtension


class MainViewController: UITableViewController {
    
    var vpnManagers =  [NETunnelProviderManager]()
    var currentVPNManager: NETunnelProviderManager? {
        willSet{
            if let vpnManager = newValue{
                self.navigationItem.title = (vpnManager.protocolConfiguration as! NETunnelProviderProtocol).providerConfiguration!["description"] as? String
            }
        }
    }
    
    var willEditVPNManager: NETunnelProviderManager?
    
    var currentVPNStatusLabel = UILabel()
    var currentVPNStatusLamp = UIImageView()
    var vpnStatusSwitch = UISwitch()
    var blockADSwitch = UISwitch()
    var globalModeSwitch = UISwitch()
    
    var currentVPNStatusIndicator: NEVPNStatus = .invalid{
        willSet{
            var on = false
            switch newValue {
            case .connecting:
                on = true
                currentVPNStatusLabel.text = "Connecting..."
                currentVPNStatusLamp.image = UIImage(named: "OrangeDot")
                blockADSwitch.isEnabled = false
                globalModeSwitch.isEnabled = false
                break
            case .connected:
                on = true
                currentVPNStatusLabel.text = "Connected"
                currentVPNStatusLamp.image = UIImage(named: "GreenDot")
                blockADSwitch.isEnabled = false
                globalModeSwitch.isEnabled = false
                break
            case .disconnecting:
                on = false
                currentVPNStatusLabel.text = "Disconnecting..."
                currentVPNStatusLamp.image = UIImage(named: "OrangeDot")
                break
            case .disconnected:
                on = false
                currentVPNStatusLabel.text = "Not Connected"
                currentVPNStatusLamp.image = UIImage(named: "GrayDot")
                blockADSwitch.isEnabled = true
                globalModeSwitch.isEnabled = true
                break
            default:
                on = false
                currentVPNStatusLabel.text = "Not Connected"
                currentVPNStatusLamp.image = UIImage(named: "GrayDot")
                break
            }
            vpnStatusSwitch.isOn = on
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false
        
        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
        
        vpnStatusSwitch.addTarget(self, action: #selector(MainViewController.vpnStatusSwitchValueDidChange(_:)), for: .valueChanged)
        blockADSwitch.addTarget(self, action: #selector(MainViewController.blockADSwitchValueDidChange(_:)), for: .valueChanged)
        globalModeSwitch.addTarget(self, action: #selector(MainViewController.globalModeSwitchDidChange(_:)), for: .valueChanged)
        tableView.tableFooterView = UIView()
        tableView.backgroundColor = UIColor.groupTableViewBackground
        RuleFileUpdateController().tryUpdateRuleFileFromBundleFile()
        readSettings()
        NotificationCenter.default.addObserver(self, selector: #selector(MainViewController.deleteEditingVPN), name: NSNotification.Name(rawValue: kDeleteEditingVPN), object: nil)
        
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationItem.title = "VPN"
        self.loadConfigurationFromSystem()
        
        NotificationCenter.default.addObserver(self, selector: #selector(MainViewController.VPNStatusDidChange(_:)), name: NSNotification.Name.NEVPNStatusDidChange, object: nil)
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NEVPNStatusDidChange, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: kDeleteEditingVPN), object: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    func mergerOldServer() {
        NETunnelProviderManager.loadAllFromPreferences() { newManagers, error in
            if error == nil {
                guard let vpnManagers = newManagers else { return }
                self.vpnManagers.removeAll()
                for vpnManager in vpnManagers {
                    if let providerProtocol = vpnManager.protocolConfiguration as? NETunnelProviderProtocol {
                        if providerProtocol.providerBundleIdentifier == kTunnelProviderBundle {
                            if vpnManager.isEnabled {
                                self.currentVPNManager = vpnManager
                            }
                            self.vpnManagers.append(vpnManager)
                        }
                    }
                }
                self.vpnStatusSwitch.isEnabled = vpnManagers.count > 0
                self.tableView.reloadData()
                self.VPNStatusDidChange(nil)
            }else{
                print(error!)
            }
        }
        
    }
    
    
    func blockADSwitchValueDidChange(_ sender: UISwitch) {
        let defaults = UserDefaults.init(suiteName: groupName)
        defaults?.set(sender.isOn, forKey: blockADSetting)
        defaults?.synchronize()
    }
    
    func globalModeSwitchDidChange(_ sender: UISwitch) {
        let defaults = UserDefaults.init(suiteName: groupName)
        defaults?.set(sender.isOn, forKey: globalModeSetting)
        defaults?.synchronize()
    }
    
    func readSettings() {
        let defaults = UserDefaults.init(suiteName: groupName)
        var blockAD = false
        var globalMode = false
        
        if let block = defaults?.value(forKey: blockADSetting) as? Bool{
            blockAD = block
        }
        
        if let global = defaults?.value(forKey: globalModeSetting) as? Bool {
            globalMode = global
        }
        
        
        DispatchQueue.main.async {
            self.blockADSwitch.isOn = blockAD
            self.globalModeSwitch.isOn = globalMode
        }
        
    }
    
    func vpnStatusSwitchValueDidChange(_ sender: UISwitch) {
        if vpnManagers.count > 0 {
            if let currentVPNManager = self.currentVPNManager {
                if sender.isOn {
                    
                    do {
                        try currentVPNManager.connection.startVPNTunnel()
                    }catch {
                        print(error)
                    }
                    
                } else {
                    currentVPNManager.connection.stopVPNTunnel()
                }
            }else{
                sender.isOn = false
            }
        }else{
            sender.isOn = false
        }
    }
    
    func VPNStatusDidChange(_ notification: Notification?) {
        if let currentVPNManager = self.currentVPNManager {
            currentVPNStatusIndicator = currentVPNManager.connection.status
        }
    }
    
    
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        switch section {
        case 0:
            //block ad section
            //global mode section
            return 3
        case 1:
            //servers status section
            //server list section
            return vpnManagers.count + 2
        default:
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            //block ad section
            //global mode section
            return nil
        case 1:
            //servers status section
            //server list section
            return "Server"
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
            view.backgroundColor = UIColor.groupTableViewBackground
            view.addSubview(label)
            return view
        }else {
            let view = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: 18))
            view.backgroundColor = UIColor.groupTableViewBackground
            return view
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Configure the cell...
        switch indexPath.section {
        case 0:
            //block ad section
            if indexPath.row == 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "mainOption", for: indexPath)
                cell.textLabel?.text = "Reject Function (Block AD)"
                cell.accessoryView = blockADSwitch
                cell.selectionStyle = .none
                return cell
            }else if indexPath.row == 1{
                //global mode section
                let cell = tableView.dequeueReusableCell(withIdentifier: "mainOption", for: indexPath)
                cell.textLabel?.text = "Global Mode"
                cell.accessoryView = globalModeSwitch
                cell.selectionStyle = .none
                return cell
            }else{
                let cell = tableView.dequeueReusableCell(withIdentifier: "midStyle", for: indexPath)
                cell.textLabel?.text = "Import Proxy Rule..."
                return cell
            }
        case 1:
            if indexPath.row == 0 {
                //servers status section
                let cell = tableView.dequeueReusableCell(withIdentifier: "status", for: indexPath)
                cell.textLabel?.text = "Status"
                currentVPNStatusLabel =  cell.detailTextLabel!
                cell.accessoryView = vpnStatusSwitch
                currentVPNStatusLamp =  cell.imageView!
                cell.selectionStyle = .none
                return cell
            }else  if indexPath.row <= vpnManagers.count {
                //server list section
                let cell = tableView.dequeueReusableCell(withIdentifier: "list", for: indexPath)
                let vpnManager = self.vpnManagers[indexPath.row - 1]
                cell.detailTextLabel?.text = vpnManager.protocolConfiguration?.serverAddress
                cell.textLabel?.text = (vpnManager.protocolConfiguration as! NETunnelProviderProtocol).providerConfiguration!["description"] as? String
                if vpnManager.isEnabled {
                    cell.imageView?.image = UIImage(named: "checkmark")
                } else {
                    cell.imageView?.image = UIImage(named: "checkmark_empty")
                }
                return cell
            }else{
                //add server
                let cell = tableView.dequeueReusableCell(withIdentifier: "midStyle", for: indexPath)
                cell.textLabel?.text = "Add New Server..."
                return cell
            }
            
        default:
            let cell = tableView.dequeueReusableCell(withIdentifier: "mainOption", for: indexPath)
            return cell
        }
    }
    
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0  && indexPath.row == 2 {
            self.performSegue(withIdentifier: "rule", sender: nil)
        }else if indexPath.section == 1  && indexPath.row > 0  {
            if indexPath.row <= vpnManagers.count {
                tableView.deselectRow(at: indexPath, animated: true)
                let vpnManager = self.vpnManagers[indexPath.row - 1]
                vpnManager.isEnabled = true
                vpnManager.saveToPreferences { (error) -> Void in
                    self.loadConfigurationFromSystem()
                }
            }else{
                addConfigure()
            }            
        }
    }
    
    
    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        if indexPath.row > 0 && indexPath.row <= vpnManagers.count {
            willEditVPNManager = vpnManagers[indexPath.row - 1]
            let showDelete = true
            self.performSegue(withIdentifier: "configure", sender: showDelete)
        }
    }
    
    /*
     // Override to support conditional editing of the table view.
     override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
     // Return false if you do not want the specified item to be editable.
     return true
     }
     */
    
    /*
     // Override to support editing the table view.
     override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
     if editingStyle == .Delete {
     // Delete the row from the data source
     tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
     } else if editingStyle == .Insert {
     // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
     }
     }
     */
    
    /*
     // Override to support rearranging the table view.
     override func tableView(tableView: UITableView, moveRowAtIndexPath fromIndexPath: NSIndexPath, toIndexPath: NSIndexPath) {
     
     }
     */
    
    /*
     // Override to support conditional rearranging of the table view.
     override func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
     // Return false if you do not want the item to be re-orderable.
     return true
     }
     */
    func addConfigure() {
        let manager = NETunnelProviderManager()
        manager.loadFromPreferences {
            print("loadFromPreferences \($0)")
            let providerProtocol = NETunnelProviderProtocol()
            providerProtocol.providerBundleIdentifier = kTunnelProviderBundle
            providerProtocol.providerConfiguration = [String: AnyObject]()
            manager.protocolConfiguration = providerProtocol
        
            self.willEditVPNManager = manager
            let showDelete = false
            self.performSegue(withIdentifier: "configure", sender: showDelete)
        }
    }
    
    func loadConfigurationFromSystem() {
        NETunnelProviderManager.loadAllFromPreferences() { newManagers, error in
            if error == nil {
                guard let vpnManagers = newManagers else { return }
                self.vpnManagers.removeAll()
                for vpnManager in vpnManagers {
                    if let providerProtocol = vpnManager.protocolConfiguration as? NETunnelProviderProtocol {
                        if providerProtocol.providerBundleIdentifier == kTunnelProviderBundle {
                            if vpnManager.isEnabled {
                                self.currentVPNManager = vpnManager
                            }
                            self.vpnManagers.append(vpnManager)
                        }
                    }
                }
                self.vpnStatusSwitch.isEnabled = vpnManagers.count > 0
                self.tableView.reloadData()
                self.VPNStatusDidChange(nil)
            }else{
                print(error!)
            }
        }
    }
    
    
    func deleteEditingVPN() {
        willEditVPNManager?.removeFromPreferences(completionHandler: { (error) in
            if error == nil {
                DispatchQueue.main.async {
                    self.willEditVPNManager = nil
                    self.loadConfigurationFromSystem()
                }
            }
        })
    }
    
    
    // MARK: - Navigation
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        if segue.identifier == "configure" {
            let destination = segue.destination as! ConfigureViewController
            destination.vpnManager = willEditVPNManager
            let showDelete = sender as! Bool
            destination.showDelete = showDelete
        }
    }
}
