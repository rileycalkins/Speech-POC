import SwiftUI
import AVFoundation
import Speech
import Combine

// Fix the missing imports by explicitly importing from the project structure
// No need for explicit imports as they're in the same module, but we need to ensure these files are included in the build
// The comments below serve as documentation for future developers

// WordTimestamp is defined in Model/WordTimestamp.swift
// RateLimiter is defined in Utilities/RateLimiter.swift

// ViewModel for audio file transcription


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
            // File selection button
            Button(action: {
                viewModel.selectAndTranscribeFile()
            }) {
                HStack {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 20))
                    Text("Select Audio File")
                        .font(.headline)
                }
                .frame(minWidth: 180, minHeight: 40)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isTranscribing || viewModel.isPreparingSegments)
            
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
            }
            
            // Show segments progress
            if viewModel.numberOfSegments > 1 && !viewModel.segmentProgress.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Overall Progress")
                            .font(.headline)
                        Spacer()
                        Text("\(Int(viewModel.overallProgress * 100))%")
                    }
                    
                    ProgressView(value: viewModel.overallProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                    
                    Divider().padding(.vertical, 8)
                    
                    Text("Segments")
                        .font(.headline)
                    
                    ForEach(0..<viewModel.segmentProgress.count, id: \.self) { index in
                        HStack {
                            Text("Segment \(index + 1)")
                                .font(.callout)
                            Spacer()
                            Text("\(Int(viewModel.segmentProgress[index] * 100))%")
                                .font(.callout)
                                .foregroundColor(viewModel.currentSegmentIndex == index ? .blue : .gray)
                        }
                        ProgressView(value: viewModel.segmentProgress[index])
                            .progressViewStyle(LinearProgressViewStyle())
                            .accentColor(viewModel.currentSegmentIndex == index ? .blue : .gray)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1))
                )
            }
            // Current segment progress when transcribing
            else if viewModel.isTranscribing {
                VStack(spacing: 12) {
                    ProgressView(value: viewModel.progress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(maxWidth: .infinity)
                    
                    HStack {
                        Text("Transcribing... \(Int(viewModel.progress * 100))%")
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
            }
            
            // Error message
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
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
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}



