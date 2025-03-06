//
//  TaggingView.swift
//  SpeechPOC
//
//  Created by Alex Lifa on 9/27/24.
//

import SwiftUI



struct TagView: View {
    let tag: String
    
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .background(
            Color.secondary
        )
        .cornerRadius(12)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var height: CGFloat = 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        
        height = y + rowHeight
        
        return CGSize(width: width, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
    }
}

struct TaggingView: View {
    @Binding var tags: [String]
    
    @State private var newTag: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tags").font(.headline)
            
            HStack {
                TextField("Add tag", text: $newTag)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button(action: addTag) {
                    Text("Add")
                }
                .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            
            FlowLayout(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    TagView(tag: tag) {
                        removeTag(tag)
                    }
                }
            }
        }
    }
    
    private func addTag() {
        let tag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tag.isEmpty && !tags.contains(tag) {
            tags.append(tag)
            newTag = ""
        }
    }
    
    private func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }
}

//struct TaggingView: View {
//    @Binding var tags: [String]
//    @State private var newTag: String = ""
//    
//    var gradientConfig: GradientConfig
//    
//    var body: some View {
//        VStack(alignment: .leading) {
//            HStack {
//                TextField("Add a tag", text: $newTag, onCommit: addTag)
//                    .textFieldStyle(RoundedBorderTextFieldStyle())
//                Button("Add") {
//                    addTag()
//                }
//            }
//            ScrollView(.horizontal, showsIndicators: false) {
//                HStack {
//                    ForEach(tags, id: \.self) { tag in
//                        HStack {
//                            Text(tag)
//                            Button(action: { removeTag(tag) }) {
//                                Image(systemName: "xmark.circle.fill")
//                                    .foregroundColor(.red)
//                            }
//                            .buttonStyle(PlainButtonStyle())
//                        }
//                        .padding(8)
//                        .background(gradientConfig.highLevelGradient)
//                        .cornerRadius(8)
//                        .overlay(
//                            RoundedRectangle(cornerRadius: 8)
//                                .stroke(Color.white.opacity(0.6), lineWidth: 1)
//                                .blendMode(.overlay)
//                        )
//                        .shadow(color: Color.black.opacity(0.2), radius: 3, x: 2, y: 2)
//                    }
//                }
//            }
//        }
//        .padding()
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
