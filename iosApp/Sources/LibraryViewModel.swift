import Foundation
import Combine

struct CharacterInfo: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let work: String
    let summary: String
    let story: String
    let imageName: String?
    let workID: String

    init(id: String, name: String, work: String, summary: String, story: String, imageName: String? = nil, workID: String) {
        self.id = id
        self.name = name
        self.work = work
        self.summary = summary
        self.story = story
        self.imageName = imageName
        self.workID = workID
    }
}

struct TimelineEvent: Codable, Hashable, Identifiable {
    let year: Int
    let title: String
    let description: String
    let kind: String
    var id: String { "\(year)-\(title)" }
}

struct Quote: Codable, Hashable, Identifiable {
    let id: String
    let workID: String
    let workTitle: String
    let chapterTitle: String
    let paragraphIndex: Int
    let text: String
}

struct WorkSummary: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let category: String
    let description: String
    let context: String
    let characters: [String]
    let year: Int
    let chapters: Int
    let words: Int
    let sourceURL: String
    let heroImageName: String?

    var coverPalette: [String] {
        switch abs(id.hashValue) % 4 {
        case 0: return ["#173B32", "#315E50"]
        case 1: return ["#3A2921", "#704B37"]
        case 2: return ["#5B3C56", "#8A5D78"]
        default: return ["#8A642E", "#B39255"]
        }
    }
}

struct WorkDocument: Decodable {
    let chapters: [DocumentChapter]
}

struct DocumentChapter: Decodable {
    let title: String
    let paragraphs: [String]
}

struct SearchHit: Identifiable, Hashable {
    let id: String
    let work: WorkSummary
    let chapterTitle: String
    let snippet: String
}

final class LibraryViewModel: ObservableObject {
    @Published private(set) var works: [WorkSummary] = []
    @Published private(set) var characters: [CharacterInfo] = LibraryViewModel.defaultCharacters
    @Published private(set) var timeline: [TimelineEvent] = LibraryViewModel.defaultTimeline
    @Published private(set) var searchResults: [SearchHit] = []
    @Published private(set) var loadError: String?
    @Published var searchQuery = ""
    @Published var theme: ReaderTheme
    @Published var fontSize: Double
    @Published private(set) var favorites: Set<String>
    @Published private(set) var favoriteCharacters: Set<String>
    @Published private(set) var quotes: [Quote]
    @Published private(set) var progress: [String: Double]
    @Published private(set) var readingMinutes: Int

    private let defaults = UserDefaults.standard
    private var documents: [String: WorkDocument] = [:]
    private var searchTask: Task<Void, Never>?

    init() {
        theme = ReaderTheme(rawValue: defaults.string(forKey: Keys.theme) ?? "Claro") ?? .light
        fontSize = defaults.object(forKey: Keys.fontSize) as? Double ?? 18
        favorites = Set(defaults.stringArray(forKey: Keys.favorites) ?? [])
        favoriteCharacters = Set(defaults.stringArray(forKey: Keys.favoriteCharacters) ?? [])
        quotes = (try? JSONDecoder().decode([Quote].self, from: defaults.data(forKey: Keys.quotes) ?? Data())) ?? []
        progress = (try? JSONDecoder().decode([String: Double].self, from: defaults.data(forKey: Keys.progress) ?? Data())) ?? [:]
        readingMinutes = defaults.integer(forKey: Keys.readingMinutes)
        do {
            works = try loadCatalog()
        } catch {
            loadError = error.localizedDescription
        }
    }

    deinit { searchTask?.cancel() }

