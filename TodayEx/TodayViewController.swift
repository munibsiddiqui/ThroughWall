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

class TodayViewController: UIViewController, NCWidgetProviding {
        
    @IBOutlet weak var upLoad: UILabel!
    @IBOutlet weak var downLoad: UILabel!
    @IBOutlet weak var vpnName: UILabel!
    @IBOutlet weak var controlSwitch: UISwitch!
    @IBOutlet weak var statusText: UILabel!
    
    let defaults = UserDefaults(suiteName: groupName)
    let notificaiton = CFNotificationCenterGetDarwinNotifyCenter()
    var observer: UnsafeRawPointer!
    var currentVPNManager: NETunnelProviderManager? {
        willSet {
        
            DispatchQueue.main.async {
                self.controlSwitch.isEnabled = true
                self.vpnName.text =  (newValue?.protocolConfiguration as! NETunnelProviderProtocol).providerConfiguration?["description"] as? String
                if let newManager = newValue {
                    switch newManager.connection.status {
                    case .connecting:
                        self.statusText.text = "Connecting..."
                    case .connected:
                        self.statusText.text = "Connected"
                        self.controlSwitch.isOn = true
                    case .disconnecting:
                        self.statusText.text = "Disconnecting..."
                    case .disconnected:
                        self.statusText.text = "Disconnected"
                        self.controlSwitch.isOn = false
                    default:
                        break
                    }
                }
                
            }
        }
    }
    
    
    var currentVPNStatusIndicator: NEVPNStatus = .invalid{
        willSet{
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view from its nib.
        
//        extensionContext?.widgetLargestAvailableDisplayMode = .expanded
        
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
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadVPN()
         NotificationCenter.default.addObserver(self, selector: #selector(TodayViewController.VPNStatusDidChange(_:)), name: NSNotification.Name.NEVPNStatusDidChange, object: nil)
    }
    
//    func widgetActiveDisplayModeDidChange(_ activeDisplayMode: NCWidgetDisplayMode, withMaximumSize maxSize: CGSize) {
//        if activeDisplayMode == .expanded {
//            preferredContentSize = CGSize(width: 0.0, height: 200.0)
//        } else if activeDisplayMode == .compact {
//            preferredContentSize = maxSize
//        }
//    }
    
    override func viewWillDisappear(_ animated: Bool) {
        CFNotificationCenterRemoveEveryObserver(notificaiton, observer)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NEVPNStatusDidChange, object: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    
    @IBAction func vpnSwitchClicked(_ sender: UISwitch) {
        if sender.isOn {
            do {
                try currentVPNManager?.connection.startVPNTunnel()
            }catch{
                
            }
        }else{
            currentVPNManager?.connection.stopVPNTunnel()
        }
    }
    
    func loadVPN() {
        NETunnelProviderManager.loadAllFromPreferences() { newManagers, error in
            if error == nil {
                guard let vpnManagers = newManagers else { return }
                for vpnManager in vpnManagers {
                    if let providerProtocol = vpnManager.protocolConfiguration as? NETunnelProviderProtocol {
                        if providerProtocol.providerBundleIdentifier == kTunnelProviderBundle {
                            if vpnManager.isEnabled {
                                self.currentVPNManager = vpnManager
                            }
                        }
                    }
                }
            }else{
                print(error!)
            }
        }
    }
    
    func VPNStatusDidChange(_ notification: Notification?) {
        if let currentVPNManager = self.currentVPNManager {
            currentVPNStatusIndicator = currentVPNManager.connection.status
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
            return String.init(format: "%.1f KB/s", Double(speed)/1024)
        default:
            return String.init(format: "%.1f MB/s", Double(speed)/1048576)
        }
    }
    
}
