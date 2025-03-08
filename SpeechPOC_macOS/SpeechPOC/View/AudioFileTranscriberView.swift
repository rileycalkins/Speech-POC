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
extension SegmentState {
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
    
    // Helper to get segment state from viewModel
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
    
    var body: some View {
        VStack(spacing: 16) {
            // File selection button has been moved to the toolbar
            
            // Show file splitting progress
            if viewModel.isPreparingSegments {
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
                .animation(.easeInOut, value: viewModel.isPreparingSegments)
            }
            
            // Show segments progress - using progress data from ViewModel which gets it from ProgressManager
            if viewModel.numberOfSegments > 1 && !viewModel.segmentProgress.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Overall Progress")
                            .font(.headline)
                        Spacer()
                        Text("\(Int(viewModel.overallProgress * 100))%")
                            .animation(.easeInOut, value: viewModel.overallProgress)
                    }
                    
                    ProgressView(value: viewModel.overallProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .animation(.easeInOut(duration: 0.5), value: viewModel.overallProgress)
                    
                    if viewModel.estimatedRemainingTime > 0 {
                        Text("Estimated time: \(viewModel.formatTimeRemaining(viewModel.estimatedRemainingTime))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider().padding(.vertical, 8)
                    
                    HStack {
                        Text("Segments")
                            .font(.headline)
                        Spacer()
                        Text("Processing segment \(viewModel.currentSegmentIndex + 1) of \(viewModel.numberOfSegments)")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .animation(.easeInOut, value: viewModel.currentSegmentIndex)
                    }
                    
                    ForEach(0..<viewModel.segmentProgress.count, id: \.self) { index in
                        VStack(spacing: 4) {
                            // Get state from our helper method for this segment
                            let state = getSegmentState(for: index)
                            
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
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1))
                )
                .transition(.opacity)
                .animation(.easeInOut, value: !viewModel.segmentProgress.isEmpty)
            }
            // Current segment progress when transcribing - using ViewModel's overallProgress property
            else if viewModel.isTranscribing {
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
            
            // Error message
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
                    .transition(.opacity)
                    .animation(.easeInOut, value: viewModel.errorMessage != nil)
            }
            
            // Transcribed text preview (when available and not empty)
            if !viewModel.transcribedText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Transcription Preview")
                            .font(.headline)
                        Spacer()
                        Button("Save") {
                            onTranscriptionComplete(viewModel.transcribedText, viewModel.wordTimestamps)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    ScrollView {
                        Text(viewModel.transcribedText)
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
                .animation(.easeInOut, value: !viewModel.transcribedText.isEmpty)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}



