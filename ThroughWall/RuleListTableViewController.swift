//
//  RuleListTableViewController.swift
//  ThroughWall
//
//  Created by Bin on 30/03/2017.
//  Copyright © 2017 Wu Bin. All rights reserved.
//

import UIKit

class RuleListTableViewController: UITableViewController, UISearchResultsUpdating, UISearchControllerDelegate, UISearchBarDelegate {

    var ruleItems = [[String]]()
    var rewriteItems = [[String]]()

    var filteredRuleItems = [[String]]()
    var filteredRewriteItems = [[String]]()

    var selectedIndex = -1

    let searchController = UISearchController(searchResultsController: nil)


    var filterText = ""

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()

        navigationController?.navigationBar.barTintColor = topUIColor

        tableView.tableFooterView = UIView()
        tableView.backgroundColor = UIColor.groupTableViewBackground

//        self.edgesForExtendedLayout = UIRectEdge.all
        self.extendedLayoutIncludesOpaqueBars = true

        NotificationCenter.default.addObserver(self, selector: #selector(RuleListTableViewController.ruleSaved(notification:)), name: NSNotification.Name(rawValue: kRuleSaved), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(RuleListTableViewController.ruleDeleted(notification:)), name: NSNotification.Name(rawValue: kRuleDeleted), object: nil)

        searchController.searchResultsUpdater = self
        searchController.dimsBackgroundDuringPresentation = false
        searchController.delegate = self
//        searchController.searchBar.scopeButtonTitles = ["All", "Rewrite", "Direct", "Proxy", "Reject"]
//        searchController.searchBar.delegate = self

        tableView.tableHeaderView = searchController.searchBar

        definesPresentationContext = true
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: kRuleSaved), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: kRuleDeleted), object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadItemsFromDisk()
    }

    func reloadItemsFromDisk() {
        ruleItems = Rule.sharedInstance.getCurrentRuleItems()
        rewriteItems = Rule.sharedInstance.getCurrentRewriteItems()
        applyFilter(withText: filterText)
        tableView.reloadData()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func ruleSaved(notification: Notification) {
        if let value = notification.userInfo?["ruleItem"] as? [String] {
            if selectedIndex == -1 {
                ruleItems.insert(value, at: 0)
            } else {
                ruleItems[selectedIndex - rewriteItems.count] = value
            }
            let content = makeRulesIntoContent()
            RuleFileUpdateController().saveToCustomRuleFile(withContent: content)
        } else if let value = notification.userInfo?["rewriteItem"] as? [String] {
            if selectedIndex == -1 {
                rewriteItems.insert(value, at: 0)
            } else {
                rewriteItems[selectedIndex] = value
            }
            let content = makeRulesIntoContent()
            RuleFileUpdateController().saveToCustomRuleFile(withContent: content)
        }
        reloadItemsFromDisk()
    }

    func ruleDeleted(notification: Notification) {
        ruleDeleted()
    }

    func ruleDeleted() {
        if selectedIndex == -1 {
            return
        }
        if selectedIndex < rewriteItems.count {
            rewriteItems.remove(at: selectedIndex)
        } else {
            ruleItems.remove(at: selectedIndex - rewriteItems.count)
        }
        selectedIndex = -1
        let content = makeRulesIntoContent()
        RuleFileUpdateController().saveToCustomRuleFile(withContent: content)
        reloadItemsFromDisk()
    }

    func makeRulesIntoContent() -> String {
        var content = "[URL Rewrite]\n"

        for rewriteItem in rewriteItems {
            let tmp = rewriteItem.joined(separator: " ")
            content.append(tmp + "\n")
        }

        content.append("[Rule]\n")

        for ruleItem in ruleItems {
            let tmp = ruleItem.joined(separator: ",")
            content.append(tmp + "\n")
        }

        return content
    }


    func applyFilter(withText text: String) {
        filteredRuleItems.removeAll()
        filteredRewriteItems.removeAll()
        for ruleItem in ruleItems {
            for item in ruleItem {
                if item.lowercased().contains(text) {
                    filteredRuleItems.append(ruleItem)
                    break
                }
            }
        }

        for rewriteItem in rewriteItems {
            for item in rewriteItem {
                if item.lowercased().contains(text) {
                    filteredRewriteItems.append(rewriteItem)
                    break
                }
            }
        }

        tableView.reloadData()
    }


    // MARK: - UISearchControllerDelegate
//    func willDismissSearchController(_ searchController: UISearchController) {
//        let indexPath = IndexPath(row: 0, section: 0)
//        tableView.scrollToRow(at: indexPath, at: .top, animated: false)
//    }

    // MARK: - UISearchResultsUpdating

    func updateSearchResults(for searchController: UISearchController) {
        if let text = searchController.searchBar.text {
            filterText = text.lowercased()
            applyFilter(withText: text.lowercased())
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        if searchController.isActive {
            return filteredRewriteItems.count + filteredRuleItems.count
        }
        return rewriteItems.count + ruleItems.count
    }


    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(withIdentifier: "listCell", for: indexPath)

        if searchController.isActive {
            if indexPath.row < filteredRewriteItems.count {
                let item = filteredRewriteItems[indexPath.row]

                cell.textLabel?.attributedText = usingFilterTextTohightlight(item[0])
                cell.detailTextLabel?.attributedText = usingFilterTextTohightlight(item[1])
            } else {
                let item = filteredRuleItems[indexPath.row - filteredRewriteItems.count]

                cell.textLabel?.attributedText = usingFilterTextTohightlight(item[1])

                //In fact, usingFilterTextTohightlight doesn't work now
                cell.detailTextLabel?.attributedText = usingFilterTextTohightlight(attributedText: makeAttributeDescription(withMatchRule: item[0], andProxyRule: item[2]))
            }
        } else {
            if indexPath.row < rewriteItems.count {
                let item = rewriteItems[indexPath.row]
                cell.textLabel?.attributedText = nil
                cell.detailTextLabel?.attributedText = nil
                cell.textLabel?.text = item[0]
                cell.detailTextLabel?.text = item[1]
            } else {
                let item = ruleItems[indexPath.row - rewriteItems.count]
                cell.textLabel?.attributedText = nil
                cell.detailTextLabel?.attributedText = nil
                if item.count >= 3 {
                    cell.textLabel?.text = item[1]
                    cell.detailTextLabel?.attributedText = makeAttributeDescription(withMatchRule: item[0], andProxyRule: item[2])
                } else {
                    cell.textLabel?.text = ""
                    cell.detailTextLabel?.attributedText = makeAttributeDescription(withMatchRule: item[0], andProxyRule: item[1])
                }
            }
        }

        return cell
    }


    func makeAttributeDescription(withMatchRule matchRule: String, andProxyRule proxyRule: String) -> NSAttributedString {
        let attributeDescription = NSMutableAttributedString(string: "")

        let attributeRequestType = NSAttributedString(string: matchRule, attributes: [NSForegroundColorAttributeName: UIColor.lightGray])
        attributeDescription.append(attributeRequestType)
        attributeDescription.append(NSAttributedString(string: " "))

        switch proxyRule.lowercased() {
        case "direct":
            let attributeRule = NSAttributedString(string: proxyRule, attributes: [NSForegroundColorAttributeName: UIColor.init(red: 0.24, green: 0.545, blue: 0.153, alpha: 1.0)])
            attributeDescription.append(attributeRule)
        case "proxy":
            let attributeRule = NSAttributedString(string: proxyRule, attributes: [NSForegroundColorAttributeName: UIColor.orange])
            attributeDescription.append(attributeRule)
        default:
            let attributeRule = NSAttributedString(string: proxyRule, attributes: [NSForegroundColorAttributeName: UIColor.red])
            attributeDescription.append(attributeRule)
        }
        return attributeDescription
    }

    func usingFilterTextTohightlight(_ text: String) -> NSAttributedString {
        let attributedText = NSAttributedString(string: text)
        return usingFilterTextTohightlight(attributedText: attributedText)
    }

    func usingFilterTextTohightlight(attributedText attributeText: NSAttributedString) -> NSAttributedString {
        let mutableAttText = NSMutableAttributedString(attributedString: attributeText)
        let text = attributeText.string

        for range in searchRangesOfFilterText(inString: text) {

            mutableAttText.addAttribute(NSBackgroundColorAttributeName, value: UIColor.yellow, range: text.toNSRange(from: range))
        }
        return mutableAttText
    }

    func searchRangesOfFilterText(inString str: String) -> [Range<String.Index>] {
        var endRange = str.endIndex
        var ranges = [Range<String.Index>]()
        while true {
            let subString = str.substring(to: endRange)
            if let range = subString.range(of: filterText, options: [.literal, .backwards]) {
                ranges.append(range)
                endRange = range.lowerBound
            } else {
                break
            }
        }

        return ranges
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        selectedIndex = indexPath.row
        performSegue(withIdentifier: "showRuleDetail", sender: nil)
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }


    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {

            let alertController = UIAlertController(title: "Delete Rule", message: nil, preferredStyle: .alert)
            let deleteAction = UIAlertAction(title: "Delete", style: .destructive, handler: { (_) in

                DispatchQueue.main.async {
                    if self.searchController.isActive {
                        if indexPath.row < self.filteredRewriteItems.count {
                            let item = self.filteredRewriteItems[indexPath.row]
                            let index = self.rewriteItems.index(where: { strs -> Bool in
                                return strs == item
                            })
                            self.selectedIndex = index!
                        } else {
                            let item = self.filteredRuleItems[indexPath.row - self.filteredRewriteItems.count]
                            let index = self.ruleItems.index(where: { strs -> Bool in
                                return strs == item
                            })
                            self.selectedIndex = index! + self.rewriteItems.count
                        }
                    } else {
                        self.selectedIndex = indexPath.row
                    }
                    self.ruleDeleted()
                }
            })
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)

            alertController.addAction(cancelAction)
            alertController.addAction(deleteAction)

            self.present(alertController, animated: true, completion: nil)

        }
    }

    @IBAction func addNewRule(_ sender: UIBarButtonItem) {
        selectedIndex = -1
        performSegue(withIdentifier: "showRuleDetail", sender: nil)
    }


    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        if segue.identifier == "showRuleDetail" {
            if let desti = segue.destination as? RuleDetailTableViewController {
                if selectedIndex != -1 {
                    let item: [String]
                    if searchController.isActive {
                        if selectedIndex < filteredRewriteItems.count {
                            item = filteredRewriteItems[selectedIndex]
                            desti.rewriteItem = item
                        } else {
                            item = filteredRuleItems[selectedIndex - filteredRewriteItems.count]
                            desti.ruleItem = item
                        }

                    } else {
                        if selectedIndex < rewriteItems.count {
                            item = rewriteItems[selectedIndex]
                            desti.rewriteItem = item
                        } else {
                            item = ruleItems[selectedIndex - rewriteItems.count]
                            desti.ruleItem = item
                        }
                    }
                    desti.showDelete = true
                } else {
                    desti.showDelete = false
                }
            }
        }
    }
}


extension String {
    func toNSRange(from range: Range<String.Index>) -> NSRange {
        let from = range.lowerBound.samePosition(in: utf16)
        let to = range.upperBound.samePosition(in: utf16)
        return NSRange.init(location: utf16.distance(from: utf16.startIndex, to: from), length: utf16.distance(from: from, to: to))
    }
}
