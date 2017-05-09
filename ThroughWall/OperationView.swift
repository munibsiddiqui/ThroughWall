//
//  OperationView.swift
//  ThroughWall
//
//  Created by Bingo on 09/05/2017.
//  Copyright © 2017 Wu Bin. All rights reserved.
//

import UIKit

class OperationView: WaveButtonView {

    override var bounds: CGRect {
        didSet {
            
        }
    }
}

class ButtonView: UIView {
    // MARK: - Accessible Parameters
    var buttonDimension: CGFloat {
        return self.bounds.width / 3
    }
    
    // MARK: - Private Parameters
    private let buttonLayer = CALayer()
    private var buttonParamter: (String, Bool)? = nil
    
    // MARK: - Init
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addButtonLayer()
        adjustButtonLayer()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        addButtonLayer()
        adjustButtonLayer()
    }
    
    // MARK: - Auto Sublayer Bounds Adjust
    
    //    override var bounds: CGRect {
    //        didSet {
    //            adjustButtonLayer()
    //        }
    //    }
    
    private func addButtonLayer() {
        if let sublayers = self.layer.sublayers {
            if sublayers.contains(buttonLayer) {
                return
            }
        }
        self.layer.addSublayer(buttonLayer)
    }
    
    private func adjustButtonLayer() {
        buttonLayer.frame = CGRect(origin: .zero, size: CGSize(width: buttonDimension, height: buttonDimension))
        buttonLayer.position = CGPoint(x: bounds.width / 2 + bounds.origin.x, y: bounds.height / 2 + bounds.origin.y)
        
        if let bParameter = buttonParamter {
            setButtonImage(withImageName: bParameter.0, withBackCircleDrawed: bParameter.1)
        }
    }
    
    // MARK: - API for setting the button
    
    func setButtonImage(withImageName name: String, withBackCircleDrawed isbackDrawed: Bool) {
        buttonParamter = (name, isbackDrawed)
        
        buttonLayer.sublayers = nil
        if isbackDrawed {
            addBackCircleLayerToButtonLayer()
        }
        drawIconOnButtonLayer(withImageName: name)
    }
    
    // MARK: - Draw Icon
    
    
    private func drawIconOnButtonLayer(withImageName name: String) {
        let iconLayer = CALayer()
        buttonLayer.addSublayer(iconLayer)
        iconLayer.frame = CGRect(origin: .zero, size: buttonLayer.frame.size)
        iconLayer.contents = UIImage(named: name)?.cgImage
    }
    
    // MARK: - Draw Back Circles
    
    private func addBackCircleLayerToButtonLayer(withCentrePoint point: CGPoint, andRadius radius: CGFloat, andColor color: UIColor) {
        let colorLayer = CAShapeLayer()
        buttonLayer.addSublayer(colorLayer)
        colorLayer.frame = CGRect(origin: .zero, size: buttonLayer.frame.size)
        
        let circlePath = UIBezierPath(arcCenter: point, radius: radius, startAngle: 0, endAngle: CGFloat.pi * 2, clockwise: true)
        
        colorLayer.path = circlePath.cgPath
        colorLayer.fillColor = color.cgColor
    }
    
    
    private func addBackCircleLayerToButtonLayer() {
        let dimension = buttonDimension
        
        addBackCircleLayerToButtonLayer(withCentrePoint: CGPoint(x: dimension / 2.0, y: dimension / 2.0), andRadius: dimension / 2.0 + 60, andColor: UIColor(red: 255.0 / 255.0, green: 88.0 / 255.0, blue: 24.0 / 255.0, alpha: 0.14))
        
        addBackCircleLayerToButtonLayer(withCentrePoint: CGPoint(x: dimension / 2.0, y: dimension / 2.0), andRadius: dimension / 2.0 + 30, andColor: UIColor(red: 255.0 / 255.0, green: 88.0 / 255.0, blue: 24.0 / 255.0, alpha: 0.22))
    }
}



class WaveButtonView: ButtonView {
    
    // MARK: - Accessible Parameters
    
