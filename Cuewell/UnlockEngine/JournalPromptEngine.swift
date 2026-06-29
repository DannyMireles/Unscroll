import Foundation
import UIKit
import Vision

// NOTE: This file hosts the content engines for the redesigned unlock activities
// (Read, Mindfulness, Go Outside). The filename is kept as-is to avoid Xcode project
// surgery; treat it as "UnlockContentEngines".

// MARK: - Reading topics & preferences

enum ReadingTopic: String, Codable, CaseIterable, Identifiable {
    case business, technology, science, psychology, philosophy
    case health, history, money, writing, productivity

    var id: String { rawValue }

    var title: String {
        switch self {
        case .business: return "Business"
        case .technology: return "Technology"
        case .science: return "Science"
        case .psychology: return "Psychology"
        case .philosophy: return "Philosophy"
        case .health: return "Health"
        case .history: return "History"
        case .money: return "Money"
        case .writing: return "Writing"
        case .productivity: return "Productivity"
        }
    }

    var systemImage: String {
        switch self {
        case .business: return "briefcase.fill"
        case .technology: return "cpu.fill"
        case .science: return "atom"
        case .psychology: return "brain.head.profile"
        case .philosophy: return "lightbulb.fill"
        case .health: return "heart.fill"
        case .history: return "building.columns.fill"
        case .money: return "dollarsign.circle.fill"
        case .writing: return "pencil.and.scribble"
        case .productivity: return "checklist"
        }
    }

    /// Curated free RSS feeds (stable, no API key — Substacks and major outlets both expose RSS).
    var feeds: [URL] {
        let strings: [String]
        switch self {
        case .business:
            strings = ["https://www.theguardian.com/business/rss",
                       "https://feeds.bbci.co.uk/news/business/rss.xml"]
        case .technology:
            strings = ["https://www.theguardian.com/technology/rss",
                       "https://feeds.bbci.co.uk/news/technology/rss.xml"]
        case .science:
            strings = ["https://www.theguardian.com/science/rss",
                       "https://feeds.bbci.co.uk/news/science_and_environment/rss.xml"]
        case .psychology:
            strings = ["https://aeon.co/feed.rss",
                       "https://www.theguardian.com/science/psychology/rss"]
        case .philosophy:
            strings = ["https://aeon.co/feed.rss"]
        case .health:
            strings = ["https://www.theguardian.com/lifeandstyle/health-and-wellbeing/rss",
                       "https://feeds.bbci.co.uk/news/health/rss.xml"]
        case .history:
            strings = ["https://www.smithsonianmag.com/rss/history/",
                       "https://aeon.co/feed.rss"]
        case .money:
            strings = ["https://www.theguardian.com/money/rss"]
        case .writing:
            strings = ["https://lithub.com/feed/"]
        case .productivity:
            strings = ["https://jamesclear.com/feed", "https://fs.blog/feed/"]
        }
        return strings.compactMap(URL.init(string:))
    }

    /// A browsable page used when no feed item could be fetched (offline / feed down).
    var homeURL: URL {
        let string: String
        switch self {
        case .business: string = "https://www.theguardian.com/business"
        case .technology: string = "https://www.theguardian.com/technology"
        case .science: string = "https://www.theguardian.com/science"
        case .psychology: string = "https://aeon.co/psychology"
        case .philosophy: string = "https://aeon.co/philosophy"
        case .health: string = "https://www.theguardian.com/lifeandstyle/health-and-wellbeing"
        case .history: string = "https://www.smithsonianmag.com/history/"
        case .money: string = "https://www.theguardian.com/money"
        case .writing: string = "https://lithub.com"
        case .productivity: string = "https://jamesclear.com/articles"
        }
        return URL(string: string)!
    }

    var sourceName: String {
        switch self {
        case .business, .technology, .science, .money, .health: return "The Guardian"
        case .psychology, .philosophy: return "Aeon"
        case .history: return "Smithsonian"
        case .writing: return "Literary Hub"
        case .productivity: return "James Clear"
        }
    }
}

enum ReadingPreferencesStore {
    private static let key = "cuewell.reading.topics"
    private static var defaults: UserDefaults? { UserDefaults(suiteName: AppConstants.appGroupIdentifier) }

    /// Defaults to a broad, generally-interesting set so Read works before any onboarding choice.
    static let fallbackTopics: [ReadingTopic] = [.science, .psychology, .business, .productivity]

    static func selectedTopics() -> [ReadingTopic] {
        guard let raw = defaults?.array(forKey: key) as? [String] else { return fallbackTopics }
        let topics = raw.compactMap(ReadingTopic.init(rawValue:))
        return topics.isEmpty ? fallbackTopics : topics
    }

    static func save(_ topics: Set<ReadingTopic>) {
        defaults?.set(topics.map(\.rawValue), forKey: key)
    }
}

// MARK: - Article model & feed engine

