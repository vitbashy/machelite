import SwiftUI

struct LanguagePicker: View {
    @Binding var selection: String
    let isSource: Bool
    let label: String
    var detected: String?
    var width: CGFloat = 180
    var onChange: () -> Void = {}

    @EnvironmentObject private var settings: AppSettings
    @Environment(\.theme) private var theme
    @State private var isPresented = false

    var body: some View {
        PickerCapsule(label: label, isOpen: isPresented, compact: false, regularWidth: width) {
            isPresented.toggle()
        }
        .accessibilityLabel(isSource ? "Source language" : "Target language")
        .accessibilityValue(label)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            LanguagePickerPanel(selection: $selection,
                                isSource: isSource,
                                detected: detected,
                                onPick: {
                                    isPresented = false
                                    onChange()
                                })
                .environmentObject(settings)
                .environment(\.theme, theme)
        }
    }
}

struct LanguagePickerPanel: View {
    @Binding var selection: String
    let isSource: Bool
    var detected: String?
    let onPick: () -> Void

    @EnvironmentObject private var settings: AppSettings
    @Environment(\.theme) private var theme
    @FocusState private var searchFocused: Bool

    @State private var query = ""
    @State private var showingAll = false
    @State private var highlighted = 0
    @State private var contentHeight: CGFloat = 0

    private enum Row: Identifiable {
        case detect
        case language(Language)
        case other

        var id: String {
            switch self {
            case .detect: return "::detect"
            case .language(let language): return language.code
            case .other: return "::other"
            }
        }
    }

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var matches: [Language] { LanguageSearch.matches(query) }

    private var listed: [Language] {
        showingAll ? Languages.all : settings.menuLanguages(including: [selection])
    }

    private var rows: [Row] {
        if isSearching { return matches.map(Row.language) }
        var result: [Row] = []
        if isSource { result.append(.detect) }
        result += listed.map(Row.language)
        if !showingAll { result.append(.other) }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField

            if rows.isEmpty {
                noResults
            } else {
                list
            }
        }
        .frame(width: 320)
        .pickerPanel(theme)
        .onAppear {
            searchFocused = true
            highlighted = initialHighlight
        }
        .onChange(of: query) { _, _ in highlighted = 0 }
        .onKeyPress(.upArrow) { move(-1); return .handled }
        .onKeyPress(.downArrow) { move(1); return .handled }
        .onKeyPress(.return) { activateHighlighted(); return .handled }
        .accessibilityLabel(isSource ? "Choose source language" : "Choose target language")
    }

    private var initialHighlight: Int {
        rows.firstIndex { row in
            switch row {
            case .detect: return selection == Languages.autoCode
            case .language(let language): return language.code == selection
            case .other: return false
            }
        } ?? 0
    }

    private var searchField: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(theme.secondaryText)
            TextField("Search languages", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($searchFocused)
            if isSearching {
                Button {
                    query = ""
                    searchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.tertiaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(theme.primaryText.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(theme.hairline, lineWidth: 0.7))
        .padding(10)
    }

    private var noResults: some View {
        VStack(spacing: 8) {
            Text("No languages found")
                .font(.system(size: 13))
                .foregroundStyle(theme.secondaryText)
            Button("Clear search") {
                query = ""
                searchFocused = true
            }
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        if case .other = row { separator }
                        if showsPinnedHeader(before: index) { sectionHeader }
                        rowView(row, index: index).id(index)
                        if case .detect = row { separator }
                    }
                    if isSearching {
                        Text(matches.count == 1 ? "1 language" : "\(matches.count) languages")
                            .font(.system(size: 11))
                            .foregroundStyle(theme.tertiaryText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                    }
                }
                .padding(.vertical, Constants.pickerRowInset)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                    contentHeight = height
                }
            }
            .frame(height: min(max(contentHeight, 60), Constants.pickerMaxListHeight))
            .scrollIndicators(contentHeight > Constants.pickerMaxListHeight ? .automatic : .hidden)
            .onChange(of: highlighted) { _, new in
                withAnimation(.linear(duration: 0.08)) { proxy.scrollTo(new, anchor: .center) }
            }
        }
    }

    private func showsPinnedHeader(before index: Int) -> Bool {
        guard !isSearching, !showingAll else { return false }
        guard case .language = rows[index] else { return false }
        guard index > 0 else { return true }
        if case .language = rows[index - 1] { return false }
        return true
    }

    private var separator: some View {
        Rectangle()
            .fill(theme.hairline)
            .frame(height: 1)
            .padding(.horizontal, 14)
            .padding(.vertical, Constants.pickerRowInset)
    }

    private var sectionHeader: some View {
        Text("PINNED")
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(theme.tertiaryText)
            .padding(.horizontal, 14)
            .padding(.top, 6)
            .padding(.bottom, 3)
    }

    @ViewBuilder
    private func rowView(_ row: Row, index: Int) -> some View {
        switch row {
        case .detect:
            PickerRow(title: "Detect language",
                      subtitle: detected.map { "Currently \(Languages.label($0))" },
                      isSelected: selection == Languages.autoCode,
                      isHighlighted: highlighted == index,
                      trailing: nil) {
                selection = Languages.autoCode
                onPick()
            }
        case .language(let language):
            PickerRow(title: language.english,
                      subtitle: language.native == language.english ? nil : language.native,
                      isSelected: selection == language.code,
                      isHighlighted: highlighted == index,
                      trailing: nil) {
                selection = language.code
                onPick()
            }
        case .other:
            PickerRow(title: "Other language…",
                      subtitle: nil,
                      isSelected: false,
                      isHighlighted: highlighted == index,
                      trailing: "chevron.right") {
                showingAll = true
                highlighted = 0
                searchFocused = true
            }
        }
    }

    private func move(_ delta: Int) {
        guard !rows.isEmpty else { return }
        highlighted = max(0, min(rows.count - 1, highlighted + delta))
    }

    private func activateHighlighted() {
        guard rows.indices.contains(highlighted) else { return }
        switch rows[highlighted] {
        case .detect:
            selection = Languages.autoCode
            onPick()
        case .language(let language):
            selection = language.code
            onPick()
        case .other:
            showingAll = true
            highlighted = 0
        }
    }
}
