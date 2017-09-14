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
    @IBOutlet weak var HintView: UIView!
    
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
    var requestTraffic = [Int]()
    var maxTrafficValue = 0
    var currentShownTraffics = [HostTraffic: UIView]()
    var timeLineRulerView = UIView()
    var speedLineRulerView = UIView()
    var trafficStreamView = UIView()
    var shownFT: Date?
    var shownTT: Date?

    var backgroundView = UIView()
    var downloadIndicator = UIActivityIndicatorView()

    let verticalOffset = 30
    let horizontalOffset = 30
    let trafficStreamStep = 0.1

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
        backgroundView.layer.cornerRadius = 10
        backgroundView.clipsToBounds = true
        
        downloadIndicator = UIActivityIndicatorView(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        downloadIndicator.center = CGPoint(x: 50, y: 50)
        downloadIndicator.activityIndicatorViewStyle = .whiteLarge
        backgroundView.addSubview(downloadIndicator)
        downloadIndicator.startAnimating()

        
        HintView.layer.cornerRadius = 10
        HintView.clipsToBounds = true
        
        DispatchQueue.global().async {
            self.requestHostTraffic()
            self.classifyTraffic()
            self.getTrafficStream()

            DispatchQueue.main.async {
                self.viewHeightConstraint.constant = CGFloat((self.classifiedTrafficsInRow.count + 1) * 48)
                let duringTime = self.endTime.timeIntervalSince(self.beginTime)
                self.viewWidthConstraint.constant = CGFloat(duringTime * Double(self.horiScaller) + 48)

                self.newScrollOffset(withValue: .zero)
                if self.classifiedTrafficsInRow.count != 0 {
                    self.drawSpeedRuler(withHeight: self.classifiedTrafficsInRow.count * 48, withXOffset: 0)
                }
                self.backgroundView.isHidden = true
                self.HintView.isHidden = false
            }
        }
    }

    @IBAction func hintViewTapped(_ sender: UITapGestureRecognizer) {
        HintView.isHidden = true
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
        newScrollOffset(withValue: scrollView.contentOffset)
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
                    let lastInRowDisTime: Date
                    if let _lastInRowDisTime = lastInRow.disconnectTime {
                        lastInRowDisTime = _lastInRowDisTime
                    } else {
                        lastInRowDisTime = Date()
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


    func newScrollOffset(withValue value: CGPoint) {
        let scale = baseScrollView.zoomScale
        let xOffset = Double(value.x / scale)
        let yOffset = Double(value.y / scale)
        let fT = beginTime.addingTimeInterval( (xOffset < 0 ? 0 : xOffset) / Double(horiScaller))
        let tT = beginTime.addingTimeInterval( (xOffset + Double(view.frame.width) / Double(scale)) / Double(horiScaller))

        if let sFT = shownFT, let sTT = shownTT {
            if fT > sFT && tT < sTT {

                drawTimelineRuler(fromTime: fT, toTime: tT, withYOffset: Double(yOffset))

                if classifiedTrafficsInRow.count != 0 {
                    baseView.bringSubview(toFront: trafficStreamView)
                    updateSpeedRule(withXOffset: CGFloat(xOffset))
                }
                return
            }
            let deltaTime = tT.timeIntervalSince(fT)
            shownFT = fT.addingTimeInterval(-deltaTime)
            shownTT = tT.addingTimeInterval(deltaTime)
        } else {
            let deltaTime = tT.timeIntervalSince(fT)
            shownFT = fT
            shownTT = tT.addingTimeInterval(deltaTime)
        }

        if shownFT! < beginTime {
            shownFT = beginTime
        }
        if shownTT! > endTime {
            shownTT = endTime
        }

        drawTraffic(fromTime: shownFT!, toTime: shownTT!)
        drawTimelineRuler(fromTime: fT, toTime: tT, withYOffset: Double(yOffset))

        if classifiedTrafficsInRow.count != 0 {
            drawTrafficStream(fromTime: shownFT!, toTime: shownTT!)
            baseView.bringSubview(toFront: trafficStreamView)
            updateSpeedRule(withXOffset: CGFloat(xOffset))
        }

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
            drawNewTraffic(with: (newTraffic, traffics[newTraffic]!))
        }
    }

    func removeUnshownAndGetNewTraffics(usingShouldShown shouldShownTraffics: [HostTraffic]) -> [HostTraffic] {
        var shouldShown = shouldShownTraffics
        for current in currentShownTraffics {
            if let index = shouldShown.index(of: current.key) {
                shouldShown.remove(at: index)
            } else {
                currentShownTraffics.removeValue(forKey: current.key)
                current.value.removeFromSuperview()
            }
        }
        return shouldShown
    }

    func drawNewTraffic(with newTraffic: (HostTraffic, Int)) {
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
        let frame = CGRect(x: offsetTime * Double(horiScaller) + Double(horizontalOffset), y: Double(48 * rowIndex + verticalOffset), width: length * Double(horiScaller), height: 48.0)
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


    func drawTimelineRuler(fromTime ft: Date, toTime tT: Date, withYOffset yOffset: Double) {
        let offsetTime = ft.timeIntervalSince(beginTime)
        let length = tT.timeIntervalSince(ft)
        let frame = CGRect(x: offsetTime * Double(horiScaller) + Double(horizontalOffset), y: yOffset, width: length * Double(horiScaller), height: Double(verticalOffset))
        let duringTime = tT.timeIntervalSince(ft)
        let repCount = Int(duringTime + 1)

        timeLineRulerView.removeFromSuperview()
        timeLineRulerView = UIView(frame: frame)
        timeLineRulerView.backgroundColor = UIColor.white

        drawSectorLines(withRepeatCount: repCount, inView: timeLineRulerView)
        drawTimeStamp(fromTime: ft, withTotalCount: repCount, inView: timeLineRulerView)

        baseView.addSubview(timeLineRulerView)
    }

    func drawSectorLines(withRepeatCount repCount: Int, inView timelineView: UIView) {
        let repLayer = CAReplicatorLayer()
        repLayer.frame = CGRect(origin: .zero, size: CGSize(width: 2, height: 48.0))

        timelineView.layer.addSublayer(repLayer)

        let singleLine = CALayer()
        singleLine.frame = CGRect(x: -2, y: 0, width: 2, height: verticalOffset)
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
            let textView = UITextField(frame: CGRect(x: offset + horiScaller * i, y: 6, width: horiScaller - 10, height: 24))
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
                self.transferBodyStampsIntoTraffic(withResponseBodies: bodyStamps)
                for body in bodyStamps {
                    privateContext.refresh(body, mergeChanges: false)
                }
            } catch {
                DDLogError("\(error)")
            }
        }
        privateContext.performAndWait {
            let fetch: NSFetchRequest<ResponseHead> = ResponseHead.fetchRequest()
            fetch.sortDescriptors = [NSSortDescriptor.init(key: "time", ascending: true)]

            do {
                let headStamps = try privateContext.fetch(fetch)
                self.transferResponseHeadIntoTraffic(withheads: headStamps)
                for head in headStamps {
                    privateContext.refresh(head, mergeChanges: false)
                }
            } catch {
                DDLogError("\(error)")
            }
        }
        privateContext.performAndWait {
            let fetch: NSFetchRequest<RequestBodyStamp> = RequestBodyStamp.fetchRequest()
            fetch.sortDescriptors = [NSSortDescriptor.init(key: "timeStamp", ascending: true)]

            do {
                let bodyStamps = try privateContext.fetch(fetch)
                self.transferBodyStampsIntoTraffic(withRequestBodies: bodyStamps)
                for body in bodyStamps {
                    privateContext.refresh(body, mergeChanges: false)
                }
            } catch {
                DDLogError("\(error)")
            }
        }

        privateContext.performAndWait {
            self.transferRequestHeadIntoTraffic()
        }

        if let maxValue = responseTraffic.max() {
            maxTrafficValue = maxValue
            if let maxValue = requestTraffic.max() {
                if maxTrafficValue < maxValue {
                    maxTrafficValue = maxValue
                }
            }
        }
    }


    func transferBodyStampsIntoTraffic(withResponseBodies boides: [ResponseBodyStamp]) {
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
            tT = fT.addingTimeInterval(trafficStreamStep)
        }
    }

    func transferResponseHeadIntoTraffic(withheads heads: [ResponseHead]) {
        var fT = beginTime
        var tT = fT.addingTimeInterval(0.1)
        var heads = heads
        var index = 0
        while fT < endTime {
            var count = 0
            while let first = heads.first {
                if let time = first.time as Date? {
                    if time >= tT {
                        break
                    }
                    if time >= fT && time < tT {
                        count = count + Int(first.size)
                    }
                    heads.removeFirst()
                } else {
                    heads.removeFirst()
                }
            }
            responseTraffic[index] = responseTraffic[index] + count
            index = index + 1
            fT = tT
            tT = fT.addingTimeInterval(trafficStreamStep)
        }
    }

    func transferBodyStampsIntoTraffic(withRequestBodies boides: [RequestBodyStamp]) {
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
                    if time >= fT && time < tT && first.size != 0 {
                        count = count + Int(first.size)
                    }
                    boides.removeFirst()
                } else {
                    boides.removeFirst()
                }
            }
            requestTraffic.append(count)
            fT = tT
            tT = fT.addingTimeInterval(trafficStreamStep)
        }
    }

    func transferRequestHeadIntoTraffic() {
        var fT = beginTime
        var tT = fT.addingTimeInterval(0.1)
        var traffic = hostTraffics
        var index = 0
        while fT < endTime {
            var count = 0
            while let first = traffic.first {
                if let time = first.hostConnectInfo?.requestTime as Date? {
                    if time >= tT {
                        break
                    }
                    if time >= fT && time < tT {
                        if let size = first.requestHead?.size, size != 0 {
                            count = count + Int(size)
                        }
                    }
                    traffic.removeFirst()
                } else {
                    traffic.removeFirst()
                }
            }
            requestTraffic[index] = requestTraffic[index] + count
            index = index + 1
            fT = tT
            tT = fT.addingTimeInterval(trafficStreamStep)
        }
    }

    func drawTrafficStream(fromTime fT: Date, toTime tT: Date) {
        let requestShapeLayer = CAShapeLayer()
        let responseShapeLayer = CAShapeLayer()
        let duringTime = tT.timeIntervalSince(fT)
        let width = Int(duringTime * Double(horiScaller))
        let height = classifiedTrafficsInRow.count * 48

        let offsetTime = fT.timeIntervalSince(beginTime)
        let length = tT.timeIntervalSince(fT)
        let frame = CGRect(x: offsetTime * Double(horiScaller) + Double(horizontalOffset), y: Double(verticalOffset), width: length * Double(horiScaller), height: Double(height))

        trafficStreamView.removeFromSuperview()
        trafficStreamView = UIView(frame: frame)
        trafficStreamView.isUserInteractionEnabled = false

        requestShapeLayer.frame = CGRect(x: 0, y: 0, width: width, height: height)
        responseShapeLayer.frame = CGRect(x: 0, y: 0, width: width, height: height)

        trafficStreamView.layer.addSublayer(requestShapeLayer)
        trafficStreamView.layer.addSublayer(responseShapeLayer)

        let startIndex = Int(offsetTime / trafficStreamStep)
        let endIndex = Int(length / trafficStreamStep) + startIndex

        let requestSubTraffics = requestTraffic[startIndex ..< endIndex]
        let responseSubTraffics = responseTraffic[startIndex ..< endIndex]
        
        drawTrafficStreamLine(inLayer: requestShapeLayer, withStrokeColor: UIColor.blue.cgColor, andSubTraffics: Array(requestSubTraffics))
        drawTrafficStreamLine(inLayer: responseShapeLayer, withStrokeColor: UIColor.green.cgColor, andSubTraffics: Array(responseSubTraffics))
        
        baseView.addSubview(trafficStreamView)
    }

    func drawTrafficStreamLine(inLayer layer: CAShapeLayer, withStrokeColor storkeColor: CGColor, andSubTraffics traffics: [Int]) {
        let line = UIBezierPath()
        line.move(to: .zero)
        
        for (index, traffic) in traffics.enumerated() {
            let x = CGFloat(trafficStreamStep) * CGFloat((index) * horiScaller)
            let y: CGFloat
            if maxTrafficValue == 0 {
                y = 0
            } else {
                y = layer.bounds.height * CGFloat(traffic) / CGFloat(maxTrafficValue)
            }
            line.addLine(to: CGPoint(x: x, y: y))
        }
        layer.path = line.cgPath
        layer.strokeColor = storkeColor
        layer.fillColor = UIColor.clear.cgColor
        layer.lineWidth = 2
    }


    func drawSpeedRuler(withHeight height: Int, withXOffset xOffset: Double) {
        let frame = CGRect(x: xOffset, y: Double(verticalOffset), width: Double(horizontalOffset), height: Double(height))

        speedLineRulerView = UIView(frame: frame)
        speedLineRulerView.backgroundColor = UIColor.white

        drawSpeedLines(withHeight: height, inRulerView: speedLineRulerView)
        drawSpeedTexts(withHeight: height, inRulerView: speedLineRulerView)

        baseView.addSubview(speedLineRulerView)
    }

    func updateSpeedRule(withXOffset xOffset: CGFloat) {
        speedLineRulerView.frame.origin.x = xOffset
        baseView.bringSubview(toFront: speedLineRulerView)
    }

    func drawSpeedLines(withHeight height: Int, inRulerView rulerView: UIView) {
        let verticalLine = CALayer()
        verticalLine.frame = CGRect(x: rulerView.bounds.width - 2, y: 0, width: 2, height: CGFloat(height))
        verticalLine.backgroundColor = UIColor.black.cgColor
        rulerView.layer.addSublayer(verticalLine)

        let repeatCount = height / Int(horiScaller) + 1
        let horiLineLayer = CAReplicatorLayer()
        horiLineLayer.frame = CGRect(x: 0, y: 0, width: rulerView.bounds.width, height: CGFloat(height))
        rulerView.layer.addSublayer(horiLineLayer)
        let horiLine = CALayer()
        horiLine.frame = CGRect(x: 0, y: -2, width: rulerView.bounds.width, height: 2)
        horiLine.backgroundColor = UIColor.black.cgColor
        horiLineLayer.addSublayer(horiLine)
        horiLineLayer.instanceCount = repeatCount
        horiLineLayer.instanceTransform = CATransform3DMakeTranslation(0, CGFloat(horiScaller), 0)
    }

    func drawSpeedTexts(withHeight height: Int, inRulerView rulerView: UIView) {
        let repeatCount = height / Int(horiScaller) + 1
        if let maxValue = responseTraffic.max() {
            for i in 0 ..< repeatCount {
                let textLayer = CATextLayer()
//                textLayer.frame = CGRect(x: 48, y: 48 + i * 100, width: 100, height: 30)
                textLayer.anchorPoint = .zero
                textLayer.bounds = CGRect(x: 0, y: 0, width: 100, height: 30)
                textLayer.position = CGPoint(x: rulerView.bounds.width, y: CGFloat(3 + i * 100))
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
                rulerView.layer.addSublayer(textLayer)

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
