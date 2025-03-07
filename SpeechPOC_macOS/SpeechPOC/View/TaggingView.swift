//
//  TaggingView.swift
//  SpeechPOC
//
//  Created by Alex Lifa on 9/27/24.
//

import SwiftUI

struct TaggingView: View {
    @Binding var tags: [String]
    @State private var newTag: String = ""
    var tagStyle: TagStyle = .standard
    var addButtonLabel: String = "Add"
    var placeholderText: String = "Add a tag"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField(placeholderText, text: $newTag, onCommit: addTag)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button(addButtonLabel) {
                    addTag()
                }
                .buttonStyle(.bordered)
            }
            
            if !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tags, id: \.self) { tag in
                            TagView(
                                tag: tag,
                                onDelete: { removeTag(tag) },
                                style: tagStyle
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    private func addTag() {
        let trimmedTag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTag.isEmpty && !tags.contains(trimmedTag) {
            tags.append(trimmedTag)
            newTag = ""
        }
    }
    
    private func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State var tags = ["SwiftUI", "iOS", "macOS"]
        
        var body: some View {
            VStack(spacing: 20) {
                TaggingView(tags: $tags)
                    .padding()
                    .border(Color.gray.opacity(0.2))
                
                TaggingView(
                    tags: $tags,
                    tagStyle: .subtle,
                    addButtonLabel: "Create",
                    placeholderText: "New tag name"
                )
                .padding()
                .border(Color.gray.opacity(0.2))
            }
            .padding()
        }
    }
    
    return PreviewWrapper()
}
