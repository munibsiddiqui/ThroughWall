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
    let bottomHillLayer = CALayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addLayers()
        setLayers()
        adjustLayers()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        addLayers()
        setLayers()
        adjustLayers()
    }


    override var bounds: CGRect {
        didSet {
            adjustLayers()
        }
    }

    // MARK: - Add layer
    private func addLayers() {
        addGraientLayer()
        addBottomHillLayer()
    }

    private func addGraientLayer() {
        if let sublayers = self.layer.sublayers {
            if sublayers.contains(gradientLayer) {
                return
            }
        }
        self.layer.addSublayer(gradientLayer)
    }

    private func addBottomHillLayer() {
        if let sublayers = self.layer.sublayers {
            if sublayers.contains(bottomHillLayer) {
                return
            }
        }
        self.layer.addSublayer(bottomHillLayer)
    }

    // MARK: - Set layer
    private func setLayers() {
        setFadeBackground()
        setHillBackground()
    }

    private func setFadeBackground() {
        gradientLayer.colors = [topUIColor.cgColor, bottomUIColor.cgColor]
        gradientLayer.locations = [0.0, 1.0]
    }

    
    private func setHillBackground() {
        bottomHillLayer.sublayers = nil
        
        //add
        let r = [bottomHillLayer.bounds.width * 3 / 4,
                 bottomHillLayer.bounds.width * 3 / 6,
                 bottomHillLayer.bounds.width * 3 / 5]
        let x = [bottomHillLayer.bounds.width * 2 / 3,
                 bottomHillLayer.bounds.width * 3 / 4,
                 bottomHillLayer.bounds.width / 4]
        let y = [bottomHillLayer.bounds.height + bottomHillLayer.bounds.width / 4,
                 bottomHillLayer.bounds.height + bottomHillLayer.bounds.width / 4,
                 bottomHillLayer.bounds.height + bottomHillLayer.bounds.width / 4]
        let color = [UIColor(red: 255.0 / 255.0, green: 88.0 / 255.0, blue: 24.0 / 255.0, alpha: 0.14),
                     UIColor(red: 255.0 / 255.0, green: 88.0 / 255.0, blue: 24.0 / 255.0, alpha: 0.13),
                     UIColor(red: 255.0 / 255.0, green: 88.0 / 255.0, blue: 24.0 / 255.0, alpha: 0.22)]
        
        for index in 0 ..< r.count {
             drawHill(withRadius: r[index], center: CGPoint.init(x: x[index], y: y[index]), color: color[index])
        }
    }
    
    private func drawHill(withRadius radius: CGFloat, center: CGPoint, color: UIColor) {
        let circle = UIBezierPath(arcCenter: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        let hillLayer = CAShapeLayer()
        
        bottomHillLayer.addSublayer(hillLayer)
        
        hillLayer.frame = CGRect(origin: .zero, size: bottomHillLayer.frame.size)
        
        hillLayer.path = circle.cgPath
        hillLayer.fillColor = color.cgColor
        
    }
    

    // MARK: - Adjust layer

    private func adjustLayers() {
        adjustGradientLayer()
        adjustBottomHillLayer()
    }

    private func adjustGradientLayer() {
        gradientLayer.frame = CGRect(origin: .zero, size: self.frame.size)
    }

    private func adjustBottomHillLayer(){
        bottomHillLayer.frame = CGRect(origin: .zero, size: self.frame.size)
        setHillBackground()
    }
}
