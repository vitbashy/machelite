import Foundation

class TranslationService {
    private let apiKey: String
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func translate(_ text: String, completion: @escaping (Result<String, Error>) -> Void) {
        print("Starting translation for text: \(text)")
        
        guard let url = URL(string: Constants.deeplBaseURL) else {
            completion(.failure(TranslationError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("DeepL-Auth-Key \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let parameters = "text=\(text)&target_lang=UK"
        request.httpBody = parameters.data(using: .utf8)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Network error: \(error)")
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(TranslationError.noData))
                return
            }
            
            do {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Response data: \(responseString)")
                }
                
                let response = try JSONDecoder().decode(TranslationResponse.self, from: data)
                if let translation = response.translations.first {
                    completion(.success(translation.text))
                } else {
                    completion(.failure(TranslationError.noTranslation))
                }
            } catch {
                print("Decoding error: \(error)")
                completion(.failure(error))
            }
        }
        task.resume()
    }
}

enum TranslationError: Error {
    case invalidURL
    case noData
    case noTranslation
    case apiError(String)
}
