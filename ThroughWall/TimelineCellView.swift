//
//  TimelineCellView.swift
//  ThroughWall
//
//  Created by Bingo on 29/05/2017.
//  Copyright © 2017 Wu Bin. All rights reserved.
//

import UIKit

class TimelineCellView: UIView {
    var touchedCallback: (() -> Void)?
    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */

    override init(frame: CGRect) {
        super.init(frame: frame)
//        self.backgroundColor = UIColor.blue
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
//        self.backgroundColor = UIColor.red
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchedCallback?()
    }
    
    func set(HostPort hp: String) {
        let frame = CGRect(origin: .zero, size: CGSize(width: self.bounds.width, height: self.bounds.height / 2))
        let textField = UITextField(frame: frame)
        textField.text = hp
        textField.backgroundColor = UIColor.white
        textField.isEnabled = false
        self.addSubview(textField)
    }
    
    func setIndicatorColor(withReqT reqT: Date, ResT resT: Date?, DisT disT: Date, andRule rule: String) {
        var cp: CGFloat = 0
        let wView: UIView
        if let _resT = resT {
            let length = disT.timeIntervalSince(reqT)
            let wLength = _resT.timeIntervalSince(reqT)
            cp = CGFloat(wLength / length)
            wView = UIView(frame: CGRect(x: 0, y: self.bounds.height / 2, width: self.bounds.width * cp, height: self.bounds.height / 2))
        }else{
            wView = UIView()
        }
        let view = UIView(frame: CGRect(x: self.bounds.width * cp, y: self.bounds.height / 2, width: self.bounds.width * (1.0 - cp), height: self.bounds.height / 2))
        self.addSubview(view)
        self.addSubview(wView)
        
        switch rule {
        case "proxy":
            wView.backgroundColor = UIColor(red: 1.0, green: 0.5, blue: 0, alpha: 0.5)
            view.backgroundColor = UIColor(red: 1.0, green: 0.5, blue: 0, alpha: 1.0)
        case "direct":
            wView.backgroundColor = UIColor(red: 0.24, green: 0.545, blue: 0.153, alpha: 0.5)
            view.backgroundColor = UIColor(red: 0.24, green: 0.545, blue: 0.153, alpha: 1.0)
        default:
            wView.backgroundColor = UIColor(red: 1.0, green: 0, blue: 0, alpha: 0.5)
            view.backgroundColor = UIColor.red
        }
    }
    
    
    func setIndicationColor(withChangePercent cp: CGFloat, andRule rule: String) {
        let wView = UIView(frame: CGRect(x: 0, y: self.bounds.height / 2, width: self.bounds.width * cp, height: self.bounds.height / 2))
        let lView = UIView(frame: CGRect(x: self.bounds.width * cp, y: self.bounds.height / 2, width: self.bounds.width * (1.0 - cp), height: self.bounds.height / 2))
        self.addSubview(wView)
        self.addSubview(lView)
        
    }    
}
