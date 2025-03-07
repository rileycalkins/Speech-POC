//
//  TagView.swift
//  SpeechPOC_macOS
//
//  Created by Riley Calkins on 3/6/25.
//
import SwiftUI

struct TagStyle {
    var backgroundColor: Color = .secondary
    var textColor: Color = .white
    var deleteIconColor: Color = .white.opacity(0.7)
    var cornerRadius: CGFloat = 12
    var fontSize: Font = .caption
    var horizontalPadding: CGFloat = 8
    var verticalPadding: CGFloat = 4
    
    static let standard = TagStyle()
    static let subtle = TagStyle(
        backgroundColor: .gray.opacity(0.2),
        textColor: .primary,
        deleteIconColor: .gray,
        cornerRadius: 8
    )
}

struct TagView: View {
    let tag: String
    let onDelete: () -> Void
    var style: TagStyle = .standard
    
    var body: some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(style.fontSize)
                .foregroundColor(style.textColor)
                .padding(.horizontal, style.horizontalPadding)
                .padding(.vertical, style.verticalPadding)
            
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(style.fontSize)
                    .foregroundColor(style.deleteIconColor)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .background(style.backgroundColor)
        .cornerRadius(style.cornerRadius)
    }
}

#Preview {
    HStack {
        TagView(tag: "Standard", onDelete: {})
        TagView(tag: "Subtle", onDelete: {}, style: .subtle)
    }
    .padding()
}
