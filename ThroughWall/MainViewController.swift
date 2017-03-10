//
//  MainViewController.swift
//  ZzzVPN
//
//  Created by Bin on 6/2/16.
//  Copyright © 2016 BinWu. All rights reserved.
//

import UIKit
import NetworkExtension


class ProxyConfig: NSObject{
    
    private let proxies = ["CUSTOM", "HTTP", "SOCKS5"]
    
    private let items = [
        "CUSTOM": ["proxy", "description", "server", "port", "password", "method", "dns"],
        "HTTP": ["proxy", "description", "server", "port", "user", "password"],
        "SOCKS5": ["proxy", "description", "server", "port", "user", "password"]
    ]
    
    private let defaults = [
        "CUSTOM": ["proxy": "CUSTOM", "method": "aes-256-cfb", "dns": "System Default"],
        "HTTP": ["proxy": "HTTP"],
        "SOCKS5": ["proxy": "SOCKS5"]
    ]
    
    private let availables = [
        "CUSTOM": [
            //            "proxy": [
            //                "preset": [
            //                    "CUSTOM", "HTTP", "SOCKS5"
            //                ]
            //            ],
            "method": [
                "preset": [
                    "table", "aes-128-ctr", "aes-192-ctr", "aes-256-ctr", "aes-128-cfb", "aes-192-cfb", "aes-256-cfb", "bf-cfb", "camellia-128-cfb", "camellia-192-cfb", "camellia-256-cfb", "cast5-cfb", "chacha20", "chacha20-ietf", "des-cfb", "idea-cfb", "rc2-cfb", "rc4", "rc4-md5", "salsa20", "seed-cfb"
                ]
            ],
            "dns": [
                "preset": [
                    "System Default"
                ],
                "customize": [
                    CustomizeOption
                ]
            ]
        ],
        "HTTP": [
            "proxy": [
                "preset": [
                    "CUSTOM", "HTTP", "SOCKS5"
                ]
            ]
        ],
        "SOCKS5": [
            "proxy": [
                "preset": [
                    "CUSTOM", "HTTP", "SOCKS5"
                ]
            ]
        ]
    ]
    
    let shownName = [
        "proxy": "ProxyType",
        "description": "Description",
        "server": "Server",
        "port": "Port",
        "user": "User",
        "password": "Password",
        "method": "Method",
        //        "dns": "DNS"
    ]
    
    private var _currentProxy = ""
    private var _containedItems = [String]()
    private var _values = [String: String]()
    private var _availableOptions = [String: [String: [String]]]()
    
    var currentProxy:String {
        set {
            if proxies.contains(newValue) {
                if _currentProxy == newValue {
                    return
                }
                _currentProxy = newValue
                if let items = items[currentProxy] {
                    _containedItems = items
                }
                if let defaults = defaults[currentProxy] {
                    _values = defaults
                }
                if let availavles = availables[currentProxy] {
                    _availableOptions = availavles
                }
            }
        }
        get {
            return _currentProxy
        }
    }
    
    var containedItems: [String] {
        return _containedItems
    }
    
    func setValue(byItem item: String, value: String) {
        _values[item] = value
    }
    
    func getValue(byItem item: String) -> String? {
        return _values[item]
    }
    
    func getAvailableOptions(byItem item: String) -> ([String], [String])?{
        
        if let itemOptions = _availableOptions[item]{
            var preset = [String]()
            var customize = [String]()
            if let temp =  itemOptions["preset"] {
                preset = temp
            }
            if let cust = itemOptions["customize"] {
                customize = cust
            }
            return (preset, customize)
            
        }else{
            return nil
        }
    }
    
    func setCustomOption(byItem item: String, option: String) {
        _availableOptions[item]?["customize"] = [option]
    }
    
    func setSelection(_ item: String, selected value: String) {
        //        print("\(item) \(selected)")
        if item == "proxy" {
            currentProxy =  value
            return
        }
        _values[item] = value
        if !_availableOptions[item]!["preset"]!.contains(value) {
            setCustomOption(byItem: item, option: value)
        }
    }
    
}


