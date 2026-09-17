import SwiftUI
import Foundation

struct ContentView: View {
    @StateObject private var library = LibraryViewModel()

    var body: some View {
        TabView {
            HomeView(library: library)
                .tabItem { Label("Início", systemImage: "house.fill") }
            LibraryView(library: library)
                .tabItem { Label("Biblioteca", systemImage: "books.vertical.fill") }
            UniverseView()
                .tabItem { Label("Universo", systemImage: "person.3.fill") }
            MyLibraryView(library: library)
                .tabItem { Label("Minha Biblioteca", systemImage: "bookmark.fill") }
        }
        .tint(Color(red: 0.45, green: 0.20, blue: 0.12))
    }
}

private struct HomeView: View {
    @ObservedObject var library: LibraryViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Biblioteca Machado de Assis").font(.largeTitle.bold())
                    Text("Leia offline. Descubra um clássico por vez.")
                        .foregroundStyle(.secondary)
                    if let error = library.loadError {
                        ResourceErrorView(message: error)
                    } else if let work = library.works.first {
                        NavigationLink(value: work) { FeaturedWorkCard(work: work) }
                            .buttonStyle(.plain)
                    }
                    Text("Continue lendo").font(.title2.bold())
                    ForEach(library.works.prefix(3)) { work in
                        NavigationLink(value: work) { WorkRow(work: work) }
                            .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Início")
            .navigationDestination(for: WorkSummary.self) { work in ReaderView(work: work) }
        }
    }
}

private struct LibraryView: View {
    @ObservedObject var library: LibraryViewModel
    @State private var query = ""

    private var filteredWorks: [WorkSummary] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return library.works }
        return library.works.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            List(filteredWorks) { work in
                NavigationLink(value: work) { WorkRow(work: work) }
            }
            .searchable(text: $query, prompt: "Buscar obra")
            .navigationTitle("Biblioteca")
            .navigationDestination(for: WorkSummary.self) { work in ReaderView(work: work) }
            .overlay { if let error = library.loadError { ResourceErrorView(message: error) } }
        }
    }
}

private struct UniverseView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Image(systemName: "person.3.fill").font(.largeTitle)
                Text("Universo Machado").font(.title2.bold())
                Text("Personagens e linha do tempo serão carregados do catálogo compartilhado.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("Universo")
        }
    }
}

private struct MyLibraryView: View {
    @ObservedObject var library: LibraryViewModel

    var body: some View {
        NavigationStack {
            List {
                Section("Leitura") {
                    Label("Obras iniciadas: \(library.progress.count)", systemImage: "book")
                    Label("Tempo de leitura: \(library.readingMinutes) min", systemImage: "clock")
                }
                Section("Privacidade") {
                    Text("Seu progresso fica somente neste aparelho.").foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Minha Biblioteca")
        }
    }
}

private struct FeaturedWorkCard: View {
    let work: WorkSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
                    Text(work.title).font(.title.bold())
                    Text(work.description).lineLimit(3).foregroundStyle(.secondary)
                    Text("\(work.chapters) capítulos · \(work.words.formatted()) palavras")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
            Label("Ler offline", systemImage: "arrow.down.circle").font(.subheadline.weight(.semibold))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.brown.opacity(0.12), in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct WorkRow: View {
    let work: WorkSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(work.title).font(.headline)
            Text(work.category.capitalized).font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct ReaderView: View {
    let work: WorkSummary
    @StateObject private var speech = SpeechReader()
    @State private var document: WorkDocument?
    @State private var chapterIndex = 0
    @State private var loadError: String?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    readingContent
                    narrationControls
                    narrationProgress
                }
                .padding()
            }
            .onChange(of: speech.currentParagraphIndex) { _, index in
                guard index >= 0 else { return }
                withAnimation { proxy.scrollTo(index, anchor: .center) }
            }
        }
        .navigationTitle(work.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { loadDocument(for: work.id) }
    }

    @ViewBuilder
    private var readingContent: some View {
        Text(work.title).font(.largeTitle.bold())
        Text(work.description).foregroundStyle(.secondary)
        Text("\(work.chapters) capítulos · \(work.words.formatted()) palavras")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        Text("Fonte: Wikisource PT")
            .font(.footnote)
            .foregroundStyle(.secondary)
        if let loadError {
            ResourceErrorView(message: loadError)
        } else if let document {
            let chapter = document.chapters[chapterIndex]
            Text(chapter.title).font(.title2.bold())
            ForEach(Array(chapter.paragraphs.enumerated()), id: \.offset) { index, paragraph in
                Text(paragraph)
                    .font(.body)
                    .textSelection(.enabled)
                    .padding(8)
                    .background(speech.currentParagraphIndex == index ? Color.accentColor.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 8))
                    .id(index)
            }
            HStack {
                Button("Anterior") { moveChapter(-1) }.disabled(chapterIndex == 0)
                Spacer()
                Text("Capítulo \(chapterIndex + 1) de \(document.chapters.count)").font(.footnote)
                Spacer()
                Button("Próximo") { moveChapter(1) }.disabled(chapterIndex == document.chapters.count - 1)
            }
            .buttonStyle(.bordered)
        } else {
            ProgressView("Carregando capítulo offline…")
        }
    }

