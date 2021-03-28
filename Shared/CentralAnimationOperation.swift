import Foundation
import SpriteKit

/// Placeholder for an operation
class CentralAnimationOperation: Operation {
    
    // MARK: - Setup
    
    override var isAsynchronous: Bool {
        get {
            return true
    } }
    
    weak var scene: ArrowScene?
    var animationType: ArrowScene.AnimationType?
    
    /// bypasses some checks
    var force: Bool = false
    
    /// Pointer to animation to execute.
    /// **Remember to nullify this when done to avoid retain cycles**.
    private var animation: (() -> Void)?
    
    private init(scene: ArrowScene) {
        self.scene = scene
        super.init()
        // MUST SET READY OUTSIDE THIS
    }
    
    // MARK: - Public inits
    
    public convenience init(tickActionWithScene: ArrowScene) {
        self.init(scene: tickActionWithScene)
        animation = scaleAndFadeInTick
        state = .ready
    }
    
    public convenience init(restoreArrowWithScene: ArrowScene, force: Bool = false) {
        self.init(scene: restoreArrowWithScene)
        self.queuePriority = .low
        self.force = force
        animation = restoreArrow
        state = .ready
    }
    
    public convenience init(unfocusArrowWithScene: ArrowScene) {
        self.init(scene: unfocusArrowWithScene)
        self.queuePriority = .high
        animation = unfocusArrow
        state = .ready
    }
    
    public convenience init(showNotificationWithScene: ArrowScene, type: ArrowScene.AnimationType) {
        self.init(scene: showNotificationWithScene)
        self.animationType = type
        animation = displayNotification
        state = .ready
    }
    
    // MARK: - Main Override
    
    override func start() {
        // Mandatory cancellation check
        guard !isCancelled else {
            state = .cancelled
            return
        }
        
        state = .executing
        
        if let animation = self.animation {
            animation()
            self.animation = nil
        } else {
            state = .finished
        }
        
    }
    
    // MARK: - Animation functions
    
    /// High priority operation
    private func unfocusArrow() {
        // Mandatory cancellation check
        guard !isCancelled, let scene = self.scene else {
            state = .cancelled
            return
        }
        
        // if arrow's alpha is 0, do nothing and complete
        guard scene.theArrow.alpha != 0 else {
            state = .finished
            return
        }
        
        let duration: TimeInterval = scene.normFade
        
        let fadeOff = SKAction.fadeAlpha(to: Constants.fadedArrowAlpha, duration: duration)
        
        DispatchQueue.main.async {
            scene.crosshair.run(fadeOff)
            scene.theArrow.run(fadeOff)
        }
        
        finish(after: duration)
    }

    
    /// Low priority operation
    private func restoreArrow() {
        // Mandatory cancellation check
        guard !isCancelled, let scene = self.scene else {
            state = .cancelled
            return
        }
        
        // if arrow's alpha is 0, do nothing and complete
        guard force || scene.theArrow.alpha != 0 else {
            state = .finished
            return
        }
        
        // last check: if arrow was hidden, complete
        guard !scene.terminated else {
            state = .finished
            return
        }
        
        let duration: TimeInterval = scene.normFade

        let fadeIn = SKAction.fadeIn(withDuration: duration)
        DispatchQueue.main.async {
            scene.theArrow.run(fadeIn)
            scene.crosshair.run(fadeIn)
        }
        
        finish(after: duration)

    }
    
    private func displayNotification() {
        // Mandatory cancellation check
        guard !isCancelled, let scene = self.scene else {
            state = .cancelled
            return
        }
        
        scene.currentAnimation = self.animationType
        
        let scaleIn = SKAction.scale(to: 1, duration: 1.0, delay: 0, usingSpringWithDamping: 0.00001, initialSpringVelocity: 0)
        let fadeIn = SKAction.fadeIn(withDuration: scene.normFade)
        let moveInVal = SKAction.moveTo(y: scene.valNotificationLabelY, duration: 1.0, delay: 0, usingSpringWithDamping: 0.00001, initialSpringVelocity: 0)
        let moveInType = SKAction.moveTo(y: scene.typeNotificationLabelY, duration: 1.0, delay: 0, usingSpringWithDamping: 0.00001, initialSpringVelocity: 0)
        let wait = SKAction.wait(forDuration: 5.0)
        let scaleOut = SKAction.scale(to: 0.1, duration: 0.50)
        let fadeOut = SKAction.fadeAlpha(to: 0, duration: 0.50)
        let moveOut = SKAction.moveTo(y: 0, duration: 0.5)
        let showActionsVal = SKAction.group([scaleIn, fadeIn, moveInVal])
        let showActionsType = SKAction.group([scaleIn, fadeIn, moveInType])
        let hideActions = SKAction.group([scaleOut, fadeOut, moveOut])
        
        let labelActionsVal = SKAction.sequence([showActionsVal, wait, hideActions])
        let labelActionsType = SKAction.sequence([showActionsType, wait, hideActions])
        
        let duration: TimeInterval = labelActionsVal.duration
        
        DispatchQueue.main.async {
            scene.valNotificationLabel.run(labelActionsVal)
            scene.typeNotificationLabel.run(labelActionsType)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            scene.currentAnimation = nil
        }
        
        finish(after: duration)

    }
    
    private func scaleAndFadeInTick() {
        // Mandatory cancellation check
        guard !isCancelled, let scene = self.scene else {
            state = .cancelled
            return
        }
        
        // do this after a slight delay so we make sure it's visible
        let wait = SKAction.wait(forDuration: 0.50)
        let scale = SKAction.scale(to: 1, duration: 1, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5)
        let fade = SKAction.fadeIn(withDuration: scene.fastFade)
        
        let tickShowAction = SKAction.group([scale, fade])
        let tickActions = SKAction.sequence([wait, tickShowAction])
        
        let rotate = SKAction.rotate(byAngle: 2.6, duration: scene.normFade * 2.5)
        let lightActions = SKAction.sequence([wait, rotate])
        
        let duration: TimeInterval = max(tickActions.duration, lightActions.duration)
        
        DispatchQueue.main.async {
            scene.tickSprite.run(tickActions)
            scene.lightContainer.run(lightActions)
        }
        
        // hide arrow if it's still visible for some reason after a tiny delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if scene.theArrow.alpha > 0 || scene.theArrow.hasActions() {
                scene.theArrow.removeAllActions()
                scene.crosshair.removeAllActions()
                scene.theArrow.run(SKAction.fadeOut(withDuration: scene.fastFade))
                scene.crosshair.run(SKAction.fadeOut(withDuration: scene.fastFade))
            }
        }
        
        finish(after: duration)

    }
    
    /// Helper function to set state on the underlying queue
    func finish(after: TimeInterval = 0) {
        guard !isCancelled else {
            state = .cancelled
            return
        }
        
        ArrowScene.animationQueue.asyncAfter(deadline: .now() + after) {
            [weak self] in
            self?.state = .finished
        }
    }

}


