//
//  RequestDetailTableViewController.swift
//  ThroughWall
//
//  Created by Bingo on 26/12/2016.
//  Copyright © 2016 Wu Bin. All rights reserved.
//

import UIKit
import CocoaAsyncSocket
import CocoaLumberjack

class RequestDetailTableViewController: UITableViewController {

    var hostRequest: HostTraffic!
    var prototypeCell: UITableViewCell!

    var outgoing = OutGoing()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
        prototypeCell = tableView.dequeueReusableCell(withIdentifier: "trafficHeader")
//        tableView.estimatedRowHeight = 48
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.tableFooterView = UIView()
        tableView.backgroundColor = veryLightGrayUIColor
//        outgoingConnection = GCDAsyncSocket(delegate: self, delegateQueue: DispatchQueue.global())
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

//    @IBAction func testConnection(_ sender: UIBarButtonItem) {
//        guard let host = hostRequest.hostConnectInfo?.name, let port = hostRequest.hostConnectInfo?.port else {
//            return
//        }
//        DispatchQueue.global().async {
//            self.outgoing.connect2(toHost: host, andPort: UInt16(port))
//        }
//    }

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
                    if let timeStamp = responseHead.time {
                        cell.detailTextLabel?.text = localFormatter.string(from: timeStamp as Date)
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


class OutGoing: NSObject, GCDAsyncSocketDelegate {

    var outgoingConnection: GCDAsyncSocket?

    func connect(toHost host: String, andPort port: UInt16) {
        outgoingConnection = GCDAsyncSocket(delegate: self, delegateQueue: DispatchQueue.global())

        do {
            try outgoingConnection?.connect(toHost: host, onPort: port)
            DDLogDebug("connecting \(host):\(port)")
        } catch {
            DDLogError("\(error)")
        }
    }

    func connect2(toHost host: String, andPort port: UInt16) {
        DDLogInfo("Start")
        var hints = addrinfo(
            ai_flags: 0,
            ai_family: PF_UNSPEC,
            ai_socktype: SOCK_STREAM,
            ai_protocol: IPPROTO_TCP,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil)

//        let host:CString = "www.apple.com"
//        let port:CString = "http" //could use "80" here
        var result: UnsafeMutablePointer<addrinfo>? = nil

        let error = getaddrinfo(host, "\(port)", &hints, &result)

        DDLogDebug("error \(error)")

        var info = result
        while info != nil {
            let (clientIp, service) = sockaddrDescription(addr: info!.pointee.ai_addr)
            let message = "HostIp: " + (clientIp ?? "?") + " at port: " + (service ?? "?")
            print(message)
            info = info!.pointee.ai_next
        }

        //free the chain
        freeaddrinfo(result)

    }


    func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        DDLogDebug("Connected \(host):\(port)")
    }


    func sockaddrDescription(addr: UnsafePointer<sockaddr>) -> (String?, String?) {

        var host: String?
        var service: String?

        var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        var serviceBuffer = [CChar](repeating: 0, count: Int(NI_MAXSERV))

        if getnameinfo(
                addr,
                socklen_t(addr.pointee.sa_len),
                    &hostBuffer,
                socklen_t(hostBuffer.count),
                    &serviceBuffer,
                socklen_t(serviceBuffer.count),
                NI_NUMERICHOST | NI_NUMERICSERV)

            == 0 {

            host = String(cString: hostBuffer)
            service = String(cString: serviceBuffer)
        }
        return (host, service)

    }

}
