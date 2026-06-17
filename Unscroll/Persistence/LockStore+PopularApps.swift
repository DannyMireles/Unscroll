import Foundation

extension LockStore {
    /// Curated, tappable shortcuts for the most commonly-locked apps, so people can confirm
    /// the app with one tap instead of typing. Each name resolves through the launch mapping.
    static let commonAppNames: [String] = [
        "TikTok", "Instagram", "X", "YouTube", "Snapchat", "Facebook",
        "Reddit", "Threads", "WhatsApp", "Messenger", "Discord", "Twitch",
        "Pinterest", "LinkedIn", "Netflix", "Spotify", "Roblox", "BeReal"
    ]

    /// Normalized name (letters + digits only, lowercased) → URL scheme host (no `://`).
    /// Covers many common apps; unknown names still fall back to using the normalized name as a scheme guess.
    static let popularAppNameToScheme: [String: String] = {
        var m: [String: String] = [:]
        func add(_ names: String..., scheme: String) {
            for n in names {
                let k = n.lowercased().filter { $0.isLetter || $0.isNumber }
                guard !k.isEmpty else { continue }
                m[k] = scheme
            }
        }
        add("tiktok", scheme: "tiktok")
        add("instagram", scheme: "instagram")
        add("facebook", scheme: "fb")
        add("messenger", "facebookmessenger", scheme: "fb-messenger")
        add("whatsapp", scheme: "whatsapp")
        add("snapchat", scheme: "snapchat")
        add("twitter", "x", scheme: "twitter")
        add("youtube", scheme: "youtube")
        add("reddit", scheme: "reddit")
        add("twitch", scheme: "twitch")
        add("discord", scheme: "discord")
        add("telegram", scheme: "tg")
        add("linkedin", scheme: "linkedin")
        add("pinterest", scheme: "pinterest")
        add("spotify", scheme: "spotify")
        add("netflix", scheme: "nflx")
        add("hulu", scheme: "hulu")
        add("disney", "disneyplus", scheme: "disneyplus")
        add("primevideo", "amazonprime", scheme: "aiv")
        add("paramount", "paramountplus", scheme: "paramountplus")
        add("peacock", scheme: "peacock")
        add("hbo", "max", scheme: "hbomax")
        add("gmail", scheme: "googlegmail")
        add("googlemaps", "googlemapsapp", scheme: "comgooglemaps")
        add("maps", "applemaps", "map", scheme: "maps")
        add("chrome", "googlechrome", scheme: "googlechrome")
        add("google", scheme: "google")
        add("safari", scheme: "http")
        add("safarisearch", scheme: "x-web-search")
        add("amazon", "amazonshopping", scheme: "amazon")
        add("uber", scheme: "uber")
        add("lyft", scheme: "lyft")
        add("doordash", scheme: "doordash")
        add("grubhub", scheme: "grubhub")
        add("ubereats", scheme: "ubereats")
        add("cashapp", "squarecash", "cashme", scheme: "squarecash")
        add("venmo", scheme: "venmo")
        add("paypal", scheme: "paypal")
        add("zelle", scheme: "zelle")
        add("zoom", scheme: "zoomus")
        add("slack", scheme: "slack")
        add("teams", "microsoftteams", scheme: "msteams")
        add("outlook", scheme: "ms-outlook")
        add("onedrive", scheme: "ms-onedrive")
        add("word", scheme: "word")
        add("excel", scheme: "excel")
        add("powerpoint", scheme: "powerpoint")
        add("microsoftword", scheme: "ms-word")
        add("microsoftexcel", scheme: "ms-excel")
        add("microsoftpowerpoint", scheme: "ms-powerpoint")
        add("notion", scheme: "notion")
        add("chatgpt", scheme: "chatgpt")
        add("googledocs", scheme: "googledocs")
        add("dropbox", scheme: "dbapi-1")
        add("googledrive", "drive", scheme: "googledrive")
        add("googlephotos", scheme: "googlephotos")
        add("applemusic", "music", scheme: "music")
        add("audible", scheme: "audible")
        add("kindle", scheme: "kindle")
        add("pandora", scheme: "pandora")
        add("soundcloud", scheme: "soundcloud")
        add("shazam", scheme: "shazam")
        add("iheartradio", scheme: "iheartradio")
        add("roblox", scheme: "roblox")
        add("minecraft", scheme: "minecraft")
        add("fortnite", scheme: "fortnite")
        add("duolingo", scheme: "duolingo")
        add("strava", scheme: "strava")
        add("nike", "nikeapp", scheme: "nike")
        add("shein", scheme: "shein")
        add("temu", scheme: "temu")
        add("capcut", scheme: "capcut")
        add("threads", scheme: "barcelona")
        add("airbnb", scheme: "airbnb")
        add("bereal", scheme: "bereal")
        add("wechat", "weixin", scheme: "weixin")
        add("yelp", scheme: "yelp")
        add("waze", scheme: "waze")
        add("ebay", scheme: "ebay")
        add("etsy", scheme: "etsy")
        add("tinder", scheme: "tinder")
        add("bumble", scheme: "bumble")
        add("hinge", scheme: "hinge")
        add("match", scheme: "match")
        add("opentable", scheme: "opentable")
        add("starbucks", scheme: "starbucks")
        add("mcdonalds", scheme: "mcdonalds")
        add("chickfila", scheme: "chickfila")
        add("coinbase", scheme: "coinbase")
        add("robinhood", scheme: "robinhood")
        add("fidelity", scheme: "fidelity")
        add("wellsfargo", scheme: "wellsfargo")
        add("bankofamerica", scheme: "bofa")
        add("chase", scheme: "chase")
        add("citizensbank", scheme: "citizensbank")
        add("tiktokstudio", scheme: "tiktok")
        add("youtubeMusic", "youtubemusic", scheme: "youtubemusic")
        add("appleTV", "appletv", scheme: "videos")
        add("podcasts", "podcast", scheme: "podcasts")
        add("books", "applebooks", scheme: "ibooks")
        add("news", "applenews", "applenewss", scheme: "applenews")
        add("fitness", "applefitness", scheme: "fitness")
        // Apple system apps & services (scheme hosts from common AppURL references)
        add("weather", scheme: "weather")
        add("appstore", scheme: "itms-apps")
        add("classical", "applemusicclassical", scheme: "classical")
        add("calshow", "calendar", scheme: "calshow")
        add("facetime", scheme: "facetime")
        add("facetimeaudio", scheme: "facetime-audio")
        add("mail", scheme: "message")
        add("messages", scheme: "sms")
        add("notes", scheme: "mobilenotes")
        add("photos", scheme: "photos-redirect")
        add("reminders", scheme: "x-apple-reminder")
        add("shortcuts", scheme: "shortcuts")
        add("voicememos", scheme: "voicememos")
        add("wallet", scheme: "shoebox")
        add("files", scheme: "shareddocuments")
        add("gamecenter", scheme: "gamecenter")
        add("clips", scheme: "clips")
        add("garageband", scheme: "garageband")
        add("imovie", scheme: "imovie")
        add("dictionary", scheme: "dict")
        add("contacts", scheme: "contacts")
        add("findmy", "findmyiphone", scheme: "fmip1")
        add("findmyfriends", scheme: "findmyfriends")
        add("headspace", scheme: "headspace")
        add("itunesstore", scheme: "itms")
        add("remote", "itunesremote", scheme: "remote")
        add("diagnostics", scheme: "diagnostics")
        add("feedback", scheme: "applefeedback")
        add("settings", "preferences", scheme: "prefs")
        add("watch", scheme: "itms-watch")
        add("workflow", "shortcutsold", scheme: "workflow")
        // Third-party & services from common AppURL lists
        add("1password", "onepassword", scheme: "onepassword")
        add("achievement", scheme: "achievement")
        add("amc", scheme: "amc")
        add("anchor", "anchorfm", scheme: "anchorfm")
        add("ancestry", scheme: "ancestry")
        add("bloomberg", scheme: "bloomberg")
        add("brave", scheme: "brave")
        add("brushstroke", scheme: "brushstroke")
        add("cameraplus", scheme: "cameraplus")
        add("castro", scheme: "castro2")
        add("citymapper", scheme: "citymapper")
        add("clashofclans", scheme: "clashofclans")
        add("discogs", scheme: "discogs")
        add("duckduckgo", scheme: "ddgLaunch")
        add("evernote", scheme: "evernote")
        add("facetune", scheme: "facetune")
        add("fandango", scheme: "fandango")
        add("fantastical", scheme: "fantastical")
        add("firefox", scheme: "firefox")
        add("firefoxfocus", scheme: "firefox-focus")
        add("fitbit", scheme: "fitbit")
        add("flickr", scheme: "flickr")
        add("forest", scheme: "forest")
        add("gboard", scheme: "gboard")
        add("genshinimpact", "genshin", scheme: "yuanshengame")
        add("github", scheme: "github")
        add("goodreads", scheme: "goodreads")
        add("googleassistant", scheme: "googleassistant")
        add("googlecalendar", scheme: "googlecalendar")
        add("googleearth", scheme: "googleearth")
        add("googlekeep", scheme: "comgooglekeep")
        add("googlesheets", scheme: "googlesheets")
        add("googletranslate", scheme: "googletranslate")
        add("googlevoice", scheme: "googlevoice")
        add("halide", scheme: "halide")
        add("hbogo", scheme: "hbogo")
        add("hbonow", scheme: "hbonow")
        add("hyperlapse", scheme: "hyperlapse")
        add("ifttt", scheme: "ifttt")
        add("imdb", scheme: "imdb")
        add("instapaper", scheme: "instapaper")
        add("instagramstories", scheme: "instagram-stories")
        add("lastpass", scheme: "lastpass")
        add("launchcenter", scheme: "launch")
        add("litely", scheme: "litely")
        add("moviepass", scheme: "moviepass")
        add("musicharbor", scheme: "musicharbor")
        add("myq", "myliftmaster", scheme: "myliftmaster")
        add("nextcloud", scheme: "nextcloud")
        add("omnifocus", scheme: "omnifocus")
        add("onenote", scheme: "onenote")
        add("overcast", scheme: "overcast")
        add("photoscan", scheme: "photoscan")
        add("plex", scheme: "plex")
        add("pyto", scheme: "pyto-run")
        add("reframe", scheme: "reframeapp")
        add("rivian", scheme: "rivian")
        add("signal", scheme: "sgnl")
        add("sketchbook", scheme: "sketchbook")
        add("skype", scheme: "skype")
        add("speedtest", scheme: "speedtest")
        add("steller", scheme: "steller")
        add("sleeptown", scheme: "sleeptown")
        add("streets", scheme: "streets")
        add("tesla", scheme: "tesla")
        add("textastic", scheme: "textastic")
        add("things", scheme: "things")
        add("tomtom", "tomtomgo", scheme: "tomtomgo")
        add("tumblr", scheme: "tumblr")
        add("tweetbot", scheme: "tweetbot")
        add("vimeo", scheme: "vimeo")
        add("vlc", scheme: "vlc")
        add("vsco", scheme: "vsco")
        add("whereto", scheme: "whereto")
        add("workingcopy", scheme: "working-copy")
        add("eufy", "eufysecurity", scheme: "eufysecurity")
        add("bambu", "bambuhandy", scheme: "bambulab")
        add("cakebrowser", scheme: "cakeslice")
        add("blind", "teamblind", scheme: "teamblind")
        add("atlasearth", scheme: "atlas-earth")
        return m
    }()

