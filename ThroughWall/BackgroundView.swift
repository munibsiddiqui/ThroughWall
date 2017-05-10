//
//  BackgroundView.swift
//  ThroughWall
//
//  Created by Bin on 10/05/2017.
//  Copyright © 2017 Wu Bin. All rights reserved.
//

import UIKit

class BackgroundView: UIView {

    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */

    let gradientLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addGraientLayer()
        setFadeBackground(withTopColor: topUIColor, bottomColor: bottomUIColor)
        adjustGradientLayer()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        addGraientLayer()
        setFadeBackground(withTopColor: topUIColor, bottomColor: bottomUIColor)
        adjustGradientLayer()
    }

    
    override var bounds: CGRect {
        didSet {
            adjustGradientLayer()
        }
    }
    
    private func addGraientLayer() {
        if let sublayers = self.layer.sublayers {
            if sublayers.contains(gradientLayer) {
                return
            }
        }
        self.layer.insertSublayer(gradientLayer, at: 0)
    }


    func setFadeBackground(withTopColor topColor: UIColor, bottomColor: UIColor) {
        gradientLayer.colors = [topColor.cgColor, bottomColor.cgColor]
        gradientLayer.locations = [0.0, 1.0]
    }
    
    func adjustGradientLayer() {
        gradientLayer.frame = CGRect(origin: .zero, size: self.frame.size)
    }
    

}
