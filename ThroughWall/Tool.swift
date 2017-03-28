//
//  Tool.swift
//  ThroughWall
//
//  Created by Bin on 13/03/2017.
//  Copyright © 2017 Wu Bin. All rights reserved.
//

import Foundation
import NetworkExtension

class ProxyConfig: NSObject {

    private let proxies = ["CUSTOM", "HTTP", "SOCKS5"]

    private let items = [
        "CUSTOM": ["proxy", "description", "server", "port", "password", "method"],
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
            "proxy": [
                "preset": [
                    "CUSTOM"//, "HTTP", "SOCKS5"
                ]
            ],
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

    var currentProxy: String {
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

    func getAvailableOptions(byItem item: String) -> ([String], [String])? {

        if let itemOptions = _availableOptions[item] {
            var preset = [String]()
            var customize = [String]()
            if let temp = itemOptions["preset"] {
                preset = temp
            }
            if let cust = itemOptions["customize"] {
                customize = cust
            }
            return (preset, customize)

        } else {
            return nil
        }
    }

    func setCustomOption(byItem item: String, option: String) {
        _availableOptions[item]?["customize"] = [option]
    }

    func setSelection(_ item: String, selected value: String) {
        //        print("\(item) \(selected)")
        if item == "proxy" {
            currentProxy = value
            return
        }
        _values[item] = value
        if !_availableOptions[item]!["preset"]!.contains(value) {
            setCustomOption(byItem: item, option: value)
        }
    }

}


class SiteConfigController {

    enum ServerVersionStatus {
        case ERROR
        case EMPTY
        case CONVERTED
        case NOTCONVERTED
    }

    private func isContainConvertedVPN(amongManagers managers: [NETunnelProviderManager]) -> Bool {
        for vpnManager in managers {
            if let providerProtocol = vpnManager.protocolConfiguration as? NETunnelProviderProtocol {
                if let _ = providerProtocol.providerConfiguration?[kConfigureVersion] {
                    return true
                }
            }
        }
        return false
    }

    private func checkServerStatus(withCompletionHandler completion: @escaping (ServerVersionStatus, [NETunnelProviderManager]) -> Void) {
        NETunnelProviderManager.loadAllFromPreferences() { newManagers, error in
            if error == nil {
                guard let vpnManagers = newManagers else {
                    completion(ServerVersionStatus.EMPTY, [NETunnelProviderManager]())
                    return
                }

                if vpnManagers.count < 1 {
                    completion(ServerVersionStatus.EMPTY, [NETunnelProviderManager]())
                    return
                }

                if self.isContainConvertedVPN(amongManagers: vpnManagers) {
                    completion(ServerVersionStatus.CONVERTED, vpnManagers)
                } else {
                    completion(ServerVersionStatus.NOTCONVERTED, vpnManagers)
                }
            } else {
                print(error!)
                completion(ServerVersionStatus.ERROR, [NETunnelProviderManager]())
            }
        }
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

    private func setConfig(fromProxyConfig config: ProxyConfig, toManager manager: NETunnelProviderManager) {

        var configuration = [String: AnyObject]()

        let items = config.containedItems

        for item in items {
            configuration[item] = config.getValue(byItem: item) as AnyObject?
        }
        configuration[kConfigureVersion] = currentConfigureVersion as AnyObject?
        (manager.protocolConfiguration as! NETunnelProviderProtocol).providerConfiguration = configuration
    }


    private func saveConfigFile(fromOldVPNManagers managers: [NETunnelProviderManager]) {
        var proxyConfigs = [ProxyConfig]()
        var index = 0
        for manager in managers {
            if let providerProtocol = manager.protocolConfiguration as? NETunnelProviderProtocol {
                if let _ = providerProtocol.providerConfiguration?[kConfigureVersion] {
                } else {
                    if let conf = self.getConfig(fromManager: manager) {
                        if manager.isEnabled {
                            setSelectedServerIndex(withValue: index)
                        }
                        proxyConfigs.append(conf)
                        index = index + 1
                    }
                }
            }
        }
        if proxyConfigs.count > 0 {
            self.writeIntoSiteConfigFile(withConfigs: proxyConfigs)
            print("save config file")
        }

    }

    private func deleteOldServer(fromVPNManagers managers: [NETunnelProviderManager]) -> NETunnelProviderManager? {
        var newVersionManager: NETunnelProviderManager? = nil
        for manager in managers {
            if let providerProtocol = manager.protocolConfiguration as? NETunnelProviderProtocol {
                if let _ = providerProtocol.providerConfiguration?[kConfigureVersion] {
                    newVersionManager = manager
                } else {
                    //delete old
                    manager.removeFromPreferences(completionHandler: nil)
                    print("delete old")
                }
            }
        }
        return newVersionManager
    }

    private func createNewTypeServer(withCompeletionHandler completionHandler: @escaping (NETunnelProviderManager?) -> Void) {
        //no saved. create one
        let manager = NETunnelProviderManager()
        manager.loadFromPreferences { error in

            if error != nil {
                print("loadFromPreferences \(error!)")
                completionHandler(nil)
                return
            }

            let providerProtocol = NETunnelProviderProtocol()
            providerProtocol.providerBundleIdentifier = kTunnelProviderBundle
            providerProtocol.providerConfiguration = [kConfigureVersion: currentConfigureVersion]
            manager.protocolConfiguration = providerProtocol
            manager.protocolConfiguration?.serverAddress = "10.0.0.0"
            manager.localizedDescription = "Chisel"
            manager.saveToPreferences() { error in
                if error != nil {
                    print("save new manager \(error!)")
                    completionHandler(nil)
                } else {
                    print("saved new manger")
                    completionHandler(manager)
                }
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
                    if let value = config.getValue(byItem: item) {
                        filehandle.write("\(item):\(value)\n".data(using: String.Encoding.utf8)!)
                    }
                }
                filehandle.write("#\n".data(using: String.Encoding.utf8)!)
            }

            filehandle.synchronizeFile()

        } catch {
            print(error)
            return
        }
    }

    func convertOldServer(withCompletionHandler completion: @escaping (NETunnelProviderManager?) -> Void) {
        checkServerStatus { (currentStatus, vpnManagers) in
            switch currentStatus {
            case .ERROR:
                print("Unknow")
                completion(nil)
            case .EMPTY:
                print("empty")
                completion(nil)
            case .CONVERTED:
                print("converted")
                let newVersionManager = self.deleteOldServer(fromVPNManagers: vpnManagers)
                completion(newVersionManager)
            case .NOTCONVERTED:
                print("not converted")
                self.saveConfigFile(fromOldVPNManagers: vpnManagers)
                self.createNewTypeServer { _newManager in
                    let _ = self.deleteOldServer(fromVPNManagers: vpnManagers)
                    let proxyConfigs = self.readSiteConfigsFromConfigFile()
                    if let newManager = _newManager {
                        if let selectedIndex = self.getSelectedServerIndex() {
                            self.save(withConfig: proxyConfigs[selectedIndex], intoManager: newManager, completionHander: {
                                completion(newManager)
                            })
                        } else {
                            self.save(withConfig: proxyConfigs[0], intoManager: newManager, completionHander: {
                                completion(newManager)
                            })
                        }
                    }

                }
            }
        }
    }

    func save(withConfig config: ProxyConfig, intoManager manager: NETunnelProviderManager, completionHander completion: @escaping (Void) -> Void) {
        self.setConfig(fromProxyConfig: config, toManager: manager)

        manager.isEnabled = true
        manager.saveToPreferences(completionHandler: { (error) in
            completion()
        })
    }

    func forceSaveToManager(withConfig config: ProxyConfig, withCompletionHandler completion: @escaping (NETunnelProviderManager?) -> Void) {
        checkServerStatus { (status, vpnManagers) in
            switch status {
            case .ERROR:
                completion(nil)
            case .EMPTY:
                self.createNewTypeServer { _newManager in
                    if let newManager = _newManager {
                        self.save(withConfig: config, intoManager: newManager, completionHander: {
                            completion(newManager)
                        })
                    } else {
                        completion(nil)
                    }
                }
            case .CONVERTED:
                let manager = vpnManagers[0]
                self.save(withConfig: config, intoManager: manager, completionHander: {
                    completion(manager)
                })
            case .NOTCONVERTED:
                //impossible
                completion(nil)
            }
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
                    items.removeLast()

                    for item in items {
                        let temp = item.components(separatedBy: ":")
                        let name = temp[0]
                        // let option = temp.count > 2 ? temp.dropFirst().joined(separator: ":") : temp[1]
                        let option: String

                        if temp.count > 2 {
                            option = temp.dropFirst().joined(separator: ":")
                        } else {
                            option = temp[1]
                        }

                        if config.containedItems.contains(name) {
                            config.setValue(byItem: name, value: option)
                        }
                    }
                    proxyConfigs.append(config)
                }
            }
        } catch {
            print(error)
        }

        return proxyConfigs
    }


    func getSelectedServerIndex() -> Int? {
        let defaults = UserDefaults.init(suiteName: groupName)

        if let index = defaults?.value(forKey: kSelectedServerIndex) as? Int {
            return index
        }
        return nil
    }

    func setSelectedServerIndex(withValue value: Int) {
        let defaults = UserDefaults.init(suiteName: groupName)

        defaults?.set(value, forKey: kSelectedServerIndex)
    }

}
