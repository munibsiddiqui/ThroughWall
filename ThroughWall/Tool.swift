//
//  Tool.swift
//  ThroughWall
//
//  Created by Bin on 13/03/2017.
//  Copyright © 2017 Wu Bin. All rights reserved.
//

import Foundation
import UIKit
import CocoaLumberjack
import CloudKit

let topUIColor = UIColor(red: 255.0 / 255.0, green: 108.0 / 255.0, blue: 66.0 / 255.0, alpha: 1.0)
let bottomUIColor = UIColor(red: 255.0 / 255.0, green: 139.0 / 255.0, blue: 71.0 / 255.0, alpha: 1.0)
let darkGreenUIColor = UIColor(red: 0.24, green: 0.545, blue: 0.153, alpha: 1.0)
let veryLightGrayUIColor = UIColor(red: 245 / 255.0, green: 245 / 255.0, blue: 245 / 255.0, alpha: 1.0)

class ICMPPing: NSObject, SimplePingDelegate {
    private var hostName: String
    private var intervalTime: Int
    private var repeatTimes: Int
    private var pinger: SimplePing?
    private var sendTimer: Timer?
    private var pendingComplete: ((Int) -> Void)?
    private var sendTimestamps = [Int: Date]()
    private var delayTimes = [Int]()

    init(withHostName name: String, intervalTime interval: Int, repeatTimes rTimes: Int) {
        hostName = name
        intervalTime = interval
        repeatTimes = rTimes
    }

    func start(withComplete complete: @escaping (Int) -> Void) {
        let pinger = SimplePing(hostName: self.hostName)
        self.pinger = pinger
        pendingComplete = complete

        pinger.addressStyle = .any
        pinger.delegate = self
        pinger.start()
    }

    /// Sends a ping.
    ///
    /// Called to send a ping, both directly (as soon as the SimplePing object starts up) and
    /// via a timer (to continue sending pings periodically).

    @objc func sendPing() {
        if repeatTimes > 0 {
            pinger!.send(with: nil)
            repeatTimes = repeatTimes - 1
        } else {
            handleResult()
        }
    }

    func handleResult() {
        sendTimer?.invalidate()
        let ave: Int
        if delayTimes.count > 0 {
            ave = delayTimes.reduce(0, +) / delayTimes.count
        } else {
            ave = -1
        }

        if let complete = pendingComplete {
            complete(ave)
        }
    }


    // MARK: pinger delegate callback

    func simplePing(_ pinger: SimplePing, didStartWithAddress address: Data) {
        sendPing()
        assert(sendTimer == nil)
        sendTimer = Timer.scheduledTimer(timeInterval: TimeInterval(intervalTime), target: self, selector: #selector(sendPing), userInfo: nil, repeats: true)
    }

    func simplePing(_ pinger: SimplePing, didSendPacket packet: Data, sequenceNumber: UInt16) {
        sendTimestamps[Int(sequenceNumber)] = Date()
//        print("#\(sequenceNumber) sent")
    }

    func simplePing(_ pinger: SimplePing, didReceivePingResponsePacket packet: Data, sequenceNumber: UInt16) {
        let receiveTimestamp = Date()
        if let sendTimestamp = sendTimestamps[Int(sequenceNumber)] {
            let deltaTime = receiveTimestamp.timeIntervalSince(sendTimestamp)
//            print(deltaTime)
            delayTimes.append(Int(deltaTime * 1000))
        }

//        print("#\(sequenceNumber) received")
    }

    func simplePing(_ pinger: SimplePing, didReceiveUnexpectedPacket packet: Data) {
        DDLogDebug("received unexpected packet")
    }

    func simplePing(_ pinger: SimplePing, didFailWithError error: Error) {
        DDLogError("\(error)")
        handleResult()
    }

    func simplePing(_ pinger: SimplePing, didFailToSendPacket packet: Data, sequenceNumber: UInt16, error: Error) {
        DDLogError("\(error)")
        handleResult()
    }

}


class FollowOnSocial {
    static func followOnTwitter(withAccount account: String) {
        let urls = [
            "twitter://user?screen_name=", // Twitter
            "tweetbot:///user_profile/", // TweetBot
            "echofon:///user_timeline?", // Echofon
            "twit:///user?screen_name=", // Twittelator Pro
            "x-seesmic://twitter_profile?twitter_screen_name=", // Seesmic
            "x-birdfeed://user?screen_name=", // Birdfeed
            "tweetings:///user?screen_name=", // Tweetings
            "simplytweet:?link=http://twitter.com/", // SimplyTweet
            "icebird://user?screen_name=", // IceBird
            "fluttr://user/", // Fluttr
            "http://twitter.com/"]

        let application = UIApplication.shared

        for url in urls {
            if let candidate = URL(string: url + account) {
                if application.canOpenURL(candidate) {
                    application.open(candidate, options: [:], completionHandler: nil)
                    return
                }
            }
        }
    }