struct ReadArticle: Equatable {
    let title: String
    let source: String
    let url: URL
    let summary: String?
}

/// Fetches a fresh article from one of the user's chosen topics via curated RSS feeds.
/// Free, no API key. Falls back to the topic's homepage when feeds can't be reached.
enum ArticleFeedEngine {
    private static let recentKey = "cuewell.reading.recentURLs"
    private static let recentLimit = 24

    static func nextArticle(topics: [ReadingTopic] = ReadingPreferencesStore.selectedTopics()) async -> ReadArticle {
        let pool = topics.isEmpty ? ReadingPreferencesStore.fallbackTopics : topics
        let topic = pool.randomElement() ?? .science
        let recent = recentURLs()

        for feed in topic.feeds.shuffled() {
            guard let items = await fetchFeed(feed), !items.isEmpty else { continue }
            let unseen = items.filter { !recent.contains($0.url.absoluteString) }
            if let pick = (unseen.first ?? items.first) {
                rememberShown(pick.url)
                return ReadArticle(title: pick.title, source: topic.sourceName, url: pick.url, summary: pick.summary)
            }
        }

        return ReadArticle(
            title: "Today in \(topic.title)",
            source: topic.sourceName,
            url: topic.homeURL,
            summary: "Open \(topic.sourceName) and pick something that catches your eye."
        )
    }

    private static func fetchFeed(_ url: URL) async -> [RSSItem]? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("Cuewell/1.0", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
            return RSSParser().parse(data)
        } catch {
            return nil
        }
    }

    private static func recentURLs() -> [String] {
        UserDefaults.standard.stringArray(forKey: recentKey) ?? []
    }

    private static func rememberShown(_ url: URL) {
        var recent = recentURLs()
        recent.removeAll { $0 == url.absoluteString }
        recent.insert(url.absoluteString, at: 0)
        if recent.count > recentLimit { recent = Array(recent.prefix(recentLimit)) }
        UserDefaults.standard.set(recent, forKey: recentKey)
    }
}

private struct RSSItem {
    let title: String
    let url: URL
    let summary: String?
}

/// Minimal RSS 2.0 reader (handles the <item><title>/<link>/<description> shape used by
/// every feed we curate). No dependency — just XMLParser.
private final class RSSParser: NSObject, XMLParserDelegate {
    private var items: [RSSItem] = []
    private var inItem = false
    private var current = ""
    private var title = ""
    private var link = ""
    private var summary = ""

