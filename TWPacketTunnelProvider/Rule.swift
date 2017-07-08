//
//  Rule.swift
//  ThroughWall
//
//  Created by Bin on 30/11/2016.
//  Copyright © 2016 Wu Bin. All rights reserved.
//

import CocoaLumberjack
import MMDB_Swift

enum DomainRule: CustomStringConvertible {
    case Proxy
    case Direct
    case Reject
    case Unkown

    var description: String {
        switch self {
        case .Proxy:
            return "Proxy"
        case .Direct:
            return "DIRECT"
        case .Reject:
            return "REJECT"
        default:
            return "Unknow"
        }
    }
}

class Rule {

    static let sharedInstance = Rule()
    private var db = MMDB()
    private var fullRules: [String: DomainRule]?
    private var suffixRules: [String: DomainRule]?
    private var containRules: [String: DomainRule]?
    private var ipRules: [String: DomainRule]?
    private var rewriteRules: [[String]]?
    private var geoIPRule: [(String, DomainRule)]?
    private var finalRule: DomainRule?
    private var bypassTunRule: [(String, String)]?
    private var globalMode = false

    private func trasnlateRule(fromString value: String) -> DomainRule {
        switch value.lowercased() {
        case "proxy":
            return DomainRule.Proxy
        case "direct":
            return DomainRule.Direct
        case "reject":
            return DomainRule.Reject
        default:
            return DomainRule.Unkown
        }
    }
    
    private func getContent(withFileName fileName: String) -> [String] {
        let fileManager = FileManager.default
        guard var url = fileManager.containerURL(forSecurityApplicationGroupIdentifier: groupName) else {
            return []
        }
        url.appendPathComponent(fileName)
        
        var fileString = ""
        do {
            fileString = try String(contentsOf: url, encoding: String.Encoding.utf8)
        } catch {
            DDLogDebug("\(error)")
            return []
        }
        
        var items = fileString.components(separatedBy: "\n")
        items.removeLast()
        return items
    }

    private func itemsInRuleFile() -> [String] {
        return getContent(withFileName: ruleFileName)
    }

    private func itemsInRewriteFile() -> [String] {
        return getContent(withFileName: rewriteFileName)
    }

    private func itemsInGeneralFile() -> [String] {
        return getContent(withFileName: generalFileName)
    }


    private func translateToBinary(fromIP ip: String) -> String {
        var ipParts = ip.components(separatedBy: ".")
        for (index, ipPart) in ipParts.enumerated() {
            ipParts[index] = pad(String(Int(ipPart) ?? 0, radix: 2), toSize: 8)
        }
        return ipParts.joined()
    }

    private func translateToBinary(fromIPRange ip: String) -> String {
        let parts = ip.components(separatedBy: "/")
        let ipAddress = translateToBinary(fromIP: parts[0])

        if parts.count > 1 {
            let index = ipAddress.index(ipAddress.startIndex, offsetBy: Int(parts[1])!)
            return ipAddress.substring(to: index)
        }
        return ipAddress
    }

    private func pad(_ string: String, toSize: Int) -> String {
        var padded = string
        for _ in 0..<toSize - string.characters.count {
            padded = "0" + padded
        }
        return padded
    }

    func getCurrentRuleItems() -> [[String]] {
        var result = [[String]]()
        let items = itemsInRuleFile()

        for item in items {
            let components = item.components(separatedBy: ",")
//            if components.count == 3 && components[0] != "GEOIP" {
            result.append(components)
//            }
        }
        return result
    }

    func getCurrentRewriteItems() -> [[String]] {
        var result = [[String]]()
        let items = itemsInRewriteFile()

        for item in items {
            let components = item.components(separatedBy: " ")
            result.append(components)

        }
        return result
    }

    private func getGeneralItems() {
        for item in itemsInGeneralFile() {
            if item.hasPrefix("bypass-tun") {
                generateBypassTun(withItem: item)
            }
        }
    }

    private func generateBypassTun(withItem item: String) {
        bypassTunRule = [(String, String)]()
        let tmp = item.components(separatedBy: "=")
        if tmp.count == 2 {
            let IPMaskPart = tmp[1]
            let IPMasks = IPMaskPart.components(separatedBy: ",")
            for IPMask in IPMasks {
                let _IPMask = removeSpaceBeforeAndAfter(forContent: IPMask)
                let parts = _IPMask.components(separatedBy: "/")
                if parts.count == 2 {
                    if let count = Int(parts[1]) {
                        let mask = generateMask(throughBitCount: count)
                        bypassTunRule?.append((parts[0], mask))
                    }
                }
            }
        }
    }

