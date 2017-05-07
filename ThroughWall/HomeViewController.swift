//
//  HomeViewController.swift
//  ThroughWall
//
//  Created by Bingo on 05/05/2017.
//  Copyright © 2017 Wu Bin. All rights reserved.
//

import UIKit
import NetworkExtension

class HomeViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var backgroundView: UIView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var operationAreaView: UIView!
    @IBOutlet weak var tableViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var currentVPNStatusLabel: UILabel!

    var addedBackground = false
    var selectedServerIndex = 0
    var willEditServerIndex = -1
    var proxyConfigs = [ProxyConfig]()
    var icmpPing: ICMPPing?
    var currentVPNStatusLamp = UIImageView()

    let waveAnimationayer = CAReplicatorLayer()
    let buttonLayer = CALayer()

    var instanceCount = 0
    let waveDuration: Double = 1.0
    let waveStep: CGFloat = 15
    var buttonDimension: CGFloat {
        return buttonLayer.frame.width
    }

    var currentVPNManager: NETunnelProviderManager? {
        willSet {
//            if let vpnManager = newValue {
//                self.navigationItem.title = (vpnManager.protocolConfiguration as! NETunnelProviderProtocol).providerConfiguration!["description"] as? String
//            }
        }
    }

    var currentVPNStatusIndicator: NEVPNStatus = .invalid {
        willSet {
//            var on = false
            switch newValue {
            case .connecting:
//                on = true
                currentVPNStatusLabel.text = "Connecting..."
                currentVPNStatusLamp.image = UIImage(named: "OrangeDot")
//                break
            case .connected:
//                on = true
                currentVPNStatusLabel.text = "Connected"
                currentVPNStatusLamp.image = UIImage(named: "GreenDot")
//                break
            case .disconnecting:
//                on = false
                currentVPNStatusLabel.text = "Disconnecting..."
                currentVPNStatusLamp.image = UIImage(named: "OrangeDot")
//                break
            case .disconnected:
//                on = false
                currentVPNStatusLabel.text = "Disconnected"
                currentVPNStatusLamp.image = UIImage(named: "GrayDot")
//                break
            default:
//                on = false
                currentVPNStatusLabel.text = "Disconnected"
                currentVPNStatusLamp.image = UIImage(named: "GrayDot")
                break
            }
//            vpnStatusSwitch.isOn = on
            
            setOperationArea()
        }
    }


    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        sleepToDelayWelcomePage()
        setTopArear()
        setupTableView()
        tryUpdateRuleFile()
        convertToNewServerStyle()
        registerNotificationWhenLoaded()

    }

    deinit {
        removeNotificationObserver()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


    override func viewDidLayoutSubviews() {
        if addedBackground {
            backgroundView.layer.sublayers?[0].removeFromSuperlayer()
        }
        addLayersToOperationArea()
        setOperationArea()
        setFadeBackground(withTopColor: topUIColor, bottomColor: bottomUIColor)
        reloadTable()
        addedBackground = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        NotificationCenter.default.addObserver(self, selector: #selector(VPNStatusDidChange(_:)), name: NSNotification.Name.NEVPNStatusDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(setOperationArea), name: .UIApplicationWillEnterForeground, object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NEVPNStatusDidChange, object: nil)
        NotificationCenter.default.removeObserver(self, name: .UIApplicationWillEnterForeground, object: nil)
    }

    // MARK: - Tools


    func addLayersToOperationArea() {

        let miniDimension = (operationAreaView.frame.width < operationAreaView.frame.height ? operationAreaView.frame.width : operationAreaView.frame.height)
        buttonLayer.frame = CGRect(origin: .zero, size: .init(width: miniDimension / 3, height: miniDimension / 3))
        buttonLayer.position = CGPoint(x: operationAreaView.frame.width / 2, y: operationAreaView.frame.height / 2)

        waveAnimationayer.frame = CGRect(origin: .zero, size: operationAreaView.frame.size)
        waveAnimationayer.position = CGPoint(x: operationAreaView.frame.width / 2, y: operationAreaView.frame.height / 2)

        addWaveAnimationLayer()
        addButtonLayer()
    }

    func addWaveAnimationLayer() {
        if let sublayers = operationAreaView.layer.sublayers {
            if sublayers.contains(waveAnimationayer) {
                return
            }
        }
        operationAreaView.layer.addSublayer(waveAnimationayer)
    }

    func addButtonLayer() {
        if let sublayers = operationAreaView.layer.sublayers {
            if sublayers.contains(buttonLayer) {
                return
            }
        }
        operationAreaView.layer.addSublayer(buttonLayer)


    }

    func getOffStateCGPath(withDimension dimension: CGFloat) -> CGPath {
        let combinedPath = CGMutablePath()

        let circlePath = UIBezierPath(arcCenter: CGPoint(x: dimension / 2.0, y: dimension / 2.0), radius: dimension / 2.0, startAngle: -CGFloat.pi * 120 / 180, endAngle: -CGFloat.pi * 60 / 180, clockwise: false)

        combinedPath.addPath(circlePath.cgPath)

        let linePath = UIBezierPath()

        linePath.move(to: CGPoint(x: dimension / 2, y: dimension / 2))
        linePath.addLine(to: CGPoint(x: dimension / 2, y: 0))

        combinedPath.addPath(linePath.cgPath)

        return combinedPath
    }

    func getAddStateCGPath(withDimension dimension: CGFloat) -> (CGPath, CGPath) {
        let combinedPath = CGMutablePath()

        let circlePath = UIBezierPath(arcCenter: CGPoint(x: dimension / 2.0, y: dimension / 2.0), radius: dimension / 2.0, startAngle: 0, endAngle: CGFloat.pi * 2, clockwise: false)

        let horizantalLinePath = UIBezierPath()
        horizantalLinePath.move(to: CGPoint(x: dimension / 2 - 30, y: dimension / 2))
        horizantalLinePath.addLine(to: CGPoint(x: dimension / 2 + 30, y: dimension / 2))
        combinedPath.addPath(horizantalLinePath.cgPath)

        let verticalLinePath = UIBezierPath()
        verticalLinePath.move(to: CGPoint(x: dimension / 2, y: dimension / 2 - 30))
        verticalLinePath.addLine(to: CGPoint(x: dimension / 2, y: dimension / 2 + 30))
        combinedPath.addPath(verticalLinePath.cgPath)

        return (circlePath.cgPath, combinedPath)
    }

    func addBaseColorLayerToButtonLayer(withCentrePoint point: CGPoint, andRadius radius: CGFloat, andColor color: UIColor) {
        let colorLayer = CAShapeLayer()
        buttonLayer.addSublayer(colorLayer)
        colorLayer.frame = CGRect(origin: .zero, size: buttonLayer.frame.size)

        let circlePath = UIBezierPath(arcCenter: point, radius: radius, startAngle: 0, endAngle: CGFloat.pi * 2, clockwise: true)

        colorLayer.path = circlePath.cgPath
        colorLayer.fillColor = color.cgColor
    }


    func addBaseColorLayerToButtonLayer() {

        let dimension = buttonDimension

        addBaseColorLayerToButtonLayer(withCentrePoint: CGPoint(x: dimension / 2.0, y: dimension / 2.0), andRadius: dimension / 2.0 + 60, andColor: UIColor(red: 255.0 / 255.0, green: 88.0 / 255.0, blue: 24.0 / 255.0, alpha: 0.14))

        addBaseColorLayerToButtonLayer(withCentrePoint: CGPoint(x: dimension / 2.0, y: dimension / 2.0), andRadius: dimension / 2.0 + 30, andColor: UIColor(red: 255.0 / 255.0, green: 88.0 / 255.0, blue: 24.0 / 255.0, alpha: 0.22))
    }

    func drawOffStateButton() {

        buttonLayer.sublayers = nil

        addBaseColorLayerToButtonLayer()

        let iconLayer = CAShapeLayer()

        buttonLayer.addSublayer(iconLayer)
        iconLayer.frame = CGRect(origin: .zero, size: buttonLayer.frame.size)

        let dimension: CGFloat = buttonDimension

        iconLayer.path = getOffStateCGPath(withDimension: dimension)
        iconLayer.fillColor = UIColor.clear.cgColor
        iconLayer.strokeColor = UIColor.white.cgColor
        iconLayer.lineWidth = 12
        iconLayer.lineCap = kCALineCapRound
    }

    func drawOnStateButton() {
        buttonLayer.sublayers = nil
        
        addBaseColorLayerToButtonLayer()
        
        let iconLayer = CAShapeLayer()
        
        buttonLayer.addSublayer(iconLayer)
        iconLayer.frame = CGRect(origin: .zero, size: buttonLayer.frame.size)
        
        let dimension: CGFloat = buttonDimension
        
        iconLayer.path = getOffStateCGPath(withDimension: dimension)
        iconLayer.fillColor = UIColor.clear.cgColor
        iconLayer.strokeColor = UIColor.green.cgColor
        iconLayer.lineWidth = 12
        iconLayer.lineCap = kCALineCapRound
    }

    func drawAddServerButton() {
        buttonLayer.sublayers = nil

        let circleLayer = CAShapeLayer()
        let crossLayer = CAShapeLayer()
        buttonLayer.addSublayer(circleLayer)
        buttonLayer.addSublayer(crossLayer)

        let dimension: CGFloat = buttonDimension * 3 / 2

        circleLayer.frame = CGRect(origin: .zero, size: CGSize(width: dimension, height: dimension))
        crossLayer.frame = CGRect(origin: .zero, size: CGSize(width: dimension, height: dimension))

        circleLayer.position = CGPoint(x: buttonDimension / 2, y: buttonDimension / 2)
        crossLayer.position = CGPoint(x: buttonDimension / 2, y: buttonDimension / 2)

        let (circlePath, crossPath) = getAddStateCGPath(withDimension: dimension)

        circleLayer.path = circlePath
        circleLayer.fillColor = UIColor.clear.cgColor
        circleLayer.strokeColor = UIColor.white.cgColor
        circleLayer.lineWidth = 2

        crossLayer.path = crossPath
        crossLayer.fillColor = UIColor.clear.cgColor
        crossLayer.strokeColor = UIColor.white.cgColor
        crossLayer.lineWidth = 6

    }

    func connectionAnimationStart() {

        waveAnimationayer.sublayers = nil

        let circleLayer = CAShapeLayer()

        waveAnimationayer.addSublayer(circleLayer)

        circleLayer.frame = CGRect(origin: .zero, size: waveAnimationayer.frame.size)

        addAnimationToCircleLayer(circleLayer)

        waveAnimationayer.instanceCount = instanceCount
        waveAnimationayer.instanceDelay = waveDuration / CFTimeInterval(instanceCount)
    }

    func connectionAnimationEnd() {
        waveAnimationayer.removeAllAnimations()
        waveAnimationayer.sublayers = nil
    }


    func addAnimationToCircleLayer(_ circleLayer: CAShapeLayer) {

        var eRadius = ((waveAnimationayer.frame.width < waveAnimationayer.frame.height ? waveAnimationayer.frame.width : waveAnimationayer.frame.height)) / 2
        let bRadius = buttonDimension / 2 + 3 * waveStep

        instanceCount = Int((eRadius - bRadius) / 2 / waveStep) + 1

        eRadius = CGFloat(instanceCount) * 2 * waveStep + bRadius

        let beginCirclePath = UIBezierPath(arcCenter: CGPoint(x: waveAnimationayer.frame.size.width / 2.0, y: waveAnimationayer.frame.size.height / 2.0), radius: bRadius, startAngle: 0.0, endAngle: CGFloat(Double.pi * 2.0), clockwise: true)


        let endCirclePath = UIBezierPath(arcCenter: CGPoint(x: waveAnimationayer.frame.size.width / 2.0, y: waveAnimationayer.frame.size.height / 2.0), radius: eRadius, startAngle: 0.0, endAngle: CGFloat(Double.pi * 2.0), clockwise: true)

        circleLayer.path = beginCirclePath.cgPath
        circleLayer.fillColor = UIColor.clear.cgColor
        circleLayer.strokeColor = UIColor(red: 255.0 / 255.0, green: 88.0 / 255.0, blue: 24.0 / 255.0, alpha: 0.14).cgColor
        circleLayer.lineWidth = 2 * waveStep
        circleLayer.opacity = 0

        let fadeOut = CABasicAnimation(keyPath: "opacity")
        fadeOut.fromValue = 1
        fadeOut.toValue = 0
        fadeOut.duration = waveDuration
        fadeOut.repeatCount = Float.greatestFiniteMagnitude
        circleLayer.add(fadeOut, forKey: nil)

        let pathAdmin = CABasicAnimation(keyPath: "path")
        pathAdmin.fromValue = circleLayer.path
        pathAdmin.toValue = endCirclePath.cgPath
        pathAdmin.duration = waveDuration
        pathAdmin.repeatCount = Float.greatestFiniteMagnitude
        circleLayer.add(pathAdmin, forKey: nil)

        let colorFade = CABasicAnimation(keyPath: "strokeColor")
        colorFade.fromValue = topUIColor.cgColor
        colorFade.toValue = UIColor.white.cgColor
        colorFade.duration = waveDuration
        colorFade.repeatCount = Float.greatestFiniteMagnitude
        circleLayer.add(colorFade, forKey: nil)
    }


    func setFadeBackground(withTopColor topColor: UIColor, bottomColor: UIColor) {
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [topColor.cgColor, bottomColor.cgColor]
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.frame = backgroundView.frame
        backgroundView.layer.insertSublayer(gradientLayer, at: 0)
    }



    func setOperationArea() {
        if proxyConfigs.count == 0 {
            drawAddServerButton()
        } else {
            switch currentVPNStatusIndicator {
            case .disconnected:
                drawOffStateButton()
                connectionAnimationEnd()
            case .connecting:
                drawOnStateButton()
                connectionAnimationStart()
            case .connected:
                drawOnStateButton()
                connectionAnimationEnd()
            case .disconnecting:
                drawOffStateButton()
                connectionAnimationStart()
            default:
                drawOffStateButton()
                connectionAnimationEnd()
            }
        }
    }


    func sleepToDelayWelcomePage() {
        Thread.sleep(forTimeInterval: 1.0)
    }

    func setTopArear() {
        navigationController?.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName: UIColor.white]
        navigationController?.navigationBar.tintColor = UIColor.white
        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.setBackgroundImage(image(fromColor: topUIColor), for: .any, barMetrics: .default)
        navigationController?.navigationBar.shadowImage = UIImage()
        self.navigationItem.title = "Chisel"
    }

    func setupTableView() {
        tableView.tableFooterView = UIView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.refreshControl = UIRefreshControl()
        //        tableView.refreshControl?.attributedTitle = NSAttributedString(string: "Pull to ping servers")
        tableView.refreshControl?.addTarget(self, action: #selector(testServerDelay(sender:)), for: UIControlEvents.valueChanged)
    }

    func reloadTable() {
        if proxyConfigs.count == 0 {
            if tableViewTopConstraint.multiplier != 1.0 {
                tableViewTopConstraint = tableViewTopConstraint.setMultiplier(multiplier: 1.0)
                DispatchQueue.main.async {
                    self.view.layoutIfNeeded()
                    // change to add
//                    if let manager = self.currentVPNManager {
//                        manager.connection.stopVPNTunnel()
//                    }
                    
                    self.setOperationArea()
                }
            }
        } else {
            if tableViewTopConstraint.multiplier != 0.64 {
                tableViewTopConstraint = tableViewTopConstraint.setMultiplier(multiplier: 0.64)
                DispatchQueue.main.async {
                    self.view.layoutIfNeeded()
                    // change to connection
                    self.setOperationArea()
                }
            }
        }
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }

    func tryUpdateRuleFile() {
        RuleFileUpdateController().tryUpdateRuleFileFromBundleFile()
    }

    func convertToNewServerStyle() {
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

            self.reloadTable()
        }
    }

    func registerNotificationWhenLoaded() {
        NotificationCenter.default.addObserver(self, selector: #selector(deleteEditingVPN), name: NSNotification.Name(rawValue: kDeleteEditingVPN), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(saveVPN(_:)), name: NSNotification.Name(rawValue: kSaveVPN), object: nil)
    }

    func removeNotificationObserver() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: kDeleteEditingVPN), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: kSaveVPN), object: nil)
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


    func VPNStatusDidChange(_ notification: Notification?) {
        if let currentVPNManager = self.currentVPNManager {
            currentVPNStatusIndicator = currentVPNManager.connection.status
        } else {
            print("!!!!!")
        }
    }

    @IBAction func operationViewTouched(_ sender: UITapGestureRecognizer) {
        if proxyConfigs.count == 0 {
            addConfigure()
        } else {

            var shouldOn = true

            switch currentVPNStatusIndicator {
            case .invalid:
                fallthrough
            case .disconnected:
                break
            case .connected:
                shouldOn = false
            default:
                return
            }

            if let manager = self.currentVPNManager {
                manager.isEnabled = true
                manager.saveToPreferences(completionHandler: { error in
                    if error != nil {
                        return
                    }
                    manager.loadFromPreferences(completionHandler: { (_error) in
                        if let error = _error {
                            print(error)

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
                                    print(error)
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

    func setVPNManager(withManager manger: NETunnelProviderManager, shouldON on: Bool) -> Bool {
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

    // MARK: - Test Server Dalay

    func testServerDelay(sender: AnyObject) {
        if let manager = currentVPNManager {
            if manager.connection.status != .disconnected {

                let alertController = UIAlertController(title: "Ping is disabled now", message: "Ping is not accurate while connecting to a server", preferredStyle: .alert)
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

        return cell
    }

    // MARK: - Table view delegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if let currentManager = currentVPNManager {
            if currentManager.connection.status != .disconnected {
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

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
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
                proxyConfigs.append(newConfig)
                SiteConfigController().writeIntoSiteConfigFile(withConfigs: proxyConfigs)
                reloadTable()
            }
        } else {
            //save
            SiteConfigController().writeIntoSiteConfigFile(withConfigs: proxyConfigs)
            reloadTable()
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
