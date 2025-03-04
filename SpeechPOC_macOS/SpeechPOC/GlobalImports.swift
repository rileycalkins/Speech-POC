import Foundation
import SwiftUI

// Make all model types available globally
// This resolves circular import issues

// Add this line at the top of each file that needs access to the models:
// import SpeechPOC

// MARK: - Common Model Typealias
typealias TranscriptionModel = Transcription
typealias WordTimestampModel = WordTimestamp
typealias AudioFileTranscriberViewModelType = AudioFileTranscriberViewModel 