    private var narrationControls: some View {
        HStack(spacing: 12) {
            Button {
                if speech.isSpeaking { speech.pause() }
                else if speech.isPaused { speech.resume() }
                else { speech.speak(currentParagraphs) }
            } label: {
                Label(speech.isSpeaking ? "Pausar" : speech.isPaused ? "Continuar" : "Ouvir", systemImage: speech.isSpeaking ? "pause.fill" : "play.fill")
            }
            .buttonStyle(.borderedProminent)
            Button { speech.stop() } label: { Image(systemName: "stop.fill") }.buttonStyle(.bordered)
            Button { speech.previous() } label: { Image(systemName: "backward.fill") }.buttonStyle(.bordered)
            Button { speech.next() } label: { Image(systemName: "forward.fill") }.buttonStyle(.bordered)
            Menu {
                Section("Voz local") {
                    if speech.voices.isEmpty {
                        Text("Nenhuma voz pt-BR alternativa instalada")
                    } else {
                        ForEach(speech.voices, id: \.identifier) { voice in
                            Button(voice.name) { speech.chooseVoice(voice) }
                        }
                    }
                }
                Section("Velocidade") {
                    ForEach([0.42, 0.5, 0.58, 0.68], id: \.self) { value in
                        Button("\(String(format: "%.1f", value / 0.5))x") { speech.rate = value }
                    }
                }
            } label: { Image(systemName: "slider.horizontal.3") }
                .buttonStyle(.bordered)
        }
        .disabled(document == nil || loadError != nil)
    }

    @ViewBuilder
    private var narrationProgress: some View {
        if speech.totalParagraphs > 0 {
            ProgressView(value: Double(max(speech.currentParagraphIndex + 1, 0)), total: Double(speech.totalParagraphs))
            Text(speech.isSpeaking || speech.isPaused ? "Parágrafo \(max(speech.currentParagraphIndex + 1, 1)) de \(speech.totalParagraphs)" : "Narração finalizada")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var currentParagraphs: [String] {
        document?.chapters[safe: chapterIndex]?.paragraphs ?? []
    }

    private func loadDocument(for id: String) {
        do {
            let data = try BundleResource.data(named: id, fileExtension: "json", subdirectory: "Texts")
            let loaded = try JSONDecoder().decode(WorkDocument.self, from: data)
            guard !loaded.chapters.isEmpty else { throw BundleResourceError.invalid("O texto de \(work.title) não contém capítulos") }
            document = loaded
        } catch { loadError = error.localizedDescription }
    }

    private func moveChapter(_ offset: Int) {
        guard let document else { return }
        let next = chapterIndex + offset
        guard document.chapters.indices.contains(next) else { return }
        speech.stop()
        chapterIndex = next
    }
}

private struct ResourceErrorView: View {
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Label("Não foi possível carregar a biblioteca", systemImage: "exclamationmark.triangle")
                .font(.headline)
            Text(message).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding()
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? { indices.contains(index) ? self[index] : nil }
}

private struct WorkDocument: Decodable {
    let chapters: [DocumentChapter]
}

private struct DocumentChapter: Decodable {
    let title: String
    let paragraphs: [String]
}
