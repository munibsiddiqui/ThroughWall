//
//  RequestListTableViewController.swift
//  ThroughWall
//
//  Created by Bin on 26/12/2016.
//  Copyright © 2016 Wu Bin. All rights reserved.
//

import UIKit
import CoreData

class RequestListTableViewController: UITableViewController {

    var hostTraffics = [HostTraffic]()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        requestHostTraffic()
    }
    
    func requestHostTraffic() {
        let fetch: NSFetchRequest<HostTraffic> = HostTraffic.fetchRequest()
        do{
            hostTraffics = try CoreDataController.sharedInstance.getContext().fetch(fetch)
        }catch{
            print(error)
        }
    }
    
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        if section == 0 {
            return hostTraffics.count
        }else{
            return 1
        }
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "requestList", for: indexPath)
            
            // Configure the cell...
            cell.textLabel?.text = hostTraffics[indexPath.row].hostName
            if hostTraffics[indexPath.row].requestTime != nil {
                cell.detailTextLabel?.attributedText = makeAttributeDescription(fromHostTraffic: hostTraffics[indexPath.row])
            }else{
                cell.detailTextLabel?.text = "Error"
            }
            return cell
        }else{
            let cell = tableView.dequeueReusableCell(withIdentifier: "clearRequests", for: indexPath)
            return cell
        }
    }
    
    
    func makeAttributeDescription(fromHostTraffic hostTraffic: HostTraffic) -> NSAttributedString {
        let localFormatter = DateFormatter()
        localFormatter.locale = Locale.current
        localFormatter.dateFormat = "HH:mm:ss:SSS"

        let attributeDescription = NSMutableAttributedString(string: "")
        
        if let rule = hostTraffic.rule {
            switch rule {
            case "Direct":
                let attributeRule = NSAttributedString(string: rule, attributes: [NSBackgroundColorAttributeName : UIColor.green])
                attributeDescription.append(attributeRule)
                attributeDescription.append(NSAttributedString(string: " "))
            case "Proxy":
                let attributeRule = NSAttributedString(string: rule, attributes: [NSBackgroundColorAttributeName : UIColor.orange])
                attributeDescription.append(attributeRule)
                attributeDescription.append(NSAttributedString(string: " "))
            default:
                let attributeRule = NSAttributedString(string: rule, attributes: [NSBackgroundColorAttributeName : UIColor.red])
                attributeDescription.append(attributeRule)
                attributeDescription.append(NSAttributedString(string: " "))
            }
        }
        
        if let requestHead = hostTraffic.requestHead {
            let requestType = requestHead.components(separatedBy: " ")[0]
            
            let attributeRequestType = NSAttributedString(string: requestType, attributes: [NSForegroundColorAttributeName : UIColor.white, NSBackgroundColorAttributeName: UIColor.green])
            
            attributeDescription.append(attributeRequestType)
            attributeDescription.append(NSAttributedString(string: " "))
        }
        
        if hostTraffic.inProcessing == true {
            let attributeIsComplete = NSAttributedString(string:  "Incomplete", attributes: [NSBackgroundColorAttributeName : UIColor.orange])
            attributeDescription.append(attributeIsComplete)
            attributeDescription.append(NSAttributedString(string: " "))
        }else {
            var backColor = UIColor.green
            if hostTraffic.forceDisconnect == true {
                backColor = UIColor.gray
            }
            let attributeIsComplete = NSAttributedString(string:  "Complete", attributes: [NSBackgroundColorAttributeName : backColor])
            attributeDescription.append(attributeIsComplete)
            attributeDescription.append(NSAttributedString(string: " "))
        }

        attributeDescription.append(NSAttributedString(string: localFormatter.string(from: hostTraffic.requestTime as! Date)))
        
        return attributeDescription
    }
    

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            performSegue(withIdentifier: "showRequestDetail", sender: hostTraffics[indexPath.row])
        }else{
            let alertController = UIAlertController(title: "Clear Completed Logs", message: nil, preferredStyle: .alert)
            let deleteAction = UIAlertAction(title: "Clear", style: .destructive, handler: { (_) in
                DispatchQueue.main.async {
                    for hostTraffic in self.hostTraffics {
                        if hostTraffic.inProcessing ==  false {
                            CoreDataController.sharedInstance.getContext().delete(hostTraffic)
                        }
                    }
                    CoreDataController.sharedInstance.saveContext()
                    self.requestHostTraffic()
                    
                    tableView.reloadData()
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

    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        if segue.identifier == "showRequestDetail"{
            let desti = segue.destination as! RequestDetailTableViewController
            desti.hostRequest = sender as! HostTraffic
        }
    }
    

}
