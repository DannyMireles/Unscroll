# Cuewell

Cuewell is a local-only SwiftUI iOS app that adds a quick cognitive challenge after a selected app passes a daily Screen Time limit.

## What is included

- Native Swift + SwiftUI app target.
- App Group backed Codable persistence.
- Family Activity Picker based app selection.
- Daily DeviceActivity monitoring setup.
- ManagedSettings shielding setup.
- DeviceActivity monitor extension.
- Shield action extension.
- Shield configuration extension.
- Four unlock methods:
  - Mental Math
  - Pattern Memory
  - Guided Breathing
  - Reflect
- 50 local reflection prompts.

## Build

Open `Cuewell.xcodeproj` in Xcode and build the `Cuewell` scheme.

For command-line compile validation without signing:

```sh
xcodebuild -project Cuewell.xcodeproj -scheme Cuewell -configuration Debug -destination generic/platform=iOS -derivedDataPath /tmp/CuewellDerivedData CODE_SIGNING_ALLOWED=NO build
```

## Required Apple setup

Screen Time APIs require Apple-managed capabilities before they work on a physical device:

- Add the Family Controls capability to the app target and all three extension targets.
- Create an App Group and replace `group.com.selerim.cuewell` in:
  - `Cuewell/App/AppConstants.swift`
  - all `.entitlements` files
- Update bundle identifiers and team settings in Xcode.
- Test Screen Time behavior on a real device. FamilyControls, DeviceActivity, and ManagedSettings behavior is limited or unavailable in the simulator.

## Single-use unlock behavior

iOS does not expose a reliable public callback for "the user has left the shielded third-party app." This V1 implements the closest reliable structure:

- The monitor extension marks a lock exceeded when the daily threshold is reached.
- ManagedSettings shields the selected app tokens.
- The shield action stores a pending local unlock request.
- Completing the challenge grants a short temporary unblock window.
- Shields are reapplied when the temporary unlock expires or when Cuewell becomes active again.

The Screen Time integration is intentionally isolated in `Cuewell/ScreenTime` and the extension targets so the unlock-session policy can be tightened if Apple exposes more precise session lifecycle hooks later.
