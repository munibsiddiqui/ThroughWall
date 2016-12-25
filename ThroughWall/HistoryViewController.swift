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

    var startTime: NSDate?
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
        let fetchSecondData: NSFetchRequest<HistoryTraffic> = HistoryTraffic.fetchRequest()
        startTime = NSDate.init(timeInterval: -3600, since: Date())
        fetchSecondData.predicate = NSPredicate(format: "timestamp >= %@ && hisType <= %@ && pathType == %@ && proxyType == %@", startTime!, "second", "WIFI", "Proxy")
        
        showDataWith(startTime!, historyType: "second", pathType: "WIFI", proxyType: "Proxy")
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    func showDataWith(_ startTime: NSDate, historyType: String, pathType: String, proxyType: String) {
        let fetchSecondData: NSFetchRequest<HistoryTraffic> = HistoryTraffic.fetchRequest()
        fetchSecondData.predicate = NSPredicate(format: "timestamp >= %@ && hisType <= %@ && pathType == %@ && proxyType == %@", startTime, historyType, pathType, proxyType)
        let localFormatter = DateFormatter()
        localFormatter.locale = Locale.current
        localFormatter.dateFormat = "HH:mm"
        var historyDic = [[Int]].init(repeating: [0, 0], count: 60)
        
        var maxInValue = 0
        var maxOutValue = 0
        do {
            let histories = try CoreDataController.sharedInstance.getContext().fetch(fetchSecondData)
            
            for history in histories {
                let index = Int((history.timestamp?.timeIntervalSince(startTime as Date))!) / 60
                historyDic[index][0] = historyDic[index][0] + Int(history.inCount)
                if maxInValue < historyDic[index][0] {
                   maxInValue = historyDic[index][0]
                }
                historyDic[index][1] = historyDic[index][1] + Int(history.outCount)
                if maxOutValue < historyDic[index][1] {
                   maxOutValue = historyDic[index][1]
                }
            }
            
        }catch{
            print(error)
        }
        
        var inValues = [ChartDataEntry]()
        var outValues = [ChartDataEntry]()
        var inScale = 1
        var outScale = 1
        var inUnit = "B"
        var outUnit = "B"
        
        switch maxInValue / 60 {
        case 0 ..< 1024:
            break
        case 1024 ..< 1024*1024:
            inScale = 1024
            inUnit = "KB"
        case 1024*1024 ..< 1024*1024*1024:
            inScale = 1024 * 1024
            inUnit = "MB"
        default:
            inScale = 1024 * 1024 * 1024
            inUnit = "GB"
        }
        
        switch maxOutValue / 60 {
        case 0 ..< 1024:
            break
        case 1024 ..< 1024*1024:
            outScale = 1024
            outUnit = "KB"
        case 1024*1024 ..< 1024*1024*1024:
            outScale = 1024 * 1024
            outUnit = "MB"
        default:
            outScale = 1024 * 1024 * 1024
            outUnit = "GB"
        }
        
        
        for index in 0 ..< historyDic.count {
            let values = historyDic[index]
            let x = Double(index)
            let yIN = Double(values[0])/Double(60 * inScale)
            let yOUT = Double(values[1])/Double(60 * outScale)
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
            xValues.append("\(localFormatter.string(from: Date.init(timeInterval: TimeInterval(i * 60) , since: startTime as Date)))")
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
