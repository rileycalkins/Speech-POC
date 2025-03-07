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
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                TextField("Add a tag", text: $newTag, onCommit: addTag)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("Add") {
                    addTag()
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(tags, id: \.self) { tag in
                        HStack {
                            Text(tag)
                            Button(action: { removeTag(tag) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(8)
                        .background(.secondary)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.6), lineWidth: 1)
                                .blendMode(.overlay)
                        )
                        .shadow(color: Color.black.opacity(0.2), radius: 3, x: 2, y: 2)
                    }
                }
            }
        }
        .padding()
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
