import AppKit
import Combine

@MainActor
final class TranslatorModel: ObservableObject {
    static let shared = TranslatorModel()

    private let settings = AppSettings.shared

    @Published var inputText: String = "" { didSet { inputChanged() } }
    @Published private(set) var outputText: String = ""
    @Published private(set) var tokens: [WordToken] = []
    @Published private(set) var detectedCode: String?
    @Published private(set) var isTranslating = false
    @Published var errorMessage: String?

    @Published private(set) var sentenceAlternatives: [String] = []
    @Published private(set) var sentenceAlternativesLoading = false

    @Published private(set) var activeTokenID: Int?
    @Published private(set) var activeWord: String = ""
    @Published private(set) var continuations: [String] = []
    @Published private(set) var continuationsLoading = false
    @Published private(set) var continuationsError: String?

    @Published private(set) var needsPermission = false
    // another app may already own the chosen shortcut
    @Published var shortcutUnavailable = false

    private var translateTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?
    private var sentenceTask: Task<Void, Never>?
    private var continuationTask: Task<Void, Never>?

    // reject responses started before the inputs changed
    private var translationGeneration = 0
    private var continuationGeneration = 0

    private var activeSpan: Range<String.Index>?
    private var rawOutput = ""
    private var sourceSnapshot = ""
    // keep alternatives tied to the source language of this translation
    private var sourceLanguageSnapshot = Languages.autoCode
    // typing must not realign the language pair
    private var previousInput = ""
    // shortcut text arrives as a complete selection
    private var arrivedWhole = false

    private init() {}

    var sourceLabel: String {
        if settings.sourceLanguage == Languages.autoCode {
            guard let detected = detectedCode else { return "Detect language" }
            return "\(Languages.label(detected)) (detected)"
        }
        return Languages.label(settings.sourceLanguage)
    }

    private var sourceForPrompt: String {
        settings.sourceLanguage == Languages.autoCode
            ? (detectedCode ?? Languages.autoCode)
            : settings.sourceLanguage
    }

    func swapLanguages() {
        // avoid translating an unfinished result back into the source language
        guard !isTranslating else { return }
        let resolvedSource = sourceForPrompt
        let newSource = settings.targetLanguage
        settings.targetLanguage = resolvedSource == Languages.autoCode ? "en" : resolvedSource
        settings.sourceLanguage = newSource

        let carried = outputText
        if !carried.isEmpty { inputText = carried }
        translateNow()
    }

    var canCopy: Bool { !outputText.isEmpty && !isTranslating }

