//
//  RequestListTableViewController.swift
//  ThroughWall
//
//  Created by Bin on 26/12/2016.
//  Copyright © 2016 Wu Bin. All rights reserved.
//

import UIKit
import CoreData
import CocoaLumberjack

class RequestListTableViewController: UITableViewController {

    var hostTraffics = [HostTraffic]()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()

        tableView.tableFooterView = UIView()
        tableView.backgroundColor = veryLightGrayUIColor
        
        let defaults = UserDefaults()
        if let vpnStatus = defaults.value(forKey: kCurrentManagerStatus) as? String {
            if vpnStatus == "Disconnected" {
                CoreDataController.sharedInstance.closeCrashLogs()
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        requestHostTraffic()
    }

    @IBAction func actionsToTake(_ sender: UIBarButtonItem) {
        let listController = UIAlertController(title: "Actions", message: nil, preferredStyle: .actionSheet)

        let showTimelineAction = UIAlertAction(title: "Timeline View (Experimental)", style: .default) { (_) in
            DispatchQueue.main.async {
                self.performSegue(withIdentifier: "showTimeline", sender: nil)
            }
        }
        listController.addAction(showTimelineAction)

        let clearLog = UIAlertAction(title: "Clear Completed Logs", style: .destructive) { (_) in
            DispatchQueue.main.async {
                self.clearCompletedLogs()
            }
        }

        let cancelItem = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)

        listController.addAction(clearLog)
        listController.addAction(cancelItem)

        if let popoverPresentationController = listController.popoverPresentationController {
            popoverPresentationController.barButtonItem = sender
        }

        present(listController, animated: true, completion: nil)
    }

    func clearCompletedLogs() {
        let defaults = UserDefaults()
        let vpnStatus: String
        if let _vpnStatus = defaults.value(forKey: kCurrentManagerStatus) as? String {
            vpnStatus = _vpnStatus
        } else {
            vpnStatus = "Disconnected"
        }

        if vpnStatus == "Disconnected" {
            for hostTraffic in self.hostTraffics {
                CoreDataController.sharedInstance.getContext().delete(hostTraffic)
            }
            let parseDirectory = CoreDataController.sharedInstance.getDatabaseUrl().appendingPathComponent(parseFolderName)
            do {
                try FileManager.default.removeItem(at: parseDirectory)
            } catch {
                DDLogError("\(error)")
            }
            CoreDataController.sharedInstance.saveContext()
            requestHostTraffic()

            tableView.reloadData()
        } else {
            let parseDirectory = CoreDataController.sharedInstance.getDatabaseUrl().appendingPathComponent(parseFolderName)
            for hostTraffic in hostTraffics {
                if hostTraffic.inProcessing == false {
                    if let requestBodies = hostTraffic.requestBodies?.allObjects as? [RequestBodyPiece] {
                        for requestBody in requestBodies {
                            let filePath = parseDirectory.appendingPathComponent(requestBody.fileName!)
                            do {
                                try FileManager.default.removeItem(at: filePath)
                            } catch {
                                DDLogError("\(error)")
                            }
                        }
                    }

                    if let responseBodies = hostTraffic.requestBodies?.allObjects as? [RequestBodyPiece] {
                        for responseBody in responseBodies {
                            let filePath = parseDirectory.appendingPathComponent(responseBody.fileName!)
                            do {
                                try FileManager.default.removeItem(at: filePath)
                            } catch {
                                DDLogError("\(error)")
                            }
                        }
                    }

                    CoreDataController.sharedInstance.getContext().delete(hostTraffic)
                }
            }
            CoreDataController.sharedInstance.saveContext()
            requestHostTraffic()
            tableView.reloadData()
        }
    }

