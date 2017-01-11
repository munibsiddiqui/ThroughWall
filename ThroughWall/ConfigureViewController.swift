//
//  ConfigureViewController.swift
//  ZzzVPN
//
//  Created by Bin on 6/2/16.
//  Copyright © 2016 BinWu. All rights reserved.
//

import UIKit
import NetworkExtension

let CustomizeOption = "Custom"

class Config: NSObject{
    
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
        "dns": "DNS"
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


class ConfigureViewController: UITableViewController {
    
    var vpnManager: NETunnelProviderManager!
    var showDelete = false
    var descriptionCell =  InputTextFieldCell()
    var serverCell =  InputTextFieldCell()
    var portCell =  InputTextFieldCell()
    var passwordCell = InputTextFieldCell()
    
    var proxyConfig = Config()
    
    var configuration: [String: AnyObject] {
        var conf = [String: AnyObject]()
        
        let items = proxyConfig.containedItems
        
        for item in items {
            conf[item] = proxyConfig.getValue(byItem: item) as AnyObject?
        }
        
        return conf
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false
        
        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
        
        if var proxy = (vpnManager.protocolConfiguration as! NETunnelProviderProtocol).providerConfiguration!["proxy"] as? String {
            if proxy == "SHADOWSOCKS" {
                proxy = "CUSTOM"
            }
            proxyConfig.currentProxy = proxy
  
            for item in proxyConfig.containedItems {
                if var value = (vpnManager.protocolConfiguration as! NETunnelProviderProtocol).providerConfiguration![item] as? String {
                    if value == "SHADOWSOCKS" {
                        value = "CUSTOM"
                    }
                    proxyConfig.setValue(byItem: item, value: value)
                }
            }
        }else{
            proxyConfig.currentProxy = "CUSTOM"
        }
        tableView.tableFooterView = UIView()
        tableView.backgroundColor = UIColor.groupTableViewBackground
        
        NotificationCenter.default.addObserver(self, selector: #selector(ConfigureViewController.didExtractedQRCode(notification:)), name: NSNotification.Name(rawValue: kQRCodeExtracted), object: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: kQRCodeExtracted), object: nil)
    }
    
    func didExtractedQRCode(notification: Notification) {
        if var ss = notification.userInfo?["string"] as? String{
            if let preRange = ss.range(of: "ss://") {
                ss.removeSubrange(preRange)
            }
            if let poundsignIndex = ss.range(of: "#")?.lowerBound {
                let removeRange = Range(uncheckedBounds: (lower: poundsignIndex, upper: ss.endIndex))
                ss.removeSubrange(removeRange)
            }
            let decodeData = Data.init(base64Encoded: ss)
            if let decodestring = String.init(data: decodeData ?? Data(), encoding: String.Encoding.utf8) {
                let components = decodestring.components(separatedBy: ":")
                if components.count == 3 {
                    var method = components[0]
                    let passwordHost = components[1]
                    let port = components[2]
                    
                    let components2 = passwordHost.components(separatedBy: "@")
                    if components2.count == 2 {
                        let password = components2[0]
                        let host = components2[1]
                        
                        if let range = method.range(of: "-auth") {
                            method.removeSubrange(range)
                        }
                        
                        proxyConfig.currentProxy = "CUSTOM"
                        proxyConfig.setValue(byItem: "description", value: "\(host):\(port)")
                        proxyConfig.setValue(byItem: "server", value: host)
                        proxyConfig.setValue(byItem: "port", value: port)
                        proxyConfig.setValue(byItem: "password", value: password)
                        proxyConfig.setValue(byItem: "method", value: method)
                        
                        DispatchQueue.main.async {
                            self.tableView.reloadData()
                        }
                        return
                    }
                }
            }
        }
        let alertController = UIAlertController(title: "Extract QRCode Failed", message: nil, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        
        alertController.addAction(okAction)
        DispatchQueue.main.async {
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        if section == 0 {
            return proxyConfig.containedItems.count
        }
        return 1
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 1 {
            return 40
        }
        return 0
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == 1 {
            //global mode section
            let view = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: 18))
            view.backgroundColor = UIColor.groupTableViewBackground
            return view
        }
        return nil
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let item = proxyConfig.containedItems[indexPath.row]
            
            if let _ = proxyConfig.getAvailableOptions(byItem: item) {
                //selection type
                let cell = tableView.dequeueReusableCell(withIdentifier: "selectionField", for: indexPath) as! SelectionFieldCell
                cell.item.text = proxyConfig.shownName[item]
                cell.selection.text = proxyConfig.getValue(byItem: item)
                return cell
            }else{
                //input type
                let cell = tableView.dequeueReusableCell(withIdentifier: "inputTextField", for: indexPath) as! InputTextFieldCell
                cell.item.text = proxyConfig.shownName[item]
                cell.itemDetail.text = proxyConfig.getValue(byItem: item)
//                cell.itemDetail.placeholder = placeholder
                
                cell.valueChanged = {
                    self.proxyConfig.setValue(byItem: item, value: cell.itemDetail.text!)
                }
                return cell
            }
        }
        if showDelete {
            let cell = tableView.dequeueReusableCell(withIdentifier: "deleteType", for: indexPath)
            return cell
        }else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "importQRType", for: indexPath)
            return cell
        }
        
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            let item = proxyConfig.containedItems[indexPath.row]
            if let _ = proxyConfig.getAvailableOptions(byItem: item){
                self.performSegue(withIdentifier: "selectInputDetail", sender: item)
                
            }
        }else{
            if showDelete {
                let alertController = UIAlertController(title: "Delete Proxy Server", message: nil, preferredStyle: .alert)
                let deleteAction = UIAlertAction(title: "Delete", style: .destructive, handler: { (_) in
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: kDeleteEditingVPN), object: nil)
                    DispatchQueue.main.async {
                        let _ = self.navigationController?.popViewController(animated: true)
                    }
                })
                let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
                
                alertController.addAction(cancelAction)
                alertController.addAction(deleteAction)
                
                self.present(alertController, animated: true, completion: nil)
                
            }else {
                performSegue(withIdentifier: "scanQRCode", sender: nil)
            }
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
    
    @IBAction func DoneTapped(_ sender: UIBarButtonItem) {
        view.endEditing(true)
        
        (vpnManager.protocolConfiguration as! NETunnelProviderProtocol).providerConfiguration = configuration
        vpnManager.protocolConfiguration?.serverAddress = configuration["server"] as? String
        vpnManager.localizedDescription = configuration["description"] as? String
        
        vpnManager.saveToPreferences { (error) -> Void in
            let _ = self.navigationController?.popViewController(animated: true)
        }
    }
    
    func updateSelectedResult(_ item: String, selected: String) {
//        print("\(item) \(selected)")
        proxyConfig.setSelection(item, selected: selected)
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    
     // MARK: - Navigation
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        if segue.identifier == "selectInputDetail" {
            let destination = segue.destination as! SelectInputViewController
            
            let item = sender as! String
            
            destination.delegate = self
            destination.item = item
            destination.selected = proxyConfig.getValue(byItem: item) ?? ""
            let (preset, custom) = proxyConfig.getAvailableOptions(byItem: item)!
            destination.presetSelections = preset
            destination.customSelection = custom
            
        }
    }
}
