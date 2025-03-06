import Foundation

/// A utility class to limit the rate of operations
class RateLimiter {
    private var lastUpdateTimes: [String: Date] = [:]
    
    /// Determines if an update should be allowed based on the minimum interval
    /// - Parameters:
    ///   - key: A unique identifier for the operation type
    ///   - minInterval: The minimum time interval (in seconds) between updates
    /// - Returns: True if the update should be allowed, false otherwise
    func shouldUpdate(for key: String, minInterval: TimeInterval) -> Bool {
        let now = Date()
        
        if let lastUpdate = lastUpdateTimes[key] {
            let timeSinceLastUpdate = now.timeIntervalSince(lastUpdate)
            if timeSinceLastUpdate < minInterval {
                return false
            }
        }
        
        lastUpdateTimes[key] = now
        return true
    }
    
    /// Resets the timer for a specific key
    /// - Parameter key: The key to reset
    func reset(for key: String) {
        lastUpdateTimes.removeValue(forKey: key)
    }
    
    /// Resets all timers
    func resetAll() {
        lastUpdateTimes.removeAll()
    }
} 