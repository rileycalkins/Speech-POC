import Foundation

/// Represents a word with its timing information in the audio
struct WordTimestamp: Identifiable, Hashable, Codable {
    /// Unique identifier for the word timestamp
    var id = UUID()
    /// The word text
    var word: String
    /// Start time of the word in seconds from the beginning of the audio
    var startTime: TimeInterval
    /// End time of the word in seconds from the beginning of the audio
    var endTime: TimeInterval
    
    /// Formatted start time (mm:ss.ms)
    var formattedStartTime: String {
        return formatTimeInterval(startTime)
    }
    
    /// Formatted end time (mm:ss.ms)
    var formattedEndTime: String {
        return formatTimeInterval(endTime)
    }
    
    /// Format a time interval as mm:ss.ms
    private func formatTimeInterval(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        let milliseconds = Int((timeInterval.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02d:%02d.%03d", minutes, seconds, milliseconds)
    }
    
    /// Create a new WordTimestamp with specified word and timing
    /// - Parameters:
    ///   - word: The word text
    ///   - startTime: Start time in seconds
    ///   - endTime: End time in seconds
    init(word: String, startTime: TimeInterval, endTime: TimeInterval) {
        self.word = word
        self.startTime = startTime
        self.endTime = endTime
    }
    
    /// Create a WordTimestamp from another one with adjusted timing
    /// - Parameters:
    ///   - timestamp: Original timestamp
    ///   - offset: Time offset to add in seconds
    init(from timestamp: WordTimestamp, withOffset offset: TimeInterval) {
        self.word = timestamp.word
        self.startTime = timestamp.startTime + offset
        self.endTime = timestamp.endTime + offset
    }
} 