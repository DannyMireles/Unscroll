import Foundation

enum RuntimeStateStore {
    private static let fileName = "runtime-state.json"

    static func load() -> UnlockRuntimeState {
        guard let url = AppGroupFile.url(named: fileName) else {
            return UnlockRuntimeState()
        }
        guard let data = try? Data(contentsOf: url) else {
            return UnlockRuntimeState()
        }

        do {
            var state = try JSONDecoder.unscroll.decode(UnlockRuntimeState.self, from: data)
            state.removeExpiredUnlocks()
            return state
        } catch {
            return UnlockRuntimeState()
        }
    }

    static func save(_ state: UnlockRuntimeState) {
        guard let url = AppGroupFile.url(named: fileName) else {
            return
        }
        do {
            let data = try JSONEncoder.unscroll.encode(state)
            try data.write(to: url, options: [.atomic])
        } catch {
            return
        }
    }

    static func update(_ mutation: (inout UnlockRuntimeState) -> Void) {
        var state = load()
        mutation(&state)
        state.removeExpiredUnlocks()
        save(state)
    }
}
