import Foundation

struct SpanishWordCard: Identifiable, Equatable {
    let id: String
    let spanish: String
    let english: String
    let acceptedEnglishAnswers: [String]
}

enum SpanishWordEngine {
    private struct Noun {
        enum Gender {
            case masculine
            case feminine
        }

        let spanish: String
        let english: String
        let articleSpanish: String
        let articleEnglish: String
        let gender: Gender
    }

    private struct Adjective {
        let spanishBase: String
        let english: String
    }

    static let learnCommand = "learn"

    private static let nouns: [Noun] = [
        .init(spanish: "casa", english: "house", articleSpanish: "la", articleEnglish: "the", gender: .feminine),
        .init(spanish: "perro", english: "dog", articleSpanish: "el", articleEnglish: "the", gender: .masculine),
        .init(spanish: "gato", english: "cat", articleSpanish: "el", articleEnglish: "the", gender: .masculine),
        .init(spanish: "escuela", english: "school", articleSpanish: "la", articleEnglish: "the", gender: .feminine),
        .init(spanish: "trabajo", english: "work", articleSpanish: "el", articleEnglish: "the", gender: .masculine),
        .init(spanish: "tiempo", english: "time", articleSpanish: "el", articleEnglish: "the", gender: .masculine),
        .init(spanish: "amigo", english: "friend", articleSpanish: "el", articleEnglish: "the", gender: .masculine),
        .init(spanish: "amiga", english: "friend", articleSpanish: "la", articleEnglish: "the", gender: .feminine),
        .init(spanish: "familia", english: "family", articleSpanish: "la", articleEnglish: "the", gender: .feminine),
        .init(spanish: "comida", english: "food", articleSpanish: "la", articleEnglish: "the", gender: .feminine),
        .init(spanish: "agua", english: "water", articleSpanish: "el", articleEnglish: "the", gender: .feminine),
        .init(spanish: "ciudad", english: "city", articleSpanish: "la", articleEnglish: "the", gender: .feminine),
        .init(spanish: "calle", english: "street", articleSpanish: "la", articleEnglish: "the", gender: .feminine),
        .init(spanish: "puerta", english: "door", articleSpanish: "la", articleEnglish: "the", gender: .feminine),
        .init(spanish: "ventana", english: "window", articleSpanish: "la", articleEnglish: "the", gender: .feminine),
        .init(spanish: "mesa", english: "table", articleSpanish: "la", articleEnglish: "the", gender: .feminine),
        .init(spanish: "silla", english: "chair", articleSpanish: "la", articleEnglish: "the", gender: .feminine),
        .init(spanish: "coche", english: "car", articleSpanish: "el", articleEnglish: "the", gender: .masculine),
        .init(spanish: "tren", english: "train", articleSpanish: "el", articleEnglish: "the", gender: .masculine),
        .init(spanish: "libro", english: "book", articleSpanish: "el", articleEnglish: "the", gender: .masculine),
        .init(spanish: "historia", english: "story", articleSpanish: "la", articleEnglish: "the", gender: .feminine),
        .init(spanish: "música", english: "music", articleSpanish: "la", articleEnglish: "the", gender: .feminine),
        .init(spanish: "película", english: "movie", articleSpanish: "la", articleEnglish: "the", gender: .feminine),
        .init(spanish: "juego", english: "game", articleSpanish: "el", articleEnglish: "the", gender: .masculine),
        .init(spanish: "idea", english: "idea", articleSpanish: "la", articleEnglish: "the", gender: .feminine),
        .init(spanish: "pregunta", english: "question", articleSpanish: "la", articleEnglish: "the", gender: .feminine),
        .init(spanish: "respuesta", english: "answer", articleSpanish: "la", articleEnglish: "the", gender: .feminine),
        .init(spanish: "mañana", english: "morning", articleSpanish: "la", articleEnglish: "the", gender: .feminine),
        .init(spanish: "noche", english: "night", articleSpanish: "la", articleEnglish: "the", gender: .feminine),
        .init(spanish: "día", english: "day", articleSpanish: "el", articleEnglish: "the", gender: .masculine),
        .init(spanish: "semana", english: "week", articleSpanish: "la", articleEnglish: "the", gender: .feminine),
        .init(spanish: "mes", english: "month", articleSpanish: "el", articleEnglish: "the", gender: .masculine),
        .init(spanish: "año", english: "year", articleSpanish: "el", articleEnglish: "the", gender: .masculine),
        .init(spanish: "mano", english: "hand", articleSpanish: "la", articleEnglish: "the", gender: .feminine),
        .init(spanish: "cabeza", english: "head", articleSpanish: "la", articleEnglish: "the", gender: .feminine),
        .init(spanish: "corazón", english: "heart", articleSpanish: "el", articleEnglish: "the", gender: .masculine),
        .init(spanish: "cuerpo", english: "body", articleSpanish: "el", articleEnglish: "the", gender: .masculine),
        .init(spanish: "cara", english: "face", articleSpanish: "la", articleEnglish: "the", gender: .feminine),
        .init(spanish: "papel", english: "paper", articleSpanish: "el", articleEnglish: "the", gender: .masculine),
        .init(spanish: "dinero", english: "money", articleSpanish: "el", articleEnglish: "the", gender: .masculine),
        .init(spanish: "aire", english: "air", articleSpanish: "el", articleEnglish: "the", gender: .masculine),
        .init(spanish: "sol", english: "sun", articleSpanish: "el", articleEnglish: "the", gender: .masculine),
        .init(spanish: "luna", english: "moon", articleSpanish: "la", articleEnglish: "the", gender: .feminine),
        .init(spanish: "estrella", english: "star", articleSpanish: "la", articleEnglish: "the", gender: .feminine),
        .init(spanish: "mar", english: "sea", articleSpanish: "el", articleEnglish: "the", gender: .masculine),
        .init(spanish: "río", english: "river", articleSpanish: "el", articleEnglish: "the", gender: .masculine),
        .init(spanish: "montaña", english: "mountain", articleSpanish: "la", articleEnglish: "the", gender: .feminine),
        .init(spanish: "árbol", english: "tree", articleSpanish: "el", articleEnglish: "the", gender: .masculine),
        .init(spanish: "flor", english: "flower", articleSpanish: "la", articleEnglish: "the", gender: .feminine),
        .init(spanish: "camino", english: "path", articleSpanish: "el", articleEnglish: "the", gender: .masculine)
    ]

