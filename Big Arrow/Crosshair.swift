//
//  Crosshair.swift
//  Big Arrow
//
//  Created by Marco Filetti on 28/10/2017.
//  Copyright © 2017 Marco Filetti. All rights reserved.
//

import UIKit

class Crosshair: CALayer {
    
    let vertColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1).cgColor
    let horzColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1).cgColor
    let circleColor = Constants.arrowColor.cgColor
    let circleWidth: CGFloat = 6
    let strokeWidth: CGFloat = 1
    let lineLength: CGFloat = 10
    
    override init() {
        super.init()
        completeInit()
    }
    
    override init(layer: Any) {
        super.init(layer: layer)
        completeInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        completeInit()
    }
    
    func recenter(_ newFrame: CGRect) {
        DispatchQueue.main.async {
            self.position.x = newFrame.width / 2
            self.position.y = newFrame.height / 2
        }
    }

    private func completeInit() {
        let circle = CAShapeLayer()
        let circlePath = UIBezierPath(ovalIn: CGRect(x: -circleWidth / 2, y: -circleWidth / 2, width: circleWidth, height: circleWidth))
        circle.path = circlePath.cgPath
        circle.fillColor = nil
        circle.strokeColor = circleColor
        circle.lineWidth = strokeWidth
        
        self.addSublayer(circle)
        
        // top line
        addLine(fromPoint: CGPoint(x: 0, y: -circleWidth / 2),
                toPoint: CGPoint(x: 0, y: (-circleWidth / 2) - lineLength),
                isVertical: true)

        // bottom line
        addLine(fromPoint: CGPoint(x: 0, y: circleWidth / 2),
                toPoint: CGPoint(x: 0, y: (circleWidth / 2) + lineLength),
                isVertical: true)

        // left line
        addLine(fromPoint: CGPoint(x: -circleWidth / 2, y: 0),
                toPoint: CGPoint(x: (-circleWidth / 2) - lineLength, y: 0),
                isVertical: false)

        // right line
        addLine(fromPoint: CGPoint(x: circleWidth / 2, y: 0),
                toPoint: CGPoint(x: (circleWidth / 2) + lineLength, y: 0),
                isVertical: false)
        
    }
    
    private func addLine(fromPoint: CGPoint, toPoint: CGPoint, isVertical: Bool) {
        let linePath = UIBezierPath()
        linePath.move(to: fromPoint)
        linePath.addLine(to: toPoint)
        let line = CAShapeLayer()
        line.path = linePath.cgPath
        line.fillColor = nil
        line.lineWidth = strokeWidth
        if isVertical {
            line.strokeColor = vertColor
        } else {
            line.strokeColor = horzColor
        }
        self.addSublayer(line)
    }
    
}
