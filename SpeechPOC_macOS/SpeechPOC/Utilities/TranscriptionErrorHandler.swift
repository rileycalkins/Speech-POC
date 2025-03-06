import Foundation
import Speech

/// A utility class to handle transcription errors
class TranscriptionErrorHandler {
    
    /// Convert a transcription error to a user-friendly message
    /// - Parameters:
    ///   - error: The error that occurred
    ///   - segment: The segment index where the error occurred
    /// - Returns: A user-friendly error message
    static func handleTranscriptionError(_ error: Error, segment: Int) -> String {
        // Check error description rather than specific types
        let errorDescription = error.localizedDescription
        
        if errorDescription.contains("not authorized") {
            return "Speech recognition not authorized. Please check permissions."
        } else if errorDescription.contains("unavailable") {
            return "Speech recognition is currently unavailable"
        } else if errorDescription.contains("cancelled") {
            return "Transcription was cancelled"
        } else if errorDescription.contains("audio") {
            return "There was a problem with the audio data"
        } else if errorDescription.contains("recognition") {
            return "Recognition failed. The audio may be unclear or in an unsupported format."
        } else {
            return "Error in segment \(segment + 1): \(errorDescription)"
        }
    }
    
    /// Handle audio session errors
    /// - Parameter error: The audio session error
    /// - Returns: A user-friendly error message
    static func handleAudioError(_ error: Error) -> String {
        return "Audio processing error: \(error.localizedDescription)"
    }
    
    /// Handle file export errors
    /// - Parameters:
    ///   - error: The error that occurred
    ///   - segment: The segment index
    /// - Returns: A user-friendly error message
    static func handleExportError(_ error: Error?, segment: Int) -> String {
        if let error = error {
            return "Failed to export segment \(segment + 1): \(error.localizedDescription)"
        } else {
            return "Failed to export segment \(segment + 1)"
        }
    }
} 