    var waveStep: CGFloat = 20.0 {
        didSet {
            bRadius = buttonDimension / 2 + 2 * waveStep
        }
    }
    
    var waveDuration: Double = 3.0 {
        didSet {
            delay = waveDuration / CFTimeInterval(instanceCount)
        }
    }
    
    //    override var bounds: CGRect {
    //        didSet {
    //            adjustWaveLayer()
    //        }
    //    }
    
    var fromUIColor = UIColor(red: 255.0 / 255.0, green: 108.0 / 255.0, blue: 66.0 / 255.0, alpha: 1.0)
    var toUIColor = UIColor.white
    
    // MARK: - Private Parameters
    
    private var bRadius: CGFloat {
        set {
            _bRadius = newValue
            instanceCount = Int((eRadius - bRadius) / waveStep) + 1
        }
        get {
            return _bRadius
        }
    }
    
    private var instanceCount: Int = 1 {
        didSet {
            delay = waveDuration / CFTimeInterval(instanceCount)
            eRadius = CGFloat(instanceCount) * waveStep + bRadius
        }
    }
    
    private lazy var eRadius: CGFloat = {
        return self.waveAnimationLayer.frame.width / 2
    }()
    
    private lazy var _bRadius: CGFloat = {
        return self.bounds.width / 6 + 2 * self.waveStep
    }()
    
    private let waveAnimationLayer = CALayer()
    private var circleLayers = [CAShapeLayer]()
    private var startTime: CFTimeInterval = 0
    private var beginCirclePath = UIBezierPath()
    private var endCirclePath = UIBezierPath()
    
