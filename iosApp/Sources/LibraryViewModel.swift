import Foundation
import Combine

struct WorkSummary: Identifiable, Hashable {
    let id: String
    let title: String
    let category: String
    let description: String
    let year: Int
    let chapters: Int
    let words: Int
    let sourceURL: String
}

final class LibraryViewModel: ObservableObject {
    @Published var works: [WorkSummary] = []
    @Published var progress: [String: Double] = [:]
    @Published private(set) var loadError: String?

    init() {
        do {
            works = try loadCatalog()
        } catch {
            loadError = error.localizedDescription
        }
    }

    var readingMinutes: Int { 0 }

    private func loadCatalog() throws -> [WorkSummary] {
        let data = try BundleResource.data(named: "catalog", fileExtension: "json")
        let entries = try JSONDecoder().decode([CatalogEntry].self, from: data)
        guard !entries.isEmpty else { throw BundleResourceError.invalid("catalog.json não contém obras") }
        return entries.map {
            WorkSummary(id: $0.id, title: $0.title, category: $0.category, description: $0.description,
                        year: $0.year, chapters: $0.chapters, words: $0.words, sourceURL: $0.sourceUrl)
        }
    }
}

enum BundleResource {
    static func data(named name: String, fileExtension: String, subdirectory: String? = nil) throws -> Data {
        let bundles = [Bundle.main] + Bundle.allFrameworks + Bundle.allBundles
        let directories = [subdirectory, "Texts", "Resources", "Resources/Texts"].compactMap { $0 }
        let urls = bundles.flatMap { bundle in
            var matches = directories.compactMap { directory in
                bundle.url(forResource: name, withExtension: fileExtension, subdirectory: directory)
            }
            if let rootResource = bundle.url(forResource: name, withExtension: fileExtension) {
                matches.append(rootResource)
            }
            return matches
        }
        guard let url = urls.first else { throw BundleResourceError.missing(name) }
        do { return try Data(contentsOf: url) }
        catch { throw BundleResourceError.read(name, error.localizedDescription) }
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

private struct CatalogEntry: Decodable {
    let id: String
    let title: String
    let year: Int
    let category: String
    let description: String
    let sourceUrl: String
    let chapters: Int
    let words: Int
}
