//
//  HomeViewController.swift
//  ThroughWall
//
//  Created by Bingo on 05/05/2017.
//  Copyright © 2017 Wu Bin. All rights reserved.
//

import UIKit
import NetworkExtension
import CocoaLumberjack

class HomeViewController: UIViewController {

    // MARK: - IBOutlet
    @IBOutlet weak var backgroundView: UIView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var operationAreaView: OperationView!
    @IBOutlet weak var tableViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var currentVPNStatusLabel: UILabel!

    // MARK: - variable
    var addedBackground = false
    var selectedServerIndex = 0
    var willEditServerIndex = -1
    var proxyConfigs = [ProxyConfig]()
    var icmpPing: ICMPPing?
    var currentVPNStatusLamp = UIImageView()
    var currentVPNManager: NETunnelProviderManager?

    var currentVPNStatusIndicator: NEVPNStatus = .invalid {
        didSet {
            setOperationArea()
        }
    }

    // MARK: - constant
    let waveDuration: Double = 2
    let waveStep: CGFloat = 30

    // MARK: - viewDidLoad
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        sleepToDelayWelcomePage()
        setupDDLog()
        setTopArea()
        setTabBarArea()
        setupOperationArea()
        setupTableView()
        tryUpdateRuleFile()
        convertToNewServerStyle()
        registerNotificationWhenLoaded()
//        print(hardwareString())
        PurchaseValidator().getReceipt()
    }

//    func hardwareString() -> String {
//        var name: [Int32] = [CTL_HW, HW_MACHINE]
//        var size: Int = 2
//        sysctl(&name, 2, nil, &size, &name, 0)
//        var hw_machine = [CChar](repeating: 0, count: Int(size))
//        sysctl(&name, 2, &hw_machine, &size, &name, 0)
//
//        let hardware: String = String(cString: hw_machine)
//        return hardware
//    }

