import Foundation
import Combine

/// Implementation of the TranscriptionCombiner protocol
class TranscriptionCombinerImpl: TranscriptionCombiner {
    /// Logger for debugging
    private let logger = Logger(subsystem: "com.speechpoc", category: "TranscriptionCombiner")
    
    /// Combine multiple segment transcriptions into a single result
    /// - Parameters:
    ///   - segmentResults: Array of segment transcription results
    ///   - segmentDurations: Array of segment durations
    /// - Returns: Combined transcription text and word timestamps
    func combineTranscriptions(
        segmentResults: [(text: String, wordTimestamps: [WordTimestamp])],
        segmentDurations: [TimeInterval]
    ) -> (text: String, wordTimestamps: [WordTimestamp]) {
        // Validate input
        guard !segmentResults.isEmpty else {
            logger.error("No segment results to combine")
            return ("", [])
        }
        
        // Ensure we have a duration for each segment
        guard segmentResults.count == segmentDurations.count else {
            logger.error("Segment count mismatch: \(segmentResults.count) results but \(segmentDurations.count) durations")
            // Use the available segments anyway, but log the error
            return ("", [])
        }
        
        // 1. Combine all segment texts with a space separator
        let combinedText = segmentResults.map { $0.text }.joined(separator: " ")
        logger.debug("Combined \(segmentResults.count) segments into text (\(combinedText.count) chars)")
        
        // 2. Adjust timestamps for word timings across segments
        var allWordTimestamps: [WordTimestamp] = []
        var timeOffset: TimeInterval = 0
        
        // Process each segment
        for (i, segment) in segmentResults.enumerated() {
            // Skip empty segments
            if segment.wordTimestamps.isEmpty {
                logger.debug("Segment \(i+1) has no word timestamps - skipping")
                
                // Still add the duration to the offset if available
                if i < segmentDurations.count {
                    timeOffset += segmentDurations[i]
                }
                continue
            }
            
            // Log segment details
            logger.debug("Processing segment \(i+1) with \(segment.wordTimestamps.count) words, offset: \(timeOffset)")
            
            // Create adjusted timestamps with proper offset
            let adjustedTimestamps = segment.wordTimestamps.map { timestamp -> WordTimestamp in
                return WordTimestamp(
                    word: timestamp.word,
                    startTime: timestamp.startTime + timeOffset,
                    endTime: timestamp.endTime + timeOffset
                )
            }
            
            // Add to the combined collection
            allWordTimestamps.append(contentsOf: adjustedTimestamps)
            
            // Add this segment's duration to the offset for the next segment
            if i < segmentDurations.count {
                timeOffset += segmentDurations[i]
            }
        }
        
        logger.debug("Combined result has \(allWordTimestamps.count) word timestamps")
        return (combinedText, allWordTimestamps)
    }
}

/// Simple logger for debugging
fileprivate class Logger {
    let subsystem: String
    let category: String
    
    init(subsystem: String, category: String) {
        self.subsystem = subsystem
        self.category = category
    }
    
    func debug(_ message: String) {
        #if DEBUG
        print("🔍 [\(category)] \(message)")
        #endif
    }
    
    func info(_ message: String) {
        #if DEBUG
        print("ℹ️ [\(category)] \(message)")
        #endif
    }
    
    func error(_ message: String) {
        #if DEBUG
        print("⚠️ [\(category)] \(message)")
        #endif
    }
} 
