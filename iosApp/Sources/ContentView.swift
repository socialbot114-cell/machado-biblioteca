import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var library = LibraryViewModel()

    var body: some View {
        TabView {
            HomeView(library: library).tabItem { Label("Início", systemImage: "house.fill") }
            LibraryView(library: library).tabItem { Label("Biblioteca", systemImage: "books.vertical.fill") }
            UniverseView(library: library).tabItem { Label("Universo", systemImage: "person.3.fill") }
            MyLibraryView(library: library).tabItem { Label("Minha biblioteca", systemImage: "bookmark.fill") }
        }
        .tint(MachadoStyle.green)
    }
}

private enum MachadoStyle {
    static let green = Color(red: 0.09, green: 0.23, blue: 0.20)
    static let gold = Color(red: 0.70, green: 0.57, blue: 0.30)
    static let paper = Color(red: 0.94, green: 0.90, blue: 0.84)
    static let ink = Color(red: 0.23, green: 0.14, blue: 0.10)
}

private struct HomeView: View {
    @ObservedObject var library: LibraryViewModel
    @State private var showingSearch = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(spacing: 12) {
                        BundledImage(name: "logo_machado").frame(width: 48, height: 48).clipShape(RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading) {
                            Text("Machado de Assis").font(.title2.bold()).foregroundStyle(MachadoStyle.green)
                            Text("Biblioteca, voz e universo").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)

                    HeroCarousel(library: library)

                    HStack(spacing: 12) {
                        NavigationLink(destination: UniverseView(library: library)) {
                            HomeActionLabel(title: "Universo", subtitle: "Personagens e histórias", icon: "person.3.fill")
                        }.buttonStyle(.plain)
                        NavigationLink(destination: MyLibraryView(library: library)) {
                            HomeActionLabel(title: "Minha biblioteca", subtitle: "Seu percurso", icon: "bookmark.fill")
                        }.buttonStyle(.plain)
                    }

                    Button { showingSearch = true } label: {
                        Label("Buscar obra, personagem ou trecho…", systemImage: "magnifyingglass")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(15)
                            .background(MachadoStyle.paper, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)

                    let active = library.works.filter { library.workProgress($0.id) > 0 && library.workProgress($0.id) < 100 }
                    if !active.isEmpty {
                        SectionHeader(title: "Continue lendo", action: "Ver todos")
                        WorkCarousel(works: Array(active.prefix(6)), library: library)
                    }

                    SectionHeader(title: "Explore a biblioteca", action: "30 obras offline")
                    ForEach(Array(library.works.map(\.category).uniqued()), id: \.self) { category in
                        WorkSection(title: category, works: library.works.filter { $0.category == category }.prefix(6), library: library)
                    }

                    NavigationLink(destination: LibraryView(library: library)) {
                        Label("Ver toda a biblioteca", systemImage: "arrow.right")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(18)
                            .background(MachadoStyle.green, in: RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
                }
                .padding()
            }
            .navigationTitle("Início")
            .sheet(isPresented: $showingSearch) { SearchView(library: library) }
            .overlay { if let error = library.loadError { ResourceErrorView(message: error) } }
        }
    }
}

private struct HeroCarousel: View {
    @ObservedObject var library: LibraryViewModel
    private let heroes: [(String, String, String)] = [
        ("hero_dom", "Dom Casmurro", "A dúvida que nunca termina"),
        ("hero_quincas", "Quincas Borba", "A filosofia dos vencedores"),
        ("hero_bras_cubas", "Memórias Póstumas de Brás Cubas", "Memórias de além-túmulo"),
        ("hero_literatura", "", "Entre na literatura de Machado")
    ]

