import SwiftUI

struct TranslationView: View {
    @Binding var originalText: String
    @Binding var translatedText: String
    
    var body: some View {
        HStack(spacing: 20) {
            // Original text panel
            VStack(alignment: .leading) {
                Text("English")
                    .font(.headline)
                TextEditor(text: .constant(originalText))
                    .frame(width: 250, height: 150)
                    .border(Color.gray.opacity(0.2))
            }
            
            // Translated text panel
            VStack(alignment: .leading) {
                Text("Українська")
                    .font(.headline)
                TextEditor(text: .constant(translatedText))
                    .frame(width: 250, height: 150)
                    .border(Color.gray.opacity(0.2))
            }
        }
        .padding(20)
    }
}
