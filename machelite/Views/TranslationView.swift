import SwiftUI

struct TranslationView: View {
    @Binding var originalText: String
    @Binding var translatedText: String
    
    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading) {
                Text("English")
                    .font(.headline)
                Text(originalText)
                    .frame(width: 250, height: 150, alignment: .topLeading)
                    .border(Color.gray.opacity(0.2))
            }
            
            VStack(alignment: .leading) {
                Text("Українська")
                    .font(.headline)
                Text(translatedText)
                    .frame(width: 250, height: 150, alignment: .topLeading)
                    .border(Color.gray.opacity(0.2))
            }
        }
        .padding(20)
    }
}
