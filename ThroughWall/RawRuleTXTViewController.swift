//
//  RawRuleTXTViewController.swift
//  ThroughWall
//
//  Created by Bin on 31/03/2017.
//  Copyright © 2017 Wu Bin. All rights reserved.
//

import UIKit

class RawRuleTXTViewController: UIViewController, UITextViewDelegate {
    @IBOutlet weak var rawRuleTXTView: UITextView!
    @IBOutlet weak var keyboardHeightLayoutConstraint: NSLayoutConstraint!

    var textChanged = false
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        let content = RuleFileUpdateController().readCurrentRuleFileContent()
        rawRuleTXTView.text = content
    
//        rawRuleTXTView.attributedText = makeAttributedText(withKeyText: "Proxy", inText: content, usingForegroundColor: UIColor.green)
        
        rawRuleTXTView.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(RawRuleTXTViewController.keyboardWillChangeFrame(notification:)), name: .UIKeyboardWillChangeFrame, object: nil)
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func saveAndExit(_ sender: UIBarButtonItem) {
        RuleFileUpdateController().saveToCustomRuleFile(withContent: rawRuleTXTView.text)
        let _ = navigationController?.popViewController(animated: true)
    }
    
    
    @objc func keyboardWillChangeFrame(notification: Notification) {
        if let userInfo = notification.userInfo {
            let endFrame = (userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
            let duration:TimeInterval = (userInfo[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0
            let animationCurveRawNSN = userInfo[UIKeyboardAnimationCurveUserInfoKey] as? NSNumber
            let animationCurveRaw = animationCurveRawNSN?.uintValue ?? UIViewAnimationOptions.curveEaseInOut.rawValue
            let animationCurve:UIViewAnimationOptions = UIViewAnimationOptions(rawValue: animationCurveRaw)
            if (endFrame?.origin.y)! >= UIScreen.main.bounds.size.height {
                self.keyboardHeightLayoutConstraint?.constant = 0.0
            } else {
                self.keyboardHeightLayoutConstraint?.constant = endFrame?.size.height ?? 0.0
            }
            UIView.animate(withDuration: duration,
                           delay: TimeInterval(0),
                           options: animationCurve,
                           animations: { self.view.layoutIfNeeded() },
                           completion: nil)
        }
    }

    func textViewDidChange(_ textView: UITextView) {
        textChanged = true
    }
    
    
    func makeAttributedText(withKeyText keyText: String, inText text:String, usingForegroundColor fColor: UIColor) -> NSAttributedString {
        let mutableAttText = NSMutableAttributedString(string: text)
        
        for range in searchRanges(ofKeytext: keyText, inString: text){
            
            mutableAttText.addAttribute(.foregroundColor, value: fColor, range: NSRange(range, in: text))
        }
        return mutableAttText
    }
    
    func searchRanges(ofKeytext keyText: String, inString str: String) -> [Range<String.Index>] {
        var endRange = str.endIndex
        var ranges = [Range<String.Index>]()
        while true {
            let subString = str.substring(to: endRange)
            if let range = subString.range(of: keyText, options: [.literal, .backwards]){
                ranges.append(range)
                endRange = range.lowerBound
            } else {
                break
            }
        }
        
        return ranges
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
