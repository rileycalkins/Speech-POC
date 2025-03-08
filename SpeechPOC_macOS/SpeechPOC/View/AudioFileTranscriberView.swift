import SwiftUI
import AVFoundation
import Speech
import Combine
import Foundation

// Fix the missing imports by explicitly importing from the project structure
// No need for explicit imports as they're in the same module, but we need to ensure these files are included in the build
// The comments below serve as documentation for future developers

// WordTimestamp is defined in Model/WordTimestamp.swift
// RateLimiter is defined in Utilities/RateLimiter.swift
// ProgressManager and SegmentState are defined in Utilities/ProgressManager.swift

// ViewModel for audio file transcription

// Extension to get color for segment state


// Extension for AVFileType to get file extensions
extension AVFileType {
    var fileExtension: String {
        switch self {
        case .wav:
            return "wav"
        case .mp3:
            return "mp3"
        case .m4a:
            return "m4a"
        case .aiff:
            return "aif"
        case .mp4:
            return "mp4"
        default:
            return "m4a"
        }
    }
}

// View for audio file transcription
struct AudioFileTranscriberView: View {
    @ObservedObject var viewModel: AudioFileTranscriberViewModel
    var onTranscriptionComplete: (String, [WordTimestamp]) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // File selection button has been moved to the toolbar
            
            // Show file splitting progress
            if viewModel.isPreparingSegments {
                PreparingSegmentsView()
            }
            
            // Show segments progress - using progress data from ViewModel which gets it from ProgressManager
            if viewModel.numberOfSegments > 1 && !viewModel.segmentProgress.isEmpty {
                MultiSegmentProgressView(viewModel: viewModel)
            }
            // Current segment progress when transcribing - using ViewModel's overallProgress property
            else if viewModel.isTranscribing {
                SingleSegmentProgressView(viewModel: viewModel)
            }
            
            // Error message
            if let errorMessage = viewModel.errorMessage {
                ErrorMessageView(message: errorMessage)
            }
            