    static func chatOnTelegram(withAccount account: String) {
        let urls = [
            "tg://resolve?domain=", // Telegram
            "https://t.me/"]

        let application = UIApplication.shared

        for url in urls {
            if let candidate = URL(string: url + account) {
                if application.canOpenURL(candidate) {
                    application.open(candidate, options: [:], completionHandler: nil)
                    return
                }
            }
        }
    }
}


class PurchaseValidator {

    func getReceipt() -> String {
        //Get the Path to the receipt
        let receiptUrl = Bundle.main.appStoreReceiptURL
        //Check if it's actually there
        if FileManager.default.fileExists(atPath: receiptUrl!.path)
            {
            //Load in the receipt
            let receipt: Data = try! Data(contentsOf: receiptUrl!, options: [])
            let receiptBio = BIO_new(BIO_s_mem())
            BIO_write(receiptBio, (receipt as NSData).bytes, Int32(receipt.count))
            let receiptPKCS7 = d2i_PKCS7_bio(receiptBio, nil)
            //Verify receiptPKCS7 is not nil

            if receiptPKCS7 == nil {
                return ""
            }

            //Swift 3
            let octets = pkcs7_d_data(pkcs7_d_sign(receiptPKCS7).pointee.contents)
            var ptr = UnsafePointer<UInt8>(octets?.pointee.data)
            let end = ptr?.advanced(by: Int((octets?.pointee.length)!))

            var type: Int32 = 0
            var xclass: Int32 = 0
            var length = 0

            ASN1_get_object(&ptr, &length, &type, &xclass, end! - ptr!)
            if (type != V_ASN1_SET) {
                print("failed to read ASN1 from receipt")
                return ""
            }

            while (ptr! < end!)
            {
                var integer: UnsafeMutablePointer<ASN1_INTEGER>

                // Expecting an attribute sequence
                ASN1_get_object(&ptr, &length, &type, &xclass, end! - ptr!)
                if type != V_ASN1_SEQUENCE {
                    print("ASN1 error: expected an attribute sequence")
                    return ""
                }
                //Swift 2
                //let seq_end = ptr.advancedBy(length)
                //Swift 3
                let seq_end = ptr?.advanced(by: length)
                var attr_type = 0

                // The attribute is an integer
                ASN1_get_object(&ptr, &length, &type, &xclass, end! - ptr!)
                if type != V_ASN1_INTEGER {
                    print("ASN1 error: attribute not an integer")
                    return ""
                }

                integer = c2i_ASN1_INTEGER(nil, &ptr, length)
                attr_type = ASN1_INTEGER_get(integer)
                ASN1_INTEGER_free(integer)

                // The version is an integer
                ASN1_get_object(&ptr, &length, &type, &xclass, end! - ptr!)
                if type != V_ASN1_INTEGER {
                    print("ASN1 error: version not an integer")
                    return ""
                }

                integer = c2i_ASN1_INTEGER(nil, &ptr, length);
                ASN1_INTEGER_free(integer);

                // The attribute value is an octet string
                ASN1_get_object(&ptr, &length, &type, &xclass, end! - ptr!)
                if type != V_ASN1_OCTET_STRING {
                    print("ASN1 error: value not an octet string")
                    return ""
                }

//                if attr_type == 2 {
//                    // Bundle identifier
//                    var str_ptr = ptr
//                    var str_type: Int32 = 0
//                    var str_length = 0
//                    var str_xclass: Int32 = 0
//                    ASN1_get_object(&str_ptr, &str_length, &str_type, &str_xclass, seq_end! - str_ptr!)
//                    if str_type == V_ASN1_UTF8STRING {
//                        //Swift 2
//                        //bundleIdString1 = NSString(bytes: str_ptr, length: str_length, encoding: NSUTF8StringEncoding)
//                        //bundleIdData1 = NSData(bytes: ptr, length: length)
//
//                        //Swift 3
//                        bundleIdString1 = NSString(bytes: str_ptr!, length: str_length, encoding: String.Encoding.utf8.rawValue)
//                        bundleIdData1 = Data(bytes: UnsafePointer<UInt8>(ptr!), count: length)
//                    }
//                }
//                else if attr_type == 3 {
//                    // Bundle version
//                    var str_ptr = ptr
//                    var str_type: Int32 = 0
//                    var str_length = 0
//                    var str_xclass: Int32 = 0
//                    ASN1_get_object(&str_ptr, &str_length, &str_type, &str_xclass, seq_end! - str_ptr!)
//
//                    if str_type == V_ASN1_UTF8STRING {
//                        //Swift 2
//                        //bundleVersionString1 = NSString(bytes: str_ptr, length: str_length, encoding: NSUTF8StringEncoding)
//                        //Swift 3
//                        bundleVersionString1 = NSString(bytes: str_ptr!, length: str_length, encoding: String.Encoding.utf8.rawValue)
//                    }
//                }
//                else if attr_type == 4 {
//                    // Opaque value
//                    //Swift 2
//                    //opaqueData1 = NSData(bytes: ptr, length: length)
//                    //Swift 3
//                    opaqueData1 = Data(bytes: UnsafePointer<UInt8>(ptr!), count: length)
//                }
//                else if attr_type == 5 {
//                    // Computed GUID (SHA-1 Hash)
//                    //Swift 2
//                    //hashData1 = NSData(bytes: ptr, length: length)
//                    //Swift 3
//                    hashData1 = Data(bytes: UnsafePointer<UInt8>(ptr!), count: length)
//                }
//                else if attr_type == 17 {
//                    //In app receipt
//                    //Swift 2
//                    //let r = NSData(bytes: ptr, length: length)
//                    //Swift 3
//                    let r = Data(bytes: UnsafePointer<UInt8>(ptr!), count: length)
//                    let id = self.getProductIdFromReceipt(r)
//
//                    if id != nil {
//                        pIds.append(id!)
//                    }
//                }else
                if attr_type == 19 {
                    var str_ptr = ptr
                    var str_type: Int32 = 0
                    var str_length = 0
                    var str_xclass: Int32 = 0
                    ASN1_get_object(&str_ptr, &str_length, &str_type, &str_xclass, seq_end! - str_ptr!)

                    if str_type == V_ASN1_UTF8STRING {
                        //Swift 2
                        //bundleVersionString1 = NSString(bytes: str_ptr, length: str_length, encoding: NSUTF8StringEncoding)
                        //Swift 3
                        if let version = NSString(bytes: str_ptr!, length: str_length, encoding: String.Encoding.utf8.rawValue) {
                            return version as String
                        }

                    }
                }

                // Move past the value
                //Swift 2
                //ptr = ptr.advancedBy(length)
                //Swift 3
                ptr = ptr?.advanced(by: length)
            }
        }
        return ""
    }
}

class CloudController {
    let container = CKContainer.default()

    func saveNewServerToiCloud(withContent content: String, completion comp: @escaping (String?, Date?, Error?) -> Void) {
        let privateDB = container.privateCloudDatabase
        let sites = CKRecord(recordType: "Servers")
        sites.setValue(content, forKey: "siteConfig")

        DispatchQueue.main.async {
            privateDB.save(sites, completionHandler: { (record, error) -> Void in
                if let _record = record {
                    let recordName = _record.recordID.recordName
                    let creationDate = _record.creationDate
                    comp(recordName, creationDate, error)
                }
                comp(nil, nil, error)
            })
        }
    }
}