    func parse(_ data: Data) -> [RSSItem] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return items
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String]) {
        current = elementName
        if elementName == "item" {
            inItem = true
            title = ""; link = ""; summary = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard inItem else { return }
        switch current {
        case "title": title += string
        case "link": link += string
        case "description": summary += string
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard inItem, let string = String(data: CDATABlock, encoding: .utf8) else { return }
        switch current {
        case "title": title += string
        case "link": link += string
        case "description": summary += string
        default: break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?) {
        if elementName == "item" {
            inItem = false
            let trimmedLink = link.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if let url = URL(string: trimmedLink), !trimmedTitle.isEmpty {
                items.append(RSSItem(title: trimmedTitle, url: url, summary: cleanSummary(summary)))
            }
        }
        current = ""
    }

    /// Strips HTML tags and common entities, caps length.
    private func cleanSummary(_ raw: String) -> String? {
        var text = raw
        while let range = text.range(of: "<[^>]+>", options: .regularExpression) {
            text.replaceSubrange(range, with: "")
        }
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&#8217;", with: "'")
            .replacingOccurrences(of: "&#8216;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if text.count > 240 { text = String(text.prefix(240)).trimmingCharacters(in: .whitespaces) + "…" }
        return text
    }
}

// MARK: - Mindfulness types, preferences & sources

enum MindfulnessType: String, Codable, CaseIterable, Identifiable {
    case meditation, breathwork, bodyScan, sleep

    var id: String { rawValue }

    var title: String {
        switch self {
        case .meditation: return "Meditation"
        case .breathwork: return "Breathwork"
        case .bodyScan: return "Body Scan"
        case .sleep: return "Sleep & Wind-down"
        }
    }

    var systemImage: String {
        switch self {
        case .meditation: return "leaf.fill"
        case .breathwork: return "wind"
        case .bodyScan: return "figure.mind.and.body"
        case .sleep: return "moon.stars.fill"
        }
    }
}

struct MindfulSession: Equatable {
    let title: String
    let source: String
    let url: URL
    let type: MindfulnessType
}

enum MindfulnessPreferencesStore {
    private static let key = "cuewell.mindfulness.types"
    private static var defaults: UserDefaults? { UserDefaults(suiteName: AppConstants.appGroupIdentifier) }

    static let fallbackTypes: [MindfulnessType] = MindfulnessType.allCases

    static func selectedTypes() -> [MindfulnessType] {
        guard let raw = defaults?.array(forKey: key) as? [String] else { return fallbackTypes }
        let types = raw.compactMap(MindfulnessType.init(rawValue:))
        return types.isEmpty ? fallbackTypes : types
    }

    static func save(_ types: Set<MindfulnessType>) {
        defaults?.set(types.map(\.rawValue), forKey: key)
    }
}

/// Curated free guided sessions. Static — no network needed to present; opening hands off
/// to the YouTube app or browser, and every URL points directly to a playable video.
enum MindfulnessSourceEngine {
    static func nextSession(types: [MindfulnessType] = MindfulnessPreferencesStore.selectedTypes()) -> MindfulSession {
        let pool = types.isEmpty ? MindfulnessType.allCases : types
        let type = pool.randomElement() ?? .meditation
        let sessions = catalog[type] ?? []
        return sessions.randomElement() ?? MindfulSession(
            title: "Calm with Headspace",
            source: "YouTube",
            url: URL(string: "https://www.youtube.com/watch?v=pB_qUY1dPrs")!,
            type: .meditation
        )
    }

    private static let catalog: [MindfulnessType: [MindfulSession]] = [
        .meditation: [
            session("5-minute meditation you can do anywhere", "Goodful", "https://www.youtube.com/watch?v=inpok4MKVLM", .meditation),
            session("10-minute meditation for anxiety", "Great Meditation", "https://www.youtube.com/watch?v=penUy-GhApQ", .meditation),
            session("Daily Calm guided meditations", "Calm", "https://www.youtube.com/watch?v=ZToicYcHIOU", .meditation)
        ],
        .breathwork: [
            session("Guided box breathing", "TAKE A DEEP BREATH", "https://www.youtube.com/watch?v=tEmt1Znux58", .breathwork),
            session("Wim Hof guided breathing", "Wim Hof", "https://www.youtube.com/watch?v=tybOi4hjZFQ", .breathwork),
            session("4-7-8 calming breath", "TAKE A DEEP BREATH", "https://www.youtube.com/watch?v=LiUnFJ8P4gM", .breathwork)
        ],
        .bodyScan: [
            session("Body scan meditation", "Michael Sealey", "https://www.youtube.com/watch?v=ihO02wUzgkc", .bodyScan),
            session("Guided body scan for relaxation", "The Honest Guys", "https://www.youtube.com/watch?v=QMv64migYjY", .bodyScan)
        ],
        .sleep: [
            session("Sleep meditation to fall asleep fast", "Jason Stephenson", "https://www.youtube.com/watch?v=U6Ay9v7gK9w", .sleep),
            session("Wind-down for better sleep", "The Honest Guys", "https://www.youtube.com/watch?v=49SKdW0w4KM", .sleep)
        ]
    ]

    private static func session(_ title: String, _ source: String, _ url: String, _ type: MindfulnessType) -> MindfulSession {
        MindfulSession(title: title, source: source, url: URL(string: url)!, type: type)
    }
}

// MARK: - Go Outside: on-device verification

enum OutdoorVerification: Equatable {
    case success
    case notOutdoors
    case unreadable

    var failureReason: String? {
        switch self {
        case .success: return nil
        case .notOutdoors: return "We couldn't see the outdoors here. Try a clearer shot of the sky, trees, or your street."
        case .unreadable: return "We couldn't read that photo. Give it another try."
        }
    }
}

/// Verifies a "Go Outside" photo entirely on-device (free, private). The photo is taken live in
/// Cuewell's camera, so it's guaranteed to be fresh (no camera-roll reuse of old shots); all we
/// need to confirm is that the scene actually looks like the outdoors.
enum OutdoorVerifier {
    private static let outdoorKeywords: Set<String> = [
        "outdoor", "sky", "cloud", "tree", "plant", "grass", "lawn", "garden", "park",
        "forest", "woodland", "foliage", "leaf", "flower", "nature", "landscape", "mountain",
        "hill", "valley", "field", "meadow", "beach", "coast", "ocean", "sea", "lake", "river",
        "water", "snow", "sunset", "sunrise", "street", "road", "sidewalk", "trail", "path",
        "cityscape", "skyline", "building_facade", "skyscraper"
    ]

    static func verify(_ image: UIImage) async -> OutdoorVerification {
        guard let cgImage = image.cgImage else { return .unreadable }
        return await isOutdoors(cgImage) ? .success : .notOutdoors
    }

    private static func isOutdoors(_ image: CGImage) async -> Bool {
        await withCheckedContinuation { continuation in
            let request = VNClassifyImageRequest()
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                    let observations = (request.results ?? []).filter { $0.confidence > 0.12 }
                    let hit = observations.contains { observation in
                        let identifier = observation.identifier.lowercased()
                        return outdoorKeywords.contains { identifier.contains($0) }
                    }
                    continuation.resume(returning: hit)
                } catch {
                    continuation.resume(returning: false)
                }
            }
        }
    }
}
