//
//  PacketTunnelProvider.swift
//  TWPacketTunnelProvider
//
//  Created by Wu Bin on 16/11/2016.
//  Copyright © 2016 Wu Bin. All rights reserved.
//

import NetworkExtension
import CocoaLumberjack
import SSRLib
import TunnelLib
import Fabric
import Crashlytics

class PacketTunnelProvider: NEPacketTunnelProvider {
    var pendingStartCompletion: ((Error?) -> Void)?
    var pendingStopCompletion: (() -> Void)?
    let ssrControler = SSRLibController()
    var lastPath: NWPath?
    var httpPort = 0
    var startTime = Date()
    let filePath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] + "/" + configFileName

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        // Add code here to start the process of connecting the tunnel.
        Fabric.with([Crashlytics.self])
        Answers.logCustomEvent(withName: "Start", customAttributes: ["time": "\(Date())"])

        setupDDLog()
        DDLogVerbose("Going to start VPN")
        pendingStartCompletion = completionHandler

        CoreDataController.sharedInstance.closeCrashLogs()

        Rule.sharedInstance.analyzeRuleFile()

        addObserver(self, forKeyPath: "defaultPath", options: NSKeyValueObservingOptions.new, context: nil)

        //Start shadowsocks_libev

        startShodowsocksClient { (shadowLibSocksPort, error) in
            if error != nil {
                self.pendingStartCompletion?(error)
                return
            }
            DDLogVerbose("shadowsocks port: \(shadowLibSocksPort)")

            NotificationCenter.default.addObserver(self, selector: #selector(PacketTunnelProvider.onShadowsocksClientClosed), name: NSNotification.Name(rawValue: Tun2SocksStoppedNotification), object: nil)
            self.startProxyManager(withSSPort: shadowLibSocksPort)
        }
    }

    func startProxyManager(withSSPort shadowLibSocksPort: Int) {
        //HTTP/HTTPS Proxy Setting
        HTTPProxyManager.shardInstance.startProxy(bindToPort: shadowLibSocksPort, callback: { (httpProxyPort, error) in

            if error != nil {
                self.pendingStartCompletion?(error)
                return
            }
            DDLogVerbose("http(s) port: \(httpProxyPort)")
            //                DDLogVerbose("\(Date().timeIntervalSince1970)")
            self.httpPort = httpProxyPort

            //socksTohttp
            Socks2HTTPS.sharedInstance.start(bindToPort: UInt16(httpProxyPort), callback: { (socksPortToHTTP, error) in
                DDLogVerbose("socksToHTTP port: \(socksPortToHTTP)")
                //                    DDLogVerbose("\(Date().timeIntervalSince1970)")
                //TunnelSetting
                self.setupTunnelWith(proxyPort: httpProxyPort, completionHandle: { (error) in
                    //Forward IP Packets
                    let error = TunnelManager.sharedInterface().startTunnel(withShadowsocksPort: socksPortToHTTP as NSNumber!, packetTunnelFlow: self.packetFlow)

                    if let _error = error {
                        DDLogVerbose("complete with \(_error)")
                    } else {
                        DDLogVerbose("complete")
                        Answers.logCustomEvent(withName: "StartComplete", customAttributes: nil)
                        self.startTime = Date()
                    }
                    //                        DDLogVerbose("\(Date().timeIntervalSince1970)")
                    self.pendingStartCompletion?(error)

                })

            })

        })
    }


    func setupDDLog() {
        DDLog.add(DDASLLogger.sharedInstance, with: DDLogLevel.warning)// ASL = Apple System Logs

        let fileManager = FileManager.default
        var url = fileManager.containerURL(forSecurityApplicationGroupIdentifier: groupName)!
        url.appendPathComponent(PacketTunnelProviderLogFolderName)

        let logFileManager = DDLogFileManagerDefault(logsDirectory: url.path)
        let fileLogger: DDFileLogger = DDFileLogger(logFileManager: logFileManager) // File Logger
        fileLogger.rollingFrequency = TimeInterval(60 * 60) // 1 hours
        fileLogger.logFileManager.maximumNumberOfLogFiles = 6 // 6 files
        fileLogger.maximumFileSize = 0
        DDLog.add(fileLogger)

        DDLogInfo("------Extension Log Start------")


        let defaults = UserDefaults.init(suiteName: groupName)
        if let logLevel = defaults?.value(forKey: klogLevel) as? String {
            DDLogError("Current Log Level: \(logLevel)")
            switch logLevel.lowercased() {
            case "off":
            defaultDebugLevel = DDLogLevel.off
            case "error":
            defaultDebugLevel = DDLogLevel.error
            case "warning":
            defaultDebugLevel = DDLogLevel.warning
            case "info":
            defaultDebugLevel = DDLogLevel.info
            case "debug":
            defaultDebugLevel = DDLogLevel.debug
            case "verbose":
            defaultDebugLevel = DDLogLevel.verbose
            case"all":
            defaultDebugLevel = DDLogLevel.all
            default:
            defaultDebugLevel = DDLogLevel.debug
            }
        } else {
            defaultDebugLevel = DDLogLevel.debug
            DDLogDebug("Current Log Level: debug")
        }

        DDLogVerbose("\(fileLogger.currentLogFileInfo)")
    }



    func startShodowsocksClient(callback: @escaping (Int, Error?) -> Void) {
        let conf = (self.protocolConfiguration as! NETunnelProviderProtocol).providerConfiguration! as [String: AnyObject]

        let server = conf["server"] as! String
        let port = Int(conf["port"] as! String)
        let password = conf["password"] as! String
        let method = conf["method"] as! String
        let protocol_ssr: String
        if let _protocol = conf["protocol"] as? String {
            protocol_ssr = _protocol
        } else {
            protocol_ssr = ""
        }
        let pro_param: String
        if let _pro_param = conf["proto_param"] as? String {
            pro_param = _pro_param
        } else {
            pro_param = ""
        }
        let obfs: String
        if let _obfs = conf["obfs"] as? String {
            obfs = _obfs
        } else {
            obfs = ""
        }
        let obfs_param: String
        if let _obfs_param = conf["obfs_param"] as? String {
            obfs_param = _obfs_param
        } else {
            obfs_param = ""
        }
//        BOOL ota = [json[@"ota"] boolValue];

        ssrControler.startShodowsocksClientWithhostAddress(server, hostPort: NSNumber(value: port!), hostPassword: password, authscheme: method, protocol: protocol_ssr, pro_para: pro_param, obfs: obfs, obfs_para: obfs_param) { (port, error) in
            callback(Int(port), error)
        }
    }

    func setupTunnelWith(proxyPort port: Int, completionHandle: @escaping (Error?) -> Void) {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "192.0.8.5")
        let ipv4Setting = NEIPv4Settings(addresses: ["192.0.8.1"], subnetMasks: ["255.255.255.0"])
        ipv4Setting.includedRoutes = [NEIPv4Route.default()]
        ipv4Setting.excludedRoutes = generateExcludedRoutes()

        settings.iPv4Settings = ipv4Setting
        settings.mtu = 1600

        let proxySettings = NEProxySettings()
        proxySettings.httpEnabled = true
        proxySettings.httpServer = NEProxyServer(address: "localhost", port: port)
        proxySettings.httpsEnabled = true
        proxySettings.httpsServer = NEProxyServer(address: "localhost", port: port)
        proxySettings.excludeSimpleHostnames = true

        proxySettings.exceptionList = ["api.smoot.apple.com",
            "configuration.apple.com",
            "xp.apple.com",
            "smp-device-content.apple.com",
            "guzzoni.apple.com",
            "captive.apple.com",
            "*.ess.apple.com",
            "*.push.apple.com",
            "*.push-apple.com.akadns.net"]

        settings.proxySettings = proxySettings
        let dnsSetting = NEDNSSettings.init(servers: DNSConfig.getSystemDnsServers() as! [String])
        dnsSetting.matchDomains = [""]
        settings.dnsSettings = dnsSetting

        self.setTunnelNetworkSettings(settings) { (error) in
            completionHandle(error)
        }
    }

    func generateExcludedRoutes() -> [NEIPv4Route] {
        let bypassTunRules = Rule.sharedInstance.getBypassTunRule()
        var result = [NEIPv4Route]()
        for rule in bypassTunRules {
            result.append(NEIPv4Route(destinationAddress: rule.0, subnetMask: rule.1))
        }
        return result
    }


    func onShadowsocksClientClosed() {
        DDLogDebug("onShadowsocksClientClosed")
        HTTPProxyManager.shardInstance.stopProxy()
        DDLogDebug("StopCompletion")
        DDLog.flushLog()

        if pendingStopCompletion != nil {
            pendingStopCompletion!()
        }
//        exit(EXIT_SUCCESS);
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {

        if keyPath == "defaultPath" {
            if defaultPath?.status != .satisfied {
                DDLogVerbose("defaultPath: not satisfied")
                lastPath = defaultPath
                return
            }

            DDLogVerbose("defaultPath: isExpensive \(defaultPath!.isExpensive)")

            if let _lastPath = lastPath {
                if !defaultPath!.isEqual(to: _lastPath) {
                    DDLogVerbose("defaultPath: received network change notification")
                    reasserting = true
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1, execute: {
                        self.setupTunnelWith(proxyPort: self.httpPort, completionHandle: { (_) in
                            DDLogVerbose("defaultPath: change done")
                        })
                        self.reasserting = false
                    })
//                    stopTunnel(with: .none, completionHandler: {
//                        DDLogVerbose("defaultPath: tunnel stopped")
//                        self.startTunnel(options: nil, completionHandler: { (error) in
//                            DDLogVerbose("defaultPath: tunnel started")
//                        })
//                    })
                }
            }
            lastPath = defaultPath
            DDLogVerbose("defaultPath: finish")
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        // Add code here to start the process of stopping the tunnel.
        TunnelManager.sharedInterface().stop()
        pendingStopCompletion = completionHandler
        DDLogDebug("stopTunnel")
        Answers.logCustomEvent(withName: "Stop", customAttributes: ["during": "\(Date().timeIntervalSince(startTime))"])
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // Add code here to handle the message.
        if let handler = completionHandler {
            handler(messageData)
        }
    }

    override func sleep(completionHandler: @escaping () -> Void) {
        // Add code here to get ready to sleep.
        completionHandler()
    }

    override func wake() {
        // Add code here to wake up.
    }
}
