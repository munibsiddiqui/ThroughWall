//
//  Tool.swift
//  ThroughWall
//
//  Created by Bin on 13/03/2017.
//  Copyright © 2017 Wu Bin. All rights reserved.
//

import Foundation

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
        print("received unepected packet")
    }

    func simplePing(_ pinger: SimplePing, didFailWithError error: Error) {
        print(error)
        handleResult()
    }

    func simplePing(_ pinger: SimplePing, didFailToSendPacket packet: Data, sequenceNumber: UInt16, error: Error) {
        print(error)
        handleResult()
    }

}
