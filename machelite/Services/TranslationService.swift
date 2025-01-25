import Foundation

class TranslationService {
    private let apiKey: String
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    // In TranslationService.swift
    func translate(_ text: String, completion: @escaping (Result<String, Error>) -> Void) {
        print("Starting translation for text: \(text)")
        
        let config = URLSessionConfiguration.default
        config.allowsCellularAccess = true
        config.allowsExpensiveNetworkAccess = true
        config.allowsConstrainedNetworkAccess = true
        let session = URLSession(configuration: config)
        
        guard var urlComponents = URLComponents(string: Constants.deeplBaseURL) else {
            completion(.failure(TranslationError.invalidURL))
            return
        }
        
        let parameters = [
            URLQueryItem(name: "text", value: text),
            URLQueryItem(name: "target_lang", value: "UK")
        ]
        urlComponents.queryItems = parameters
        
        guard let url = urlComponents.url else {
            completion(.failure(TranslationError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("DeepL-Auth-Key \(apiKey)", forHTTPHeaderField: "Authorization")
        
        print("Making request to: \(url)")
        
        let task = session.dataTask(with: request) { data, response, error in
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
                let response = try JSONDecoder().decode(TranslationResponse.self, from: data)
                if let translation = response.translations.first {
                    completion(.success(translation.text))
                } else {
                    completion(.failure(TranslationError.noTranslation))
                }
            } catch {
                print("Decoding error: \(error)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Response data: \(responseString)")
                }
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