class SiteConfigController {
    func convertOldServer() {
        
        NETunnelProviderManager.loadAllFromPreferences() { newManagers, error in
            if error == nil {
                guard let vpnManagers = newManagers else { return }
                
                var proxyConfigs = [ProxyConfig]()
                for vpnManager in vpnManagers {
                    if let providerProtocol = vpnManager.protocolConfiguration as? NETunnelProviderProtocol {
                        if let _ = providerProtocol.providerConfiguration?[kConfigureVersion] {
                        }else {
                            if let conf = self.getConfig(fromManager: vpnManager) {
                                proxyConfigs.append(conf)
                                //delete old
                                
                            }
                        }
                        vpnManager.removeFromPreferences(completionHandler: nil)
                    }
                }
                if proxyConfigs.count > 0 {
                    self.writeIntoSiteConfigFile(withConfigs: proxyConfigs)
                    //add new
                    
                    let manager = NETunnelProviderManager()
                    manager.loadFromPreferences {
                        print("loadFromPreferences \($0)")
                        let providerProtocol = NETunnelProviderProtocol()
                        providerProtocol.providerBundleIdentifier = kTunnelProviderBundle
                        providerProtocol.providerConfiguration = ["server": "10.0.0.0", "description": "Chisel"]
                        manager.protocolConfiguration = providerProtocol
                        
                        manager.saveToPreferences(completionHandler: nil)
                    }
                }
            }else{
                print(error!)
            }
        }
    }
    
    func writeIntoSiteConfigFile(withConfigs configs: [ProxyConfig]) {
        let fileManager = FileManager.default
        
        guard var url = fileManager.containerURL(forSecurityApplicationGroupIdentifier: groupName) else {
            return
        }
        url.appendPathComponent(siteFileName)
        
        do {
            
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
            
            fileManager.createFile(atPath: url.path, contents: nil, attributes: nil)
            let filehandle = try FileHandle(forWritingTo: url)
            
            for config in configs {
                
                let items = config.containedItems
                //the first item should be proxy !!!
                for item in items {
                    let value = config.getValue(byItem: item)
                    filehandle.write("\(item):\(value)\n".data(using: String.Encoding.utf8)!)
                }
                filehandle.write("#\n".data(using: String.Encoding.utf8)!)
                
            }
            
            filehandle.synchronizeFile()
            
        }catch {
            print(error)
            return
        }
    }
    
    
    func readSiteConfigsFromConfigFile() -> [ProxyConfig] {
        var proxyConfigs = [ProxyConfig]()
        
        let fileManager = FileManager.default
        
        guard var url = fileManager.containerURL(forSecurityApplicationGroupIdentifier: groupName) else {
            return proxyConfigs
        }
        
        url.appendPathComponent(siteFileName)
        if !fileManager.fileExists(atPath: url.path) {
            return proxyConfigs
        }
        
        do {
            
            let content = try String(contentsOf: url, encoding: String.Encoding.utf8)
            let sites = content.components(separatedBy: "#\n")
            for site in sites {
                var items = site.components(separatedBy: "\n")
                let config = ProxyConfig()
                
                let firstItem = items[0]
                
                if firstItem.hasPrefix("proxy:") {
                    config.currentProxy = firstItem.substring(from: firstItem.index(firstItem.startIndex, offsetBy: 6))
                    items.removeFirst()
                    
                    for item in items {
                        let temp = item.components(separatedBy: ":")
                        let name = temp[0]
                        //                        let option = temp.count > 2 ? temp.dropFirst().joined(separator: ":") : temp[1]
                        let option: String
                        
                        if temp.count > 2 {
                            option = temp.dropFirst().joined(separator: ":")
                        }else {
                            option =  temp[1]
                        }
                        
                        if config.containedItems.contains(name) {
                            config.setValue(byItem: name, value: option)
                        }
                    }
                    
                }
                proxyConfigs.append(config)
            }
        }catch {
            print(error)
        }
        
        return proxyConfigs
    }
    
    
    private func getConfig(fromManager mamager: NETunnelProviderManager) -> ProxyConfig? {
        
        if var proxy = (mamager.protocolConfiguration as! NETunnelProviderProtocol).providerConfiguration!["proxy"] as? String {
            if proxy == "SHADOWSOCKS" {
                proxy = "CUSTOM"
            }
            let proxyConfig = ProxyConfig()
            proxyConfig.currentProxy = proxy
            
            for item in proxyConfig.containedItems {
                if var value = (mamager.protocolConfiguration as! NETunnelProviderProtocol).providerConfiguration![item] as? String {
                    if value == "SHADOWSOCKS" {
                        value = "CUSTOM"
                    }
                    proxyConfig.setValue(byItem: item, value: value)
                }
            }
            return proxyConfig
        }
        return nil
    }
}


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
            return 2
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
