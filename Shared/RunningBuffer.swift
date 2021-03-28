/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 This class manages a running buffer of Double values.
 */

import Foundation

struct RunningBuffer {
    
    // MARK: Properties
    
    private(set) var buffer = [Double]()
    private let size: Int
    
    var isEmpty: Bool { get {
        return buffer.isEmpty
    } }
    
    var isFull: Bool { get {
        return size == buffer.count
    } }

    // MARK: Initialization
    
    init(size: Int) {
        self.size = size
        self.buffer = [Double](repeating: 0.0, count: self.size)
        self.reset()
    }
    
    // MARK: Running Buffer
    
    mutating func addSample(_ sample: Double) {
        buffer.insert(sample, at:0)
        if buffer.count > size  {
            buffer.removeLast()
        }
    }
    
    mutating func reset() {
        buffer.removeAll(keepingCapacity: true)
    }
    
    func sum() -> Double {
        return buffer.reduce(0.0, +)
    }
    
    func min() -> Double {
        var min = 0.0
        if let bufMin = buffer.min() {
            min = bufMin
        }
        return min
    }
    
    func max() -> Double {
        var max = 0.0
        if let bufMax = buffer.max() {
            max = bufMax
        }
        return max
    }
    
    func recentMean() -> Double? {
        /// we need at least two items, just in case
        guard buffer.count >= 2 else {
            return nil
        }
        
        // Calculate the mean over the beginning half of the buffer.
        let recentCount = self.size / 2
        var mean = 0.0
        
        if (buffer.count >= recentCount) {
            let recentBuffer = buffer[0..<recentCount]
            mean = recentBuffer.reduce(0.0, +) / Double(recentBuffer.count)
        }
        
        return mean
    }
    
    func oldMean() -> Double? {
        let oldCount = self.size / 2
        /// we need at least two items, just in case
        guard buffer.count >= oldCount + 2 else {
            return nil
        }
        
        // Calculate the mean over the latter half of the buffer.
        var mean = 0.0
        
        let oldBuffer = buffer[oldCount...]
        mean = oldBuffer.reduce(0.0, +) / Double(oldBuffer.count)
        
        return mean
    }
    
    /// Weighted mean uses double weight for the recentMean
    func weightedMean() -> Double? {
        // it is only valid if oldMean is valid
        if let newMean = recentMean(), let oldMean = oldMean() {
            return (newMean * 2 + oldMean * 1 ) / 3
        } else {
            return mean()
        }
    }
    
    /// Angle mean considers that angle is from 0 to 360 (or -360)
    func angleMean() -> Double? {
        guard !buffer.isEmpty else {
            return nil
        }
        // formula is
        // atan2(x,y)
        // where
        // x: sum(sin(angle[i]))/n
        // y: sum(cos(angle[i]))/n
        let sins = buffer.map(deg2rad).map(sin).reduce(0, +) / Double(buffer.count)
        let coss = buffer.map(deg2rad).map(cos).reduce(0, +) / Double(buffer.count)
        let r = atan2(sins, coss)
        return rad2deg(r)
    }
    
    func mean() -> Double? {
        /// we need at least two items, just in case
        guard buffer.count >= 2 else { return nil }
        return buffer.reduce(0.0, +) / Double(buffer.count)
    }
}