    private func removeSpaceBeforeAndAfter(forContent content: String) -> String {
        var chars = content.characters
        while chars.first == " " {
            chars.removeFirst()
        }
        while chars.last == " " {
            chars.removeLast()
        }
        return String(chars)
    }

    private func generateMask(throughBitCount count: Int) -> String {
        var masks = [String]()
        var _count = count
        for _ in 0 ..< 4 {
            let subCount: Int
            if _count >= 8 {
                subCount = 8
                _count = _count - 8
            } else {
                subCount = _count
                _count = 0
            }
            var number = 0
            for i in 0 ..< subCount {
                number = number * 2
                number = number + 1
            }
            number = number << (8 - subCount)
            masks.append("\(number)")
        }
        return masks.joined(separator: ".")
    }

    func getBypassTunRule() -> [(String, String)] {
        return bypassTunRule!
    }


    func analyzeRuleFile() {

        let items = itemsInRuleFile()

        fullRules = [String: DomainRule]()
        suffixRules = [String: DomainRule]()
        containRules = [String: DomainRule]()
        ipRules = [String: DomainRule]()
        geoIPRule = [(String, DomainRule)]()
        for item in items {
//            DDLogVerbose(item)
            let components = item.components(separatedBy: ",")
            if components.count >= 3 {
                let rule = trasnlateRule(fromString: components[2])

                switch components[0] {
                case "DOMAIN":
                    fullRules?[components[1]] = rule
                case "DOMAIN-SUFFIX":
                    suffixRules?[components[1]] = rule
                case "DOMAIN-MATCH":
                    fallthrough
                case "DOMAIN-KEYWORD":
                    containRules?[components[1]] = rule
                case "IP-CIDR":
                    ipRules?[translateToBinary(fromIPRange: components[1])] = rule
                case "GEOIP":
                    geoIPRule?.append((components[1], rule))
                default:
                    break
                }
            } else if components.count == 2 {
                let rule = trasnlateRule(fromString: components[1])
                if components[0] == "FINAL" {
                    finalRule = rule
                }
            }
        }

        rewriteRules = getCurrentRewriteItems()
        getGeneralItems()

        let defaults = UserDefaults.init(suiteName: groupName)

//        if let block = defaults?.value(forKey: blockADSetting) as? Bool {
//            blockAD = block
//            DDLogVerbose("Block AD \(blockAD)")
//        }
        if let global = defaults?.value(forKey: globalModeSetting) as? Bool {
            globalMode = global
//            DDLogVerbose("Global Mode \(globalMode)")
        }

//        if let realFullRules = fullRules {
//            DDLogVerbose("fullRule")
//            for fullRule in realFullRules {
//                DDLogVerbose("\(fullRule.key) : \(fullRule.value.description)")
//            }
//        }
//        if let realSuffixRules = suffixRules {
//            DDLogVerbose("suffixRule")
//            for suffixRule in realSuffixRules {
//                DDLogVerbose("\(suffixRule.key) : \(suffixRule.value.description)")
//            }
//        }
//
//        if let realContainRules = containRules {
//            DDLogVerbose("containRule")
//            for containRule in realContainRules {
//                DDLogVerbose("\(containRule.key) : \(containRule.value.description)")
//            }
//        }
    }

    private func validateIpAddress(ipToValidate: String) -> Bool {

        var sin = sockaddr_in()
        var sin6 = sockaddr_in6()

        if ipToValidate.withCString({ cstring in inet_pton(AF_INET6, cstring, &sin6.sin6_addr) }) == 1 {
            // IPv6 peer.
            return false
        }
            else if ipToValidate.withCString({ cstring in inet_pton(AF_INET, cstring, &sin.sin_addr) }) == 1 {
                // IPv4 peer.
                return true
        }

        return false;
    }

    private func _ruleForDomain(_ domain: String) -> DomainRule {

        if validateIpAddress(ipToValidate: domain) {
            let ipInBinary = translateToBinary(fromIP: domain)
            if let realIPRules = ipRules {
                for ipRule in realIPRules {
                    if ipInBinary.hasPrefix(ipRule.key) {
                        return ipRule.value
                    }
                }
            }
        } else {
            if let rule = fullRules?[domain] {
                return rule
            }

            if let realSuffixRules = suffixRules {
                for suffixRule in realSuffixRules {
                    var pieceDomains = domain.components(separatedBy: ".")

                    while !pieceDomains.isEmpty {
                        let madeDomain = pieceDomains.joined(separator: ".")
                        if madeDomain == suffixRule.key {
                            return suffixRule.value
                        }
                        pieceDomains.removeFirst()
                    }
                }
            }

            if let realContainRules = containRules {
                for containRule in realContainRules {
                    let pieceDomains = domain.components(separatedBy: ".")

                    if pieceDomains.contains(containRule.key) {
                        return containRule.value
                    }
                }
            }
        }
        return DomainRule.Unkown
    }

