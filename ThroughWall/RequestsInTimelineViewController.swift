//
//  RequestsInTimelineViewController.swift
//  ThroughWall
//
//  Created by Bingo on 29/05/2017.
//  Copyright © 2017 Wu Bin. All rights reserved.
//

import UIKit
import CoreData
import CocoaLumberjack

class RequestsInTimelineViewController: UIViewController, UIScrollViewDelegate {

    @IBOutlet weak var viewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var viewWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var baseView: TimelineBaseView!
    @IBOutlet weak var baseScrollView: UIScrollView!

    @IBOutlet weak var topPadConstraint: NSLayoutConstraint!
    @IBOutlet weak var bottomPadConstraint: NSLayoutConstraint!
    @IBOutlet weak var leadingPadConstraint: NSLayoutConstraint!
    @IBOutlet weak var trailingPadConstraint: NSLayoutConstraint!


    var hostTraffics = [HostTraffic]()
    var classifiedTrafficsInRow = [[HostTraffic]]()
    var beginTime = Date()
    var endTime = Date()
    var horiScaller = 100
    var responseTraffic = [Int]()
    var currentShownTraffics = [HostTraffic: UIView]()
    var timeLineRulerView = UIView()
    var backgroundView = UIView()
    var downloadIndicator = UIActivityIndicatorView()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        baseScrollView.delegate = self
        baseScrollView.minimumZoomScale = 0.01
        baseScrollView.maximumZoomScale = 10
        baseView.contentMode = .scaleAspectFit

        view.backgroundColor = veryLightGrayUIColor

        let defaults = UserDefaults()
        if let vpnStatus = defaults.value(forKey: kCurrentManagerStatus) as? String {
            if vpnStatus == "Disconnected" {
                CoreDataController.sharedInstance.closeCrashLogs()
            }
        }

        backgroundView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        backgroundView.center = CGPoint(x: view.bounds.width / 2, y: view.bounds.height / 2)
        backgroundView.backgroundColor = UIColor.darkGray

