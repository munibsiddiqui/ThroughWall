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

    var currentVPNManager: NETunnelProviderManager? {
        willSet {
            if let vpnManager = newValue {
                self.navigationItem.title = (vpnManager.protocolConfiguration as! NETunnelProviderProtocol).providerConfiguration!["description"] as? String
            }
        }
    }

    var currentVPNStatusLabel = UILabel()
    var currentVPNStatusLamp = UIImageView()
    var vpnStatusSwitch = UISwitch()
//    var blockADSwitch = UISwitch()
//    var globalModeSwitch = UISwitch()
    
    var proxyConfigs = [ProxyConfig]()
    var selectedServerIndex = 0
    var willEditServerIndex = -1
    var icmpPing: ICMPPing?

    var currentVPNStatusIndicator: NEVPNStatus = .invalid {
        willSet {
            var on = false
            switch newValue {
            case .connecting:
                on = true
                currentVPNStatusLabel.text = "Connecting..."
                currentVPNStatusLamp.image = UIImage(named: "OrangeDot")
//                blockADSwitch.isEnabled = false
//                globalModeSwitch.isEnabled = false
                break
            case .connected:
                on = true
                currentVPNStatusLabel.text = "Connected"
                currentVPNStatusLamp.image = UIImage(named: "GreenDot")
//                blockADSwitch.isEnabled = false
//                globalModeSwitch.isEnabled = false
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
//                blockADSwitch.isEnabled = true
//                globalModeSwitch.isEnabled = true
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
//        blockADSwitch.addTarget(self, action: #selector(MainViewController.blockADSwitchValueDidChange(_:)), for: .valueChanged)
//        globalModeSwitch.addTarget(self, action: #selector(MainViewController.globalModeSwitchDidChange(_:)), for: .valueChanged)
        tableView.tableFooterView = UIView()
        tableView.backgroundColor = UIColor.groupTableViewBackground
        tableView.refreshControl = UIRefreshControl()
        tableView.refreshControl?.attributedTitle = NSAttributedString(string: "Pull to ping servers")
        tableView.refreshControl?.addTarget(self, action: #selector(refresh(sender:)), for: UIControlEvents.valueChanged)
//        tableView.addSubview(refreshControl) // not required when using UITableViewController
        
        
        RuleFileUpdateController().tryUpdateRuleFileFromBundleFile()
//        readSettings()

        SiteConfigController().convertOldServer { newManager in
            print("completed")
            self.currentVPNManager = newManager
            self.proxyConfigs = SiteConfigController().readSiteConfigsFromConfigFile()
            if let index = SiteConfigController().getSelectedServerIndex() {
                self.selectedServerIndex = index
            }

            self.tableView.reloadData()
        }
        NotificationCenter.default.addObserver(self, selector: #selector(MainViewController.deleteEditingVPN), name: NSNotification.Name(rawValue: kDeleteEditingVPN), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(saveVPN(_:)), name: NSNotification.Name(rawValue: kSaveVPN), object: nil)
    }

    
    func refresh(sender:AnyObject) {
        // Code to refresh table view
        icmpPing = ICMPPing(withHostName: "www.apple.com", intervalTime: 1, repeatTimes: 5)
        icmpPing?.start { (delay) in
            
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.tableView.refreshControl?.endRefreshing()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationItem.title = "VPN"

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


    func vpnStatusSwitchValueDidChange(_ sender: UISwitch) {
        let on = sender.isOn
        if let manager = self.currentVPNManager {
            manager.loadFromPreferences(completionHandler: { (_error) in
                if let error = _error{
                    print(error)
                    sender.isOn = false
                }else {
                    if self.trigerVPNManager(withManager: manager, shouldON: sender.isOn) == false {
                        sender.isOn = false
                    }
                }
            })
        } else {
            if proxyConfigs.count > selectedServerIndex {
                let proxyConfig = proxyConfigs[selectedServerIndex]
                SiteConfigController().forceSaveToManager(withConfig: proxyConfig, withCompletionHandler: { (_manager) in
                    if let manager = _manager {
                        self.currentVPNManager = manager
                        manager.loadFromPreferences(completionHandler: { (_error) in
                            if let error = _error{
                                print(error)
                                sender.isOn = false
                            }else {
                                if self.trigerVPNManager(withManager: manager, shouldON: on) == false {
                                    sender.isOn = false
                                }
                            }
                        })
                    } else {
                        sender.isOn = false
                    }
                })
            } else {
                sender.isOn = false
            }
        }
    }

    func trigerVPNManager(withManager manger: NETunnelProviderManager, shouldON on: Bool) -> Bool {
        var result = true
        if on {
            do {
                try manger.connection.startVPNTunnel()
            } catch {
                print(error)
                result = false
            }
        } else {
            manger.connection.stopVPNTunnel()
        }
        return result
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
            //servers status section
            return 1
        case 1:
            //server list section
            return proxyConfigs.count + 1
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
        } else {
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
            let cell = tableView.dequeueReusableCell(withIdentifier: "status", for: indexPath)
            cell.textLabel?.text = "Status"
            currentVPNStatusLabel = cell.detailTextLabel!
            cell.accessoryView = vpnStatusSwitch
            currentVPNStatusLamp = cell.imageView!
            cell.selectionStyle = .none
            return cell
        case 1:
            if indexPath.row < proxyConfigs.count {
                let cell = tableView.dequeueReusableCell(withIdentifier: "list", for: indexPath)

                cell.detailTextLabel?.text = proxyConfigs[indexPath.row].getValue(byItem: "server")
                cell.textLabel?.text = proxyConfigs[indexPath.row].getValue(byItem: "description")
                if indexPath.row == selectedServerIndex {
                    cell.imageView?.image = UIImage(named: "checkmark")
                } else {
                    cell.imageView?.image = UIImage(named: "checkmark_empty")
                }
                return cell
            } else {
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
        if indexPath.section == 0 && indexPath.row == 2 {
            self.performSegue(withIdentifier: "rule", sender: nil)
        } else if indexPath.section == 1 {
            if indexPath.row < proxyConfigs.count {
                tableView.deselectRow(at: indexPath, animated: true)
                if let currentManager = currentVPNManager {
                    SiteConfigController().save(withConfig: proxyConfigs[indexPath.row], intoManager: currentManager, completionHander: {
                    })
                }
                self.selectedServerIndex = indexPath.row
                SiteConfigController().setSelectedServerIndex(withValue: indexPath.row)
                tableView.reloadData()
            } else {
                addConfigure()
            }
        }
    }


    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        if indexPath.row < proxyConfigs.count {
            willEditServerIndex = indexPath.row
            self.performSegue(withIdentifier: "configure", sender: nil)
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
        willEditServerIndex = -1
        self.performSegue(withIdentifier: "configure", sender: nil)
    }

    func saveVPN(_ notification: NSNotification) {
        if willEditServerIndex == -1 {
            //add
            if let newConfig = notification.userInfo?["proxyConfig"] as? ProxyConfig {
                proxyConfigs.append(newConfig)
                SiteConfigController().writeIntoSiteConfigFile(withConfigs: proxyConfigs)
                tableView.reloadData()
            }
        } else {
            //save
            SiteConfigController().writeIntoSiteConfigFile(withConfigs: proxyConfigs)
            tableView.reloadData()
        }
    }

    func deleteEditingVPN() {
        let selectedServer = proxyConfigs[selectedServerIndex]
        proxyConfigs.remove(at: willEditServerIndex)
        if let newSelectedServerIndex = proxyConfigs.index(of: selectedServer) {
            selectedServerIndex = newSelectedServerIndex
            SiteConfigController().setSelectedServerIndex(withValue: selectedServerIndex)
        } else {
            selectedServerIndex = 0
            SiteConfigController().setSelectedServerIndex(withValue: selectedServerIndex)
        }
        SiteConfigController().writeIntoSiteConfigFile(withConfigs: proxyConfigs)
        tableView.reloadData()
    }


    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        if segue.identifier == "configure" {
            let destination = segue.destination as! ConfigureViewController
            if willEditServerIndex != -1 {
                destination.proxyConfig = proxyConfigs[willEditServerIndex]
            }
        }
    }
}
