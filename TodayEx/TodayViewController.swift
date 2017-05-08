//
//  TodayViewController.swift
//  TodayEx
//
//  Created by Wu Bin on 16/11/2016.
//  Copyright © 2016 Wu Bin. All rights reserved.
//

import UIKit
import NotificationCenter
import NetworkExtension
import Fabric
import Crashlytics

class TodayViewController: UIViewController, NCWidgetProviding, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var upLoad: UILabel!
    @IBOutlet weak var downLoad: UILabel!
    @IBOutlet weak var vpnName: UILabel!
    @IBOutlet weak var controlSwitch: UISwitch!
    @IBOutlet weak var statusText: UILabel!
    @IBOutlet weak var tableview: UITableView!

    var proxyConfigs = [ProxyConfig]()
    var selectedServerIndex = 0

    let notificaiton = CFNotificationCenterGetDarwinNotifyCenter()
    var observer: UnsafeRawPointer!

    var currentVPNManager: NETunnelProviderManager? {
        willSet {

            DispatchQueue.main.async {
                self.controlSwitch.isEnabled = true
                self.vpnName.text = (newValue?.protocolConfiguration as! NETunnelProviderProtocol).providerConfiguration?["description"] as? String
            }
        }
    }


    var currentVPNStatusIndicator: NEVPNStatus = .invalid {
        willSet {
            switch newValue {
            case .connecting:
                statusText.text = "Connecting..."
//                currentVPNStatusLamp.image = UIImage(named: "OrangeDot")
                break
            case .connected:
                statusText.text = "Connected"
//                currentVPNStatusLamp.image = UIImage(named: "GreenDot")
                controlSwitch.isOn = true
                break
            case .disconnecting:
                self.statusText.text = "Disconnecting..."
//                currentVPNStatusLamp.image = UIImage(named: "OrangeDot")
                break
            case .disconnected:
                self.statusText.text = "Disconnected"
//                currentVPNStatusLamp.image = UIImage(named: "GrayDot")
                controlSwitch.isOn = false
                self.downLoad.text = "0 B/s"
                self.upLoad.text = "0 B/s"
                break
            default:
//                on = false
//                currentVPNStatusLabel.text = "Not Connected"
//                currentVPNStatusLamp.image = UIImage(named: "GrayDot")
                break
            }
        }
    }

//    required init?(coder aDecoder: NSCoder) {
//        super.init(coder: aDecoder)
////        Fabric.with([Crashlytics.self])
//        Crashlytics.start(withAPIKey: "ea6ae7041e03704c8768e183adaa548fa1192da8")
//    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view from its nib.

        extensionContext?.widgetLargestAvailableDisplayMode = .expanded

        tableview.tableFooterView = UIView()
