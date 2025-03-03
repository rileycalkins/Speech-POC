import SwiftUI

struct SaveButton: View {
    var action: () -> Void
    var title: String = "Save Transcription"
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "square.and.arrow.down")
                Text(title)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .buttonStyle(.borderedProminent)
    }
}

struct SaveButton_Previews: PreviewProvider {
    static var previews: some View {
        SaveButton(action: {})
    }
} 