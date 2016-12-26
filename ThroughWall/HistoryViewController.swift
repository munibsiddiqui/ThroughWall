//
//  HistoryViewController.swift
//  ThroughWall
//
//  Created by Bingo on 25/12/2016.
//  Copyright © 2016 Wu Bin. All rights reserved.
//

import UIKit
import Charts
import CoreData

class HistoryViewController: UIViewController {
    @IBOutlet weak var downloadChartView: LineChartView!
    @IBOutlet weak var uploadChartView: LineChartView!

//    var startTime: NSDate?
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        downloadChartView.noDataText = "Not Enough Data"
        downloadChartView.xAxis.labelPosition = .bottom
        downloadChartView.rightAxis.enabled = false
        downloadChartView.chartDescription?.text = ""
        
        uploadChartView.noDataText = "Not Enough Data"
        uploadChartView.xAxis.labelPosition = .bottom
        uploadChartView.rightAxis.enabled = false
        uploadChartView.chartDescription?.text = ""
    }

    
    override func viewWillAppear(_ animated: Bool) {
        showRecent()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func segmentChanged(_ sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 0 {
            showRecent()
        }else{
            showHour()
        }
    }
    
    
    func showRecent() {
        let pastSeconds = 3600
        let step = 30
        let startTime = NSDate.init(timeInterval: TimeInterval(-1 * pastSeconds), since: Date())
        
        let fetch: NSFetchRequest<HistoryTraffic> = HistoryTraffic.fetchRequest()
        fetch.predicate = NSPredicate(format: "timestamp >= %@ && hisType == %@ && proxyType == %@", startTime, "second", "Proxy")
        let histories = fetchHistory(fetch)
        drawHistory(histories, startTime: startTime, pastSeconds: pastSeconds, stepSeconds: step)
    }
    
    func showHour() {
        let pastSeconds = 3600 * 12
        let step = 3600
        let startTime = NSDate.init(timeInterval: TimeInterval(-1 * pastSeconds), since: Date())
        let fetch: NSFetchRequest<HistoryTraffic> = HistoryTraffic.fetchRequest()
        
        fetch.predicate = NSPredicate(format: "timestamp >= %@ && hisType == %@ && proxyType == %@", startTime, "second", "Proxy")
        let histories = fetchHistory(fetch)
        drawHistory(histories, startTime: startTime, pastSeconds: pastSeconds, stepSeconds: step)

    }
    
    
    func fetchHistory(_ fetch: NSFetchRequest<HistoryTraffic>) -> [HistoryTraffic] {
        do{
            let histories = try CoreDataController.sharedInstance.getContext().fetch(fetch)
            return histories
        }catch{
            print(error)
            return [HistoryTraffic]()
        }
    }
    
    func autoFitRange(maxValue: Int) -> (Int, String) {
        var scale = 1
        var unit = "B"
        switch maxValue {
        case 0 ..< 1024:
            break
        case 1024 ..< 1024*1024:
            scale = 1024
            unit = "KB"
        case 1024*1024 ..< 1024*1024*1024:
            scale = 1024*1024
            unit = "MB"
        default:
            scale = 1024*1024*1024
            unit = "GB"
        }
        return (scale, unit)
    }
    
    func drawHistory(_ histories: [HistoryTraffic],startTime: NSDate , pastSeconds: Int, stepSeconds: Int) {
        let localFormatter = DateFormatter()
        localFormatter.locale = Locale.current
        localFormatter.dateFormat = "HH:mm"
        let count = pastSeconds%stepSeconds > 0 ? pastSeconds/stepSeconds + 1 : pastSeconds/stepSeconds
        var historyDic = [[Int]].init(repeating: [0, 0], count: count)
        var maxInValue = 0
        var maxOutValue = 0
        
        for history in histories {
            let index = Int((history.timestamp?.timeIntervalSince(startTime as Date))!) / stepSeconds
            historyDic[index][0] = historyDic[index][0] + Int(history.inCount)
            if maxInValue < historyDic[index][0] {
                maxInValue = historyDic[index][0]
            }
            historyDic[index][1] = historyDic[index][1] + Int(history.outCount)
            if maxOutValue < historyDic[index][1] {
                maxOutValue = historyDic[index][1]
            }
        }
        
        var inValues = [ChartDataEntry]()
        var outValues = [ChartDataEntry]()
        
        let (inScale, inUnit) = autoFitRange(maxValue: maxInValue/stepSeconds)
        let (outScale, outUnit) = autoFitRange(maxValue: maxOutValue/stepSeconds)
        
        for index in 0 ..< historyDic.count {
            let values = historyDic[index]
            let x = Double(index)
            let yIN = Double(values[0])/Double(stepSeconds * inScale)
            let yOUT = Double(values[1])/Double(stepSeconds * outScale)
            inValues.append(ChartDataEntry(x: x, y: yIN))
            outValues.append(ChartDataEntry(x: x, y: yOUT))
        }
        
        let inSet = LineChartDataSet(values: inValues, label: "Download(\(inUnit)/s)")
        let outSet = LineChartDataSet(values: outValues, label: "Upload(\(outUnit)/s)")
        
        inSet.drawCirclesEnabled = false
        inSet.drawValuesEnabled = false
        
        outSet.drawCirclesEnabled = false
        outSet.drawValuesEnabled = false
        
        let downloadChartData = LineChartData(dataSet: inSet)
        let uploadChartData = LineChartData(dataSet: outSet)
        downloadChartView.data = downloadChartData
        uploadChartView.data = uploadChartData
        
        var xValues = [String]()
        for i in 0 ..< 60 {
            xValues.append("\(localFormatter.string(from: Date.init(timeInterval: TimeInterval(i * stepSeconds) , since: startTime as Date)))")
        }
        
        downloadChartView.xAxis.valueFormatter = IndexAxisValueFormatter(values: xValues)
        uploadChartView.xAxis.valueFormatter = IndexAxisValueFormatter(values: xValues)
        
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