    var body: some View {
        TabView {
            ForEach(heroes, id: \.0) { hero in
                let work = library.works.first { $0.title == hero.1 }
                Group {
                    if let work {
                        NavigationLink(destination: WorkDetailView(work: work, library: library)) { heroCard(hero) }
                    } else { heroCard(hero) }
                }
                .buttonStyle(.plain)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .frame(height: 205)
    }

    private func heroCard(_ hero: (String, String, String)) -> some View {
        ZStack(alignment: .bottomLeading) {
            BundledImage(name: hero.0).scaledToFill()
            LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 4) {
                Text(hero.2).font(.title3.bold()).foregroundStyle(.white)
                if !hero.1.isEmpty { Text(hero.1).font(.subheadline).foregroundStyle(.white.opacity(0.85)) }
            }.padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
    }
}

private struct LibraryView: View {
    @ObservedObject var library: LibraryViewModel
    @State private var query = ""
    @State private var category = "Todos"

    private var filtered: [WorkSummary] {
        library.works.filter {
            (category == "Todos" || $0.category == category) &&
            (query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) || $0.description.localizedCaseInsensitiveContains(query) || $0.characters.joined().localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            FilterChip(title: "Todos", selected: category == "Todos") { category = "Todos" }
                            ForEach(Array(library.works.map(\.category).uniqued()), id: \.self) { item in
                                FilterChip(title: item, selected: category == item) { category = item }
                            }
                        }
                    }
                    Text("\(filtered.count) obras encontradas").font(.subheadline).foregroundStyle(.secondary)
                    ForEach(filtered) { work in
                        NavigationLink(destination: WorkDetailView(work: work, library: library)) {
                            WorkRow(work: work, progress: library.workProgress(work.id))
                        }.buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .searchable(text: $query, prompt: "Filtrar obras")
            .navigationTitle("Biblioteca")
        }
    }
}

private struct SearchView: View {
    @ObservedObject var library: LibraryViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List {
                if query.trimmingCharacters(in: .whitespacesAndNewlines).count < 3 {
                    Text("Digite ao menos 3 letras para pesquisar no texto integral.").foregroundStyle(.secondary)
                } else if library.searchResults.isEmpty {
                    Text("Nenhum trecho encontrado.").foregroundStyle(.secondary)
                } else {
                    Section("\(library.searchResults.count) ocorrências") {
                        ForEach(library.searchResults) { hit in
                            NavigationLink(destination: WorkDetailView(work: hit.work, library: library)) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(hit.work.title).font(.headline)
                                    Text(hit.chapterTitle).font(.subheadline).foregroundStyle(MachadoStyle.green)
                                    Text(hit.snippet).font(.callout).lineLimit(3)
                                }.padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Buscar palavra ou trecho")
            .onChange(of: query) { _, value in library.searchChanged(value) }
            .navigationTitle("Busca integral")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fechar") { dismiss() } } }
        }
    }
}

private struct WorkDetailView: View {
    let work: WorkSummary
    @ObservedObject var library: LibraryViewModel
    @State private var document: WorkDocument?
    @State private var showReader = false
    @State private var chapterIndex = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    CoverView(work: work).frame(width: 112, height: 162)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Machado de Assis").font(.headline).foregroundStyle(MachadoStyle.green)
                        Text("\(work.year)").font(.title3)
                        Text("\(work.category.uppercased()) • \(work.chapters) capítulos").font(.subheadline).foregroundStyle(.secondary)
                        Text("\(work.words.formatted()) palavras").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Button { showReader = true } label: {
                    Label(library.workProgress(work.id) > 0 ? "Continuar leitura" : "Começar a ler", systemImage: "book.fill")
                        .frame(maxWidth: .infinity).padding(14)
                }.buttonStyle(.borderedProminent)
                Button { library.toggleFavorite(work.id) } label: {
                    Label(library.favorites.contains(work.id) ? "Remover dos favoritos" : "Adicionar aos favoritos", systemImage: library.favorites.contains(work.id) ? "star.fill" : "star")
                        .frame(maxWidth: .infinity)
                }.buttonStyle(.bordered)

                DetailSection(title: "Sobre a obra", text: work.description)
                DetailSection(title: "Contexto", text: work.context)
                if !work.characters.isEmpty { DetailSection(title: "Personagens", text: work.characters.joined(separator: " • ")) }
                if let document {
                    Text("CAPÍTULOS • \(document.chapters.count)").sectionLabel()
                    ForEach(Array(document.chapters.enumerated()), id: \.offset) { index, chapter in
                        Button { chapterIndex = index; showReader = true } label: {
                            HStack { Text("\(index + 1).").foregroundStyle(MachadoStyle.gold); Text(chapter.title).foregroundStyle(.primary); Spacer(); Image(systemName: "chevron.right").foregroundStyle(.secondary) }
                        }.buttonStyle(.plain).padding(.vertical, 4)
                    }
                }
                DetailSection(title: "Fonte", text: "Domínio público • Transcrição Wikisource PT (CC BY-SA).")
            }.padding()
        }
        .navigationTitle(work.title).navigationBarTitleDisplayMode(.inline)
        .task { document = library.document(for: work) }
        .fullScreenCover(isPresented: $showReader) { ReaderView(work: work, library: library, initialChapter: chapterIndex) }
    }
}

