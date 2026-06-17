import Foundation

extension LockStore {
    /// Curated, tappable shortcuts for the most commonly-locked apps, so people can confirm
    /// the app with one tap instead of typing. Each name resolves through the launch mapping.
    static let commonAppNames: [String] = [
        "TikTok", "Instagram", "X", "YouTube", "Snapchat", "Facebook",
        "Reddit", "Threads", "WhatsApp", "Messenger", "Discord", "Twitch",
        "Pinterest", "LinkedIn", "Netflix", "Spotify", "Roblox", "BeReal"
    ]

    /// Normalized user-entered names and common aliases -> high-confidence bundle IDs.
    /// This sits ahead of App Store search so the most common locks do not depend on
    /// network order, App Store ranking, or Screen Time exposing private token details.
    static let popularAppNameToBundleID: [String: String] = {
        var m: [String: String] = [:]
        func add(_ names: String..., bundleID: String) {
            for name in names {
                let key = name.lowercased().filter { $0.isLetter || $0.isNumber }
                guard !key.isEmpty else { continue }
                m[key] = bundleID
            }
        }

        add("tiktok", "ticktok", "ticktock", "musically", bundleID: "com.zhiliaoapp.musically")
        add("instagram", "ig", bundleID: "com.burbn.instagram")
        add("x", "twitter", bundleID: "com.atebits.Tweetie2")
        add("youtube", "you tube", bundleID: "com.google.ios.youtube")
        add("youtube music", "youtubemusic", bundleID: "com.google.ios.youtubemusic")
        add("snapchat", bundleID: "com.toyopagroup.picaboo")
        add("facebook", bundleID: "com.facebook.Facebook")
        add("messenger", "facebook messenger", bundleID: "com.facebook.Messenger")
        add("whatsapp", "whats app", bundleID: "net.whatsapp.WhatsApp")
        add("reddit", bundleID: "com.reddit.Reddit")
        add("threads", bundleID: "com.instagram.barcelona")
        add("discord", bundleID: "com.hammerandchisel.discord")
        add("telegram", bundleID: "ph.telegra.Telegraph")
        add("signal", bundleID: "org.whispersystems.signal")
        add("linkedin", bundleID: "com.linkedin.LinkedIn")
        add("pinterest", bundleID: "com.pinterest.Pinterest")
        add("spotify", bundleID: "com.spotify.client")
        add("netflix", bundleID: "com.netflix.Netflix")
        add("twitch", bundleID: "tv.twitch")
        add("hulu", bundleID: "com.hulu.Plus")
        add("disney", "disney plus", "disney+", bundleID: "com.disney.disneyplus")
        add("prime video", "amazon prime video", bundleID: "com.amazon.aiv.AIVVideoApp")
        add("max", "hbo max", bundleID: "com.wbd.stream")
        add("peacock", bundleID: "com.peacocktv.peacock")
        add("paramount", "paramount+", bundleID: "com.cbs.app")
        add("amazon", "amazon shopping", bundleID: "com.amazon.Amazon")
        add("temu", bundleID: "com.einnovation.temu")
        add("shein", bundleID: "com.zzkko")
        add("ebay", bundleID: "com.ebay.iphone")
        add("etsy", bundleID: "com.etsy.etsyforios")
        add("doordash", "door dash", bundleID: "com.doordash.DoorDashConsumer")
        add("uber", bundleID: "com.ubercab.UberClient")
        add("uber eats", "ubereats", bundleID: "com.ubercab.UberEats")
        add("lyft", bundleID: "com.lyft.ios")
        add("airbnb", bundleID: "com.airbnb.app")
        add("waze", bundleID: "com.waze.iphone")
        add("apple maps", "maps", bundleID: "com.apple.Maps")
        add("google maps", bundleID: "com.google.Maps")
        add("chrome", "google chrome", bundleID: "com.google.chrome.ios")
        add("gmail", bundleID: "com.google.Gmail")
        add("google drive", "drive", bundleID: "com.google.Drive")
        add("google docs", "docs", bundleID: "com.google.Docs")
        add("google sheets", "sheets", bundleID: "com.google.Sheets")
        add("google meet", "meet", bundleID: "com.google.hangouts")
        add("zoom", bundleID: "us.zoom.videomeetings")
        add("slack", bundleID: "com.tinyspeck.chatlyio")
        add("teams", "microsoft teams", bundleID: "com.microsoft.teams")
        add("outlook", bundleID: "com.microsoft.Office.Outlook")
        add("word", "microsoft word", bundleID: "com.microsoft.Office.Word")
        add("excel", "microsoft excel", bundleID: "com.microsoft.Office.Excel")
        add("notion", bundleID: "notion.id")
        add("chatgpt", "chat gpt", bundleID: "com.openai.chat")
        add("cash app", "cashapp", bundleID: "com.squareup.cash")
        add("venmo", bundleID: "com.venmo.Venmo")
        add("paypal", "pay pal", bundleID: "com.paypal.ppclient.touch")
        add("zelle", bundleID: "com.zellepay.zelle")
        add("robinhood", bundleID: "com.robinhood.robinhood")
        add("coinbase", bundleID: "com.coinbase.Coinbase")
        add("roblox", bundleID: "com.roblox.RobloxMobile")
        add("bereal", "be real", bundleID: "com.bereal.BeReal")
        add("9gag", "ninegag", bundleID: "com.9gag.ios.mobile")
        add("chase", "chase mobile", bundleID: "com.chase")
        add("dropbox", bundleID: "com.getdropbox.Dropbox")
        add("evernote", bundleID: "com.evernote.Evernote")
        add("google", "google search", bundleID: "com.google.GoogleMobile")
        add("google earth", "earth", bundleID: "com.google.b612")
        add("google translate", "translate", bundleID: "com.google.Translate")
        add("soundhound", bundleID: "com.melodis.midomi")
        add("photomath", bundleID: "com.microblink.PhotoMath")
        add("skype", bundleID: "com.skype.skype")
        add("teamviewer", bundleID: "com.teamviewer.teamviewer")
        add("ultimate guitar", "ultimate guitar tabs", bundleID: "com.ultimateguitar.tabs100")
        add("phonto", bundleID: "com.youthhr.Phonto")
        add("things", bundleID: "com.culturedcode.ThingsTouch")
        add("photoshop express", bundleID: "com.adobe.PSMobile")
        add("etrade", "e trade", bundleID: "com.etrade.mobileproiphone")
        add("1password", "one password", bundleID: "com.agilebits.onepassword-ios")
        add("booking", "booking.com", bundleID: "com.booking.Booking")
        add("instacart", bundleID: "com.instacart.Instacart")
        add("target", bundleID: "com.target.TargetConsumer")
        add("walmart", bundleID: "com.walmart.electronics")
        add("soundcloud", bundleID: "com.soundcloud.TouchApp")
        add("shazam", bundleID: "com.shazam.Shazam")
        add("testflight", "test flight", bundleID: "com.apple.TestFlight")
        add("developer", "wwdc", bundleID: "developer.apple.wwdc-Release")
        add("safari", bundleID: "com.apple.mobilesafari")
        add("messages", "imessage", bundleID: "com.apple.MobileSMS")
        add("photos", bundleID: "com.apple.mobileslideshow")
        add("camera", bundleID: "com.apple.camera")
        add("settings", bundleID: "com.apple.Preferences")
        add("mail", bundleID: "com.apple.mobilemail")
        add("calendar", bundleID: "com.apple.mobilecal")
        add("notes", bundleID: "com.apple.mobilenotes")
        add("reminders", bundleID: "com.apple.reminders")
        add("contacts", bundleID: "com.apple.MobileAddressBook")
        add("facetime", "face time", bundleID: "com.apple.facetime")
        add("find my", "findmy", "find my iphone", bundleID: "com.apple.findmy")
        add("files", bundleID: "com.apple.DocumentsApp")
        add("calculator", bundleID: "com.apple.calculator")
        add("clock", bundleID: "com.apple.mobiletimer")
        add("weather", bundleID: "com.apple.weather")
        add("stocks", bundleID: "com.apple.stocks")
        add("health", bundleID: "com.apple.Health")
        add("fitness", bundleID: "com.apple.Fitness")
        add("freeform", bundleID: "com.apple.freeform")
        add("journal", bundleID: "com.apple.journal")
        add("home", bundleID: "com.apple.Home")
        add("wallet", "passbook", bundleID: "com.apple.Passbook")
        add("voice memos", "voicememos", bundleID: "com.apple.VoiceMemos")
        add("translate app", "apple translate", bundleID: "com.apple.Translate")
        add("books", "ibooks", "apple books", bundleID: "com.apple.iBooks")
        add("news", "apple news", bundleID: "com.apple.news")
        add("tv", "apple tv", bundleID: "com.apple.tv")
        add("watch", bundleID: "com.apple.Bridge")
        add("keynote", bundleID: "com.apple.Keynote")
        add("numbers", bundleID: "com.apple.Numbers")
        add("pages", bundleID: "com.apple.Pages")
        add("passwords", bundleID: "com.apple.Passwords")
        add("phone", bundleID: "com.apple.mobilephone")
        add("garageband", bundleID: "com.apple.mobilegarageband")
        add("imovie", bundleID: "com.apple.iMovie")
        add("clips", bundleID: "com.apple.clips")
        add("magnifier", bundleID: "com.apple.Magnifier")
        add("measure", bundleID: "com.apple.measure")
        add("sports", "apple sports", bundleID: "com.apple.sports")
        add("app store connect", "itunes connect", bundleID: "com.apple.AppStoreConnect")
        add("music", "apple music", bundleID: "com.apple.Music")
        add("podcasts", bundleID: "com.apple.podcasts")
        add("app store", "appstore", bundleID: "com.apple.AppStore")
        add("shortcuts", bundleID: "com.apple.shortcuts")
        return m
    }()

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
        add("tiktok", "ticktok", "ticktock", scheme: "snssdk1233")
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
        add("googlesearch", scheme: "google")
        add("googleearth", scheme: "comgoogleearth")
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
        add("booking", "bookingcom", scheme: "booking")
        add("instacart", scheme: "instacart")
        add("target", scheme: "target")
        add("walmart", scheme: "walmart")
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
        add("tiktokstudio", scheme: "snssdk1233")
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
        add("calculator", scheme: "calc")
        add("camera", scheme: "camera")
        add("clock", scheme: "clock")
        add("health", scheme: "x-apple-health")
        add("home", scheme: "home")
        add("journal", scheme: "moments")
        add("keynote", scheme: "keynote")
        add("numbers", scheme: "numbers")
        add("pages", scheme: "pages")
        add("phone", scheme: "mobilephone")
        add("testflight", "testflightapp", scheme: "itms-beta")
        add("translateapp", "appletranslate", scheme: "translate")
        // Third-party & services from common AppURL lists
        add("9gag", "ninegag", scheme: "ninegag")
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
        add("chase", "chasemobile", scheme: "chase")
        add("etrade", "etrademobile", scheme: "etrade")
        add("photomath", scheme: "photomath")
        add("teamviewer", scheme: "teamviewer")
        add("things", scheme: "things")
        add("ultimateguitar", "ultimateguitartabs", scheme: "ultimateguitar")
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
        add("tiktok", "ticktok", "ticktock", "tiktokstudio", schemes: ["snssdk1233", "musically", "tiktok"])
        add("youtube", schemes: ["youtube", "vnd.youtube"])
        add("twitter", "x", schemes: ["twitter"])
        add("facebook", schemes: ["fb"])
        add("messenger", "facebookmessenger", schemes: ["fb-messenger"])
        add("instagram", schemes: ["instagram"])
        add("snapchat", schemes: ["snapchat"])
        add("reddit", schemes: ["reddit"])
        add("threads", schemes: ["barcelona"])
        add("whatsapp", schemes: ["whatsapp"])
        add("discord", schemes: ["discord"])
        add("linkedin", schemes: ["linkedin"])
        add("pinterest", schemes: ["pinterest"])
        add("spotify", schemes: ["spotify"])
        add("netflix", schemes: ["nflx"])
        add("twitch", schemes: ["twitch"])
        add("zoom", schemes: ["zoomus"])
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
        "com.instagram.barcelona": ["barcelona"],
        "net.whatsapp.WhatsApp": ["whatsapp"],
        "com.hammerandchisel.discord": ["discord"],
        "com.discord.Discord": ["discord"],
        "ph.telegra.Telegraph": ["tg"],
        "org.telegram.Telegram": ["tg"],
        "org.whispersystems.signal": ["sgnl"],
        "com.linkedin.LinkedIn": ["linkedin"],
        "com.pinterest.Pinterest": ["pinterest"],
        "com.pinterest.pinterest": ["pinterest"],
        "com.spotify.client": ["spotify"],
        "com.netflix.Netflix": ["nflx"],
        "tv.twitch": ["twitch"],
        "us.zoom.videomeetings": ["zoomus"],
        "com.google.ios.youtubemusic": ["youtubemusic"],
        "com.google.chrome.ios": ["googlechrome"],
        "com.google.Maps": ["comgooglemaps"],
        "com.google.Gmail": ["googlegmail"],
        "com.squareup.cash": ["squarecash"],
        "com.venmo.venmo": ["venmo"],
        "com.venmo.Venmo": ["venmo"],
        "com.paypal.ppclient.touch": ["paypal"],
        "com.skype.skype": ["skype"],
        "com.apple.mobilesafari": ["http"],
        "com.apple.MobileSMS": ["sms"],
        "com.apple.Maps": ["maps"],
        "com.apple.Music": ["music"],
        "com.apple.AppStore": ["itms-apps"],
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
        add("tiktok", "ticktok", "ticktock", domain: "tiktok.com")
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
        "com.zhiliaoapp.musically": ("TikTok", "snssdk1233"),
        "com.burbn.instagram": ("Instagram", "instagram"),
        "com.atebits.Tweetie2": ("X", "twitter"),
        "com.toyopagroup.picaboo": ("Snapchat", "snapchat"),
        "com.google.ios.youtube": ("YouTube", "youtube"),
        "com.reddit.Reddit": ("Reddit", "reddit"),
        "com.facebook.Facebook": ("Facebook", "fb"),
        "com.facebook.Messenger": ("Messenger", "fb-messenger"),
        "net.whatsapp.WhatsApp": ("WhatsApp", "whatsapp"),
        "com.zhiliaoapp.musically.go": ("TikTok", "snssdk1233"),
        "com.burbn.barcelona": ("Threads", "barcelona"),
        "com.instagram.barcelona": ("Threads", "barcelona"),
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
        "com.yourcompany.PPClient": ("PayPal", "paypal"),
        "com.zellepay.zelle": ("Zelle", "zelle"),
        "com.robinhood.robinhood": ("Robinhood", "robinhood"),
        "us.zoom.videomeetings": ("Zoom", "zoomus"),
        "com.tinyspeck.chatlyio": ("Slack", "slack"),
        "com.microsoft.skype.teams": ("Teams", "msteams"),
        "com.microsoft.teams": ("Teams", "msteams"),
        "com.microsoft.Office.Outlook": ("Outlook", "ms-outlook"),
        "com.microsoft.Office.Word": ("Word", "ms-word"),
        "com.microsoft.Office.Excel": ("Excel", "ms-excel"),
        "com.microsoft.skydrive": ("OneDrive", "ms-onedrive"),
        "com.apple.mobilesafari": ("Safari", "http"),
        "com.apple.Music": ("Music", "music"),
        "com.apple.tv": ("TV", "videos"),
        "com.discord.Discord": ("Discord", "discord"),
        "org.telegram.Telegram": ("Telegram", "tg"),
        "com.linkedin.LinkedIn": ("LinkedIn", "linkedin"),
        "com.pinterest": ("Pinterest", "pinterest"),
        "com.pinterest.Pinterest": ("Pinterest", "pinterest"),
        "com.hulu.plus": ("Hulu", "hulu"),
        "com.hulu.Plus": ("Hulu", "hulu"),
        "com.disney.disneyplus": ("Disney+", "disneyplus"),
        "com.amazon.aiv.AIVApp": ("Prime Video", "aiv"),
        "com.amazon.aiv.AIVVideoApp": ("Prime Video", "aiv"),
        "com.peacocktv.peacock": ("Peacock", "peacock"),
        "com.cbs.app": ("Paramount+", "paramountplus"),
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
        "com.google.Sheets": ("Google Sheets", "googlesheets"),
        "com.google.hangouts": ("Google Meet", "googlemeet"),
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
        "com.zzkko": ("SHEIN", "shein"),
        "com.target.TargetConsumer": ("Target", "target"),
        "com.walmart.electronics": ("Walmart", "walmart"),
        "com.instacart.Instacart": ("Instacart", "instacart"),
        "com.lemon.lvoverseas": ("CapCut", "capcut"),
        "AlexisBarreyat.BeReal": ("BeReal", "bereal"),
        "com.bereal.BeReal": ("BeReal", "bereal"),
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
        "com.9gag.ios.mobile": ("9GAG", "ninegag"),
        "com.chase": ("Chase", "chase"),
        "com.evernote.Evernote": ("Evernote", "evernote"),
        "com.gamestop.powerup": ("GameStop", "gamestop"),
        "com.google.b612": ("Google Earth", "comgoogleearth"),
        "com.googlecode.mobileterminal.Terminal": ("Terminal", "terminal"),
        "com.melodis.midomi": ("SoundHound", "soundhound"),
        "com.microblink.PhotoMath": ("PhotoMath", "photomath"),
        "com.microsoft.xboxavatars": ("Xbox", "xbox"),
        "com.ookla.speedtest": ("Speedtest", "speedtest"),
        "com.oovoo.iphone.free": ("Oovoo", "oovoo"),
        "com.teamviewer.teamviewer": ("TeamViewer", "teamviewer"),
        "com.ultimateguitar.tabs100": ("Ultimate Guitar", "ultimateguitar"),
        "com.youthhr.Phonto": ("Phonto", "phonto"),
        "developer.apple.wwdc": ("Developer", "developer"),
        "developer.apple.wwdc-Release": ("Developer", "developer"),
        "com.cogitap.SlowShutter": ("Slow Shutter", "slowshutter"),
        "com.cateater.funapps.stopmotion": ("Stop Motion", "stopmotion"),
        "com.taptaptap.cloudphotos": ("Camera+", "cameraplus"),
        "com.facebook.Groups": ("Facebook Groups", "fb"),
        "com.apple.TestFlight": ("TestFlight", "itms-beta"),
        "com.culturedcode.ThingsTouch": ("Things", "things"),
        "com.adobe.PSMobile": ("Photoshop Express", "photoshop"),
        "com.etrade.mobileproiphone": ("E*TRADE", "etrade"),
        "fm.ask.askfm": ("Ask.fm", "askfm"),
        "com.agilebits.onepassword-ios": ("1Password", "onepassword"),
        "com.apple.AppStoreConnect": ("App Store Connect", "itms-apps"),
        "com.apple.itunesconnect.mobile": ("App Store Connect", "itms-apps"),
        "com.foap.foap": ("Foap", "foap"),
        "com.remotemouse.remoteMouse": ("Remote Mouse", "remotemouse"),
        "com.ketchapp.circlethedot": ("Circle the Dot", "circlethedot"),
        "com.google.GooglePlus": ("Google+", "google"),
        "com.plainvanillacorp.quizup": ("QuizUp", "quizup"),
        "com.apple.calculator": ("Calculator", "calc"),
        "com.apple.camera": ("Camera", "camera"),
        "com.apple.facetime": ("FaceTime", "facetime"),
        "com.apple.gamecenter": ("Game Center", "gamecenter"),
        "com.apple.Health": ("Health", "x-apple-health"),
        "com.apple.iMovie": ("iMovie", "imovie"),
        "com.apple.MobileAddressBook": ("Contacts", "contacts"),
        "com.apple.mobileme.fmip1": ("Find My", "fmip1"),
        "com.apple.mobilenotes": ("Notes", "mobilenotes"),
        "com.apple.MobileStore": ("iTunes Store", "itms"),
        "com.apple.mobiletimer": ("Clock", "clock"),
        "com.apple.Passbook": ("Wallet", "shoebox"),
        "com.apple.reminders": ("Reminders", "x-apple-reminder"),
        "com.apple.Remote": ("Remote", "remote"),
        "com.apple.stocks": ("Stocks", "stocks"),
        "com.apple.tips": ("Tips", "tips"),
        "com.apple.videos": ("Videos", "videos"),
        "com.apple.VoiceMemos": ("Voice Memos", "voicememos"),
        "com.apple.weather": ("Weather", "weather"),
        "com.apple.DocumentsApp": ("Files", "shareddocuments"),
        "com.apple.findmy": ("Find My", "fmip1"),
        "com.apple.Fitness": ("Fitness", "fitness"),
        "com.apple.freeform": ("Freeform", "freeform"),
        "com.apple.Home": ("Home", "home"),
        "com.apple.journal": ("Journal", "moments"),
        "com.apple.Keynote": ("Keynote", "keynote"),
        "com.apple.Magnifier": ("Magnifier", "magnifier"),
        "com.apple.measure": ("Measure", "measure"),
        "com.apple.Numbers": ("Numbers", "numbers"),
        "com.apple.Pages": ("Pages", "pages"),
        "com.apple.Passwords": ("Passwords", "passwords"),
        "com.apple.mobilephone": ("Phone", "mobilephone"),
        "com.apple.shortcuts": ("Shortcuts", "shortcuts"),
        "com.apple.sports": ("Sports", "sports"),
        "com.apple.Translate": ("Translate", "translate"),
        "com.apple.Bridge": ("Watch", "itms-watch"),
        "com.apple.mobilegarageband": ("GarageBand", "garageband"),
        "com.apple.clips": ("Clips", "clips"),
        "com.apple.music.classical": ("Classical", "classical"),
        "com.apple.store.Jolly": ("Apple Store", "applestore"),
        "com.lyft.passenger": ("Lyft", "lyft"),
        "com.booking.Booking": ("Booking.com", "booking"),
        "com.venmo.venmo": ("Venmo", "venmo"),
        "com.hbo.hbonow": ("Max", "hbomax"),
    ]

    struct AppStoreResolvedApp: Equatable {
        let displayName: String
        let bundleID: String
        let launchSchemes: [String]
    }

    static func resolveAppStoreApp(named rawName: String) async -> AppStoreResolvedApp? {
        let term = cleanAppStoreDisplayName(rawName, fallback: rawName)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty, !isGenericDisplayName(term) else { return nil }

        if let known = resolveKnownCatalogApp(named: term) {
            NSLog(
                "🌐 Unscroll catalog resolved '%@' -> '%@' bundle=%@ scheme=%@",
                term,
                known.displayName,
                known.bundleID,
                known.launchSchemes.first ?? "nil"
            )
            return known
        }

        var components = URLComponents(string: "https://itunes.apple.com/search")
        components?.queryItems = [
            URLQueryItem(name: "limit", value: "25"),
            URLQueryItem(name: "media", value: "software"),
            URLQueryItem(name: "entity", value: "software"),
            URLQueryItem(name: "term", value: term),
            URLQueryItem(name: "country", value: Locale.current.region?.identifier ?? "US"),
            URLQueryItem(name: "lang", value: "en-us")
        ]
        guard let url = components?.url else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(AppStoreSearchResponse.self, from: data)
            guard let best = response.results.max(by: {
                scoreAppStoreResult($0, term: term) < scoreAppStoreResult($1, term: term)
            }) else {
                return nil
            }

            let schemes = launchSchemes(forBundleID: best.bundleId) + launchSchemes(forName: best.trackName)
            let uniqueSchemes = schemes.reduce(into: [String]()) { result, scheme in
                guard !result.contains(scheme) else { return }
                result.append(scheme)
            }

            NSLog(
                "🌐 Unscroll App Store lookup '%@' -> '%@' bundle=%@ score=%d",
                term,
                best.trackName,
                best.bundleId,
                scoreAppStoreResult(best, term: term)
            )

            return AppStoreResolvedApp(
                displayName: cleanAppStoreDisplayName(best.trackName, fallback: term),
                bundleID: best.bundleId,
                launchSchemes: uniqueSchemes
            )
        } catch {
            NSLog("🌐 Unscroll App Store lookup failed '%@': %@", term, String(describing: error))
            return nil
        }
    }

    static func resolveKnownCatalogApp(named rawName: String) -> AppStoreResolvedApp? {
        let term = cleanAppStoreDisplayName(rawName, fallback: rawName)
        let termKey = normalizedCatalogKey(term)
        guard !termKey.isEmpty else { return nil }

        if let bundleID = popularAppNameToBundleID[termKey],
           let mapped = popularBundleIDToNameAndScheme[bundleID] {
            return resolvedCatalogApp(bundleID: bundleID, mapped: mapped)
        }

        if let match = popularBundleIDToNameAndScheme.first(where: { element in
            normalizedCatalogKey(element.value.name) == termKey
        }) {
            return resolvedCatalogApp(bundleID: match.key, mapped: match.value)
        }

        if let match = popularBundleIDToNameAndScheme.first(where: { element in
            let nameKey = normalizedCatalogKey(element.value.name)
            return nameKey.count > 3 && (termKey.contains(nameKey) || nameKey.contains(termKey))
        }) {
            return resolvedCatalogApp(bundleID: match.key, mapped: match.value)
        }

        return nil
    }

    private static func resolvedCatalogApp(
        bundleID: String,
        mapped: (name: String, scheme: String)
    ) -> AppStoreResolvedApp {
        var schemes = launchSchemes(forBundleID: bundleID) + launchSchemes(forName: mapped.name)
        if !mapped.scheme.isEmpty {
            schemes.insert(mapped.scheme, at: 0)
        }
        let uniqueSchemes = schemes.reduce(into: [String]()) { result, scheme in
            guard !result.contains(scheme) else { return }
            result.append(scheme)
        }
        return AppStoreResolvedApp(
            displayName: mapped.name,
            bundleID: bundleID,
            launchSchemes: uniqueSchemes
        )
    }

    static func cleanAppStoreDisplayName(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let noDash = trimmed.components(separatedBy: " - ").first ?? trimmed
        let noColon = noDash.components(separatedBy: ":").first ?? noDash
        let cleaned = noColon.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? fallback : cleaned
    }

    private static func scoreAppStoreResult(_ result: AppStoreSearchResult, term: String) -> Int {
        let termKey = normalizedCatalogKey(term)
        let titleKey = normalizedCatalogKey(cleanAppStoreDisplayName(result.trackName, fallback: result.trackName))
        var score = 0

        if let known = popularBundleIDToNameAndScheme[result.bundleId] {
            let knownKey = normalizedCatalogKey(known.name)
            if knownKey == termKey { score += 500 }
            if knownKey.contains(termKey) || termKey.contains(knownKey) { score += 160 }
        }
        if titleKey == termKey { score += 260 }
        if titleKey.hasPrefix(termKey) || termKey.hasPrefix(titleKey) { score += 120 }
        if titleKey.contains(termKey) || termKey.contains(titleKey) { score += 80 }
        if result.trackName.localizedCaseInsensitiveContains(term) { score += 60 }
        score += min(result.userRatingCount ?? 0, 5_000_000) / 100_000

        let noisyFragments = ["follower", "hashtag", "save", "repost", "likes", "tracker", "analytics", "wallpaper"]
        let lowerTitle = result.trackName.lowercased()
        if noisyFragments.contains(where: { lowerTitle.contains($0) }) {
            score -= 220
        }
        return score
    }

    private static func normalizedCatalogKey(_ value: String) -> String {
        value.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}

private struct AppStoreSearchResponse: Decodable {
    let results: [AppStoreSearchResult]
}

private struct AppStoreSearchResult: Decodable {
    let trackName: String
    let bundleId: String
    let userRatingCount: Int?
}
