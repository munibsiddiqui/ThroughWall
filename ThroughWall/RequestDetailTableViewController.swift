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
        return 5
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        if section == 0 {
            return 1
        } else if section == 1 {
            return 3
        } else if section == 2 {
            return 2
        } else if section == 3 {
            return 1
        }
        return 2
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "Rule"
        case 1:
            return "Time"
        case 2:
            return "Traffic"
        case 3:
            return "Status"
        default:
            return "Request & Response"
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Configure the cell...
        switch indexPath.section {
        case 0:
            let cell = tableView.dequeueReusableCell(withIdentifier: "timeDetail", for: indexPath)

            cell.textLabel?.text = "Rule"
            cell.detailTextLabel?.text = hostRequest.hostConnectInfo?.rule

            return cell
        case 1:
            let localFormatter = DateFormatter()
            localFormatter.locale = Locale.current
            localFormatter.dateFormat = "HH:mm:ss:SSS"

            let cell = tableView.dequeueReusableCell(withIdentifier: "timeDetail", for: indexPath)

            if indexPath.row == 0 {
                cell.textLabel?.text = "Request Time"
                if let hostInfo = hostRequest.hostConnectInfo {
                    if hostInfo.requestTime != nil {
                        cell.detailTextLabel?.text = localFormatter.string(from: hostInfo.requestTime! as Date)
                        return cell
                    }
                }

                cell.detailTextLabel?.text = ""

            } else if indexPath.row == 1 {
                cell.textLabel?.text = "Response Time"
                if let responseHead = hostRequest.responseHead {
                    if responseHead.time != nil {
                        cell.detailTextLabel?.text = localFormatter.string(from: responseHead.time! as Date)
                        return cell
                    }
                }
                cell.detailTextLabel?.text = ""
            } else {
                cell.textLabel?.text = "Disconnect Time"
                if hostRequest.disconnectTime != nil {
                    cell.detailTextLabel?.text = localFormatter.string(from: hostRequest.disconnectTime! as Date)
                } else {
                    cell.detailTextLabel?.text = ""
                }
            }
            return cell
        case 2:
            let cell = tableView.dequeueReusableCell(withIdentifier: "timeDetail", for: indexPath)
            if indexPath.row == 0 {
                cell.textLabel?.text = "Upload"
                cell.detailTextLabel?.text = "\(hostRequest.outCount)B"
            } else if indexPath.row == 1 {
                cell.textLabel?.text = "Download"
                cell.detailTextLabel?.text = "\(hostRequest.inCount)B"
            }
            return cell
        case 3:
            let cell = tableView.dequeueReusableCell(withIdentifier: "timeDetail", for: indexPath)

            cell.textLabel?.text = "Status"
            cell.detailTextLabel?.text = hostRequest.inProcessing ? "Incomplete" : "Complete"

            return cell
        default:
            let cell = tableView.dequeueReusableCell(withIdentifier: "trafficHeader", for: indexPath)
            let textView = cell.viewWithTag(103) as! UITextView
            if indexPath.row == 0 {
                textView.text = hostRequest.requestHead?.head
            } else {
                textView.text = hostRequest.responseHead?.head
            }
            return cell
        }

    }

    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section != 4 {
            return 38
        } else {
            let textView = prototypeCell.viewWithTag(103) as! UITextView
            if indexPath.row == 0 {
                textView.text = hostRequest.requestHead?.head
            } else {
                textView.text = hostRequest.responseHead?.head
            }
            let contentSize = textView.sizeThatFits(self.view.bounds.size)
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
