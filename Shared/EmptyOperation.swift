import Foundation

/// Placeholder for an operation (not linked to a target)
class EmptyOperation: Operation {
    
    override var isAsynchronous: Bool {
        get {
            return true
    } }
    
    override init() {
        super.init()
        state = .ready
    }
    
    override func start() {
        // Mandatory cancellation check
        guard !isCancelled else {
            state = .cancelled
            return
        }
        
        state = .executing
        
        let startDelay: TimeInterval = 0.0
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + startDelay) {
            self.something()
        }

    }
    
    private func something() {
        // Mandatory cancellation check
        guard !isCancelled else {
            state = .cancelled
            return
        }
        
        state = .finished
    }
}