    private static let adjectives: [Adjective] = [
        .init(spanishBase: "grande", english: "big"), .init(spanishBase: "pequeño", english: "small"),
        .init(spanishBase: "rápido", english: "fast"), .init(spanishBase: "lento", english: "slow"),
        .init(spanishBase: "fácil", english: "easy"), .init(spanishBase: "difícil", english: "difficult"),
        .init(spanishBase: "nuevo", english: "new"), .init(spanishBase: "viejo", english: "old"),
        .init(spanishBase: "feliz", english: "happy"), .init(spanishBase: "triste", english: "sad"),
        .init(spanishBase: "claro", english: "clear"), .init(spanishBase: "oscuro", english: "dark"),
        .init(spanishBase: "fuerte", english: "strong"), .init(spanishBase: "suave", english: "soft"),
        .init(spanishBase: "caliente", english: "hot"), .init(spanishBase: "frío", english: "cold"),
        .init(spanishBase: "alto", english: "tall"), .init(spanishBase: "bajo", english: "short"),
        .init(spanishBase: "largo", english: "long"), .init(spanishBase: "corto", english: "short"),
        .init(spanishBase: "limpio", english: "clean"), .init(spanishBase: "sucio", english: "dirty"),
        .init(spanishBase: "bonito", english: "pretty"), .init(spanishBase: "feo", english: "ugly"),
        .init(spanishBase: "bueno", english: "good"), .init(spanishBase: "malo", english: "bad"),
        .init(spanishBase: "dulce", english: "sweet"), .init(spanishBase: "salado", english: "salty"),
        .init(spanishBase: "profundo", english: "deep"), .init(spanishBase: "ligero", english: "light"),
        .init(spanishBase: "pesado", english: "heavy"), .init(spanishBase: "famoso", english: "famous"),
        .init(spanishBase: "tranquilo", english: "calm"), .init(spanishBase: "ruidoso", english: "noisy"),
        .init(spanishBase: "abierto", english: "open"), .init(spanishBase: "cerrado", english: "closed"),
        .init(spanishBase: "lleno", english: "full"), .init(spanishBase: "vacío", english: "empty"),
        .init(spanishBase: "seguro", english: "safe"), .init(spanishBase: "libre", english: "free")
    ]