    private func inputChanged() {
        let reading = LanguageDetector.reading(inputText)
        detectedCode = reading?.code

        // realign on whole selections or pastes, never ordinary typing
        let previous = previousInput
        previousInput = inputText
        if LanguagePairResolver.shouldRealign(text: inputText, previous: previous,
                                              arrivedWhole: arrivedWhole, detected: reading) {
            realignPairIfTranslatingIntoItself(reading?.code)
        }
        arrivedWhole = false
        dismissContinuations()
        clearSentenceAlternatives()

        // invalidate pending requests even when automatic translation is off
        debounceTask?.cancel()
        translateTask?.cancel()
        translationGeneration &+= 1
        // clear errors belonging to superseded input
        errorMessage = nil

        if isTranslating {
            // discard partial output when its input changes
            isTranslating = false
            outputText = ""
            rawOutput = ""
            tokens = []
        }

        guard settings.translateOnType else { return }
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Constants.autoTranslateDebounce * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.translateNow()
        }
    }

    // avoid requesting a translation into the detected source language
    private func realignPairIfTranslatingIntoItself(_ detected: String?) {
        guard let detected,
              let pair = LanguagePairResolver.realigned(
                detected: detected,
                source: settings.sourceLanguage,
                target: settings.targetLanguage,
                preferred: settings.favoriteLanguages)
        else { return }

        DiagnosticsLog.shared.record(
            .request,
            "Text looks like \(Languages.label(detected)) — switched to "
            + "\(Languages.label(pair.source)) → \(Languages.label(pair.target))")

        settings.sourceLanguage = pair.source
        settings.targetLanguage = pair.target
    }

    func retranslate() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        translateNow()
    }

    func translateNow() {
        debounceTask?.cancel()
        translateTask?.cancel()
        dismissContinuations()
        clearSentenceAlternatives()

        translationGeneration &+= 1
        let generation = translationGeneration

        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            outputText = ""
            rawOutput = ""
            tokens = []
            errorMessage = nil
            isTranslating = false
            return
        }

        let client: LLMClient
        do {
            client = try makeClient()
        } catch {
            // the cancelled request cannot clear this flag after its generation changes
            isTranslating = false
            errorMessage = error.localizedDescription
            return
        }

        errorMessage = nil
        isTranslating = true
        outputText = ""
        rawOutput = ""
        tokens = []

        let service = TranslationService(client: client,
                                         promptTemplate: settings.translationPrompt,
                                         style: settings.style)
        let source = sourceForPrompt
        let target = settings.targetLanguage
        sourceSnapshot = text
        sourceLanguageSnapshot = source

        DiagnosticsLog.shared.record(
            .request,
            "Translate \(Languages.label(source)) → \(Languages.label(target)) · "
            + "\(settings.provider.title) · \(settings.activeModel) · \(settings.style.title) · "
            + "\(text.count) chars")

        translateTask = Task { [weak self] in
            do {
                var extractor = StreamingExtractor()
                var lastPublished = Date.distantPast

                for try await chunk in service.translate(text, from: source, to: target) {
                    guard let self, self.translationGeneration == generation else { return }
                    extractor.append(chunk)
                    // coalesce output updates to avoid repainting for every token
                    let now = Date()
                    if now.timeIntervalSince(lastPublished) >= Constants.streamPublishInterval {
                        lastPublished = now
                        self.outputText = extractor.visible(finished: false)
                    }
                }
                guard let self, self.translationGeneration == generation else { return }

                self.rawOutput = extractor.raw
                self.outputText = extractor.visible(finished: true)

                // treat empty streams as failures before requesting alternatives
                guard !self.outputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    self.isTranslating = false
                    self.errorMessage = "The model returned no translation. Try again."
                    DiagnosticsLog.shared.record(
                        .failure, "Empty translation stream", detail: extractor.raw)
                    return
                }

                self.tokens = TextTokenizer.tokens(in: self.outputText)
                self.isTranslating = false

                let stripped = self.rawOutput.count - self.outputText.count
                DiagnosticsLog.shared.record(
                    .response,
                    stripped > 0
                        ? "Translation returned; \(stripped) characters outside the markers discarded"
                        : "Translation returned",
                    detail: self.rawOutput)

                self.requestSentenceAlternatives(generation: generation, service: service,
                                                 source: text, sourceLanguage: source,
                                                 target: target)
            } catch is CancellationError {
                return
            } catch {
                guard let self, self.translationGeneration == generation else { return }
                self.errorMessage = error.localizedDescription
                self.isTranslating = false
                DiagnosticsLog.shared.record(.failure, "Translation failed: \(error.localizedDescription)")
            }
        }
    }

    func retryTranslation() { translateNow() }

    private func clearSentenceAlternatives() {
        sentenceTask?.cancel()
        sentenceTask = nil
        sentenceAlternatives = []
        sentenceAlternativesLoading = false
    }

    private func requestSentenceAlternatives(
        generation: Int, service: TranslationService,
        source: String, sourceLanguage: String, target: String
    ) {
        let count = AlternativesEligibility.requestedCount(for: source)
        guard count > 0 else { return }

        let translation = outputText
        guard !translation.isEmpty else { return }

        sentenceAlternativesLoading = true

        sentenceTask = Task { [weak self] in
            do {
                let result = try await service.sentenceAlternatives(
                    source: source, sourceLanguage: sourceLanguage,
                    translation: translation, targetLanguage: target, count: count)

                guard let self, self.translationGeneration == generation else { return }

                let primary = translation.trimmingCharacters(in: .whitespacesAndNewlines)
                self.sentenceAlternatives = Array(
                    result.alternatives
                        .filter { $0.trimmingCharacters(in: .whitespacesAndNewlines) != primary }
                        .prefix(count))
                self.sentenceAlternativesLoading = false

                DiagnosticsLog.shared.record(
                    .response,
                    "\(self.sentenceAlternatives.count) sentence alternatives (asked for \(count))",
                    detail: result.raw)
            } catch is CancellationError {
                return
            } catch {
                guard let self, self.translationGeneration == generation else { return }
                self.sentenceAlternatives = []
                self.sentenceAlternativesLoading = false
                DiagnosticsLog.shared.record(
                    .failure, "Sentence alternatives failed: \(error.localizedDescription)")
            }
        }
    }

    func apply(sentenceAlternative text: String) {
        guard !text.isEmpty else { return }
        dismissContinuations()
        outputText = text
        tokens = TextTokenizer.tokens(in: text)
        sentenceAlternatives = []
    }

    func selectToken(_ token: WordToken) {
        guard !isTranslating, !outputText.isEmpty else { return }
        if activeTokenID == token.id {
            dismissContinuations()
            return
        }

        let span = TextTokenizer.replacementSpan(from: token.wordStart, in: outputText)
        guard !span.isEmpty else { return }
        let fragment = String(outputText[span])

        continuationTask?.cancel()
        continuationGeneration &+= 1
        let generation = continuationGeneration

        activeTokenID = token.id
        activeWord = token.display.trimmingCharacters(in: .punctuationCharacters)
        activeSpan = span
        continuations = []
        continuationsError = nil
        continuationsLoading = true

        let client: LLMClient
        do {
            client = try makeClient()
        } catch {
            continuationsError = error.localizedDescription
            continuationsLoading = false
            return
        }

        let service = TranslationService(client: client,
                                         promptTemplate: settings.translationPrompt,
                                         style: settings.style)
        let source = sourceSnapshot.isEmpty ? inputText : sourceSnapshot
        let translation = outputText
        let sourceLanguage = sourceLanguageSnapshot
        let target = settings.targetLanguage
        let count = settings.alternativesCount

        DiagnosticsLog.shared.record(.request, "Continuations requested (\(fragment.count) chars)")

        continuationTask = Task { [weak self] in
            do {
                let (results, raw) = try await service.alternativesWithRaw(
                    for: fragment, source: source, sourceLanguage: sourceLanguage,
                    translation: translation, targetLanguage: target, count: count)

                guard let self, self.continuationGeneration == generation else { return }
                self.continuations = Array(results.prefix(count))
                self.continuationsLoading = false

                DiagnosticsLog.shared.record(
                    self.continuations.isEmpty ? .failure : .response,
                    self.continuations.isEmpty
                        ? "No usable continuations in the reply — no JSON array found"
                        : "\(self.continuations.count) continuations parsed",
                    detail: raw)

                if self.continuations.isEmpty {
                    self.continuationsError = "No alternatives came back."
                }
            } catch is CancellationError {
                return
            } catch {
                guard let self, self.continuationGeneration == generation else { return }
                self.continuationsError = error.localizedDescription
                self.continuationsLoading = false
                DiagnosticsLog.shared.record(
                    .failure, "Continuations failed: \(error.localizedDescription)")
            }
        }
    }

    func apply(continuation text: String) {
        guard let span = activeSpan,
              span.lowerBound >= outputText.startIndex,
              span.upperBound <= outputText.endIndex
        else {
            dismissContinuations()
            return
        }
        outputText.replaceSubrange(span, with: text)
        tokens = TextTokenizer.tokens(in: outputText)
        dismissContinuations()
    }

    func dismissContinuations() {
        continuationTask?.cancel()
        continuationTask = nil
        continuationGeneration &+= 1
        activeTokenID = nil
        activeWord = ""
        activeSpan = nil
        continuations = []
        continuationsError = nil
        continuationsLoading = false
    }

    func receive(_ text: String) {
        // a complete shortcut selection may realign without increasing input length
        arrivedWhole = true
        inputText = text
        translateNow()
    }

    func clearInput() {
        translateTask?.cancel()
        debounceTask?.cancel()
        translationGeneration &+= 1
        isTranslating = false
        inputText = ""
        outputText = ""
        rawOutput = ""
        tokens = []
        errorMessage = nil
        clearSentenceAlternatives()
        dismissContinuations()
    }

    func copyOutput() {
        guard !outputText.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(outputText, forType: .string)
    }

    func refreshPermissionState() {
        let spec = settings.shortcut
        needsPermission = spec.needsKeystrokePermission && !KeystrokePermission.isGranted
    }

    private func makeClient() throws -> LLMClient {
        let key = settings.secret(for: settings.provider)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw LLMError.missingKey(settings.provider) }
        let model = settings.activeModel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.isEmpty else { throw LLMError.missingModel(settings.provider) }

        return LLMClientFactory.make(provider: settings.provider, key: key, model: model)
    }
}