//    override func didReceiveMemoryWarning() {
//        super.didReceiveMemoryWarning()
//        // Dispose of any resources that can be recreated.
//    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        animationResume()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        operationAreaView.forceStopAnimation()
    }

    // MARK: - deinit
    deinit {
        removeNotificationObserver()
    }

    func removeNotificationObserver() {
        NotificationCenter.default.removeObserver(self, name: .NEVPNStatusDidChange, object: nil)
        NotificationCenter.default.removeObserver(self, name: .UIApplicationWillEnterForeground, object: nil)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: kDeleteEditingVPN), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: kSaveVPN), object: nil)
    }

    // MARK: - set Status Bar color
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    // MARK: - ViewDidLoad Setup session
    func sleepToDelayWelcomePage() {
        Thread.sleep(forTimeInterval: 1.0)
    }

    func setupDDLog() {
        DDLog.add(DDTTYLogger.sharedInstance)// TTY = Xcode console
//        DDLog.add(DDASLLogger.sharedInstance) // ASL = Apple System Logs

        let fileLogger: DDFileLogger = DDFileLogger() // File Logger
        fileLogger.rollingFrequency = TimeInterval(60 * 60) // 24 hours
        fileLogger.logFileManager.maximumNumberOfLogFiles = 7
        DDLog.add(fileLogger)

        DDLogInfo("------App Log Start------")

        #if DEBUG
            defaultDebugLevel = DDLogLevel.verbose
            DDLogDebug("Current Log Level: verbose")
        #else
            defaultDebugLevel = DDLogLevel.info
            DDLogDebug("Current Log Level: info")
        #endif

//        DDLogVerbose("\(fileLogger.currentLogFileInfo)")
    }


    func setTopArea() {
        navigationController?.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName: UIColor.white]
        navigationController?.navigationBar.tintColor = UIColor.white
        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.setBackgroundImage(image(fromColor: topUIColor), for: .any, barMetrics: .default)
        navigationController?.navigationBar.shadowImage = UIImage()
        self.navigationItem.title = "Chisel"
    }

    func setTabBarArea() {
        tabBarController?.tabBar.tintColor = UIColor.init(red: 255.0 / 255.0, green: 88.0 / 255.0, blue: 24.0 / 255.0, alpha: 1.0)
        tabBarController?.tabBar.backgroundImage = image(fromColor: UIColor.white)
        tabBarController?.tabBar.clipsToBounds = true
        tabBarController?.tabBar.shadowImage = UIImage()
    }

    func setupOperationArea() {
        //        operationAreaView.waveStep = waveStep
        operationAreaView.waveDuration = waveDuration
    }

    func setupTableView() {
        tableView.tableFooterView = UIView()
        tableView.backgroundColor = veryLightGrayUIColor
        tableView.delegate = self
        tableView.dataSource = self
        tableView.refreshControl = UIRefreshControl()
        //        tableView.refreshControl?.attributedTitle = NSAttributedString(string: "Pull to ping servers")
        tableView.refreshControl?.addTarget(self, action: #selector(testServerDelay(sender:)), for: UIControlEvents.valueChanged)
    }

    func tryUpdateRuleFile() {
        RuleFileUpdateController().tryUpdateRuleFileFromBundleFile()
    }

    func convertToNewServerStyle() {
        SiteConfigController().convertOldServer { newManager in
            DDLogDebug("completed")
            if newManager != nil {
                self.currentVPNManager = newManager
                self.currentVPNStatusIndicator = self.currentVPNManager!.connection.status
            }

            self.proxyConfigs = SiteConfigController().readSiteConfigsFromConfigFile()
            if let index = SiteConfigController().getSelectedServerIndex() {
                self.selectedServerIndex = index
            }

            self.reloadTable()
            self.setOperationArea()
        }
    }

    func registerNotificationWhenLoaded() {
        NotificationCenter.default.addObserver(self, selector: #selector(VPNStatusDidChange(_:)), name: .NEVPNStatusDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(animationResume), name: .UIApplicationWillEnterForeground, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(deleteEditingVPN), name: NSNotification.Name(rawValue: kDeleteEditingVPN), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(saveVPN(_:)), name: NSNotification.Name(rawValue: kSaveVPN), object: nil)
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

    // MARK: - Tools
    func setOperationArea() {
        DispatchQueue.main.async {
            if self.proxyConfigs.count == 0 {
                self.operationAreaView.setButtonImage(withImageName: "Add", withBackCircleDrawed: false)
                self.currentVPNStatusLabel.text = "Add"
            } else {
                switch self.currentVPNStatusIndicator {

                case .connecting:
                    self.operationAreaView.setButtonImage(withImageName: "Connected", withBackCircleDrawed: true)
                    self.operationAreaView.forceStartAnimation()
                    self.setVPNStatusIndicator(withLabelText: "Connecting...", andLampImageName: "OrangeDot")
                case .connected:
                    self.operationAreaView.setButtonImage(withImageName: "Connected", withBackCircleDrawed: true)
                    self.operationAreaView.stopAnimation()
                    self.setVPNStatusIndicator(withLabelText: "Connected", andLampImageName: "GreenDot")
                case .disconnecting:
                    self.operationAreaView.setButtonImage(withImageName: "Disconnected", withBackCircleDrawed: true)
                    self.operationAreaView.forceStartAnimation()
                    self.setVPNStatusIndicator(withLabelText: "Disconnecting...", andLampImageName: "OrangeDot")
                case .disconnected:
                    self.operationAreaView.setButtonImage(withImageName: "Disconnected", withBackCircleDrawed: true)
                    self.operationAreaView.stopAnimation()
                    self.setVPNStatusIndicator(withLabelText: "Disconnected", andLampImageName: "GrayDot")
                default:
                    self.operationAreaView.setButtonImage(withImageName: "Disconnected", withBackCircleDrawed: true)
                    self.operationAreaView.stopAnimation()
                    self.setVPNStatusIndicator(withLabelText: "Disconnected", andLampImageName: "GrayDot")
                }
            }
        }
    }

    func setVPNStatusIndicator(withLabelText text: String, andLampImageName imageName: String) {
        currentVPNStatusLabel.text = text
        currentVPNStatusLamp.image = UIImage(named: imageName)
        let defaults = UserDefaults()
        defaults.set(text, forKey: kCurrentManagerStatus)
        defaults.synchronize()
        DDLogDebug(text)
    }

    func reloadTable() {
        if proxyConfigs.count == 0 {
            if tableViewTopConstraint.multiplier != 1.0 {
                tableViewTopConstraint = tableViewTopConstraint.setMultiplier(multiplier: 1.0)
                DispatchQueue.main.async {
                    self.view.layoutIfNeeded()
                    self.setOperationArea()
                }
                currentVPNManager?.removeFromPreferences(completionHandler: { (error) in
                    if let error = error {
                        self.showError(error, title: "Delete failed")
                    }
                    self.currentVPNManager = nil
                })
            }
        } else {
            if tableViewTopConstraint.multiplier == 1.0 {
                tableViewTopConstraint = tableViewTopConstraint.setMultiplier(multiplier: 0.64)
                DispatchQueue.main.async {
                    self.view.layoutIfNeeded()
                    self.setOperationArea()
                }
            }
        }
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }

    // MARK: - kQRCodeExtracted notification
    func didExtractedQRCode(notification: Notification) {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: kQRCodeExtracted), object: nil)
        if let code = notification.userInfo?["string"] as? String {
            let proxyConfig = ProxyConfig()
            proxyConfig.currentProxy = "CUSTOM"
            let (_proxyConfig, succeed) = QRCodeProcess().decode(QRCode: code, intoProxyConfig: proxyConfig)
            if succeed {
                DispatchQueue.main.async {
                    self.addNewVPN(withNewConfig: _proxyConfig)
                }
                return
            }
        }
        presentExtractQRFailed()
    }

    func presentExtractQRFailed() {
        let alertController = UIAlertController(title: "Extract QRCode Failed", message: nil, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)

        alertController.addAction(okAction)
        DispatchQueue.main.async {
            self.present(alertController, animated: true, completion: nil)
        }
    }

    // MARK: - NEVPNStatusDidChange notification
    func VPNStatusDidChange(_ notification: Notification?) {
        if let currentVPNManager = self.currentVPNManager {
            currentVPNStatusIndicator = currentVPNManager.connection.status
        } else {
            DDLogError("empty manager. This should not happen!")
        }
    }

    // MARK: - UIApplicationWillEnterForeground notification
    func animationResume() {
        setOperationArea()
    }


    // MARK: - Scan QRCode Action
    @IBAction func scanQRCode(_ sender: UIBarButtonItem) {
        NotificationCenter.default.addObserver(self, selector: #selector(didExtractedQRCode(notification:)), name: NSNotification.Name(rawValue: kQRCodeExtracted), object: nil)
        performSegue(withIdentifier: "QRCodeScan", sender: nil)
    }

    // MARK: - Switch Button Action
    @IBAction func operationViewTouched(_ sender: UITapGestureRecognizer) {
        if proxyConfigs.count == 0 {
            addConfigure()
        } else {

            var shouldOn = true

            switch currentVPNStatusIndicator {
            case .invalid:
                fallthrough
            case .disconnecting:
                fallthrough
            case .disconnected:
                break
            case .connecting:
                fallthrough
            case .connected:
                shouldOn = false
            default:
                return
            }



            if let manager = self.currentVPNManager {
                SiteConfigController().save(withConfig: proxyConfigs[selectedServerIndex], intoManager: manager, completionHander: {
                    manager.loadFromPreferences(completionHandler: { (_error) in
                        if let error = _error {
                            self.showError(error, title: "load preferences 2")
                        } else {
                            if self.setVPNManager(withManager: manager, shouldON: shouldOn) == false {

                            }
                        }
                    })
                })
            } else {
                if proxyConfigs.count > selectedServerIndex {
                    let proxyConfig = proxyConfigs[selectedServerIndex]
                    SiteConfigController().forceSaveToManager(withConfig: proxyConfig, withCompletionHandler: { (_manager) in
                        if let manager = _manager {
                            self.currentVPNManager = manager
                            manager.loadFromPreferences(completionHandler: { (_error) in
                                if let error = _error {
                                    self.showError(error, title: "load preferences")
                                    return
                                }
                                if self.setVPNManager(withManager: manager, shouldON: shouldOn) == false {

                                }
                            })
                        }
                    })
                }
            }
        }
    }

    func showError(_ error: Error, title: String) {
        DispatchQueue.main.async {
            let alertController = UIAlertController(title: "\(title) Error", message: "\(error)", preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)

            alertController.addAction(okAction)

            self.present(alertController, animated: true, completion: nil)
        }
    }

    func setVPNManager(withManager manger: NETunnelProviderManager, shouldON on: Bool) -> Bool {
        var result = true
        if on {
            do {
                try manger.connection.startVPNTunnel()
                let userDefault = UserDefaults()
                if let _hintVersion = userDefault.value(forKey: kHintVersion) as? Int {
                    if _hintVersion < hintVersion {
                        tryShowWarning()
                    }
                } else {
                    tryShowWarning()
                }

            } catch {
                showError(error, title: "start vpn")

                result = false

            }
        } else {
            manger.connection.stopVPNTunnel()
        }
        return result
    }

    func tryShowWarning() {
        DispatchQueue.main.async {
            let alertController = UIAlertController(title: "Hint", message: "最近增加了SSR支持，如遇网络连接问题，请联系我。我会尽力修复问题。\nSSR support was added recently. If any networking problem happens, please do not hesitate to contact me. I'll try my best to fix it.", preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)

            alertController.addAction(okAction)

            self.present(alertController, animated: true, completion: nil)
            let userDefault = UserDefaults()
            userDefault.set(hintVersion, forKey: kHintVersion)
        }
    }

    // MARK: - Test Server Dalay
    func testServerDelay(sender: AnyObject) {
        if let manager = currentVPNManager {
            if manager.connection.status != .disconnected {

                let alertController = UIAlertController(title: "Ping is disabled now", message: "Ping is not accurate while connected to a server", preferredStyle: .alert)
                let okAction = UIAlertAction(title: "Done", style: .default, handler: { _ in
                    DispatchQueue.main.async {
                        self.tableView.refreshControl?.endRefreshing()
                        self.tableView.refreshControl?.attributedTitle = NSAttributedString(string: "")
                    }
                })

                alertController.addAction(okAction)

                self.present(alertController, animated: true, completion: nil)
                return
            }
        }
        testServerDelay(withIndex: 0)
    }

    func testServerDelay(withIndex index: Int) {
        if index < proxyConfigs.count {
            if let server = proxyConfigs[index].getValue(byItem: "server") {
                icmpPing = ICMPPing(withHostName: server, intervalTime: 1, repeatTimes: 1)
                DispatchQueue.main.async {
                    self.tableView.refreshControl?.attributedTitle = NSAttributedString(string: server)
                }
                icmpPing?.start { (delay) in
                    self.proxyConfigs[index].setValue(byItem: "delay", value: "\(delay)")
                    self.testServerDelay(withIndex: index + 1)
                }
            }
        } else {
            SiteConfigController().writeIntoSiteConfigFile(withConfigs: proxyConfigs)
            DispatchQueue.main.async {
                self.tableView.refreshControl?.endRefreshing()
                self.tableView.refreshControl?.attributedTitle = NSAttributedString(string: "")
                self.tableView.reloadData()
            }
        }
    }

    // MARK: - Server List Configure
    @IBAction func addConfigure(_ sender: UIBarButtonItem) {
        addConfigure()
    }

    func addConfigure() {
        willEditServerIndex = -1
        self.performSegue(withIdentifier: "configure", sender: nil)
    }

    func saveVPN(_ notification: NSNotification) {
        if willEditServerIndex == -1 {
            //add
            if let newConfig = notification.userInfo?["proxyConfig"] as? ProxyConfig {
                addNewVPN(withNewConfig: newConfig)
            }
        } else {
            //save

            SiteConfigController().writeIntoSiteConfigFile(withConfigs: proxyConfigs)
            reloadTable()
        }
    }

    func addNewVPN(withNewConfig newConfig: ProxyConfig) {
        proxyConfigs.append(newConfig)
        SiteConfigController().writeIntoSiteConfigFile(withConfigs: proxyConfigs)
        reloadTable()
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
        reloadTable()

        //TODO check table cell count
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


extension HomeViewController: UITableViewDelegate, UITableViewDataSource {

    // MARK: - Table view data source
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return proxyConfigs.count + 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        if indexPath.row == proxyConfigs.count {
            let cell = tableView.dequeueReusableCell(withIdentifier: "dragHint", for: indexPath)
            cell.separatorInset = UIEdgeInsetsMake(0.0, 0.0, 0.0, cell.bounds.size.width)
            cell.backgroundColor = veryLightGrayUIColor
            return cell
        }


        let cell = tableView.dequeueReusableCell(withIdentifier: "serverList", for: indexPath)

        let textLabel = cell.viewWithTag(1) as! UILabel
        textLabel.text = proxyConfigs[indexPath.row].getValue(byItem: "description")
        let detailTextLabel = cell.viewWithTag(2) as! UILabel
        detailTextLabel.text = (proxyConfigs[indexPath.row].getValue(byItem: "server") ?? "")
        let delayLabel = cell.viewWithTag(3) as! UILabel

        if let delayValue = proxyConfigs[indexPath.row].getValue(byItem: "delay") {
            if let intDelayValue = Int(delayValue) {
                switch intDelayValue {
                case -1:
                    delayLabel.attributedText = NSAttributedString(string: "Timeout", attributes: [NSForegroundColorAttributeName: UIColor.red])
                case 0 ..< 100:
                    delayLabel.attributedText = NSAttributedString(string: "\(delayValue) ms", attributes: [NSForegroundColorAttributeName: darkGreenUIColor])
                default:
                    delayLabel.attributedText = NSAttributedString(string: "\(delayValue) ms", attributes: [NSForegroundColorAttributeName: UIColor.black])
                }
            } else {
                delayLabel.text = ""
            }

        } else {
            delayLabel.attributedText = NSAttributedString(string: "? ms", attributes: [NSForegroundColorAttributeName: UIColor.orange])
        }


        if indexPath.row == selectedServerIndex {
            if let manager = currentVPNManager {
                switch manager.connection.status {
                case .connected:
                    cell.imageView?.image = UIImage(named: "GreenDot")
                case .connecting:
                    fallthrough
                case .disconnecting:
                    cell.imageView?.image = UIImage(named: "OrangeDot")
                default:
                    cell.imageView?.image = UIImage(named: "GrayDot")
                }
            } else {
                cell.imageView?.image = UIImage(named: "GrayDot")
            }
            currentVPNStatusLamp = cell.imageView!
            //            self.navigationItem.title = textLabel.text
        } else {
            cell.imageView?.image = UIImage(named: "TSDot")
        }

        cell.backgroundColor = veryLightGrayUIColor

        return cell
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if indexPath.row < proxyConfigs.count {
            return true
        }
        return false
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {

            let alertController = UIAlertController(title: "Delete Proxy Server?", message: nil, preferredStyle: .alert)
            let deleteAction = UIAlertAction(title: "Delete", style: .destructive, handler: { (_) in
                self.willEditServerIndex = indexPath.row
                self.deleteEditingVPN()
            })
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)

            alertController.addAction(cancelAction)
            alertController.addAction(deleteAction)

            self.present(alertController, animated: true, completion: nil)

        }
    }

    // MARK: - Table view delegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if indexPath.row >= proxyConfigs.count {
            return
        }

        if let currentManager = currentVPNManager {
            if currentManager.connection.status != .disconnected && selectedServerIndex != indexPath.row {
                //pop a alert
                let alertController = UIAlertController(title: "Error", message: "Please disconnect before changing server", preferredStyle: .alert)
                let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                alertController.addAction(okAction)
                self.present(alertController, animated: true, completion: nil)
                return
            } else {
                SiteConfigController().save(withConfig: proxyConfigs[indexPath.row], intoManager: currentManager, completionHander: {
                    //                    DispatchQueue.main.async {
                    //                        self.navigationItem.title = (currentManager.protocolConfiguration as! NETunnelProviderProtocol).providerConfiguration!["description"] as? String
                    //                    }
                })
            }
        }
        self.selectedServerIndex = indexPath.row
        SiteConfigController().setSelectedServerIndex(withValue: indexPath.row)
        reloadTable()
    }

    func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        if indexPath.row < proxyConfigs.count {
            willEditServerIndex = indexPath.row
            self.performSegue(withIdentifier: "configure", sender: nil)
        }
    }
}

extension NSLayoutConstraint {
    /**
     Change multiplier constraint
     
     - parameter multiplier: CGFloat
     - returns: NSLayoutConstraint
     */
    func setMultiplier(multiplier: CGFloat) -> NSLayoutConstraint {

        NSLayoutConstraint.deactivate([self])

        let newConstraint = NSLayoutConstraint(
            item: firstItem,
            attribute: firstAttribute,
            relatedBy: relation,
            toItem: secondItem,
            attribute: secondAttribute,
            multiplier: multiplier,
            constant: constant)

        newConstraint.priority = priority
        newConstraint.shouldBeArchived = self.shouldBeArchived
        newConstraint.identifier = self.identifier

        NSLayoutConstraint.activate([newConstraint])
        return newConstraint
    }
}

extension UINavigationController {
    open override var preferredStatusBarStyle: UIStatusBarStyle {
        if let style = topViewController?.preferredStatusBarStyle {
            return style
        }
        return .lightContent
    }
}