    /// Ordered, most-reliable-first launch scheme variants for apps whose canonical
    /// "open the app" scheme isn't the obvious one. For example TikTok opens via
    /// `snssdk1233://` (its real registered scheme) — a bare `tiktok://` is unreliable and
    /// `canOpenURL` returns false for it, which previously made us fall through to the
    /// website instead of the app. We try every variant in order and launch the first one
    /// the device confirms is installed.
    static let popularAppNameToSchemeVariants: [String: [String]] = {
        var m: [String: [String]] = [:]
        func add(_ names: String..., schemes: [String]) {
            for n in names {
                let k = n.lowercased().filter { $0.isLetter || $0.isNumber }
                guard !k.isEmpty else { continue }
                m[k] = schemes
            }
        }
        add("tiktok", "tiktokstudio", schemes: ["snssdk1233", "musically", "tiktok"])
        add("youtube", schemes: ["youtube", "vnd.youtube"])
        add("twitter", "x", schemes: ["twitter"])
        add("facebook", schemes: ["fb"])
        add("messenger", "facebookmessenger", schemes: ["fb-messenger"])
        add("instagram", schemes: ["instagram"])
        add("snapchat", schemes: ["snapchat"])
        add("reddit", schemes: ["reddit"])
        add("threads", schemes: ["barcelona"])
        return m
    }()