private struct ReaderView: View {
    let work: WorkSummary
    @ObservedObject var library: LibraryViewModel
    let initialChapter: Int
    @Environment(\.dismiss) private var dismiss
    @StateObject private var speech = SpeechReader()
    @State private var document: WorkDocument?
    @State private var chapterIndex = 0
    @State private var pageIndex = 0

    private var chapter: DocumentChapter? { document?.chapters[safe: chapterIndex] }
    private var pages: [[String]] { chapter?.paragraphs.chunked(into: 4) ?? [] }
    private var readerBackground: Color { library.theme == .dark ? Color(red: 0.10, green: 0.09, blue: 0.08) : library.theme == .sepia ? Color(red: 0.94, green: 0.89, blue: 0.80) : Color(.systemBackground) }
    private var readerForeground: Color { library.theme == .dark ? .white.opacity(0.9) : MachadoStyle.ink }

    var body: some View {
        NavigationStack {
            ZStack {
                readerBackground.ignoresSafeArea()
                if document == nil {
                    ProgressView("Carregando texto offline…")
                } else if pages.isEmpty {
                    Text("Texto indisponível.")
                } else {
                    VStack(spacing: 0) {
                        TabView(selection: $pageIndex) {
                            ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 18) {
                                        Text(work.title).font(.title.bold()).foregroundStyle(readerForeground)
                                        Text(chapter?.title ?? "").font(.title3.bold()).foregroundStyle(MachadoStyle.green)
                                        ForEach(Array(page.enumerated()), id: \.offset) { offset, paragraph in
                                            let globalIndex = index * 4 + offset
                                            Text(paragraph)
                                                .font(.system(size: library.fontSize, design: .serif))
                                                .foregroundStyle(readerForeground)
                                                .lineSpacing(6)
                                                .textSelection(.enabled)
                                                .contextMenu {
                                                    Button { saveQuote(paragraph, index: globalIndex) } label: { Label("Salvar citação", systemImage: "quote.opening") }
                                                    Button { speech.speak([paragraph], startAt: 0) } label: { Label("Ouvir trecho", systemImage: "speaker.wave.2") }
                                                }
                                        }
                                        HStack { Button("‹ Anterior") { moveChapter(-1) }.disabled(chapterIndex == 0); Spacer(); Button("Próximo ›") { moveChapter(1) }.disabled(chapterIndex >= (document?.chapters.count ?? 1) - 1) }.buttonStyle(.bordered)
                                    }
                                    .padding(.horizontal, 20).padding(.vertical, 24)
                                }
                                .tag(index)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        ProgressView(value: Double(pageIndex + 1), total: Double(max(pages.count, 1))).tint(MachadoStyle.gold).padding(.horizontal)
                        HStack {
                            Text("Página \(pageIndex + 1) de \(pages.count)").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button { library.setFontSize(library.fontSize - 1) } label: { Text("A−") }
                            Button { library.setFontSize(library.fontSize + 1) } label: { Text("A+") }
                            Menu {
                                ForEach(ReaderTheme.allCases, id: \.self) { theme in Button(theme.rawValue) { library.setTheme(theme) } }
                            } label: { Image(systemName: "textformat") }
                            Menu {
                                Button { speech.previous() } label: { Label("Parágrafo anterior", systemImage: "backward.fill") }
                                Button { speech.isSpeaking ? speech.pause() : speech.isPaused ? speech.resume() : speech.speak(chapter?.paragraphs ?? []) } label: { Label(speech.isSpeaking ? "Pausar" : "Ouvir capítulo", systemImage: speech.isSpeaking ? "pause.fill" : "play.fill") }
                                Button { speech.next() } label: { Label("Próximo parágrafo", systemImage: "forward.fill") }
                                Button { speech.stop() } label: { Label("Parar", systemImage: "stop.fill") }
                            } label: { Image(systemName: speech.isSpeaking ? "pause.circle.fill" : "speaker.wave.2.fill") }
                        }.padding(.horizontal, 20).padding(.vertical, 10)
                    }
                    .onChange(of: pageIndex) { _, value in library.saveProgress(workID: work.id, chapter: chapterIndex, page: value, pageCount: pages.count) }
                }
            }
            .navigationTitle(work.title).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fechar") { speech.stop(); dismiss() } }; ToolbarItem(placement: .topBarTrailing) { Menu { if let document { ForEach(Array(document.chapters.enumerated()), id: \.offset) { index, item in Button(item.title) { chapterIndex = index; pageIndex = 0; speech.stop() } } } } label: { Image(systemName: "list.bullet") } } }
            .task { document = library.document(for: work); chapterIndex = min(initialChapter, max((document?.chapters.count ?? 1) - 1, 0)); pageIndex = 0 }
            .onDisappear { speech.stop() }
        }
    }

    private func moveChapter(_ offset: Int) { guard let document else { return }; let next = chapterIndex + offset; guard document.chapters.indices.contains(next) else { return }; chapterIndex = next; pageIndex = 0; speech.stop() }
    private func saveQuote(_ text: String, index: Int) { let quote = Quote(id: "\(work.id)-\(chapterIndex)-\(index)", workID: work.id, workTitle: work.title, chapterTitle: chapter?.title ?? "", paragraphIndex: index, text: text); library.addQuote(quote) }
}

