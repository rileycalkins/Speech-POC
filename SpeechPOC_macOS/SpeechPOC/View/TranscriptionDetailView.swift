//
//  TranscriptionDetailView.swift
//  SpeechPOC
//
//  Created by Alex Lifa on 9/27/24.
//

import SwiftUI
import Foundation

// Note: The linter errors for missing types will need to be resolved in Xcode
// You will need to:
// 1. Make sure all model files (Transcription.swift, WordTimestamp.swift) are included in the target
// 2. Check that your module organization is correct
// 3. Ensure the files are in the correct build phases

struct TranscriptionDetailView: View {
    @Binding var transcription: Transcription
    var onSave: (Transcription) -> Void
    var gradientConfig: GradientConfiguration = .defaultConfig
    
    @State private var editedTitle: String = ""
    @State private var showTimestamps: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Title", text: $transcription.title)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding([.leading, .trailing, .top])

            TextEditor(text: $transcription.content)
                .border(Color.gray, width: 1)
                .frame(minHeight: 200)
                .padding([.leading, .trailing])
            
            // Word timestamps section
            if !transcription.wordTimestamps.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Word Timestamps")
                            .font(.headline)
                        
                        Spacer()
                        
                        Toggle("Show", isOn: $showTimestamps)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                    .padding(.horizontal)
                    
                    if showTimestamps {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 4) {
                                ForEach(transcription.wordTimestamps) { timestamp in
                                    HStack {
                                        Text(timestamp.word)
                                            .font(.system(.body, design: .monospaced))
                                        
                                        Spacer()
                                        
                                        Text("Start: \(timestamp.formattedStartTime)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Text("End: \(timestamp.formattedEndTime)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 2)
                                    .padding(.horizontal, 8)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(4)
                                }
                            }
                            .padding(8)
                        }
                        .frame(height: 200)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.05))
                        )
                        .padding(.horizontal)
                    }
                }
            }
            
            TaggingView(tags: $transcription.tags, gradientConfig: gradientConfig)
                .padding([.leading, .trailing])
            
            Spacer()
            
            HStack {
                Spacer()
                Button(action: {
                    onSave(transcription)
                }) {
                    Text("Save")
                        .fontWeight(.bold)
                        .padding()
                        .frame(minWidth: 100)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
        .onAppear {
            editedTitle = transcription.title
        }
    }
}

#if DEBUG || TracePreviews
struct TranscriptionDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleTranscription = Transcription(
            title: "Transcription title",
            content: "blablablablablablabla.",
            tags: ["????", "blablablabla", "tag"],
            wordTimestamps: [
                WordTimestamp(word: "hello", startTime: 0.0, endTime: 0.5),
                WordTimestamp(word: "world", startTime: 0.6, endTime: 1.2)
            ]
        )
        
        StatefulPreviewWrapper(sampleTranscription) { binding in
            TranscriptionDetailView(transcription: binding, onSave: { updatedTranscription in
            })
        }
        .previewLayout(.sizeThatFits)
        .padding()
    }
}

// MARK: - Preview helper

struct StatefulPreviewWrapper<Value: Identifiable, Content: View>: View where Value: Hashable {
    @State private var value: Value
    var content: (Binding<Value>) -> Content
    
    init(_ value: Value, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
        _value = State(wrappedValue: value)
        self.content = content
    }
    
    var body: some View {
        content($value)
    }
}
#endif


