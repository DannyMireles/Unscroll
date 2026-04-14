import Foundation

enum RuntimeStateStore {
    private static let fileName = "runtime-state.json"
    private static let logPrefix = "[UnscrollDebug][RuntimeStateStore]"

    private static func log(_ message: String) {
        NSLog("\(logPrefix) \(message)")
    }

    static func load() -> UnlockRuntimeState {
        guard let url = AppGroupFile.url(named: fileName) else {
            log("load: missing app-group container; returning default state")
            return UnlockRuntimeState()
        }
        guard let data = try? Data(contentsOf: url) else {
            log("load: no file at \(url.path); returning default state")
            return UnlockRuntimeState()
        }

        do {
            var state = try JSONDecoder.unscroll.decode(UnlockRuntimeState.self, from: data)
            state.removeExpiredUnlocks()
            log("load: success from \(url.path); \(state.debugSummary)")
            return state
        } catch {
            log("load: decode failed from \(url.path); error=\(error)")
            assertionFailure("Failed to decode runtime state: \(error)")
            return UnlockRuntimeState()
        }
    }

    static func save(_ state: UnlockRuntimeState) {
        guard let url = AppGroupFile.url(named: fileName) else {
            log("save: missing app-group container; dropping save")
            return
        }
        do {
            let data = try JSONEncoder.unscroll.encode(state)
            try data.write(to: url, options: [.atomic])
            log("save: success to \(url.path); \(state.debugSummary)")
        } catch {
            log("save: failed to \(url.path); error=\(error)")
            assertionFailure("Failed to save runtime state: \(error)")
        }
    }

    static func update(_ mutation: (inout UnlockRuntimeState) -> Void) {
        var state = load()
        let before = state.debugSummary
        mutation(&state)
        state.removeExpiredUnlocks()
        let after = state.debugSummary
        log("update: before={\(before)} after={\(after)}")
        save(state)
    }
}