//        tableview.backgroundColor = UIColor.groupTableViewBackground

        RuleFileUpdateController().tryUpdateRuleFileFromBundleFile()

        SiteConfigController().convertOldServer { newManager in
            print("completed")

            if newManager != nil {
                self.currentVPNManager = newManager
                self.currentVPNStatusIndicator = self.currentVPNManager!.connection.status
            }
            self.proxyConfigs = SiteConfigController().readSiteConfigsFromConfigFile()
            if let index = SiteConfigController().getSelectedServerIndex() {
                self.selectedServerIndex = index
            }

            //TODO
            self.tableview.reloadData()
        }

    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        observer = UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let name = DarwinNotifications.updateWidget.rawValue

        CFNotificationCenterAddObserver(notificaiton, observer, { (_, observer, name, _, _) in
            if let observer = observer, let name = name {

                // Extract pointer to `self` from void pointer:
                let mySelf = Unmanaged<TodayViewController>.fromOpaque(observer).takeUnretainedValue()
                // Call instance method:
                mySelf.darwinNotification(name: name.rawValue as String)
            }
        }, name as CFString, nil, .deliverImmediately)
        NotificationCenter.default.addObserver(self, selector: #selector(TodayViewController.VPNStatusDidChange(_:)), name: NSNotification.Name.NEVPNStatusDidChange, object: nil)
    }

    func widgetActiveDisplayModeDidChange(_ activeDisplayMode: NCWidgetDisplayMode, withMaximumSize maxSize: CGSize) {
        if activeDisplayMode == .expanded {
            proxyConfigs = SiteConfigController().readSiteConfigsFromConfigFile()
            tableview.reloadData()
            preferredContentSize = CGSize(width: 0.0, height: Double(110 + 44 * proxyConfigs.count))
        } else if activeDisplayMode == .compact {
            preferredContentSize = maxSize
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        CFNotificationCenterRemoveEveryObserver(notificaiton, observer)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NEVPNStatusDidChange, object: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }



    @IBAction func vpnSwitchClicked(_ sender: UISwitch) {
        let on = sender.isOn
        if let manager = self.currentVPNManager {
            manager.loadFromPreferences(completionHandler: { (_error) in
                if let error = _error {
                    print(error)
                    sender.isOn = false
                } else {
                    if self.trigerVPNManager(withManager: manager, shouldON: on) == false {
                        sender.isOn = false
                    }
                }
            })
        } else {
//            if proxyConfigs.count > selectedServerIndex {
//                let proxyConfig = proxyConfigs[selectedServerIndex]
//                SiteConfigController().forceSaveToManager(withConfig: proxyConfig, withCompletionHandler: { (_manager) in
//                    if let manager = _manager {
//                        self.currentVPNManager = manager
//                        manager.loadFromPreferences(completionHandler: { (_error) in
//                            if let error = _error {
//                                print(error)
//                                sender.isOn = false
//                            } else {
//                                if self.trigerVPNManager(withManager: manager, shouldON: on) == false {
//                                    sender.isOn = false
//                                }
//                            }
//                        })
//                    } else {
//                        sender.isOn = false
//                    }
//                })
//            } else {
//                sender.isOn = false
//            }
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
        } else {
            print("!!!!!")
        }
    }

    func widgetPerformUpdate(_ completionHandler: (@escaping (NCUpdateResult) -> Void)) {
        // Perform any setup necessary in order to update the view.

        // If an error is encountered, use NCUpdateResult.Failed
        // If there's no update required, use NCUpdateResult.NoData
        // If there's an update, use NCUpdateResult.NewData

        completionHandler(NCUpdateResult.newData)
    }

    func darwinNotification(name: String) {
        switch name {
        case DarwinNotifications.updateWidget.rawValue:
            updateWidget()
        default:
            break
        }
    }

    func updateWidget() {
        let defaults = UserDefaults(suiteName: groupName)
        if let downloadCount = defaults?.value(forKey: downloadCountKey) as? Int {
            DispatchQueue.main.async {
                self.downLoad.text = self.formatSpeed(downloadCount)
            }
        }
        if let uploadCount = defaults?.value(forKey: uploadCountKey) as? Int {
            DispatchQueue.main.async {
                self.upLoad.text = self.formatSpeed(uploadCount)
            }
        }
    }

    func formatSpeed(_ speed: Int) -> String {
        switch speed {
        case 0 ..< 1024:
            return String.init(format: "%d B/s", speed)
        case 1024 ..< 1048576:
            return String.init(format: "%.1f KB/s", Double(speed) / 1024)
        default:
            return String.init(format: "%.1f MB/s", Double(speed) / 1048576)
        }
    }



    // MARK: - Table view data source

    func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return proxyConfigs.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "vpnListCell", for: indexPath) as! VPNTableViewContTableViewCell
        cell.VPNNameLabel.text = proxyConfigs[indexPath.row].getValue(byItem: "description")
        if let delayValue = proxyConfigs[indexPath.row].getValue(byItem: "delay") {
            if let intDelayValue = Int(delayValue) {
                switch intDelayValue {
                case -1:
                    cell.VPNPingValueLabel.attributedText = NSAttributedString(string: "Timeout", attributes: [NSForegroundColorAttributeName: UIColor.red])
                case 0 ..< 100:
                    cell.VPNPingValueLabel.attributedText = NSAttributedString(string: "\(delayValue) ms", attributes: [NSForegroundColorAttributeName: UIColor.init(red: 0.24, green: 0.545, blue: 0.153, alpha: 1.0)])
                default:
                    cell.VPNPingValueLabel.attributedText = NSAttributedString(string: "\(delayValue) ms", attributes: [NSForegroundColorAttributeName: UIColor.black])
                }
            } else {
                cell.VPNPingValueLabel.text = ""
            }
//            cell.VPNPingValueLabel.text = delayValue + " ms"
        } else {
            cell.VPNPingValueLabel.text = "Unknown"
        }

        if indexPath.row == selectedServerIndex {
//            cell.setSelected(true, animated: false)
            cell.accessoryType = .checkmark
            vpnName.text = cell.VPNNameLabel.text
        } else {
            cell.accessoryType = .none
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)

        if let currentManager = currentVPNManager {
            if currentManager.connection.status == .connected || currentManager.connection.status == .connecting {
                return
            } else {
                let oldIndexPath = IndexPath(row: selectedServerIndex, section: 0)
                tableView.cellForRow(at: oldIndexPath)?.accessoryType = .none
                tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
                selectedServerIndex = indexPath.row

                SiteConfigController().save(withConfig: proxyConfigs[indexPath.row], intoManager: currentManager, completionHander: {
                    DispatchQueue.main.async {
                        self.vpnName.text = (currentManager.protocolConfiguration as! NETunnelProviderProtocol).providerConfiguration?["description"] as? String
                    }
                })
            }
        }
        self.selectedServerIndex = indexPath.row
        SiteConfigController().setSelectedServerIndex(withValue: indexPath.row)
        tableView.reloadData()

    }

}