    func requestHostTraffic() {
        let fetch: NSFetchRequest<HostTraffic> = HostTraffic.fetchRequest()
//        fetch.sortDescriptors = [NSSortDescriptor.init(key: "requestTime", ascending: true)]

        do {
            hostTraffics = try CoreDataController.sharedInstance.getContext().fetch(fetch)
            hostTraffics.sort(by: { (first, second) -> Bool in
                guard let firstTime = first.hostConnectInfo?.requestTime, let secondTime = second.hostConnectInfo?.requestTime else {
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


    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return hostTraffics.count

    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "requestList", for: indexPath)

        // Configure the cell...
        cell.textLabel?.text = (hostTraffics[indexPath.row].hostConnectInfo?.name ?? "") + ":\(hostTraffics[indexPath.row].hostConnectInfo?.port ?? 0)"
        if hostTraffics[indexPath.row].hostConnectInfo?.requestTime != nil {
            cell.detailTextLabel?.attributedText = makeAttributeDescription(fromHostTraffic: hostTraffics[indexPath.row])
        } else {
            cell.detailTextLabel?.text = "Error \(hostTraffics[indexPath.row].inProcessing) P"
        }
        return cell

    }


    func makeAttributeDescription(fromHostTraffic hostTraffic: HostTraffic) -> NSAttributedString {
        let localFormatter = DateFormatter()
        localFormatter.locale = Locale.current
        localFormatter.dateFormat = "HH:mm:ss:SSS"

        let attributeDescription = NSMutableAttributedString(string: "")

        if let rule = hostTraffic.hostConnectInfo?.rule {
            switch rule.lowercased() {
            case "direct":
                let attributeRule = NSAttributedString(string: rule, attributes: [NSBackgroundColorAttributeName: UIColor.init(red: 0.24, green: 0.545, blue: 0.153, alpha: 1.0)])
                attributeDescription.append(attributeRule)
                attributeDescription.append(NSAttributedString(string: " "))
            case "proxy":
                let attributeRule = NSAttributedString(string: rule, attributes: [NSBackgroundColorAttributeName: UIColor.orange])
                attributeDescription.append(attributeRule)
                attributeDescription.append(NSAttributedString(string: " "))
            default:
                let attributeRule = NSAttributedString(string: rule, attributes: [NSBackgroundColorAttributeName: UIColor.red])
                attributeDescription.append(attributeRule)
                attributeDescription.append(NSAttributedString(string: " "))
            }
        }

        if let requestHead = hostTraffic.requestHead?.head {
            let requestType = requestHead.components(separatedBy: " ")[0]

            let attributeRequestType = NSAttributedString(string: requestType, attributes: [NSForegroundColorAttributeName: UIColor.white, NSBackgroundColorAttributeName: UIColor.init(red: 0.24, green: 0.545, blue: 0.153, alpha: 1.0)])

            attributeDescription.append(attributeRequestType)
            attributeDescription.append(NSAttributedString(string: " "))
        }

        if hostTraffic.inProcessing == true {
            let attributeIsComplete = NSAttributedString(string: "Incomplete", attributes: [NSBackgroundColorAttributeName: UIColor.orange])
            attributeDescription.append(attributeIsComplete)
            attributeDescription.append(NSAttributedString(string: " "))
        } else {
            var backColor = UIColor.green
            if hostTraffic.forceDisconnect == true {
                backColor = UIColor.gray
            }
            let attributeIsComplete = NSAttributedString(string: "Complete", attributes: [NSBackgroundColorAttributeName: backColor])
            attributeDescription.append(attributeIsComplete)
            attributeDescription.append(NSAttributedString(string: " "))
        }

        attributeDescription.append(NSAttributedString(string: localFormatter.string(from: hostTraffic.hostConnectInfo!.requestTime! as Date)))

        return attributeDescription
    }


    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        performSegue(withIdentifier: "showRequestDetail", sender: hostTraffics[indexPath.row])
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
        if segue.identifier == "showRequestDetail" {
            let desti = segue.destination as! RequestDetailTableViewController
            desti.hostRequest = sender as! HostTraffic
        }
    }


}
