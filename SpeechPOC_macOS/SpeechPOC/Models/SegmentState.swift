import SwiftUI

/// Represents the state of a segment in the transcription process
enum SegmentState: Equatable {
    /// Segment is waiting to be processed
    case pending
    /// Segment is currently being processed
    case inProgress
    /// Segment has been successfully processed
    case completed
    /// Segment processing failed
    case error
    
    /// Textual description of the state
    var description: String {
        switch self {
        case .pending:
            return "Pending"
        case .inProgress:
            return "In Progress"
        case .completed:
            return "Completed"
        case .error:
            return "Error"
        }
    }
    
    /// The color associated with this state for UI display
    var color: Color {
        switch self {
        case .pending:
            return .gray
        case .inProgress:
            return .blue
        case .completed:
            return .green
        case .error:
            return .red
        }
    }
    
    /// The label associated with this state for UI display
    var label: String {
        switch self {
        case .pending:
            return "(Pending)"
        case .inProgress:
            return "(Processing)"
        case .completed:
            return "(Completed)"
        case .error:
            return "(Error)"
        }
    }
} 