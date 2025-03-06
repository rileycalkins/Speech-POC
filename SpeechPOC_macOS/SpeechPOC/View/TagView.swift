//
//  TagView.swift
//  SpeechPOC_macOS
//
//  Created by Riley Calkins on 3/6/25.
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