    /// Ordered, most-reliable-first launch scheme variants keyed by bundle ID, used when
    /// the Shield extension has captured the real bundle identifier.
    static let popularBundleIDToSchemeVariants: [String: [String]] = [
        "com.zhiliaoapp.musically": ["snssdk1233", "musically", "tiktok"],
        "com.zhiliaoapp.musically.go": ["snssdk1233", "musically", "tiktok"],
        "com.google.ios.youtube": ["youtube", "vnd.youtube"],
        "com.atebits.Tweetie2": ["twitter"],
        "com.burbn.instagram": ["instagram"],
        "com.toyopagroup.picaboo": ["snapchat"],
        "com.facebook.Facebook": ["fb"],
        "com.facebook.Messenger": ["fb-messenger"],
        "com.reddit.Reddit": ["reddit"],
        "com.burbn.barcelona": ["barcelona"],
    ]

    /// Ordered launch scheme candidates for a display name (handles the variant apps above,
    /// otherwise falls back to the single best-guess scheme). Returns an empty array for
    /// generic placeholder names like "App".
    static func launchSchemes(forName name: String) -> [String] {
        guard !isGenericDisplayName(name) else { return [] }

        let normalized = name.lowercased().filter { $0.isLetter || $0.isNumber }
        if let variants = popularAppNameToSchemeVariants[normalized] {
            return variants
        }

        let parts = name.split { !$0.isLetter && !$0.isNumber }
        if let first = parts.first {
            let firstKey = String(first).lowercased().filter { $0.isLetter || $0.isNumber }
            if let variants = popularAppNameToSchemeVariants[firstKey] {
                return variants
            }
        }

        let single = suggestedScheme(for: name)
        return single.isEmpty ? [] : [single]
    }