        downloadIndicator = UIActivityIndicatorView(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        downloadIndicator.center = CGPoint(x: 50, y: 50)
        downloadIndicator.activityIndicatorViewStyle = .whiteLarge
        backgroundView.addSubview(downloadIndicator)
        downloadIndicator.startAnimating()

        DispatchQueue.global().async {
            self.requestHostTraffic()
            self.classifyTraffic()
            self.getTrafficStream()

            DispatchQueue.main.async {
                self.viewHeightConstraint.constant = CGFloat((self.classifiedTrafficsInRow.count + 1) * 48)
                let duringTime = self.endTime.timeIntervalSince(self.beginTime)
                self.viewWidthConstraint.constant = CGFloat(duringTime * Double(self.horiScaller) + 48)

                self.newScrollOffset(withValue: 0)

                self.backgroundView.isHidden = true
            }
        }
    }


    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !view.subviews.contains(backgroundView) {
            view.addSubview(backgroundView)
        }
        backgroundView.center = CGPoint(x: view.bounds.width / 2, y: view.bounds.height / 2)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
//        clearDrawedTraffics()
        newScrollOffset(withValue: scrollView.contentOffset.x)
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return baseView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        updateConstraintsForSize(view.bounds.size)
    }

    private func updateConstraintsForSize(_ size: CGSize) {

        let yOffset = max(0, (size.height - baseView.frame.height) / 2)
        topPadConstraint.constant = yOffset
        bottomPadConstraint.constant = yOffset

        let xOffset = max(0, (size.width - baseView.frame.width) / 2)
        leadingPadConstraint.constant = xOffset
        trailingPadConstraint.constant = xOffset

        view.layoutIfNeeded()
    }

    func requestHostTraffic() {
        let privateContext = CoreDataController.sharedInstance.getPrivateContext()

        privateContext.performAndWait {
            let fetch: NSFetchRequest<HostTraffic> = HostTraffic.fetchRequest()
            fetch.includesPropertyValues = false
            fetch.includesSubentities = false

            do {
                self.hostTraffics = try privateContext.fetch(fetch)
                self.hostTraffics.sort(by: { (first, second) -> Bool in
                    guard let firstTime = first.hostConnectInfo?.requestTime else {
                        return false
                    }
                    guard let secondTime = second.hostConnectInfo?.requestTime else {
                        return true
                    }
                    if firstTime.timeIntervalSince(secondTime as Date) > 0 {
                        return false
                    }
                    return true
                })
            } catch {
                DDLogError("\(error)")
            }
        }
    }

    func classifyTraffic() {
        let privateContext = CoreDataController.sharedInstance.getPrivateContext()
        privateContext.performAndWait {
            self._classifyTraffic()
        }
    }

    func _classifyTraffic() {
        classifiedTrafficsInRow.removeAll()

        if let first = hostTraffics.first {
            if let firstReqTime = first.hostConnectInfo?.requestTime as Date? {
                beginTime = firstReqTime
                endTime = beginTime
            }
        }

        for traffic in hostTraffics {
            if let trafficDisTime = traffic.disconnectTime {
                if trafficDisTime.timeIntervalSince(endTime) > 0 {
                    endTime = trafficDisTime as Date
                }
            } else {
                endTime = Date()
            }
            var inserted = false
            for (rowIndex, row) in classifiedTrafficsInRow.enumerated() {
                if let lastInRow = row.last {
                    let lastInRowDisTime: NSDate
                    if let _lastInRowDisTime = lastInRow.disconnectTime {
                        lastInRowDisTime = _lastInRowDisTime
                    } else {
                        lastInRowDisTime = NSDate()
                    }
                    if let trafficReqTime = traffic.hostConnectInfo?.requestTime {
                        if trafficReqTime.timeIntervalSince(lastInRowDisTime as Date) >= 0 {
                            // ADD
                            var oldRow = classifiedTrafficsInRow[rowIndex]
                            oldRow.append(traffic)
                            classifiedTrafficsInRow[rowIndex] = oldRow
                            inserted = true
                            break
                        }
                    }

                }
            }
            if !inserted {
                classifiedTrafficsInRow.append([traffic])
            }
        }
    }

    func clearDrawedTraffics() {
        for view in baseView.subviews {
            view.removeFromSuperview()
        }
    }


    func newScrollOffset(withValue value: CGFloat) {
        let offset = Double(value)
        let ft = beginTime.addingTimeInterval( offset / Double(horiScaller) / Double(baseScrollView.zoomScale))
        let tT = beginTime.addingTimeInterval( (offset + Double(view.frame.width)) / Double(horiScaller) / Double(baseScrollView.zoomScale))
        drawTraffic(fromTime: ft, toTime: tT)
        drawTimelineRuler(fromTime: ft, toTime: tT)
        baseView.layoutIfNeeded()
    }


    func drawTraffic(fromTime fT: Date, toTime tT: Date) {
        let privateContext = CoreDataController.sharedInstance.getPrivateContext()
        privateContext.performAndWait {
            self._drawTraffic(fromTime: fT, toTime: tT)
        }
    }
    func _drawTraffic(fromTime fT: Date, toTime tT: Date) {
        var shouldShownTraffics = [HostTraffic: Int]()
        
        for (rowIndex, rowTraffics) in classifiedTrafficsInRow.enumerated() {
            for rowTraffic in rowTraffics {
                let disTime: Date
                if let _disTime = rowTraffic.disconnectTime {
                    disTime = _disTime as Date
                } else {
                    disTime = endTime
                }
                if let reqTime = rowTraffic.hostConnectInfo?.requestTime as Date? {
                    if reqTime > tT {
                        break
                    }
                    if disTime < fT {
                        continue
                    }
                    shouldShownTraffics[rowTraffic] = rowIndex
                }
            }
        }
        
        _drawTraffic(withTraffics: shouldShownTraffics)
    }
    
    func _drawTraffic(withTraffics traffics: [HostTraffic: Int]) {
    
        let newTraffics = removeUnshownAndGetNewTraffics(usingShouldShown: Array(traffics.keys))
        
        for newTraffic in newTraffics {
            drawNewTraffic(with: (newTraffic,traffics[newTraffic]!))
        }
    }

    func removeUnshownAndGetNewTraffics(usingShouldShown shouldShownTraffics: [HostTraffic]) -> [HostTraffic] {
        var shouldShown = shouldShownTraffics
        for current in currentShownTraffics {
            if let index = shouldShown.index(of: current.key) {
                shouldShown.remove(at: index)
            }else {
                currentShownTraffics.removeValue(forKey: current.key)
                current.value.removeFromSuperview()
            }
        }
        return shouldShown
    }
    
    func drawNewTraffic(with newTraffic: (HostTraffic, Int))  {
        let rowTraffic = newTraffic.0
        let rowIndex = newTraffic.1
        
        // draw
        let reqTime = rowTraffic.hostConnectInfo!.requestTime! as Date
        let disTime: Date
        if let _disTime = rowTraffic.disconnectTime {
            disTime = _disTime as Date
        } else {
            disTime = endTime
        }
        let offsetTime = reqTime.timeIntervalSince(beginTime)
        let length = disTime.timeIntervalSince(reqTime)
        let frame = CGRect(x: offsetTime * Double(horiScaller), y: Double(48 * rowIndex) + 48.0, width: length * Double(horiScaller), height: 48.0)
        let tView = TimelineCellView(frame: frame)
        
        tView.touchedCallback = {
            self.performSegue(withIdentifier: "showRequestDetail", sender: rowTraffic)
        }
        
        if let rule = rowTraffic.hostConnectInfo?.rule?.lowercased() {
            var resTime: Date? = nil
            if let responseHead = rowTraffic.responseHead {
                resTime = responseHead.time as Date?
            }
            tView.setIndicatorColor(withReqT: reqTime, ResT: resTime, DisT: disTime, andRule: rule)
        }
        
        if let host = rowTraffic.hostConnectInfo?.name {
            if let port = rowTraffic.hostConnectInfo?.port {
                tView.set(HostPort: "\(host):\(port)")
            }
        }
        
        currentShownTraffics[rowTraffic] = tView
        
        DispatchQueue.main.async {
            self.baseView.addSubview(tView)
        }
    }


    func drawTimelineRuler(fromTime ft: Date, toTime tT: Date) {
        let offsetTime = ft.timeIntervalSince(beginTime)
        let length = tT.timeIntervalSince(ft)
        let frame = CGRect(x: offsetTime * Double(horiScaller), y: 0, width: length * Double(horiScaller), height: 48.0)
        timeLineRulerView.removeFromSuperview()
        timeLineRulerView = UIView(frame: frame)

        _drawTimelineRuler(fromTime: ft, toTime: tT, inView: timeLineRulerView)
        baseView.addSubview(timeLineRulerView)
    }

    func _drawTimelineRuler(fromTime ft: Date, toTime tT: Date, inView timelineView: UIView) {
        let duringTime = tT.timeIntervalSince(ft)
        let repCount = Int(duringTime + 1)
        drawSectorLines(withRepeatCount: repCount, inView: timelineView)
        drawTimeStamp(fromTime: ft, withTotalCount: repCount, inView: timelineView)
    }

    func drawSectorLines(withRepeatCount repCount: Int, inView timelineView: UIView) {
        let repLayer = CAReplicatorLayer()
        repLayer.frame = CGRect(origin: .zero, size: CGSize(width: 2, height: 48.0))

        timelineView.layer.addSublayer(repLayer)

        let singleLine = CALayer()
        singleLine.frame = CGRect(x: 0, y: 18, width: 2, height: 30)
        singleLine.backgroundColor = UIColor.black.cgColor

        repLayer.addSublayer(singleLine)
        repLayer.instanceCount = repCount
        repLayer.instanceTransform = CATransform3DMakeTranslation(CGFloat(horiScaller), 0, 0)
    }

    func drawTimeStamp(fromTime ft: Date, withTotalCount repCount: Int, inView timelineView: UIView) {
        let offset = 3
        let localFormatter = DateFormatter()
        localFormatter.locale = Locale.current
        localFormatter.dateFormat = "HH:mm:ss.SSS"
        for i in 0 ..< repCount {
            let textView = UITextField(frame: CGRect(x: offset + horiScaller * i, y: 24, width: horiScaller - 10, height: 24))
            textView.text = localFormatter.string(from: ft.addingTimeInterval(1.0 * Double(i)))
            textView.adjustsFontSizeToFitWidth = true
            timelineView.addSubview(textView)
        }
    }

    
    func getTrafficStream() {
        let privateContext = CoreDataController.sharedInstance.getPrivateContext()

        privateContext.performAndWait {
            let fetch: NSFetchRequest<ResponseBodyStamp> = ResponseBodyStamp.fetchRequest()
            fetch.sortDescriptors = [NSSortDescriptor.init(key: "timeStamp", ascending: true)]

            do {
                let bodyStamps = try privateContext.fetch(fetch)
                transferBodyStampsIntoTraffic(withbodies: bodyStamps)
                for body in bodyStamps {
                    privateContext.refresh(body, mergeChanges: false)
                }
            } catch {
                DDLogError("\(error)")
            }
        }
    }


    func transferBodyStampsIntoTraffic(withbodies boides: [ResponseBodyStamp]) {
        var fT = beginTime
        var tT = fT.addingTimeInterval(0.1)
        var boides = boides

        while fT < endTime {
            var count = 0
            while let first = boides.first {
                if let time = first.timeStamp as Date? {
                    if time >= tT {
                        break
                    }
                    if time >= fT && time < tT {
                        count = count + Int(first.size)
                    }
                    boides.removeFirst()
                } else {
                    boides.removeFirst()
                }
            }
            responseTraffic.append(count)
            fT = tT
            tT = fT.addingTimeInterval(0.1)
        }
    }

    func getRecordFileSize(withFileName fileName: String) -> Int {
        let dataBaseURL = CoreDataController.sharedInstance.getDatabaseUrl()
        let parseURL = dataBaseURL.appendingPathComponent(parseFolderName)
        do {
            let data = try Data(contentsOf: parseURL.appendingPathComponent(fileName))
            return data.count
        } catch {
            DDLogError("getRecordFileSize \(fileName) error. \(error)")
        }
        return 0
    }


    func drawTrafficStream() {
        let shapeLayer = CAShapeLayer()
        let duringTime = endTime.timeIntervalSince(beginTime)
        let width = Int(duringTime * Double(horiScaller))
        let height = classifiedTrafficsInRow.count * 48
        if height == 0 {
            return
        }
        shapeLayer.frame = CGRect(x: 48, y: 48, width: width, height: height)
        baseView.layer.addSublayer(shapeLayer)
//        if let maxValue = responseTraffic.max() {
//            let line = UIBezierPath()
//            line.move(to: .zero)
//            for (index, value) in responseTraffic.enumerated() {
//                let x = 0.1 * Double((index + 1) * horiScaller)
//                let y: Int
//                if maxValue == 0 {
//                    y = 0
//                } else {
//                    y = height * value / maxValue
//                }
//                line.addLine(to: CGPoint(x: CGFloat(x), y: CGFloat(y)))
//            }
//            shapeLayer.path = line.cgPath
//            shapeLayer.strokeColor = UIColor.green.cgColor
//            shapeLayer.fillColor = UIColor.clear.cgColor
//            shapeLayer.lineWidth = 2
//        }
        drawSpeedRuler(withHeight: height)
        responseTraffic.removeAll()
    }

    func drawSpeedRuler(withHeight height: Int) {
        drawSpeedLine(withHeight: height)
    }

    func drawSpeedLine(withHeight height: Int) {
        let verticalLine = CALayer()
        verticalLine.frame = CGRect(x: 47, y: 48, width: 2, height: height)
        verticalLine.backgroundColor = UIColor.black.cgColor
        baseView.layer.addSublayer(verticalLine)

        let repeatCount = height / Int(horiScaller) + 1
        let horiLineLayer = CAReplicatorLayer()
        horiLineLayer.frame = CGRect(x: 0, y: 48, width: 48, height: height)
        baseView.layer.addSublayer(horiLineLayer)
        let horiLine = CALayer()
        horiLine.frame = CGRect(x: 18, y: -1, width: 30, height: 2)
        horiLine.backgroundColor = UIColor.black.cgColor
        horiLineLayer.addSublayer(horiLine)
        horiLineLayer.instanceCount = repeatCount
        horiLineLayer.instanceTransform = CATransform3DMakeTranslation(0, CGFloat(horiScaller), 0)

        if let maxValue = responseTraffic.max() {
            for i in 0 ..< repeatCount {
                let textLayer = CATextLayer()
//                textLayer.frame = CGRect(x: 48, y: 48 + i * 100, width: 100, height: 30)
                textLayer.anchorPoint = .zero
                textLayer.bounds = CGRect(x: 0, y: 0, width: 100, height: 30)
                textLayer.position = CGPoint(x: 48, y: 48 + 3 + i * 100)
                let speed = maxValue * i * 100 * 10 / height
                let speedText: String
                switch speed {
                case 0 ..< 1024:
                    speedText = "\(speed) B/s"
                case 1024 ..< 1024 * 1024:
                    speedText = "\(String(format: "%.1f", Double(speed) / 1024.0)) KB/s"
                case 1024 * 1024 ..< 1024 * 1024 * 1024:
                    speedText = "\(String(format: "%.1f", Double(speed) / 1024.0 / 1024.0)) MB/s"
                default:
                    speedText = "\(String(format: "%.1f", Double(speed) / 1024.0 / 1024.0 / 1024.0)) GB/s"
                }
                textLayer.string = speedText
                textLayer.fontSize = 15
                textLayer.foregroundColor = UIColor.black.cgColor
                baseView.layer.addSublayer(textLayer)

                textLayer.transform = CATransform3DMakeRotation(.pi / 2, 0, 0, 1)
            }
        }
    }

    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        if segue.identifier == "showRequestDetail" {
            let desti = segue.destination as! RequestDetailTableViewController
            desti.hostRequest = sender as! HostTraffic
        }
    }


}

class TimelineBaseView: UIView {
//    var unzoomedViewHeight: CGFloat?
//    override func layoutSubviews() {
//        super.layoutSubviews()
//        unzoomedViewHeight = frame.size.height
//    }
//
//    override var transform: CGAffineTransform {
//        get { return super.transform }
//        set {
//            if let unzoomedViewHeight = unzoomedViewHeight {
//                var t = newValue
//                t.d = 1.0
//                t.ty = (1.0 - t.a) * unzoomedViewHeight/2
//                super.transform = t
//            }
//        }
//    }
}
