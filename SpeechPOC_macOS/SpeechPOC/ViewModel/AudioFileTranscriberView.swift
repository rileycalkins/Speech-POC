import SwiftUI
import AVFoundation
import Speech
import Combine

// Note: If you see linter errors about missing WordTimestamp type:
// 1. Make sure WordTimestamp.swift is included in your target
// 2. Check your project's build phases and module organization
// 3. Resolve these issues in Xcode by ensuring all model files are properly included

// ViewModel for audio file transcription
class AudioFileTranscriberViewModel: ObservableObject {
    @Published var transcribedText: String = ""
    @Published var isTranscribing: Bool = false
    @Published var progress: Double = 0.0
    @Published var estimatedRemainingTime: TimeInterval = 0
    @Published var errorMessage: String?
    @Published var wordTimestamps: [WordTimestamp] = []
    
    private var recognitionRequest: SFSpeechURLRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var fileURL: URL?
    private var startTime: Date?
    private var audioDuration: TimeInterval = 0
    private var progressTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        requestSpeechRecognitionAccess()
    }
    
    func selectAndTranscribeFile() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.audio, .mp3, .wav, .mpeg4Audio, .aiff]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        
        openPanel.begin { [weak self] response in
            guard let self = self else { return }
            
            if response == .OK, let url = openPanel.url {
                self.fileURL = url
                self.processAudioFile(url: url)
            }
        }
    }
    
    private func processAudioFile(url: URL) {
        guard !isTranscribing else { return }
        
        // Reset previous state
        self.transcribedText = ""
        self.progress = 0
        self.errorMessage = nil
        self.wordTimestamps = []
        
        // Get audio file duration for progress calculation
        getAudioDuration(for: url) { [weak self] duration in
            guard let self = self else { return }
            
            self.audioDuration = duration
            self.startTranscription(url: url)
        }
    }
    
    private func getAudioDuration(for url: URL, completion: @escaping (TimeInterval) -> Void) {
        let asset = AVAsset(url: url)
        asset.loadValuesAsynchronously(forKeys: ["duration"]) {
            var error: NSError? = nil
            let status = asset.statusOfValue(forKey: "duration", error: &error)
            
            DispatchQueue.main.async {
                if status == .loaded {
                    let duration = CMTimeGetSeconds(asset.duration)
                    completion(duration)
                } else {
                    // If we can't get duration, use a default estimate
                    completion(60) // Default 1 minute
                }
            }
        }
    }
    
    private func startTranscription(url: URL) {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            self.errorMessage = "Speech recognizer not available"
            return
        }
        
        isTranscribing = true
        startTime = Date()
        
        // Create and configure the speech recognition request
        recognitionRequest = SFSpeechURLRecognitionRequest(url: url)
        
        guard let recognitionRequest = recognitionRequest else {
            self.errorMessage = "Unable to create recognition request"
            isTranscribing = false
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Start progress tracking
        startProgressTracking()
        
        // Start the recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                DispatchQueue.main.async {
                    self.transcribedText = result.bestTranscription.formattedString
                    
                    // Extract word timestamps
                    self.extractWordTimestamps(from: result.bestTranscription)
                    
                    // Update progress based on the transcribed text length if final
                    if result.isFinal {
                        self.progress = 1.0
                        self.stopProgressTracking()
                        self.isTranscribing = false
                    }
                }
            }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isTranscribing = false
                    self.stopProgressTracking()
                }
            }
        }
    }
    
    private func extractWordTimestamps(from transcription: SFTranscription) {
        var updatedTimestamps: [WordTimestamp] = []
        
        for segment in transcription.segments {
            let wordTimestamp = WordTimestamp(
                word: segment.substring,
                startTime: segment.timestamp,
                endTime: segment.timestamp + segment.duration
            )
            updatedTimestamps.append(wordTimestamp)
        }
        
        self.wordTimestamps = updatedTimestamps
    }
    
    func cancelTranscription() {
        recognitionTask?.cancel()
        recognitionTask = nil
        stopProgressTracking()
        isTranscribing = false
    }
    
    private func startProgressTracking() {
        // Start a timer to update progress
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self, self.isTranscribing, let startTime = self.startTime else { return }
            
            let elapsedTime = Date().timeIntervalSince(startTime)
            
            // Calculate progress as a ratio of elapsed time to estimated duration
            // We add a 20% processing overhead to account for recognition processing time
            let estimatedTotalTime = self.audioDuration * 1.2
            let newProgress = min(elapsedTime / estimatedTotalTime, 0.95) // Cap at 95% until final result
            
            // Calculate estimated remaining time
            let remainingTime = max(0, estimatedTotalTime - elapsedTime)
            
            DispatchQueue.main.async {
                self.progress = newProgress
                self.estimatedRemainingTime = remainingTime
            }
        }
    }
    
    private func stopProgressTracking() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
    
    private func requestSpeechRecognitionAccess() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    // Ready to transcribe
                    break
                default:
                    self.errorMessage = "Speech recognition authorization not granted"
                }
            }
        }
    }
    
    // Format time interval to string (e.g., "2:30" for 2 minutes and 30 seconds)
    func formatTimeRemaining(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%d:%02d", minutes, seconds)
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
            .disabled(viewModel.isTranscribing)
            
            // Progress indicator when transcription is in progress
            if viewModel.isTranscribing {
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

struct AudioFileTranscriberView_Previews: PreviewProvider {
    static var previews: some View {
        AudioFileTranscriberView(
            viewModel: AudioFileTranscriberViewModel(),
            onTranscriptionComplete: { _, _ in }
        )
        .frame(width: 500, height: 400)
        .previewLayout(.sizeThatFits)
    }
}