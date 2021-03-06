/*
Copyright (C) 2015 Apple Inc. All Rights Reserved.
See LICENSE.txt for this sample’s licensing information

Abstract:
A subclass of `NSOperation` that maps the different states of an `NSOperation`
        to an explicit `state` enum.
*/

import Foundation

class Operation: Foundation.Operation {
    // MARK: Types
    
    /**
        Using the `@objc` prefix exposes this enum to the ObjC runtime,
        allowing the use of `dynamic` on the `state` property.
    */
    @objc enum State: Int {
        /// The `Operation` is being initialized (before being ready)
        case Init
        
        /// The `Operation` is ready to begin execution.
        case ready
        
        /// The `Operation` is executing.
        case executing
        
        /// The `Operation` has finished executing.
        case finished
        
        /// The `Operation` has been cancelled. Operations must set this
        /// state themselves upon checking super's `cancelled` flag.
        case cancelled
    }
    
    // MARK: Properties
    
    /// Marking `state` as dynamic allows this property to be key-value observed.
    @objc dynamic var state = State.Init
    
    // MARK: NSOperation
    override var isReady: Bool {
        return state == .ready
    }
    
    override var isExecuting: Bool {
        return state == .executing
    }
    
    override var isFinished: Bool {
        return state == .finished || state == .cancelled
    }
    
    /**
        Add the "state" key to the key value observable properties of `NSOperation`.
    */
    @objc class func keyPathsForValuesAffectingIsReady() -> Set<String> {
        return ["state"]
    }
    
    @objc class func keyPathsForValuesAffectingIsExecuting() -> Set<String> {
        return ["state"]
    }
    
    @objc class func keyPathsForValuesAffectingIsFinished() -> Set<String> {
        return ["state"]
    }
}