            // Transcribed text preview (when available and not empty)
            if !viewModel.transcribedText.isEmpty {
                TranscriptionPreviewView(
                    text: viewModel.transcribedText,
                    wordTimestamps: viewModel.wordTimestamps,
                    onComplete: onTranscriptionComplete
                )
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Helper methods 
    private func getSegmentState(for index: Int) -> SegmentState {
        // Access segment state directly through the view model if possible
        // No need for optional binding as progressManager is guaranteed to exist
        let state = viewModel.progressManager.getSegmentState(index)
        
        // If segment states aren't populated yet, fall back to basic state logic
        if case .pending = state, viewModel.currentSegmentIndex > 0 {
            if viewModel.currentSegmentIndex == index && viewModel.isTranscribing {
                return .inProgress
            } else if index < viewModel.currentSegmentIndex {
                return .completed
            }
        }
        
        return state
    }
    
    // MARK: - Subviews
    
    // Preparing segments view
    struct PreparingSegmentsView: View {
        var body: some View {
            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                Text("Preparing audio segments...")
                    .font(.callout)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.1))
            )
            .transition(.opacity)
            .animation(.easeInOut, value: true)
        }
    }
    
    // Multi-segment progress view 
    struct MultiSegmentProgressView: View {
        @ObservedObject var viewModel: AudioFileTranscriberViewModel
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                // Overall progress header
                HStack {
                    Text("Overall Progress")
                        .font(.headline)
                    Spacer()
                    Text("\(Int(viewModel.overallProgress * 100))%")
                        .animation(.easeInOut, value: viewModel.overallProgress)
                }
                
                // Overall progress bar
                ProgressView(value: viewModel.overallProgress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .animation(.easeInOut(duration: 0.5), value: viewModel.overallProgress)
                
                // Estimated time remaining
                if viewModel.estimatedRemainingTime > 0 {
                    Text("Estimated time: \(viewModel.formatTimeRemaining(viewModel.estimatedRemainingTime))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider().padding(.vertical, 8)
                
                // Segments header
                HStack {
                    Text("Segments")
                        .font(.headline)
                    Spacer()
                    Text("Processing segment \(viewModel.currentSegmentIndex) of \(viewModel.numberOfSegments)")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .animation(.easeInOut, value: viewModel.currentSegmentIndex)
                }
                
                // Individual segment progress views
                ForEach(0..<viewModel.segmentProgress.count, id: \.self) { index in
                    SegmentProgressItemView(viewModel: viewModel, index: index)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.1))
            )
            .transition(.opacity)
            .animation(.easeInOut, value: !viewModel.segmentProgress.isEmpty)
        }
    }
    
    // Single segment item view
    struct SegmentProgressItemView: View {
        @ObservedObject var viewModel: AudioFileTranscriberViewModel
        let index: Int
        
        var body: some View {
            VStack(spacing: 4) {
                // Get state from our helper method for this segment
                let state = getSegmentState()
                
                HStack {
                    Text("Segment \(index + 1)")
                        .font(.callout)
                    Text(state.label)
                        .font(.caption)
                        .foregroundColor(state.color)
                    
                    Spacer()
                    Text("\(Int(viewModel.segmentProgress[index] * 100))%")
                        .font(.callout)
                        .foregroundColor(state.color)
                        .animation(.easeInOut, value: viewModel.segmentProgress[index])
                }
                ProgressView(value: viewModel.segmentProgress[index])
                    .progressViewStyle(LinearProgressViewStyle())
                    .accentColor(state.color)
                    .animation(.easeInOut(duration: 0.5), value: viewModel.segmentProgress[index])
            }
        }
        
        // Helper to get segment state 
        private func getSegmentState() -> SegmentState {
            // Access segment state through view model
            let state = viewModel.progressManager.getSegmentState(index)
            
            // Fall back to derived state if needed
            if case .pending = state, viewModel.currentSegmentIndex > 0 {
                if viewModel.currentSegmentIndex == index && viewModel.isTranscribing {
                    return .inProgress
                } else if index < viewModel.currentSegmentIndex {
                    return .completed
                }
            }
            
            return state
        }
    }
    
    // Single segment progress view
    struct SingleSegmentProgressView: View {
        @ObservedObject var viewModel: AudioFileTranscriberViewModel
        
        var body: some View {
            VStack(spacing: 12) {
                ProgressView(value: viewModel.overallProgress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(maxWidth: .infinity)
                    .animation(.easeInOut(duration: 0.5), value: viewModel.overallProgress)
                
                HStack {
                    if viewModel.numberOfSegments > 1 {
                        Text("Transcribing segment \(viewModel.currentSegmentIndex + 1) of \(viewModel.numberOfSegments) • \(Int(viewModel.overallProgress * 100))%")
                            .animation(.easeInOut, value: viewModel.overallProgress)
                    } else {
                        Text("Transcribing... \(Int(viewModel.overallProgress * 100))%")
                            .animation(.easeInOut, value: viewModel.overallProgress)
                    }
                    Spacer()
                    if viewModel.estimatedRemainingTime > 0 {
                        Text("Estimated time: \(viewModel.formatTimeRemaining(viewModel.estimatedRemainingTime))")
                            .foregroundColor(.secondary)
                    }
                }
                
                Button("Cancel") {
                    viewModel.cancelTranscription()
                }
                .buttonStyle(.borderless)
                .foregroundColor(.red)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.1))
            )
            .transition(.opacity)
            .animation(.easeInOut, value: viewModel.isTranscribing)
        }
    }
    
    // Error message view
    struct ErrorMessageView: View {
        let message: String
        
        var body: some View {
            Text(message)
                .foregroundColor(.red)
                .font(.caption)
                .padding(.horizontal)
                .transition(.opacity)
                .animation(.easeInOut, value: true)
        }
    }
    
    // Transcription preview view
    struct TranscriptionPreviewView: View {
        let text: String
        let wordTimestamps: [WordTimestamp]
        let onComplete: (String, [WordTimestamp]) -> Void
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Transcription Preview")
                        .font(.headline)
                    Spacer()
                    Button("Save") {
                        onComplete(text, wordTimestamps)
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                ScrollView {
                    Text(text)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .frame(height: 150)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1))
                )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            .transition(.opacity)
            .animation(.easeInOut, value: !text.isEmpty)
        }
    }
}



