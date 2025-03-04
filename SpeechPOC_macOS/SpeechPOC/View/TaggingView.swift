//
//  TaggingView.swift
//  SpeechPOC
//
//  Created by Alex Lifa on 9/27/24.
//

import SwiftUI

// Import GradientConfiguration - adjust for your project configuration
// You may need to fix these imports in Xcode: make sure all files are
// included in the correct target and build phases

struct TaggingView: View {
    @Binding var tags: [String]
    var gradientConfig: GradientConfiguration
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
                    TagView(tag: tag, gradientConfig: gradientConfig) {
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

struct TagView: View {
    let tag: String
    let gradientConfig: GradientConfiguration
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
            LinearGradient(
                gradient: Gradient(colors: [gradientConfig.startColor, gradientConfig.endColor]),
                startPoint: gradientConfig.direction == .horizontal ? .leading : (gradientConfig.direction == .vertical ? .top : .topLeading),
                endPoint: gradientConfig.direction == .horizontal ? .trailing : (gradientConfig.direction == .vertical ? .bottom : .bottomTrailing)
            )
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
