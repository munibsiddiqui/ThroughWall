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
    @IBOutlet weak var chartView: LineChartView!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        chartView.noDataText = "Not Enough Data"
        
        
    }

    
    override func viewWillAppear(_ animated: Bool) {
        let fetchSecondData: NSFetchRequest<HistoryTraffic> = HistoryTraffic.fetchRequest()
        fetchSecondData.predicate = NSPredicate(format: "hisType <= %@ && pathType == %@ && proxyType == %@", "second", "WIFI", "Proxy")
        
        do {
            let histories = try CoreDataController.sharedInstance.getContext().fetch(fetchSecondData)
            
            for history in histories {
                print("\(history.timestamp) \(history.inCount) \(history.outCount)")
            }
            
        }catch{
            print(error)
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
