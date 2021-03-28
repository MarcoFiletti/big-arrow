//
//  ArrowScene
//  Big Arrow WatchKit Extension
//
//  Created by Marco Filetti on 15/06/2017.
//  Copyright © 2017 Marco Filetti. All rights reserved.
//

import SpriteKit

class ArrowScene: SKScene {
    
    // MARK: - Central Animation Type
    
    /// Used to define the animation currently playing in the center.
    /// So that labels can be updated accordingly.
    enum AnimationType {
        case eta
        case nearby
    }
    
    // MARK: - Constants
    
    let fastFade: TimeInterval = 0.2
    let normFade: TimeInterval = 0.4
    #if WatchApp
    var compassMode: Bool = false
    let accuracyDotRadius: CGFloat = 4
    let progressBarSize = CGSize(width: 100, height: 6)
    let progressBarRadius: CGFloat = 2.5
    let progressBarStrokeWidth: CGFloat = 2
    #else
    let compassMode: Bool = false
    let accuracyDotRadius: CGFloat = 8
    let progressBarSize = CGSize(width: 200, height: 12)
    let progressBarRadius: CGFloat = 5
    let progressBarStrokeWidth: CGFloat = 3
    #endif
    
    // MARK: - Private
    
    private var compassArrow: SKNode!
    private var arrow: SKNode!
    private var cross: SKNode!
    private var accuracyGroup: SKNode!
    private var gpsLabel: SKLabelNode!
    private var waitLabel: SKLabelNode!
    private var accuracyDotsShown = false
    private var progressGroup: SKNode!
    
    private var lastAccuracy: FuzzyAccuracy?
    private var lastDistance = ""
    private var lastEta = ""
    
    // progress bar front and back
    private var progBarBack: SKShapeNode!
    private var progBarFront: SKShapeNode!
    
    // MARK: - Internal
    
    /// The three dots alternating blinking
    private(set) var waitDots: SKNode!
    
    /// Crosshair
    private(set) var crosshair: SKNode!

    // initial vertical locations of labels for animation
    private(set) var typeNotificationLabelY: CGFloat = 0
    private(set) var valNotificationLabelY: CGFloat = 0

    /// If true, do not animate anything anymore
    var terminated = false
    
    /// Dispatch queue on which to run scene operation
    static let animationQueue = DispatchQueue(label: "com.marcofiletti.scenequeue", qos: .userInitiated)
    
    /// Queue for central animations.
    /// The user should see these animations, so the queue
    /// should be suspended externally when the scene is not visible.
    let animQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.underlyingQueue = ArrowScene.animationQueue
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    
    var isVisible: Bool = true
    private(set) var tickSprite: SKNode!
    private(set) var lightContainer: SKNode!
    private(set) var typeNotificationLabel: SKLabelNode!  // i.e. top
    private(set) var valNotificationLabel: SKLabelNode!  // i.e. bottom
    
    /// Animation being displayed currently in the center.
    var currentAnimation: AnimationType? = nil { didSet {
        if currentAnimation == .eta {
            typeNotificationLabel.text = "ETA"
            valNotificationLabel.text = lastEta
        } else if currentAnimation == .nearby {
            typeNotificationLabel.text = "distance".localized.uppercased()
            valNotificationLabel.text = lastDistance
        }
    } }
    
    /// Returns the node for THE arrow (big arrow or compass, depending on mode)
    var theArrow: SKNode { get {
        if compassMode {
            return compassArrow
        } else {
            return arrow
        }
    } }
    
    // MARK: - Init
    