    /// Ordered launch scheme candidates for a captured bundle identifier.
    static func launchSchemes(forBundleID bundleID: String) -> [String] {
        if let variants = popularBundleIDToSchemeVariants[bundleID] {
            return variants
        }
        if let mapped = popularBundleIDToNameAndScheme[bundleID] {
            return [mapped.scheme]
        }
        return []
    }

    /// Normalized app name → website domain, used as a universal-link launch fallback
    /// when a custom URL scheme is missing or unreliable (e.g. X / Twitter). The
    /// installed app intercepts these links; otherwise the site opens in Safari.
    static let popularAppNameToWebDomain: [String: String] = {
        var m: [String: String] = [:]
        func add(_ names: String..., domain: String) {
            for n in names {
                let k = n.lowercased().filter { $0.isLetter || $0.isNumber }
                guard !k.isEmpty else { continue }
                m[k] = domain
            }
        }
        add("tiktok", domain: "tiktok.com")
        add("instagram", domain: "instagram.com")
        add("facebook", domain: "facebook.com")
        add("messenger", "facebookmessenger", domain: "messenger.com")
        add("whatsapp", domain: "whatsapp.com")
        add("snapchat", domain: "snapchat.com")
        add("twitter", "x", domain: "x.com")
        add("youtube", domain: "youtube.com")
        add("youtubemusic", domain: "music.youtube.com")
        add("reddit", domain: "reddit.com")
        add("twitch", domain: "twitch.tv")
        add("discord", domain: "discord.com")
        add("telegram", domain: "telegram.org")
        add("linkedin", domain: "linkedin.com")
        add("pinterest", domain: "pinterest.com")
        add("spotify", domain: "open.spotify.com")
        add("netflix", domain: "netflix.com")
        add("hulu", domain: "hulu.com")
        add("disney", "disneyplus", domain: "disneyplus.com")
        add("threads", domain: "threads.net")
        add("amazon", "amazonshopping", domain: "amazon.com")
        add("ebay", domain: "ebay.com")
        add("etsy", domain: "etsy.com")
        add("yelp", domain: "yelp.com")
        add("tumblr", domain: "tumblr.com")
        add("vimeo", domain: "vimeo.com")
        add("imdb", domain: "imdb.com")
        add("duolingo", domain: "duolingo.com")
        add("github", domain: "github.com")
        add("notion", domain: "notion.so")
        add("chatgpt", domain: "chatgpt.com")
        add("googlemaps", domain: "maps.google.com")
        add("googlechrome", "chrome", domain: "google.com")
        add("gmail", domain: "mail.google.com")
        return m
    }()

