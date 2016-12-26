//
//  RequestDetailTableViewController.swift
//  ThroughWall
//
//  Created by Bingo on 26/12/2016.
//  Copyright © 2016 Wu Bin. All rights reserved.
//

import UIKit

class RequestDetailTableViewController: UITableViewController {

    var hostRequest: HostTraffic!
    var prototypeCell: UITableViewCell!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
        prototypeCell = tableView.dequeueReusableCell(withIdentifier: "trafficHeader")
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
        return 2
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Configure the cell...
        switch indexPath.section {
        case 0:
            let localFormatter = DateFormatter()
            localFormatter.locale = Locale.current
            localFormatter.dateFormat = "HH:mm:ss:SSS"
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "timeDetail", for: indexPath)
            
            if indexPath.row == 0 {
                cell.textLabel?.text = "Request Time"
                if hostRequest.requestTime != nil{
                    cell.detailTextLabel?.text = localFormatter.string(from: hostRequest.requestTime as! Date)
                }
            }else{
                cell.textLabel?.text = "Response Time"
                if hostRequest.responseTime != nil {
                    cell.detailTextLabel?.text = localFormatter.string(from: hostRequest.responseTime as! Date)
                }
            }
            return cell
        default:
            let cell = tableView.dequeueReusableCell(withIdentifier: "trafficHeader", for: indexPath)
            let textView = cell.viewWithTag(103) as! UITextView
            if indexPath.row == 0 {
                textView.text = hostRequest.requestHead
            }else{
                textView.text = hostRequest.responseHead
            }
            return cell
        }
        
    }
    
    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 {
            return 38
        }else{
            let textView = prototypeCell.viewWithTag(103) as! UITextView
            if indexPath.row == 0 {
                textView.text = hostRequest.requestHead
            }else{
                textView.text = hostRequest.responseHead
            }
            let contentSize = textView.sizeThatFits(textView.bounds.size)
            return contentSize.height
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
