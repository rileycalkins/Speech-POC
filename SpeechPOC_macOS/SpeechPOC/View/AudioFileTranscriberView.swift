import SwiftUI
import Combine
import AVFoundation

struct AudioFileTranscriberView: View {
    @ObservedObject var viewModel: AudioFileTranscriberViewModel
    var onTranscriptionComplete: (String, [WordTimestamp]) -> Void
    
    var body: some View {
        VStack(spacing: 15) {
            Text("Audio File Transcription")
                .font(.title)
            
            HStack {
                Button("Select Audio File") {
                    viewModel.selectAndTranscribeFile()
                }
                .disabled(viewModel.isTranscribing)
                
                if viewModel.isTranscribing {
                    Button("Cancel") {
                        viewModel.cancelTranscription()
                    }
                }
            }
            
            if viewModel.isTranscribing {
                VStack {
                    ProgressView(value: viewModel.progress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(maxWidth: .infinity)
                    
                    Text("Transcribing... \(Int(viewModel.progress * 100))%")
                    
                    if viewModel.estimatedRemainingTime > 0 {
                        Text("Estimated time remaining: \(formatTimeRemaining(viewModel.estimatedRemainingTime))")
                            .font(.caption)
                    }
                }
                .padding(.vertical)
            }
            
            if !viewModel.transcribedText.isEmpty {
                VStack(alignment: .leading) {
                    Text("Transcription:")
                        .font(.headline)
                    
                    ScrollView {
                        Text(viewModel.transcribedText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 150)
                    .padding(5)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(5)
                    
                    Button("Save Transcription") {
                        onTranscriptionComplete(viewModel.transcribedText, viewModel.wordTimestamps)
                    }
                    .disabled(viewModel.transcribedText.isEmpty || viewModel.isTranscribing)
                }
            }
            
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func formatTimeRemaining(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
} 