    private static let verbs: [(spanish: String, english: String)] = [
        ("hablar", "to speak"), ("comer", "to eat"), ("vivir", "to live"), ("leer", "to read"),
        ("escribir", "to write"), ("caminar", "to walk"), ("correr", "to run"), ("mirar", "to watch"),
        ("escuchar", "to listen"), ("aprender", "to learn"), ("enseñar", "to teach"), ("trabajar", "to work"),
        ("descansar", "to rest"), ("dormir", "to sleep"), ("despertar", "to wake up"), ("viajar", "to travel"),
        ("cocinar", "to cook"), ("limpiar", "to clean"), ("ayudar", "to help"), ("abrir", "to open"),
        ("cerrar", "to close"), ("entrar", "to enter"), ("salir", "to leave"), ("pensar", "to think"),
        ("crear", "to create"), ("cambiar", "to change"), ("usar", "to use"), ("buscar", "to search"),
        ("encontrar", "to find"), ("comprar", "to buy"), ("vender", "to sell"), ("pagar", "to pay"),
        ("esperar", "to wait"), ("empezar", "to start"), ("terminar", "to finish"), ("jugar", "to play"),
        ("estudiar", "to study"), ("recordar", "to remember"), ("olvidar", "to forget"), ("llamar", "to call"),
        ("enviar", "to send"), ("recibir", "to receive"), ("compartir", "to share"), ("mejorar", "to improve"),
        ("ganar", "to win"), ("perder", "to lose"), ("construir", "to build"), ("romper", "to break"),
        ("guardar", "to save"), ("repetir", "to repeat")
    ]

    static let cards: [SpanishWordCard] = {
        var generated: [SpanishWordCard] = []

        for noun in nouns {
            generated.append(
                SpanishWordCard(
                    id: "noun-\(noun.spanish)",
                    spanish: noun.spanish,
                    english: noun.english,
                    acceptedEnglishAnswers: [noun.english]
                )
            )
            generated.append(
                SpanishWordCard(
                    id: "phrase-\(noun.articleSpanish)-\(noun.spanish)",
                    spanish: "\(noun.articleSpanish) \(noun.spanish)",
                    english: "\(noun.articleEnglish) \(noun.english)",
                    acceptedEnglishAnswers: [noun.english, "\(noun.articleEnglish) \(noun.english)"]
                )
            )
        }

        for adjective in adjectives {
            generated.append(
                SpanishWordCard(
                    id: "adj-\(adjective.spanishBase)",
                    spanish: adjective.spanishBase,
                    english: adjective.english,
                    acceptedEnglishAnswers: [adjective.english]
                )
            )
        }

        for verb in verbs {
            generated.append(
                SpanishWordCard(
                    id: "verb-\(verb.spanish)",
                    spanish: verb.spanish,
                    english: verb.english,
                    acceptedEnglishAnswers: [verb.english, verb.english.replacingOccurrences(of: "to ", with: "")]
                )
            )
        }

        // Build thousands of randomizable cards by combining nouns and adjectives.
        for noun in nouns {
            for adjective in adjectives {
                let inflectedAdjective = inflected(adjective: adjective.spanishBase, for: noun.gender)
                generated.append(
                    SpanishWordCard(
                        id: "combo-\(noun.spanish)-\(inflectedAdjective)",
                        spanish: "\(noun.articleSpanish) \(noun.spanish) \(inflectedAdjective)",
                        english: "\(noun.articleEnglish) \(adjective.english) \(noun.english)",
                        acceptedEnglishAnswers: [
                            "\(adjective.english) \(noun.english)",
                            "\(noun.articleEnglish) \(adjective.english) \(noun.english)"
                        ]
                    )
                )
            }
        }

        return generated
    }()

    private static func inflected(adjective: String, for gender: Noun.Gender) -> String {
        guard gender == .feminine else { return adjective }
        guard adjective.hasSuffix("o") else { return adjective }
        return String(adjective.dropLast()) + "a"
    }

    static func randomCard(avoiding previousID: String?) -> SpanishWordCard {
        guard cards.count > 1 else { return cards[0] }
        var card = cards.randomElement() ?? cards[0]
        while card.id == previousID {
            card = cards.randomElement() ?? cards[0]
        }
        return card
    }

