////
////  AppCore.swift
////  SpeechPOC
////
////  Created by Generated on 3/6/25.
////
//
//import SwiftUI
//import Foundation
//
//// MARK: - Models
//
//struct WordTimestamp: Identifiable, Codable, Equatable {
//    var id: String
//    var word: String
//    var startTime: Double
//    var endTime: Double
//    
//    var formattedStartTime: String {
//        formatTime(startTime)
//    }
//    
//    var formattedEndTime: String {
//        formatTime(endTime)
//    }
//    
//    private func formatTime(_ timeInSeconds: Double) -> String {
//        let minutes = Int(timeInSeconds / 60)
//        let seconds = Int(timeInSeconds.truncatingRemainder(dividingBy: 60))
//        let milliseconds = Int((timeInSeconds.truncatingRemainder(dividingBy: 1)) * 1000)
//        
//        return String(format: "%02d:%02d.%03d", minutes, seconds, milliseconds)
//    }
//}
//
//struct Transcription: Identifiable, Codable, Equatable {
//    var id: String
//    var title: String
//    var content: String
//    var tags: [String]
//    var wordTimestamps: [WordTimestamp]
//}
//
//// MARK: - UI Components
//
//// MARK: Tag Style
//
//struct TagStyle {
//    var backgroundColor: Color = .secondary
//    var textColor: Color = .white
//    var deleteIconColor: Color = .white.opacity(0.7)
//    var cornerRadius: CGFloat = 12
//    var fontSize: Font = .caption
//    var horizontalPadding: CGFloat = 8
//    var verticalPadding: CGFloat = 4
//    
//    static let standard = TagStyle()
//    static let subtle = TagStyle(
//        backgroundColor: .gray.opacity(0.2),
//        textColor: .primary,
//        deleteIconColor: .gray,
//        cornerRadius: 8
//    )
//}
//
//// MARK: Tag View
//
//struct TagView: View {
//    let tag: String
//    let onDelete: () -> Void
//    var style: TagStyle = .standard
//    
//    var body: some View {
//        HStack(spacing: 4) {
//            Text(tag)
//                .font(style.fontSize)
//                .foregroundColor(style.textColor)
//                .padding(.horizontal, style.horizontalPadding)
//                .padding(.vertical, style.verticalPadding)
//            
//            Button(action: onDelete) {
//                Image(systemName: "xmark.circle.fill")
//                    .font(style.fontSize)
//                    .foregroundColor(style.deleteIconColor)
//            }
//            .buttonStyle(PlainButtonStyle())
//        }
//        .background(style.backgroundColor)
//        .cornerRadius(style.cornerRadius)
//    }
//}
//
//// MARK: Tagging View
//
//struct TaggingView: View {
//    @Binding var tags: [String]
//    @State private var newTag: String = ""
//    var tagStyle: TagStyle = .standard
//    var addButtonLabel: String = "Add"
//    var placeholderText: String = "Add a tag"
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 8) {
//            HStack {
//                TextField(placeholderText, text: $newTag, onCommit: addTag)
//                    .textFieldStyle(RoundedBorderTextFieldStyle())
//                
//                Button(addButtonLabel) {
//                    addTag()
//                }
//                .buttonStyle(.bordered)
//            }
//            
//            if !tags.isEmpty {
//                ScrollView(.horizontal, showsIndicators: false) {
//                    HStack(spacing: 8) {
//                        ForEach(tags, id: \.self) { tag in
//                            TagView(
//                                tag: tag,
//                                onDelete: { removeTag(tag) },
//                                style: tagStyle
//                            )
//                        }
//                    }
//                    .padding(.vertical, 4)
//                }
//            }
//        }
//    }
//    
//    private func addTag() {
//        let trimmedTag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
//        if !trimmedTag.isEmpty && !tags.contains(trimmedTag) {
//            tags.append(trimmedTag)
//            newTag = ""
//        }
//    }
//    
//    private func removeTag(_ tag: String) {
//        tags.removeAll { $0 == tag }
//    }
//}
//
//// MARK: Button Styles
//
//struct PrimaryButtonStyle: ButtonStyle {
//    var backgroundColor: Color = .blue
//    var foregroundColor: Color = .white
//    var minWidth: CGFloat? = 100
//    var fontWeight: Font.Weight = .bold
//    
//    func makeBody(configuration: Configuration) -> some View {
//        configuration.label
//            .fontWeight(fontWeight)
//            .padding()
//            .frame(minWidth: minWidth)
//            .background(backgroundColor)
//            .foregroundColor(foregroundColor)
//            .cornerRadius(8)
//            .opacity(configuration.isPressed ? 0.8 : 1.0)
//            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
//    }
//}
//
//// MARK: Timestamp Components
//
//struct TimestampItemView: View {
//    let word: String
//    let startTime: String
//    let endTime: String
//    
//    var body: some View {
//        HStack {
//            Text(word)
//                .font(.system(.body, design: .monospaced))
//            
//            Spacer()
//            
//            Text("Start: \(startTime)")
//                .font(.caption)
//                .foregroundColor(.secondary)
//            
//            Text("End: \(endTime)")
//                .font(.caption)
//                .foregroundColor(.secondary)
//        }
//        .padding(.vertical, 2)
//        .padding(.horizontal, 8)
//        .background(Color.gray.opacity(0.1))
//        .cornerRadius(4)
//    }
//}
//
//struct TimestampListView: View {
//    let wordTimestamps: [WordTimestamp]
//    
//    var body: some View {
//        ScrollView {
//            LazyVStack(alignment: .leading, spacing: 4) {
//                ForEach(wordTimestamps) { timestamp in
//                    TimestampItemView(
//                        word: timestamp.word,
//                        startTime: timestamp.formattedStartTime,
//                        endTime: timestamp.formattedEndTime
//                    )
//                }
//            }
//            .padding(8)
//        }
//        .frame(height: 200)
//        .background(
//            RoundedRectangle(cornerRadius: 8)
//                .fill(Color.gray.opacity(0.05))
//        )
//        .padding(.horizontal)
//    }
//}
//
//// MARK: Section Header
//
//struct SectionHeaderView: View {
//    let title: String
//    @Binding var isExpanded: Bool
//    
//    var body: some View {
//        HStack {
//            Text(title)
//                .font(.headline)
//            
//            Spacer()
//            
//            Toggle("Show", isOn: $isExpanded)
//                .toggleStyle(.switch)
//                .labelsHidden()
//        }
//        .padding(.horizontal)
//    }
//}
//
//// MARK: - TranscriptionDetailView
//
//struct TranscriptionDetailView: View {
//    @Binding var transcription: Transcription
//    var onSave: (Transcription) -> Void
//    
//    @State private var editedTitle: String = ""
//    @State private var showTimestamps: Bool = false
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 16) {
//            // Title field
//            TextField("Title", text: $transcription.title)
//                .textFieldStyle(RoundedBorderTextFieldStyle())
//                .padding([.leading, .trailing, .top])
//
//            // Content editor
//            TextEditor(text: $transcription.content)
//                .border(Color.gray, width: 1)
//                .frame(minHeight: 200)
//                .padding([.leading, .trailing])
//            
//            // Word timestamps section
//            if !transcription.wordTimestamps.isEmpty {
//                VStack(alignment: .leading, spacing: 8) {
//                    SectionHeaderView(
//                        title: "Word Timestamps",
//                        isExpanded: $showTimestamps
//                    )
//                    
//                    if showTimestamps {
//                        TimestampListView(wordTimestamps: transcription.wordTimestamps)
//                    }
//                }
//            }
//            
//            // Tags section
//            TaggingView(tags: $transcription.tags)
//                .padding([.leading, .trailing])
//            
//            Spacer()
//            
//            // Save button
//            HStack {
//                Spacer()
//                Button("Save") {
//                    onSave(transcription)
//                }
//                .buttonStyle(PrimaryButtonStyle())
//            }
//            .padding()
//        }
//        .padding()
//        .frame(minWidth: 400, minHeight: 300)
//        .onAppear {
//            editedTitle = transcription.title
//        }
//    }
//}
//
//// MARK: - Previews
//
//struct PreviewHelper {
//    static var sampleTranscription: Transcription {
//        Transcription(
//            id: UUID().uuidString,
//            title: "Sample Transcription",
//            content: "This is a sample transcription with some content.",
//            tags: ["Sample", "Preview"],
//            wordTimestamps: [
//                WordTimestamp(id: "1", word: "Sample", startTime: 0, endTime: 0.5),
//                WordTimestamp(id: "2", word: "Transcription", startTime: 0.6, endTime: 1.2)
//            ]
//        )
//    }
//}
//
//#Preview("Transcription Detail") {
//    struct PreviewWrapper: View {
//        @State var transcription = PreviewHelper.sampleTranscription
//        
//        var body: some View {
//            TranscriptionDetailView(
//                transcription: $transcription,
//                onSave: { _ in }
//            )
//        }
//    }
//    
//    return PreviewWrapper()
//}
//
//#Preview("UI Components") {
//    VStack(spacing: 20) {
//        Button("Primary Button") {}
//            .buttonStyle(PrimaryButtonStyle())
//        
//        TimestampItemView(
//            word: "Example",
//            startTime: "00:01:23",
//            endTime: "00:01:25"
//        )
//        
//        SectionHeaderView(title: "Section Title", isExpanded: .constant(true))
//    }
//    .padding()
//} 