private struct UniverseView: View {
    @ObservedObject var library: LibraryViewModel
    @State private var tab = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Image("hero_universo").resizable().scaledToFill().frame(height: 180).clipped().clipShape(RoundedRectangle(cornerRadius: 20))
                    Text("UNIVERSO MACHADO").font(.caption.bold()).tracking(2).foregroundStyle(MachadoStyle.gold)
                    Text("Vidas, vozes e destinos").font(.largeTitle.bold()).foregroundStyle(MachadoStyle.green)
                    Text("Entre nos livros por quem os habita e pelo tempo que formou seu autor.").foregroundStyle(.secondary)
                    Picker("Universo", selection: $tab) { Text("Personagens").tag(0); Text("Linha do tempo").tag(1) }.pickerStyle(.segmented)
                    if tab == 0 {
                        ForEach(library.characters) { character in
                            NavigationLink(destination: CharacterDetailView(character: character, library: library)) { CharacterRow(character: character) }.buttonStyle(.plain)
                        }
                    } else {
                        ForEach(library.timeline) { event in
                            HStack(alignment: .top, spacing: 14) { Text("\(event.year)").font(.headline).foregroundStyle(MachadoStyle.gold).frame(width: 48, alignment: .leading); VStack(alignment: .leading) { Text(event.title).font(.headline); Text(event.description).foregroundStyle(.secondary); Text(event.kind).font(.caption.bold()).foregroundStyle(MachadoStyle.gold) } }.padding(.vertical, 5)
                        }
                    }
                }.padding()
            }.navigationTitle("Universo")
        }
    }
}

private struct CharacterDetailView: View {
    let character: CharacterInfo
    @ObservedObject var library: LibraryViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                CharacterImage(character: character).frame(maxWidth: .infinity).frame(height: 260)
                Text(character.name).font(.largeTitle.bold()).foregroundStyle(MachadoStyle.green)
                Text(character.work.uppercased()).font(.caption.bold()).tracking(1).foregroundStyle(MachadoStyle.gold)
                DetailSection(title: "Resumo", text: character.summary)
                Text("Contém revelações da obra").font(.caption.bold()).foregroundStyle(.orange)
                DetailSection(title: "História completa", text: character.story)
                Button { library.toggleCharacterFavorite(character.id) } label: { Label(library.favoriteCharacters.contains(character.id) ? "Remover favorito" : "Adicionar favorito", systemImage: library.favoriteCharacters.contains(character.id) ? "star.fill" : "star").frame(maxWidth: .infinity) }.buttonStyle(.bordered)
                if let work = library.works.first(where: { $0.id == character.workID }) { NavigationLink("Ler obra relacionada", destination: WorkDetailView(work: work, library: library)).buttonStyle(.borderedProminent) }
            }.padding()
        }.navigationTitle(character.name).navigationBarTitleDisplayMode(.inline)
    }
}

