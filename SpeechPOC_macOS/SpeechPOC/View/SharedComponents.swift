//
//  SharedComponents.swift
//  SpeechPOC
//
//  Created by Generated on 3/6/25.
//

import SwiftUI

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    var backgroundColor: Color = .blue
    var foregroundColor: Color = .white
    var minWidth: CGFloat? = 100
    var fontWeight: Font.Weight = .bold
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(fontWeight)
            .padding()
            .frame(minWidth: minWidth)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(8)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

// MARK: - Timestamp Components

struct TimestampItemView: View {
    let word: String
    let startTime: String
    let endTime: String
    
    var body: some View {
        HStack {
            Text(word)
                .font(.system(.body, design: .monospaced))
            
            Spacer()
            
            Text("Start: \(startTime)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("End: \(endTime)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(4)
    }
}

struct TimestampListView: View {
    let wordTimestamps: [WordTimestamp]
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(wordTimestamps) { timestamp in
                    TimestampItemView(
                        word: timestamp.word,
                        startTime: timestamp.formattedStartTime,
                        endTime: timestamp.formattedEndTime
                    )
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

// MARK: - Section Header

struct SectionHeaderView: View {
    let title: String
    @Binding var isExpanded: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
            
            Spacer()
            
            Toggle("Show", isOn: $isExpanded)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .padding(.horizontal)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        Button("Primary Button") {}
            .buttonStyle(PrimaryButtonStyle())
        
        TimestampItemView(
            word: "Example",
            startTime: "00:01:23",
            endTime: "00:01:25"
        )
        
        SectionHeaderView(title: "Section Title", isExpanded: .constant(true))
    }
    .padding()
} 