    private lazy var delay: CFTimeInterval = 0
    private var animationDelegate = AnimationDelegate()
    
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addWaveLayer()
        adjustWaveLayer()
        setCallback()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        addWaveLayer()
        adjustWaveLayer()
        setCallback()
    }
    
    private func setCallback() {
        animationDelegate.didStopCallback = animationDidStop
    }
    
    private func addWaveLayer() {
        if let sublayers = self.layer.sublayers {
            if sublayers.contains(waveAnimationLayer) {
                return
            }
        }
        self.layer.insertSublayer(waveAnimationLayer, at: 0)
    }
    
    private func adjustWaveLayer() {
        waveAnimationLayer.frame = CGRect(origin: .zero, size: bounds.size)
        waveAnimationLayer.position = CGPoint(x: bounds.width / 2 + bounds.origin.x, y: bounds.height / 2 + bounds.origin.y)
        
        bRadius = buttonDimension / 2 + 2 * waveStep
        
        beginCirclePath = UIBezierPath(arcCenter: CGPoint(x: waveAnimationLayer.frame.size.width / 2.0, y: waveAnimationLayer.frame.size.height / 2.0), radius: bRadius, startAngle: 0.0, endAngle: CGFloat(Double.pi * 2.0), clockwise: true)
        endCirclePath = UIBezierPath(arcCenter: CGPoint(x: waveAnimationLayer.frame.size.width / 2.0, y: waveAnimationLayer.frame.size.height / 2.0), radius: eRadius, startAngle: 0.0, endAngle: CGFloat(Double.pi * 2.0), clockwise: true)
    }
    
    private func setupCircleLayer(_ circleLayer: CAShapeLayer) {
        circleLayer.path = beginCirclePath.cgPath
        circleLayer.fillColor = UIColor.clear.cgColor
        circleLayer.strokeColor = UIColor(red: 255.0 / 255.0, green: 88.0 / 255.0, blue: 24.0 / 255.0, alpha: 0.14).cgColor
        circleLayer.lineWidth = waveStep
        circleLayer.opacity = 0
    }
    
    private func setAnimationToCircleLayer(_ circleLayer: CAShapeLayer, withBeginTime beginTime: CFTimeInterval) {
        
        let fadeOut = CABasicAnimation(keyPath: "opacity")
        fadeOut.fromValue = 1
        fadeOut.toValue = 0
        fadeOut.duration = waveDuration
        
        let pathAdmin = CABasicAnimation(keyPath: "path")
        pathAdmin.fromValue = beginCirclePath.cgPath
        pathAdmin.toValue = endCirclePath.cgPath
        pathAdmin.duration = waveDuration
        
        let colorFade = CABasicAnimation(keyPath: "strokeColor")
        colorFade.fromValue = fromUIColor.cgColor
        colorFade.toValue = toUIColor.cgColor
        colorFade.duration = waveDuration
        
        let animaitonGroup = CAAnimationGroup()
        animaitonGroup.duration = waveDuration
        animaitonGroup.animations = [fadeOut, pathAdmin, colorFade]
        
        animaitonGroup.delegate = animationDelegate
        animaitonGroup.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        animaitonGroup.beginTime = beginTime
        animaitonGroup.setValue(circleLayer, forKey: "layerOwner")
        animaitonGroup.setValue(false, forKey: "shouldStopAnimation")
        
        circleLayer.add(animaitonGroup, forKey: "waveAnimation")
        
    }
    
    func startAnimation() {
        if circleLayers.count != 0 {
            return
        }
        //        animationShouldStop = false
        //        let staticCircleLayer = CAShapeLayer()
        //        waveAnimationLayer.addSublayer(staticCircleLayer)
        //        staticCircleLayer.frame = CGRect(origin: .zero, size: waveAnimationLayer.frame.size)
        //        setupCircleLayer(staticCircleLayer)
        //        staticCircleLayer.opacity = 1
        //        adjustWaveParameters()
        
        startTime = waveAnimationLayer.convertTime(CACurrentMediaTime(), from: nil)
        //        delay = waveDuration / CFTimeInterval(instanceCount)
        for index in 0 ..< instanceCount {
            
            let circleLayer = CAShapeLayer()
            
            waveAnimationLayer.addSublayer(circleLayer)
            
            circleLayer.frame = CGRect(origin: .zero, size: waveAnimationLayer.frame.size)
            
            setupCircleLayer(circleLayer)
            
            setAnimationToCircleLayer(circleLayer, withBeginTime: startTime + delay * Double(index))
            
            circleLayers.append(circleLayer)
        }
    }
    
    func stopAnimation() {
        for circleLayer in circleLayers {
            if let animation = circleLayer.animation(forKey: "waveAnimation") {
                animation.setValue(true, forKey: "shouldStopAnimation")
            }
        }
        
        let currentTime = waveAnimationLayer.convertTime(CACurrentMediaTime(), from: nil)
        let offset = lround((currentTime - startTime) / delay + 0.5)
        
        
        if offset < circleLayers.count {
            for index in offset ..< circleLayers.count {
                circleLayers[index].removeAllAnimations()
                circleLayers[index].removeFromSuperlayer()
            }
        }
        
        startTime = 0
    }
    
    func forceStartAnimation() {
        forceStopAnimation()
        startAnimation()
    }
    
    func forceStopAnimation() {
        for circleLayer in circleLayers {
            if let animation = circleLayer.animation(forKey: "waveAnimation") {
                animation.setValue(true, forKey: "shouldStopAnimation")
            }
        }
        for circleLayer in circleLayers {
            circleLayer.removeAllAnimations()
        }
        circleLayers.removeAll()
    }
    
    private func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        if let owner = anim.value(forKey: "layerOwner") as? CAShapeLayer {
            if let shouldStop = anim.value(forKey: "shouldStopAnimation") as? Bool {
                if shouldStop {
                    owner.removeAllAnimations()
                    owner.removeFromSuperlayer()
                    //                    print("animation Stop")
                    if let index = circleLayers.index(of: owner) {
                        circleLayers.remove(at: index)
                    }
                } else {
                    setAnimationToCircleLayer(owner, withBeginTime: 0)
                    //                    print("animation Restart")
                }
            }
        }
    }
    
    
    private class AnimationDelegate: NSObject, CAAnimationDelegate {
        var didStopCallback: ((CAAnimation, Bool) -> Void)? = nil
        
        func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
            didStopCallback?(anim, flag)
        }
        
    }
}