private struct MyLibraryView: View {
    @ObservedObject var library: LibraryViewModel
    private var active: [WorkSummary] { library.works.filter { let value = library.workProgress($0.id); return value > 0 && value < 100 } }
    private var completed: [WorkSummary] { library.works.filter { library.workProgress($0.id) >= 100 } }

    var body: some View {
        NavigationStack {
            List {
                Section { HStack { Metric(value: "\(completed.count)", label: "concluídas"); Metric(value: "\(active.count)", label: "em andamento"); Metric(value: "\(library.quotes.count)", label: "citações") }; HStack { Metric(value: "\(library.favorites.count)", label: "favoritos"); Metric(value: "\(library.readingMinutes)m", label: "lendo") } }
                Section("Continuar lendo") {
                    if active.isEmpty { Text("Você ainda não iniciou uma obra.").foregroundStyle(.secondary) }
                    ForEach(active.prefix(3)) { work in NavigationLink(work.title, destination: WorkDetailView(work: work, library: library)) }
                }
                Section("Favoritos") {
                    ForEach(library.works.filter { library.favorites.contains($0.id) }) { work in NavigationLink(work.title, destination: WorkDetailView(work: work, library: library)) }
                    if library.favorites.isEmpty { Text("Seus favoritos aparecerão aqui.").foregroundStyle(.secondary) }
                }
                Section("Citações salvas") {
                    ForEach(library.quotes) { quote in VStack(alignment: .leading) { Text("“\(quote.text)”").font(.system(.body, design: .serif)); Text("\(quote.workTitle) • \(quote.chapterTitle)").font(.caption).foregroundStyle(MachadoStyle.green) }.swipeActions { Button(role: .destructive) { library.removeQuote(quote) } label: { Label("Excluir", systemImage: "trash") } } }
                    if library.quotes.isEmpty { Text("Toque e segure um parágrafo no leitor para salvar uma citação.").foregroundStyle(.secondary) }
                }
                Section("Tema do leitor") { Picker("Tema", selection: Binding(get: { library.theme }, set: { library.setTheme($0) })) { ForEach(ReaderTheme.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented) }
                Section("Privacidade") { Text("Todo o progresso, favoritos e citações ficam somente neste aparelho. O app funciona sem conta, anúncios ou rastreamento.").font(.footnote).foregroundStyle(.secondary) }
            }.navigationTitle("Minha biblioteca")
        }
    }
}

private struct WorkSection: View {
    let title: String
    let works: ArraySlice<WorkSummary>
    @ObservedObject var library: LibraryViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.title3.bold())
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(works)) { work in
                        NavigationLink(destination: WorkDetailView(work: work, library: library)) {
                            VStack(alignment: .leading) {
                                CoverView(work: work).frame(width: 126, height: 176)
                                Text(work.title).font(.headline).lineLimit(2)
                                Text("\(work.year) • \(work.category)").font(.caption).foregroundStyle(.secondary)
                            }
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct WorkCarousel: View {
    let works: [WorkSummary]
    @ObservedObject var library: LibraryViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(works) { work in
                    NavigationLink(destination: WorkDetailView(work: work, library: library)) {
                        WorkRow(work: work, progress: library.workProgress(work.id)).frame(width: 280)
                    }.buttonStyle(.plain)
                }
            }
        }
    }
}

private struct WorkRow: View {
    let work: WorkSummary
    let progress: Double

