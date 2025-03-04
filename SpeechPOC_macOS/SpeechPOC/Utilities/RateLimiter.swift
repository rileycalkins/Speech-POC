import Foundation

/// Utility to manage rate limiting for UI updates
/// This helps prevent the "Message send exceeds rate-limit threshold and will be dropped" error
class RateLimiter {
    private var lastUpdateTimes = [String: Date]()
    
    /// Check if an update should be allowed based on minimum time interval
    /// - Parameters:
    ///   - key: Identifier for the type of update
    ///   - minInterval: Minimum time interval between updates (in seconds)
    /// - Returns: True if update should be allowed, false if it should be throttled
    func shouldUpdate(for key: String, minInterval: TimeInterval) -> Bool {
        let now = Date()
        
        if let lastUpdate = lastUpdateTimes[key], 
           now.timeIntervalSince(lastUpdate) < minInterval {
            return false
        }
        
        lastUpdateTimes[key] = now
        return true
    }
    
    /// Reset all stored timestamps
    func reset() {
        lastUpdateTimes.removeAll()
    }
    
    /// Reset a specific timestamp
    func reset(for key: String) {
        lastUpdateTimes.removeValue(forKey: key)
    }
} 