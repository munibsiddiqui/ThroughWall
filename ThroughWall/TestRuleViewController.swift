//
//  TestRuleViewController.swift
//  ThroughWall
//
//  Created by Bin on 31/03/2017.
//  Copyright © 2017 Wu Bin. All rights reserved.
//

import UIKit

class TestRuleViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var inputTextField: UITextField!
    @IBOutlet weak var resultLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        resultLabel.text = ""
        inputTextField.delegate = self
        Rule.sharedInstance.analyzeRuleFile()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        var result = "Empty"
        if let server = textField.text {
            let rule = Rule.sharedInstance.ruleForDomain(server)
            result = rule.description
        }

        resultLabel.attributedText = makeAttributeDescription(withProxyRule: result)
        return true
    }

    func makeAttributeDescription(withProxyRule proxyRule: String) -> NSAttributedString {
        switch proxyRule.lowercased() {
        case "direct":
            let attributeRule = NSAttributedString(string: proxyRule, attributes: [NSForegroundColorAttributeName: UIColor.init(red: 0.24, green: 0.545, blue: 0.153, alpha: 1.0)])
            return attributeRule
        case "proxy":
            let attributeRule = NSAttributedString(string: proxyRule, attributes: [NSForegroundColorAttributeName: UIColor.orange])
             return attributeRule
        default:
            let attributeRule = NSAttributedString(string: proxyRule, attributes: [NSForegroundColorAttributeName: UIColor.red])
             return attributeRule
        }
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