    var body: some View {
        HStack(spacing: 12) {
            CoverView(work: work).frame(width: 54, height: 76)
            VStack(alignment: .leading, spacing: 5) {
                Text(work.title).font(.headline)
                Text("\(work.year) • \(work.category)").font(.caption).foregroundStyle(.secondary)
                ProgressView(value: progress / 100).tint(MachadoStyle.gold)
            }
        }
        .padding(12)
        .background(MachadoStyle.paper, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct CoverView: View {
    let work: WorkSummary

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: work.coverPalette.map(Color.init(hex:)), startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading) {
                Text("MACHADO DE ASSIS").font(.system(size: 7, weight: .bold)).tracking(1)
                Spacer()
                Text(work.title).font(.system(size: 16, weight: .bold, design: .serif)).lineLimit(4)
                Text(work.category.uppercased()).font(.system(size: 8, weight: .bold))
            }.foregroundStyle(.white).padding(10)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct CharacterRow: View {
    let character: CharacterInfo

    var body: some View {
        HStack(spacing: 14) {
            CharacterImage(character: character).frame(width: 64, height: 64)
            VStack(alignment: .leading) {
                Text(character.name).font(.headline)
                Text(character.work).font(.caption).foregroundStyle(.secondary)
                Text(character.summary).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }.padding(.vertical, 5)
    }
}

private struct CharacterImage: View {
    let character: CharacterInfo

    var body: some View {
        Group {
            if let imageName = character.imageName {
                BundledImage(name: imageName).scaledToFill()
            } else {
                ZStack { MachadoStyle.green; Text(String(character.name.prefix(1))).font(.largeTitle.bold()).foregroundStyle(.white) }
            }
        }.clipShape(Circle())
    }
}

private struct BundledImage: View {
    let name: String

    var body: some View {
        if let image = Self.load(name) {
            Image(uiImage: image).resizable()
        } else {
            MachadoStyle.paper
        }
    }

    private static func load(_ name: String) -> UIImage? {
        for ext in ["jpg", "png"] {
            if let path = Bundle.main.path(forResource: name, ofType: ext, inDirectory: "Images"), let image = UIImage(contentsOfFile: path) { return image }
            if let path = Bundle.main.path(forResource: name, ofType: ext), let image = UIImage(contentsOfFile: path) { return image }
        }
        return nil
    }
}

private struct HomeAction: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) { HomeActionLabel(title: title, subtitle: subtitle, icon: icon) }.buttonStyle(.plain)
    }
}

private struct HomeActionLabel: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon).foregroundStyle(MachadoStyle.gold)
            VStack(alignment: .leading) { Text(title).font(.headline).foregroundStyle(MachadoStyle.green); Text(subtitle).font(.caption).foregroundStyle(.secondary) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(MachadoStyle.paper, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct SectionHeader: View {
    let title: String
    let action: String

    var body: some View {
        HStack { Text(title).font(.title3.bold()); Spacer(); Text(action).font(.caption).foregroundStyle(MachadoStyle.green) }
    }
}

private struct FilterChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(.subheadline.bold())
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .foregroundStyle(selected ? .white : MachadoStyle.green)
            .background(selected ? MachadoStyle.green : MachadoStyle.paper, in: Capsule())
    }
}

private struct DetailSection: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased()).font(.caption.bold()).tracking(1).foregroundStyle(MachadoStyle.gold)
            Text(text).font(.system(.body, design: .serif)).lineSpacing(4)
        }
    }
}

private struct Metric: View {
    let value: String
    let label: String

    var body: some View {
        VStack { Text(value).font(.title2.bold()).foregroundStyle(MachadoStyle.green); Text(label).font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity)
    }
}

private struct ResourceErrorView: View {
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Label("Não foi possível carregar a biblioteca", systemImage: "exclamationmark.triangle").font(.headline)
            Text(message).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.padding()
    }
}

private extension View { func sectionLabel() -> some View { self.font(.caption.bold()).tracking(1).foregroundStyle(MachadoStyle.gold).padding(.top, 8) } }
private extension Array where Element == String { func chunked(into size: Int) -> [[String]] { stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) } } }
private extension Array { subscript(safe index: Index) -> Element? { indices.contains(index) ? self[index] : nil } }
private extension Color { init(hex: String) { let value = UInt64(hex.dropFirst(), radix: 16) ?? 0; self.init(red: Double((value >> 16) & 0xff) / 255, green: Double((value >> 8) & 0xff) / 255, blue: Double(value & 0xff) / 255) } }
private extension Sequence where Element: Hashable { func uniqued() -> [Element] { var seen = Set<Element>(); return filter { seen.insert($0).inserted } } }
