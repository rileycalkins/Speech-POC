import Foundation
import AVFoundation
import Combine

/// Implementation of AudioSegmenter using AVFoundation
class AVAudioSegmenter: AudioSegmenter {
    private var temporaryDirectoryURL: URL?
    private var cancellables = Set<AnyCancellable>()
    
    /// Logger for debugging
    private let logger = Logger(subsystem: "com.speechpoc", category: "AVAudioSegmenter")
    
    /// Split an audio file into multiple segments
    /// - Parameters:
    ///   - url: The URL of the audio file to split
    ///   - segmentCount: The number of segments to create
    ///   - onProgress: Callback for segmentation progress
    ///   - onCompletion: Callback with array of segment URLs and durations
    ///   - onError: Callback for errors
    func splitAudioFile(
        url: URL,
        segmentCount: Int,
        onProgress: @escaping (Double) -> Void,
        onCompletion: @escaping ([AudioSegment]) -> Void,
        onError: @escaping (TranscriptionError) -> Void
    ) {
        guard segmentCount > 0 else {
            onError(.segmentationFailed("Segment count must be positive"))
            return
        }
        
        if segmentCount == 1 {
            // No need to split, just get duration and return original
            getAudioDuration(for: url) { [weak self] duration in
                guard let self = self else { return }
                let segment = AudioSegment(url: url, duration: duration, index: 0, totalSegments: 1)
                onCompletion([segment])
            }
            return
        }
        
        // Create temporary directory for segments
        createTemporaryDirectory { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let tempDir):
                self.temporaryDirectoryURL = tempDir
                self.splitAudioIntoSegments(
                    url: url,
                    segmentCount: segmentCount,
                    tempDir: tempDir,
                    onProgress: onProgress,
                    onCompletion: onCompletion,
                    onError: onError
                )
                
            case .failure(let error):
                onError(error)
            }
        }
    }
    
    /// Clean up temporary files created during segmentation
    func cleanup() {
        guard let temporaryDirectoryURL = temporaryDirectoryURL else { return }
        
        do {
            try FileManager.default.removeItem(at: temporaryDirectoryURL)
            self.temporaryDirectoryURL = nil
            logger.debug("Cleaned up temporary directory: \(temporaryDirectoryURL.lastPathComponent)")
        } catch {
            logger.error("Error cleaning up temporary files: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Methods
    
    /// Create a temporary directory for segment files
    private func createTemporaryDirectory(completion: @escaping (Result<URL, TranscriptionError>) -> Void) {
        let temporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        
        do {
            try FileManager.default.createDirectory(
                at: temporaryDirectory,
                withIntermediateDirectories: true
            )
            logger.debug("Created temporary directory: \(temporaryDirectory.lastPathComponent)")
            completion(.success(temporaryDirectory))
        } catch {
            let errorMsg = "Failed to create temporary directory: \(error.localizedDescription)"
            logger.error(errorMsg)
            completion(.failure(.fileAccessError(errorMsg)))
        }
    }
    
    /// Split audio file into segments using AVAssetExportSession
    private func splitAudioIntoSegments(
        url: URL,
        segmentCount: Int,
        tempDir: URL,
        onProgress: @escaping (Double) -> Void,
        onCompletion: @escaping ([AudioSegment]) -> Void,
        onError: @escaping (TranscriptionError) -> Void
    ) {
        let asset = AVAsset(url: url)
        
        asset.loadValuesAsynchronously(forKeys: ["duration"]) { [weak self] in
            guard let self = self else { return }
            
            // Check if asset duration is available
            var error: NSError? = nil
            let status = asset.statusOfValue(forKey: "duration", error: &error)
            
            DispatchQueue.main.async {
                guard status == .loaded else {
                    let errorMsg = "Failed to load audio asset: \(error?.localizedDescription ?? "Unknown error")"
                    self.logger.error(errorMsg)
                    onError(.fileAccessError(errorMsg))
                    return
                }
                
                let duration = CMTimeGetSeconds(asset.duration)
                let segmentDuration = duration / Double(segmentCount)
                self.logger.debug("Total duration: \(duration), segment duration: \(segmentDuration)")
                
                // Initialize arrays to store segment info
                var segmentURLs: [URL] = []
                var segmentDurations: [TimeInterval] = []
                var segments: [AudioSegment] = []
                
                // Create export sessions for each segment
                let fileType = self.determineFileType(from: url)
                var completedExports = 0
                
                // Calculate segment durations in advance
                let segmentTimeRanges = self.calculateSegmentTimeRanges(
                    duration: duration,
                    segmentCount: segmentCount
                )
                
                // Create export sessions
                for (index, timeRange) in segmentTimeRanges.enumerated() {
                    let segmentFileName = "segment_\(index).\(fileType.fileExtension)"
                    let segmentURL = tempDir.appendingPathComponent(segmentFileName)
                    
                    self.logger.debug("Creating segment \(index+1): \(segmentFileName), duration: \(timeRange.duration)")
                    
                    // Set up export session
                    guard let exportSession = AVAssetExportSession(
                        asset: asset,
                        presetName: AVAssetExportPresetPassthrough
                    ) else {
                        let errorMsg = "Failed to create export session for segment \(index+1)"
                        self.logger.error(errorMsg)
                        onError(.segmentationFailed(errorMsg))
                        return
                    }
                    
                    exportSession.outputURL = segmentURL
                    exportSession.outputFileType = fileType
                    exportSession.timeRange = timeRange.cmTimeRange
                    
                    // Add to tracking arrays
                    segmentURLs.append(segmentURL)
                    segmentDurations.append(timeRange.duration)
                    
                    // Export the segment
                    exportSession.exportAsynchronously { [weak self] in
                        guard let self = self else { return }
                        
                        DispatchQueue.main.async {
                            completedExports += 1
                            onProgress(Double(completedExports) / Double(segmentCount))
                            
                            if exportSession.status == .completed {
                                self.logger.debug("Completed export of segment \(index+1)/\(segmentCount)")
                                
                                // Create AudioSegment object
                                let segment = AudioSegment(
                                    url: segmentURL,
                                    duration: timeRange.duration,
                                    index: index,
                                    totalSegments: segmentCount
                                )
                                segments.append(segment)
                                
                                // Check if all segments are processed
                                if completedExports == segmentCount {
                                    // Sort segments by index
                                    let sortedSegments = segments.sorted { $0.index < $1.index }
                                    self.logger.debug("All \(segmentCount) segments exported successfully")
                                    onCompletion(sortedSegments)
                                }
                            } else if exportSession.status == .failed {
                                let errorMsg = "Failed to export segment \(index+1): \(exportSession.error?.localizedDescription ?? "Unknown error")"
                                self.logger.error(errorMsg)
                                onError(.segmentationFailed(errorMsg))
                            }
                        }
                    }
                }
            }
        }
    }
    
    /// Calculate time ranges for segments with a small overlap
    private func calculateSegmentTimeRanges(duration: TimeInterval, segmentCount: Int) -> [(startTime: TimeInterval, duration: TimeInterval, cmTimeRange: CMTimeRange)] {
        var timeRanges: [(startTime: TimeInterval, duration: TimeInterval, cmTimeRange: CMTimeRange)] = []
        
        let segmentDuration = duration / Double(segmentCount)
        let overlap: TimeInterval = min(0.5, segmentDuration * 0.1) // 0.5 second or 10% overlap, whichever is smaller
        
        for i in 0..<segmentCount {
            let startTime = max(0, Double(i) * segmentDuration - (i > 0 ? overlap : 0))
            let endTime = min(startTime + segmentDuration + (i < segmentCount - 1 ? overlap : 0), duration)
            let segmentDuration = endTime - startTime
            
            let startCMTime = CMTimeMakeWithSeconds(startTime, preferredTimescale: 600)
            let endCMTime = CMTimeMakeWithSeconds(endTime, preferredTimescale: 600)
            let timeRange = CMTimeRangeFromTimeToTime(start: startCMTime, end: endCMTime)
            
            timeRanges.append((startTime, segmentDuration, timeRange))
        }
        
        return timeRanges
    }
    
    /// Get the duration of an audio file
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
    
    /// Determine the AVFileType from a URL
    private func determineFileType(from url: URL) -> AVFileType {
        let pathExtension = url.pathExtension.lowercased()
        
        switch pathExtension {
        case "wav":
            return .wav
        case "mp3":
            return .mp3
        case "m4a":
            return .m4a
        case "aiff", "aif":
            return .aiff
        default:
            // Default to mp4 as a fallback
            return .mp4
        }
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