    func searchChanged(_ query: String) {
        searchQuery = query
        searchTask?.cancel()
        guard query.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3 else {
            searchResults = []
            return
        }
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, let self else { return }
            self.searchResults = self.search(query: query)
        }
    }

    func document(for work: WorkSummary) -> WorkDocument? {
        if let document = documents[work.id] { return document }
        do {
            let data = try BundleResource.data(named: work.id, fileExtension: "json", subdirectory: "Texts")
            let document = try JSONDecoder().decode(WorkDocument.self, from: data)
            documents[work.id] = document
            return document
        } catch {
            return nil
        }
    }

    func progress(for workID: String, chapter: Int, page: Int, pageCount: Int) -> Double {
        progress[progressKey(workID, chapter)] ?? (pageCount > 0 ? Double(page) / Double(pageCount) * 100 : 0)
    }

    func saveProgress(workID: String, chapter: Int, page: Int, pageCount: Int) {
        let percent = pageCount == 0 ? 0 : min(100, Double(page + 1) / Double(pageCount) * 100)
        progress[progressKey(workID, chapter)] = percent
        persist(progress, key: Keys.progress)
    }

    func workProgress(_ workID: String) -> Double {
        let values = progress.filter { $0.key.hasPrefix("\(workID):") }.map(\.value)
        return values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }

    func toggleFavorite(_ workID: String) {
        if favorites.contains(workID) { favorites.remove(workID) } else { favorites.insert(workID) }
        defaults.set(Array(favorites), forKey: Keys.favorites)
    }

    func toggleCharacterFavorite(_ characterID: String) {
        if favoriteCharacters.contains(characterID) { favoriteCharacters.remove(characterID) } else { favoriteCharacters.insert(characterID) }
        defaults.set(Array(favoriteCharacters), forKey: Keys.favoriteCharacters)
    }

    func addQuote(_ quote: Quote) {
        guard !quotes.contains(where: { $0.id == quote.id }) else { return }
        quotes.insert(quote, at: 0)
        persist(quotes, key: Keys.quotes)
    }

    func removeQuote(_ quote: Quote) {
        quotes.removeAll { $0.id == quote.id }
        persist(quotes, key: Keys.quotes)
    }

    func setTheme(_ value: ReaderTheme) {
        theme = value
        defaults.set(value.rawValue, forKey: Keys.theme)
    }

    func setFontSize(_ value: Double) {
        fontSize = min(30, max(14, value))
        defaults.set(fontSize, forKey: Keys.fontSize)
    }

    func addReadingMinute() {
        readingMinutes += 1
        defaults.set(readingMinutes, forKey: Keys.readingMinutes)
    }

    private func search(query: String) -> [SearchHit] {
        let normalized = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        var hits: [SearchHit] = []
        for work in works {
            guard let document = document(for: work) else { continue }
            for chapter in document.chapters {
                for paragraph in chapter.paragraphs where paragraph.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).contains(normalized) {
                    let compact = paragraph.replacingOccurrences(of: "\n", with: " ")
                    hits.append(SearchHit(id: "\(work.id)-\(chapter.title)-\(hits.count)", work: work, chapterTitle: chapter.title, snippet: compact.count > 180 ? String(compact.prefix(180)) + "…" : compact))
                    if hits.count == 40 { return hits }
                }
            }
        }
        return hits
    }

    private func loadCatalog() throws -> [WorkSummary] {
        let data = try BundleResource.data(named: "catalog", fileExtension: "json")
        let entries = try JSONDecoder().decode([CatalogEntry].self, from: data)
        guard !entries.isEmpty else { throw BundleResourceError.invalid("catalog.json não contém obras") }
        return entries.map {
            WorkSummary(id: $0.id, title: $0.title, category: $0.category, description: $0.description,
                        context: $0.context ?? "", characters: $0.characters ?? [], year: $0.year,
                        chapters: $0.chapters, words: $0.words, sourceURL: $0.sourceUrl,
                        heroImageName: ["dom": "hero_dom", "quincas": "hero_quincas", "brascubas": "hero_bras_cubas"][$0.id])
        }
    }

    private func progressKey(_ workID: String, _ chapter: Int) -> String { "\(workID):\(chapter)" }

    private func persist<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }

    private enum Keys {
        static let theme = "machado.theme"
        static let fontSize = "machado.fontSize"
        static let favorites = "machado.favorites"
        static let favoriteCharacters = "machado.favoriteCharacters"
        static let quotes = "machado.quotes"
        static let progress = "machado.progress"
        static let readingMinutes = "machado.readingMinutes"
    }

    static let defaultCharacters = [
        CharacterInfo(id: "capitu", name: "Capitu", work: "Dom Casmurro", summary: "Olhos de ressaca, inteligência e uma presença impossível de reduzir à dúvida de Bentinho.", story: "Capitu cresce em uma sociedade que espera silêncio das mulheres. Sua história também é a disputa entre memória, ciúme e autonomia.", imageName: "avatar_capitu", workID: "dom"),
        CharacterInfo(id: "bentinho", name: "Bentinho", work: "Dom Casmurro", summary: "O narrador que tenta reconstruir a própria vida para convencer o leitor e a si mesmo.", story: "Bentinho abandona o seminário, casa-se com Capitu e transforma a memória em tribunal. O que ele conta é inseparável do que escolhe omitir.", workID: "dom"),
        CharacterInfo(id: "brascubas", name: "Brás Cubas", work: "Memórias Póstumas", summary: "Um defunto-autor que narra a vida com humor, vaidade e liberdade.", story: "Depois de morto, Brás Cubas revisita seus amores, ambições e fracassos. Sua trajetória desmonta a ideia de uma vida exemplar.", imageName: "avatar_bras_cubas", workID: "brascubas"),
        CharacterInfo(id: "rubiao", name: "Rubião", work: "Quincas Borba", summary: "Professor que herda fortuna e filosofia, mas perde o chão entre o Humanitismo e a sociedade.", story: "Rubião sai de Barbacena rumo ao Rio de Janeiro. A riqueza abre portas, enquanto a ingenuidade o torna presa de relações interessadas.", imageName: "avatar_rubiao", workID: "quincas"),
        CharacterInfo(id: "bacamarte", name: "Simão Bacamarte", work: "O Alienista", summary: "A ciência transformada em autoridade absoluta numa sátira sobre normalidade e poder.", story: "Bacamarte funda a Casa Verde em Itaguaí e passa a classificar a população. Sua busca pela razão revela a instabilidade de todo julgamento.", workID: "alienista"),
        CharacterInfo(id: "aires", name: "Conselheiro Aires", work: "Memorial de Aires", summary: "Diplomata aposentado que observa o mundo com ironia, delicadeza e distância.", story: "Aires registra a passagem do tempo e os afetos alheios em forma de diário. Sua aparente neutralidade nunca elimina a compaixão.", workID: "memorial")
    ]

    static let defaultTimeline = [
        TimelineEvent(year: 1839, title: "Nascimento", description: "Joaquim Maria Machado de Assis nasce no Rio de Janeiro, no Morro do Livramento.", kind: "VIDA"),
        TimelineEvent(year: 1855, title: "Primeiras publicações", description: "Ainda jovem, inicia colaboração na imprensa e se aproxima do ambiente literário da Corte.", kind: "VIDA"),
        TimelineEvent(year: 1864, title: "Crisálidas", description: "Publica seu primeiro livro de poesias, consolidando sua presença literária.", kind: "OBRA"),
        TimelineEvent(year: 1869, title: "Casamento com Carolina", description: "Casa-se com Carolina Augusta Xavier de Novais, sua companheira por toda a vida.", kind: "VIDA"),
        TimelineEvent(year: 1872, title: "Ressurreição", description: "Publica seu primeiro romance e começa a construir uma obra de observação psicológica.", kind: "OBRA"),
        TimelineEvent(year: 1881, title: "Memórias Póstumas", description: "A publicação do romance marca uma ruptura decisiva e inaugura uma nova fase estética.", kind: "OBRA"),
        TimelineEvent(year: 1891, title: "Quincas Borba", description: "A sátira do Humanitismo amplia o universo do Realismo machadiano.", kind: "OBRA"),
        TimelineEvent(year: 1897, title: "Academia Brasileira de Letras", description: "Machado participa da fundação da Academia e torna-se seu primeiro presidente.", kind: "BRASIL"),
        TimelineEvent(year: 1899, title: "Dom Casmurro", description: "Publica um dos romances mais discutidos da língua portuguesa.", kind: "OBRA"),
        TimelineEvent(year: 1908, title: "Memorial de Aires e morte", description: "Publica seu último romance e morre no Rio de Janeiro em 29 de setembro.", kind: "VIDA")
    ]
}