    static func webDomain(for appName: String) -> String? {
        let normalized = appName.lowercased().filter { $0.isLetter || $0.isNumber }
        if let domain = popularAppNameToWebDomain[normalized] {
            return domain
        }
        let parts = appName.split { !$0.isLetter && !$0.isNumber }
        if let first = parts.first {
            let firstKey = String(first).lowercased().filter { $0.isLetter || $0.isNumber }
            if let domain = popularAppNameToWebDomain[firstKey] {
                return domain
            }
        }
        return nil
    }

    /// Known bundle IDs → (display name hint, URL scheme). Used when a single app token is selected.
    static let popularBundleIDToNameAndScheme: [String: (name: String, scheme: String)] = [
        "com.zhiliaoapp.musically": ("TikTok", "tiktok"),
        "com.burbn.instagram": ("Instagram", "instagram"),
        "com.atebits.Tweetie2": ("X", "twitter"),
        "com.toyopagroup.picaboo": ("Snapchat", "snapchat"),
        "com.google.ios.youtube": ("YouTube", "youtube"),
        "com.reddit.Reddit": ("Reddit", "reddit"),
        "com.facebook.Facebook": ("Facebook", "fb"),
        "com.facebook.Messenger": ("Messenger", "fb-messenger"),
        "net.whatsapp.WhatsApp": ("WhatsApp", "whatsapp"),
        "com.zhiliaoapp.musically.go": ("TikTok", "tiktok"),
        "com.burbn.barcelona": ("Threads", "barcelona"),
        "com.google.chrome.ios": ("Chrome", "googlechrome"),
        "com.google.Gmail": ("Gmail", "googlegmail"),
        "com.google.Maps": ("Google Maps", "comgooglemaps"),
        "com.google.ios.youtubeunplugged": ("YouTube TV", "youtube"),
        "com.spotify.client": ("Spotify", "spotify"),
        "com.netflix.Netflix": ("Netflix", "nflx"),
        "com.amazon.Amazon": ("Amazon", "amazon"),
        "com.ubercab.UberClient": ("Uber", "uber"),
        "com.lyft.ios": ("Lyft", "lyft"),
        "com.doordash.DoorDashConsumer": ("DoorDash", "doordash"),
        "com.grubhub.search": ("Grubhub", "grubhub"),
        "com.ubercab.UberEats": ("Uber Eats", "ubereats"),
        "com.squareup.cash": ("Cash App", "squarecash"),
        "com.venmo.Venmo": ("Venmo", "venmo"),
        "com.paypal.ppclient.touch": ("PayPal", "paypal"),
        "us.zoom.videomeetings": ("Zoom", "zoomus"),
        "com.tinyspeck.chatlyio": ("Slack", "slack"),
        "com.microsoft.skype.teams": ("Teams", "msteams"),
        "com.microsoft.Office.Outlook": ("Outlook", "ms-outlook"),
        "com.microsoft.skydrive": ("OneDrive", "ms-onedrive"),
        "com.apple.mobilesafari": ("Safari", "http"),
        "com.apple.Music": ("Music", "music"),
        "com.apple.tv": ("TV", "videos"),
        "com.discord.Discord": ("Discord", "discord"),
        "org.telegram.Telegram": ("Telegram", "tg"),
        "com.linkedin.LinkedIn": ("LinkedIn", "linkedin"),
        "com.pinterest": ("Pinterest", "pinterest"),
        "com.hulu.plus": ("Hulu", "hulu"),
        "com.disney.disneyplus": ("Disney+", "disneyplus"),
        "com.amazon.aiv.AIVApp": ("Prime Video", "aiv"),
        "com.roblox.RobloxMobile": ("Roblox", "roblox"),
        "com.duolingo.DuolingoMobile": ("Duolingo", "duolingo"),
        "com.strava.stravaride": ("Strava", "strava"),
        "com.nike.omega": ("Nike", "nike"),
        "com.ebay.iphone": ("eBay", "ebay"),
        "com.etsy.etsyforios": ("Etsy", "etsy"),
        "com.tinder.Tinder": ("Tinder", "tinder"),
        "com.bumble.app": ("Bumble", "bumble"),
        "com.match.match.com": ("Match", "match"),
        "com.yelp.yelpiphone": ("Yelp", "yelp"),
        "com.waze.iphone": ("Waze", "waze"),
        "com.google.Docs": ("Google Docs", "googledocs"),
        "com.google.Drive": ("Google Drive", "googledrive"),
        "com.dropbox.Dropbox": ("Dropbox", "dbapi-1"),
        "com.notion.id": ("Notion", "notion"),
        "com.openai.chat": ("ChatGPT", "chatgpt"),
        "com.openai.ChatGPT": ("ChatGPT", "chatgpt"),
        // Additional high-confidence bundle IDs and common variants.
        "tv.twitch": ("Twitch", "twitch"),
        "com.hammerandchisel.discord": ("Discord", "discord"),
        "ph.telegra.Telegraph": ("Telegram", "tg"),
        "com.pinterest.pinterest": ("Pinterest", "pinterest"),
        "com.cardify.tinder": ("Tinder", "tinder"),
        "com.getdropbox.Dropbox": ("Dropbox", "dbapi-1"),
        "notion.id": ("Notion", "notion"),
        "com.google.photos": ("Google Photos", "googlephotos"),
        "com.google.GoogleMobile": ("Google", "google"),
        "com.google.calendar": ("Google Calendar", "googlecalendar"),
        "com.tencent.xin": ("WeChat", "weixin"),
        "org.whispersystems.signal": ("Signal", "sgnl"),
        "com.einnovation.temu": ("Temu", "temu"),
        "com.lemon.lvoverseas": ("CapCut", "capcut"),
        "AlexisBarreyat.BeReal": ("BeReal", "bereal"),
        "com.skype.skype": ("Skype", "skype"),
        "com.google.ios.youtubemusic": ("YouTube Music", "youtubemusic"),
        "com.shazam.Shazam": ("Shazam", "shazam"),
        "com.soundcloud.TouchApp": ("SoundCloud", "soundcloud"),
        "com.audible.iphone": ("Audible", "audible"),
        "com.amazon.Lassen": ("Kindle", "kindle"),
        "com.google.Translate": ("Google Translate", "googletranslate"),
        "com.robinhood.release.Robinhood": ("Robinhood", "robinhood"),
        "com.coinbase.Coinbase": ("Coinbase", "coinbase"),
        "com.starbucks.mystarbucks": ("Starbucks", "starbucks"),
        "com.airbnb.app": ("Airbnb", "airbnb"),
        "com.wbd.stream": ("Max", "hbomax"),
        "com.venmo.TouchFree": ("Venmo", "venmo"),
        "com.apple.podcasts": ("Podcasts", "podcasts"),
        "com.apple.news": ("News", "applenews"),
        "com.apple.mobileslideshow": ("Photos", "photos-redirect"),
        "com.apple.AppStore": ("App Store", "itms-apps"),
        "com.apple.mobilecal": ("Calendar", "calshow"),
        "com.apple.MobileSMS": ("Messages", "sms"),
        "com.apple.mobilemail": ("Mail", "message"),
        "com.apple.Maps": ("Apple Maps", "maps"),
        "com.apple.iBooks": ("Books", "ibooks"),
    ]
}
