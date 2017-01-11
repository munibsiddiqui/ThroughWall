//
//  ArchivedTrafficCountTableViewController.swift
//  ThroughWall
//
//  Created by Bin on 11/01/2017.
//  Copyright © 2017 Wu Bin. All rights reserved.
//

import UIKit
import CoreData


class ArchivedTrafficCountTableViewController: UITableViewController {

    var archived = [(String, Int)]()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
        let fetchData: NSFetchRequest<HistoryTraffic> = HistoryTraffic.fetchRequest()
        fetchData.predicate = NSPredicate(format: "hisType == %@", "month")
        fetchData.sortDescriptors = [NSSortDescriptor.init(key: "timestamp", ascending: true)]
        
        let localFormatter = DateFormatter()
        localFormatter.locale = Locale.current
        localFormatter.dateFormat = "yyyy-MMMM"
        
        do {
            let data = try CoreDataController.sharedInstance.getContext().fetch(fetchData)
            for _data in data {
                if let date = _data.timestamp {
                    let time = localFormatter.string(from: date as Date)
                    let count = _data.inCount + _data.outCount
                    archived.append((time, Int(count)))
                }
            }
        }catch{
            print(error)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        if section == 0 {
            return archived.count
        }
        return 1
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "basiccell", for: indexPath)
            
            // Configure the cell...
            let (date, count) = archived[indexPath.row]
            let (scale, unit) = autoFitRange(maxValue: count)
            cell.textLabel?.text = "\(date): \(count/scale)\(unit)"
            
            return cell
        }else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "clearCell", for: indexPath)
            return cell
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
    
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 1 {
            let alertController = UIAlertController(title: "Clear Archived Logs", message: nil, preferredStyle: .alert)
            let deleteAction = UIAlertAction(title: "Clear", style: .destructive, handler: { (_) in
                
                let fetchData: NSFetchRequest<HistoryTraffic> = HistoryTraffic.fetchRequest()
                fetchData.predicate = NSPredicate(format: "hisType == %@", "month")
                
                do {
                    let data = try CoreDataController.sharedInstance.getContext().fetch(fetchData)
                    DispatchQueue.main.async {
                        for _data in data {
                            CoreDataController.sharedInstance.getContext().delete(_data)
                        }
                        CoreDataController.sharedInstance.saveContext()
                        
                        tableView.reloadData()
                    }
                }catch{
                    print(error)
                }
                
            })
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
            
            alertController.addAction(cancelAction)
            alertController.addAction(deleteAction)
            
            self.present(alertController, animated: true, completion: nil)
        }
    }

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