enum ReaderTheme: String, CaseIterable, Codable {
    case light = "Claro"
    case sepia = "Sépia"
    case dark = "Escuro"
}

private struct CatalogEntry: Decodable {
    let id: String
    let title: String
    let year: Int
    let category: String
    let description: String
    let context: String?
    let characters: [String]?
    let sourceUrl: String
    let chapters: Int
    let words: Int
}

enum BundleResource {
    static func data(named name: String, fileExtension: String, subdirectory: String? = nil) throws -> Data {
        let directories = [subdirectory, "Texts", "Resources", "Resources/Texts"].compactMap { $0 }
        let urls = directories.compactMap { Bundle.main.url(forResource: name, withExtension: fileExtension, subdirectory: $0) }
        guard let url = urls.first ?? Bundle.main.url(forResource: name, withExtension: fileExtension) else { throw BundleResourceError.missing(name) }
        do { return try Data(contentsOf: url) } catch { throw BundleResourceError.read(name, error.localizedDescription) }
    }
}

enum BundleResourceError: LocalizedError {
    case missing(String)
    case read(String, String)
    case invalid(String)

    var errorDescription: String? {
        switch self {
        case .missing(let name): return "Recurso offline não encontrado: \(name).json"
        case .read(let name, let detail): return "Não foi possível ler \(name).json: \(detail)"
        case .invalid(let detail): return detail
        }
    }
}
