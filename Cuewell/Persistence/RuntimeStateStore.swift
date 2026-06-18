import Foundation

enum RuntimeStateStore {
    private static let fileName = "runtime-state.json"

    static func load() -> UnlockRuntimeState {
        guard let url = AppGroupFile.url(named: fileName) else {
            return freshState()
        }
        guard let data = try? Data(contentsOf: url) else {
            return freshState()
        }

        do {
            var state = try JSONDecoder.cuewell.decode(UnlockRuntimeState.self, from: data)
            // Roll the limit state over to today before anything reads it, then persist
            // the reset so shields from a previous day cannot linger into the new day.
            let didReset = state.resetForNewDayIfNeeded()
            state.removeExpiredUnlocks()
            if didReset {
                save(state)
            }
            return state
        } catch {
            return freshState()
        }
    }

    private static func freshState() -> UnlockRuntimeState {
        UnlockRuntimeState(dayStart: Calendar.current.startOfDay(for: Date()))
    }

    static func save(_ state: UnlockRuntimeState) {
        guard let url = AppGroupFile.url(named: fileName) else {
            return
        }
        do {
            let data = try JSONEncoder.cuewell.encode(state)
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