    override func sceneDidLoad() {
        
        arrow = self.childNode(withName: "TheArrow")!
        cross = self.childNode(withName: "Cross")!
        compassArrow = self.childNode(withName: "TheCompass")!
        
        progressGroup = self.childNode(withName: "progressGroup")!
        makeProgBar()
        
        // accuracy dots
        accuracyGroup = self.childNode(withName: "accuracyGroup")!
        accuracyGroup.alpha = 0
        let ad1 = SKShapeNode(circleOfRadius: accuracyDotRadius)
        let ad2 = SKShapeNode(circleOfRadius: accuracyDotRadius)
        let ad3 = SKShapeNode(circleOfRadius: accuracyDotRadius)
        accuracyGroup.addChild(ad1)
        accuracyGroup.addChild(ad2)
        accuracyGroup.addChild(ad3)
        ad1.position.x -= accuracyDotRadius * 2 + 1
        ad3.position.x += accuracyDotRadius * 2 + 1
        
        gpsLabel = self.childNode(withName: "gpsLabel") as? SKLabelNode
        gpsLabel.alpha = 0
        
        waitLabel = SKLabelNode(text: "keep_moving".localized)
        waitLabel.fontName = "HelveticaNeue-Medium"
        waitLabel.alpha = 0
        addChild(waitLabel)
        
        typeNotificationLabel = ArrowScene.makeNotificationLabel()
        addChild(typeNotificationLabel)
        valNotificationLabel = ArrowScene.makeNotificationLabel()
        addChild(valNotificationLabel)
        
        // start with big arrow hidden
        arrow.alpha = 0
        
        makeCrosshair()
        
        lightContainer = self.childNode(withName: "LightContainer")!
        tickSprite = self.childNode(withName: "TickSprite")!
        
        #if WatchApp
            waitLabel.position.y -= 64
        #else
            waitLabel.position.y -= 128
        #endif
        
        #if WatchApp
            waitLabel.fontSize = 32
            typeNotificationLabel.fontSize = 28
            typeNotificationLabel.position.y += typeNotificationLabel.fontSize / 2 + 4
            valNotificationLabel.fontSize = 36
            valNotificationLabel.position.y -= valNotificationLabel.fontSize / 2 + 4
        #else
            waitLabel.fontSize = 58
            typeNotificationLabel.fontSize = 56
            typeNotificationLabel.position.y += typeNotificationLabel.fontSize / 2 + 6
            valNotificationLabel.fontSize = 64
            valNotificationLabel.position.y -= valNotificationLabel.fontSize / 2 + 6
        #endif
        
        valNotificationLabelY = valNotificationLabel.position.y
        typeNotificationLabelY = typeNotificationLabel.position.y
        
        valNotificationLabel.position.y = 0
        typeNotificationLabel.position.y = 0
        
        updateArrowSize(nil)
        NotificationCenter.default.addObserver(self, selector: #selector(changedProgressBarPreference(_:)), name: Constants.Notifications.changedProgressBarPreference, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateArrowSize(_:)), name: Constants.Notifications.arrowSizeChanged, object: nil)
        
    }
    
    private static func makeNotificationLabel() -> SKLabelNode {
        let notificationLabel = SKLabelNode(text: "-")
        notificationLabel.fontName = "HelveticaNeue-Bold"
        notificationLabel.alpha = 0
        notificationLabel.verticalAlignmentMode = .center
        notificationLabel.horizontalAlignmentMode = .center
        notificationLabel.zPosition = 10
        notificationLabel.xScale = 0.1
        notificationLabel.yScale = 0.1
        return notificationLabel
    }
    
    // MARK: - Sequenced animations
    
    /// Shows the tick and cancels everything else
    public func enqueueTickFadeIn() {
        if self.isVisible {
            animQueue.isSuspended = false
        } else {
            animQueue.isSuspended = true
        }
        animQueue.addOperation(CentralAnimationOperation(tickActionWithScene: self))
    }
    
    /// Shows the given notification, creating also arrow show and hide if queue is empty
    public func enqueueNotification(type: AnimationType) {
        guard !terminated else {
            return
        }
        
        DispatchQueue.main.async {
            [weak self] in
            self?.hideWaitLabel()
        }
        
        if theArrow.alpha != Constants.fadedArrowAlpha {
            animQueue.addOperation(CentralAnimationOperation(unfocusArrowWithScene: self))
            animQueue.addOperation(CentralAnimationOperation(restoreArrowWithScene: self))
        }
        animQueue.addOperation(CentralAnimationOperation(showNotificationWithScene: self, type: type))
    }
    
    // MARK: - Public functions
    
    /// Makes three dots appear to signal waiting
    public func makeWaitDots() {
        let dotsNode = SKNode()
        
        hideAccuracyDots()
        
        let r = self.size.width * 0.025
        let c1 = SKShapeNode(circleOfRadius: r)
        let c2 = SKShapeNode(circleOfRadius: r)
        let c3 = SKShapeNode(circleOfRadius: r)
        
        c1.position = CGPoint(x: -self.size.width * 0.15, y: 0)
        c2.position = CGPoint(x: 0, y: 0)
        c3.position = CGPoint(x: self.size.width * 0.15, y: 0)
        
        dotsNode.addChild(makeDot(dot: c1, waitOn: 0, waitOff: 2))
        dotsNode.addChild(makeDot(dot: c2, waitOn: 1, waitOff: 1))
        dotsNode.addChild(makeDot(dot: c3, waitOn: 2, waitOff: 0))
        
        self.waitDots = dotsNode
        self.addChild(self.waitDots)
    }
    
    public func moveWaitDotsTogether() {
        waitDots.children.forEach() {
            $0.removeAllActions()
            fadeInAndOutForever(duration: 0.5, node: $0)
            let act = SKAction.moveTo(x: 0, duration: 3)
            $0.run(act)
        }
    }
    
    public func hideWaitDots() {
        guard waitDots.alpha > 0 else {
            return
        }
        waitDots.removeAllActions()
        let act = SKAction.fadeOut(withDuration: fastFade)
        waitDots.run(act) {
            self.waitDots.isPaused = true
        }
    }
    
    public func showWaitDots() {
        guard waitDots.alpha < 1 else {
            return
        }
        waitDots.removeAllActions()
        waitDots.isPaused = false
        let act = SKAction.fadeIn(withDuration: fastFade)
        waitDots.run(act)
    }
    
    /// Hides the arrow and everything related to it
    public func hideArrowAndFriends() {
        animQueue.cancelAllOperations()
        hideAccuracyDots()
        
        fadeOutArrowAndProgress()
        
        let act = SKAction.fadeOut(withDuration: fastFade)
        
        // hide notification label 1
        if typeNotificationLabel.alpha > 0 || typeNotificationLabel.hasActions() {
            typeNotificationLabel.removeAllActions()
            typeNotificationLabel.run(act)
        }
        // hide notification label 2
        if valNotificationLabel.alpha > 0 || valNotificationLabel.hasActions() {
            valNotificationLabel.removeAllActions()
            valNotificationLabel.run(act)
        }
    }
    
    public func setAccuracy(_ acc: FuzzyAccuracy) {
        guard accuracyDotsShown else {
            return
        }
        
        guard lastAccuracy == nil || lastAccuracy! != acc else {
            return
        }
        
        let d: TimeInterval = 1
        
        // show and hide children dots according to accuracy level
        for (i, c) in accuracyGroup.children.enumerated() {
            c.removeAllActions()  // clear all actions before continuing
            if let d = c as? SKShapeNode {
                d.strokeColor = acc.color
                d.fillColor = acc.color
            }
            let t: Int  // threshold of dots to fade in or out
            switch acc {
            case .good:
                // fade in all
                t = 2
            case .medium:
                // fade in only the first two
                t = 1
            case .low:
                // fade in only the first
                t = 0
            }
            let act: SKAction
            if i <= t {
                act = SKAction.fadeIn(withDuration: d)
            } else {
                act = SKAction.fadeOut(withDuration: d)
            }
            c.run(act)
        }
        
        // fade out or blink all dots depending on accuracy
        switch acc {
        case .good:
            accuracyGroup.removeAllActions()
            let act = SKAction.fadeIn(withDuration: d)
            let w = SKAction.wait(forDuration: 2)
            let act2 = SKAction.fadeOut(withDuration: 1)
            let seq = SKAction.sequence([act, w, act2])
            accuracyGroup.run(seq)
            gpsLabel.run(seq)
        case .medium, .low:
            if lastAccuracy == nil || lastAccuracy! == .good {
                accuracyGroup.removeAllActions()
                fadeInAndOutForever(duration: d, node: accuracyGroup)
                gpsLabel.removeAllActions()
                gpsLabel.run(SKAction.fadeIn(withDuration: d))
            }
        }
        
        lastAccuracy = acc
    }
    
    // sets the arrow angle using a location angle
    // (north = 0, east = 90, etc.).
    // Only for watch, does this action to the compass arrow, if it's visible.
    public func setArrowAngle(locationAngle: CGFloat) {
        // invert direction, since in spritekit we increase ccw
        let angle = 360 - locationAngle
        let radians = angle.toRad()
        
        let act = SKAction.rotate(toAngle: radians, duration: 0.3, shortestUnitArc: true)
        act.timingMode = .easeOut
        
        // apply action THE arrow
        theArrow.run(act)
    }
    
    /// Sets progress to a new value between 0 and 1, and update bar accordingly
    public func setProgress(to prog: CGFloat) {
        guard prog > 0 else {
            return
        }
        
        // set width to max if progress > 1
        let width: CGFloat
        if prog <= 1 {
            width = progressBarSize.width * prog
            guard width > progressBarRadius * 2 else {
                return
            }
        } else {
            width = progressBarSize.width
        }
        
        let rect = CGRect(x: -(progressBarSize.width/2), y: -progressBarSize.height / 2, width: width, height: progressBarSize.height)
        let path = CGPath(roundedRect: rect, cornerWidth: progressBarRadius, cornerHeight: progressBarRadius, transform: nil)
        
        progBarBack.path = path
    }

    public func showWaitLabel() {
        guard waitLabel.alpha < 1 else {
            return
        }
        waitLabel.removeAllActions()
        let act = SKAction.fadeIn(withDuration: fastFade)
        waitLabel.run(act)
    }
    
    public func hideWaitLabel() {
        guard waitLabel.alpha > 0 else {
            return
        }
        waitLabel.removeAllActions()
        let act = SKAction.fadeOut(withDuration: fastFade)
        waitLabel.run(act)
    }
    
    /// Animate arrow appearance (and progress bar, if on) if it was not visible
    public func showArrowIfNotShown() {
        guard !terminated else {
            return
        }
        
        self.hideWaitDots()
        self.hideWaitLabel()
        self.showArrow()
        self.accuracyDotsShown = true
    }
    
    public func showCross() {
        theArrow.alpha = 0
        hideAccuracyDots()
        cross.alpha = 1
    }
        
    /// Sets the label for notifications (skips if not needed)
    public func setDistance(_ distance: String) {
        lastDistance = distance
        
        guard currentAnimation == .nearby else {
            return
        }
        
        typeNotificationLabel.text = "distance".localized.uppercased()
        valNotificationLabel.text = distance
    }
    
    /// Sets the label for notifications (skips if not needed)
    public func setETA(_ eta: String?) {
        guard let eta = eta else {
            return
        }
        
        lastEta = eta
        
        guard currentAnimation == .eta else {
            return
        }

        typeNotificationLabel.text = "ETA"
        valNotificationLabel.text = eta
    }
    
    /// Hide the arrow and displays the given message (e.g. if signal was lost)
    /// If a message is already being shown, changes the label after a second to avoid overloading the fades
    public func hideArrowAndDisplayWaitMessage(messageText: String) {
        if waitLabel.text != messageText {
            let act: SKAction
            if waitLabel.alpha == 1 {
                let waitAction = SKAction.wait(forDuration: 1)
                let fadeAction = SKAction.fadeOut(withDuration: fastFade)
                act = SKAction.sequence([waitAction, fadeAction])
            } else {
                act = SKAction.fadeOut(withDuration: fastFade)
            }
            waitLabel.run(act) {
                self.waitLabel.text = messageText
                self.showWaitLabel()
            }
        } else {
            showWaitLabel()
        }
        showWaitDots()
        hideArrowAndFriends()
    }
    
    // MARK: - Private helpers
    
    private func showArrow() {
        guard theArrow.alpha == 0 else {
            return
        }
        accuracyDotsShown = true
        if UserDefaults.standard.object(forKey: Constants.Defs.showProgressBar) as! Bool,
           !compassMode {
            let act = SKAction.fadeIn(withDuration: normFade)
            progressGroup.run(act)
        }
        animQueue.addOperation(CentralAnimationOperation(restoreArrowWithScene: self, force: true))
    }
    
    private func makeDot(dot: SKShapeNode, waitOn: Double, waitOff: Double) -> SKNode {
        dot.fillColor = Constants.arrowColor
        dot.strokeColor = Constants.strokeColor
        dot.alpha = 0
        
        let fadeing = SKAction.sequence([SKAction.wait(forDuration: waitOn), SKAction.fadeIn(withDuration: 0.5), SKAction.fadeOut(withDuration: 0.5), SKAction.wait(forDuration: waitOff)])
        
        dot.run(SKAction.repeatForever(fadeing))
        
        return dot
    }
    
    private func hideAccuracyDots() {
        guard accuracyDotsShown else {
            return
        }
        
        accuracyDotsShown = false
        lastAccuracy = nil
        accuracyGroup.removeAllActions()
        let act = SKAction.fadeOut(withDuration: normFade)
        gpsLabel.removeAllActions()
        gpsLabel.run(act)
        accuracyGroup.run(act)
    }
    
    private func fadeOutArrowAndProgress() {
        let act = SKAction.fadeOut(withDuration: fastFade)
        if theArrow.alpha > 0 || theArrow.hasActions() {
            theArrow.removeAllActions()
            theArrow.run(act)
        }
        if crosshair.alpha > 0 || crosshair.hasActions() {
            crosshair.removeAllActions()
            crosshair.run(act)
        }
        if progressGroup.alpha > 0 || progressGroup.hasActions() {
            progressGroup.removeAllActions()
            progressGroup.run(act)
        }
    }
    
    private func makeProgBar() {
        progBarFront = SKShapeNode(rectOf: progressBarSize, cornerRadius: progressBarRadius)
        progBarFront.fillColor = .clear
        progBarFront.strokeColor = Constants.arrowColor
        progBarFront.lineWidth = progressBarStrokeWidth
        
        progBarBack = SKShapeNode()
        progBarBack.fillColor = Constants.arrowColor
        progBarBack.strokeColor = .clear
        
        progressGroup.alpha = 0
        progressGroup.addChild(progBarFront)
        progressGroup.addChild(progBarBack)
    }
    
    // MARK: - Notification callbacks
    
    @objc private func changedProgressBarPreference(_ notification: Notification) {
        guard theArrow.alpha > 0 else {
            return
        }
        
        let act: SKAction
        if UserDefaults.standard.object(forKey: Constants.Defs.showProgressBar) as! Bool {
            act = SKAction.fadeIn(withDuration: normFade)
        } else {
            act = SKAction.fadeOut(withDuration: normFade)
        }
        progressGroup.run(act)
    }
    
    @objc private func updateArrowSize(_ notification: Notification?) {
        #if WatchApp
        guard let size: CGFloat = UserDefaults.standard.object(forKey: Constants.Defs.watchArrowSize) as? CGFloat else { return }
        #else
        guard let size: CGFloat = UserDefaults.standard.object(forKey: Constants.Defs.iPhoneArrowSize) as? CGFloat else { return }
        #endif
        #if WatchApp
        let refSize: CGFloat = 128
        #else
        let refSize: CGFloat = 240
        #endif
        (theArrow as! SKSpriteNode).size = CGSize(width: size, height: size)
        (compassArrow as! SKSpriteNode).size = CGSize(width: size, height: size)
        crosshair.setScale(size / refSize)
    }
    
    // MARK: - Helper functions
    
    private func fadeInAndOutForever(duration: TimeInterval, node: SKNode) {
        let fin = SKAction.fadeIn(withDuration: duration)
        let fou = SKAction.fadeOut(withDuration: duration)
        let acts = SKAction.sequence([fin, fou])
        let fora = SKAction.repeatForever(acts)
        node.run(fora)
    }
    
    private func makeCrosshair() {
        #if WatchApp
        let crosshairTopThickness: CGFloat = 5.0
        let crosshairCornerThickness: CGFloat = 2.0
        let crosshairSideThickness: CGFloat = 1.5
        #else
        let crosshairTopThickness: CGFloat = 10.0
        let crosshairCornerThickness: CGFloat = 4.0
        let crosshairSideThickness: CGFloat = 3.0
        #endif
        
        let sidePoint: CGFloat = arrow.frame.size.width * 0.7  // starting point for 90° crosshairs (all three of them)
        let cornerPoint: CGFloat = arrow.frame.size.height * 0.4 // start point for corners (both)
        
        let topLength: CGFloat = arrow.frame.size.height * 0.4 // top length
        let cornerLength: CGFloat = arrow.frame.size.height * 0.1  // corner length
        let sideLength: CGFloat = arrow.frame.size.width * 0.20  // side length
        crosshair = SKNode()
        
        // 5 points, two one sides, two on corners, one on top
        
        // top line
        var topPoints = [CGPoint]()
        topPoints.append(CGPoint(x: 0, y: sidePoint))
        // next point ends at top minus size divided by proportion
        topPoints.append(CGPoint(x: 0, y: sidePoint - topLength))
        let topLine = SKShapeNode(points: &topPoints, count: 2)
        topLine.lineWidth =  crosshairTopThickness
        topLine.strokeColor = Constants.crosshairColor
        crosshair.addChild(topLine)
        
        // corner lines
        var leftCornerPoints = [CGPoint]()
        leftCornerPoints.append(CGPoint(x: -cornerPoint, y: cornerPoint))
        leftCornerPoints.append(CGPoint(x: -cornerPoint + cornerLength, y: cornerPoint - cornerLength))
        let leftCornerLine = SKShapeNode(points: &leftCornerPoints, count: 2)
        leftCornerLine.lineWidth =  crosshairCornerThickness
        leftCornerLine.strokeColor = Constants.crosshairColor
        crosshair.addChild(leftCornerLine)
        
        var rightCornerPoints = [CGPoint]()
        rightCornerPoints.append(CGPoint(x: cornerPoint, y: cornerPoint))
        rightCornerPoints.append(CGPoint(x: cornerPoint - cornerLength, y: cornerPoint - cornerLength))
        let rightCornerLine = SKShapeNode(points: &rightCornerPoints, count: 2)
        rightCornerLine.lineWidth =  crosshairCornerThickness
        rightCornerLine.strokeColor = Constants.crosshairColor
        crosshair.addChild(rightCornerLine)
        
        // side lines
        var leftSidePoints = [CGPoint]()
        leftSidePoints.append(CGPoint(x: -sidePoint, y: 0))
        leftSidePoints.append(CGPoint(x: -sidePoint + sideLength, y: 0))
        let leftSideLine = SKShapeNode(points: &leftSidePoints, count: 2)
        leftSideLine.lineWidth =  crosshairSideThickness
        leftSideLine.strokeColor = Constants.crosshairColor
        crosshair.addChild(leftSideLine)
        
        var rightSidePoints = [CGPoint]()
        rightSidePoints.append(CGPoint(x: sidePoint, y: 0))
        rightSidePoints.append(CGPoint(x: sidePoint - sideLength, y: 0))
        let rightSideLine = SKShapeNode(points: &rightSidePoints, count: 2)
        rightSideLine.lineWidth =  crosshairSideThickness
        rightSideLine.strokeColor = Constants.crosshairColor
        crosshair.addChild(rightSideLine)

        crosshair.alpha = 0
        addChild(crosshair)
        crosshair.zPosition = theArrow.zPosition - 1
    }

}