    /// Returns shuffled English answer choices for a card: the correct meaning plus
    /// distractors drawn from other cards. Choices are de-duplicated by meaning so
    /// two options never read the same.
    static func choices(for card: SpanishWordCard, count: Int = 4) -> [String] {
        var seen: Set<String> = [normalized(card.english)]
        var result: [String] = [card.english]

        var pool = cards.shuffled()
        while result.count < count, let candidate = pool.popLast() {
            let key = normalized(candidate.english)
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(candidate.english)
        }

        return result.shuffled()
    }

    static func isLearnCommand(_ value: String) -> Bool {
        normalized(value) == learnCommand
    }

    static func isCorrectAnswer(_ value: String, for card: SpanishWordCard) -> Bool {
        let normalizedAnswer = normalized(value)
        guard !normalizedAnswer.isEmpty else { return false }
        return card.acceptedEnglishAnswers.contains { normalized($0) == normalizedAnswer }
    }

    private static func normalized(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "  ", with: " ")
    }
}

// MARK: - Reading exercise

/// A short, readable article for the "Read Something" unlock exercise.
struct ReadArticle: Equatable {
    let title: String
    let extract: String
}

/// Fetches a random Wikipedia article summary for the reading exercise. Wikipedia's REST
/// summary endpoint needs no API key and returns plain-text extracts. When the network is
/// unavailable we fall back to a small bundled set of facts so the unlock never blocks.
enum WikipediaReadEngine {
    private struct Summary: Decodable {
        let title: String
        let extract: String
        let type: String?
    }

    private static let endpoint = URL(string: "https://en.wikipedia.org/api/rest_v1/page/random/summary")!

    /// Tries a few times to land on a substantive article (skipping disambiguation pages and
    /// very thin stubs). Returns `nil` only when every attempt fails (e.g. offline).
    static func fetchRandomArticle(maxAttempts: Int = 3) async -> ReadArticle? {
        for _ in 0..<max(1, maxAttempts) {
            if let article = await fetchOnce() {
                return article
            }
        }
        return nil
    }

    private static func fetchOnce() async -> ReadArticle? {
        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 8
        request.cachePolicy = .reloadIgnoringLocalCacheData
        // Wikimedia asks API clients to identify themselves.
        request.setValue("Cuewell/1.0 (https://cuewell.app)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            let summary = try JSONDecoder().decode(Summary.self, from: data)
            let extract = summary.extract.trimmingCharacters(in: .whitespacesAndNewlines)
            guard summary.type != "disambiguation", extract.count >= 80 else { return nil }
            return ReadArticle(title: summary.title, extract: extract)
        } catch {
            return nil
        }
    }

    /// A random bundled fact used when the network can't be reached.
    static func fallbackArticle() -> ReadArticle {
        fallbackFacts.randomElement() ?? fallbackFacts[0]
    }

    private static let fallbackFacts: [ReadArticle] = [
        ReadArticle(
            title: "Octopuses",
            extract: "An octopus has three hearts and blue, copper-based blood. Two hearts pump blood to the gills, while the third circulates it to the rest of the body — and that main heart stops beating when the octopus swims, which is part of why they often prefer to crawl."
        ),
        ReadArticle(
            title: "Honey",
            extract: "Honey never really spoils. Archaeologists have found pots of honey in ancient Egyptian tombs that are over 3,000 years old and still perfectly edible. Its low moisture and high acidity make it an environment in which bacteria cannot survive."
        ),
        ReadArticle(
            title: "The Eiffel Tower",
            extract: "The Eiffel Tower can grow more than 15 centimetres taller in summer. As the iron structure heats up, the metal expands; when it cools in winter, the tower shrinks back down. It can also lean slightly away from the sun as the warmed side expands."
        ),
        ReadArticle(
            title: "Bananas",
            extract: "Bananas are botanically classified as berries, while strawberries are not. To a botanist, a berry is a fruit produced from a single flower with one ovary and seeds embedded in the flesh — which bananas qualify for and strawberries don't."
        ),
        ReadArticle(
            title: "Sea Otters",
            extract: "Sea otters hold hands while they sleep so they don't drift apart on the water. A group floating together is called a raft, and they sometimes wrap themselves in kelp to stay anchored in one place through the night."
        ),
        ReadArticle(
            title: "The Speed of Light",
            extract: "Light from the Sun takes about eight minutes and twenty seconds to reach Earth. So when you look at the Sun, you're seeing it as it was over eight minutes ago — and for the most distant stars, the light reaching you left them thousands of years ago."
        )
    ]
}