    func ruleForDomain(_ domain: String) -> DomainRule {
        var rule = _ruleForDomain(domain)
//        switch rule {
//        case .Direct:
//            if globalMode {
//                rule = .Proxy
//            }
//        case .Reject:
//            if !blockAD && globalMode {
//                rule = .Direct
//            }
//        default:
//            break
//        }
        if rule != .Reject && globalMode {
            rule = .Proxy
        }
        return rule
    }

    func checkLastRule(forDomain domain: String, andPort port: UInt16) -> (DomainRule, String) {
        let (rule, ip) = checkGEORule(forDomain: domain, andPort: port)
        if rule != .Unkown {
            return (rule, ip)
        }

        if let final = finalRule {
            return (final, domain)
        }

        return(.Direct, domain)
    }

    private func checkGEORule(forDomain domain: String, andPort port: UInt16) -> (DomainRule, String) {
        guard let geoRule = geoIPRule else {
            return(.Unkown, domain)
        }

        if geoRule.isEmpty {
            return(.Unkown, domain)
        }

        let (ip, _) = convertToIPPort(toHost: domain, andPort: port)

        if let _ip = ip {
            let country = lookupCountry(withIP: _ip)
            DDLogVerbose("\(country) \(domain) \(_ip)")
            for _geoRule in geoRule {
                if country == _geoRule.0 {
                    DDLogVerbose("\(_geoRule.1.description) \(domain)")
                    return (_geoRule.1, _ip)
                }
            }
            DDLogVerbose("GEO no match for \(domain):\(port)")
        } else {
            DDLogVerbose("no IP for \(domain):\(port)")
        }

        return(.Unkown, domain)
    }



    private func lookupCountry(withIP ip: String) -> String {
        guard let _db = db else {
            return "Unknown"
        }
        if let country = _db.lookup(ip) {
            return country.isoCode
        }
        return "Unknown"
    }


    private func convertToIPPort(toHost host: String, andPort port: UInt16) -> (String?, String?) {

        var hints = addrinfo(
            ai_flags: 0,
            ai_family: PF_INET,
            ai_socktype: SOCK_STREAM,
            ai_protocol: IPPROTO_TCP,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil)

        var result: UnsafeMutablePointer<addrinfo>? = nil

        let error = getaddrinfo(host, "\(port)", &hints, &result)

        if error != 0 {
            DDLogError("getaddrinfo \(error)")
            //free the chain
            freeaddrinfo(result)
            return (nil, nil)
        }

        var info = result
        while info != nil {
            let (clientIp, service) = sockaddrDescription(addr: info!.pointee.ai_addr)
            if clientIp != nil && service != nil {
                //free the chain
                freeaddrinfo(result)
                return (clientIp, service)
            }
            info = info!.pointee.ai_next
        }

        //free the chain
        freeaddrinfo(result)
        return(nil, nil)
    }

    private func sockaddrDescription(addr: UnsafePointer<sockaddr>) -> (String?, String?) {

        var host: String?
        var service: String?

        var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        var serviceBuffer = [CChar](repeating: 0, count: Int(NI_MAXSERV))

        if getnameinfo(
                addr,
                socklen_t(addr.pointee.sa_len),
                    &hostBuffer,
                socklen_t(hostBuffer.count),
                    &serviceBuffer,
                socklen_t(serviceBuffer.count),
                NI_NUMERICHOST | NI_NUMERICSERV)

            == 0 {

            host = String(cString: hostBuffer)
            service = String(cString: serviceBuffer)
        }
        return (host, service)

    }

    private func replace(_ url: String, byString bString: String, withPattern pattern: String) -> String {
        let regex = try! NSRegularExpression(pattern: pattern, options: NSRegularExpression.Options(rawValue: 0))
        //    let matches = regex.matches(in: url, options: NSRegularExpression.MatchingOptions(rawValue:0), range: NSMakeRange(0, url.characters.count))

        let result = regex.stringByReplacingMatches(in: url, range: NSMakeRange(0, url.characters.count), withTemplate: bString)


        return result
    }

    func tryRewriteURL(withURLString urlString: String) -> String {
        if let realRewriteRules = rewriteRules {
            for rewrite in realRewriteRules {
                let result = replace(urlString, byString: rewrite[1], withPattern: rewrite[0])
                if result != urlString {
                    if rewrite.count == 3 {
                        if rewrite[2].lowercased() == "reject" {
                            return ""
                        }
                    }
                    return result
                }
            }
        }
        return urlString
    }

}
