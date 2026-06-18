# Cuewell RevenueCat And Launch Handoff

This document has two jobs:

1. Give another Codex agent a complete implementation prompt for the Cuewell product, RevenueCat, paywall, and launch-readiness changes.
2. Define the company/product direction and the low-spend marketing plan for the first 30-60 days.

## Product Direction

Cuewell is the first paid product in a small portfolio of lightweight behavior-change apps. The company direction is to build calm, privacy-respecting tools that turn impulsive digital habits into intentional actions.

The first product is Cuewell:

- Mission: help people keep the apps they like without opening them automatically.
- Promise: Cuewell does not ban your apps. It adds a small mental speed bump before you scroll.
- Core line: Train your mind. Earn your scroll.
- Category: screen-time friction, habit interruption, intentional app use.
- Business model: freemium iOS app with RevenueCat-managed in-app subscriptions.
- Privacy posture: local-first. No account required. No backend in V1.

Future products can follow this pattern once Cuewell proves the loop:

- ViaSync: social calendar/travel coordination, free-first network product.
- BirdCherry: casual social birdwatching, low-spend hobby product.
- Looprail: internal growth operating system used to produce, schedule, and learn from content across the portfolio.

Cuewell is the first focus because purchase intent is clearest and the app can launch without a backend.

## Copy/Paste Codex Implementation Prompt

Use this prompt with another Codex agent after the current repo work is finished.

```text
You are working in /Users/danielmireles/Desktop/SelerimProjects/Cuewell.

Goal:
Prepare Cuewell for a low-cost paid launch with RevenueCat, a coherent free/pro product model, a clean paywall, restore purchases, privacy-safe local behavior, and a shareable progress loop. Do not add a custom backend.

Important context:
- Cuewell is a SwiftUI iOS app using Apple's Screen Time APIs: FamilyControls, ManagedSettings, DeviceActivity, and Shield extensions.
- The app is currently local-first with App Group persistence.
- Keep the privacy posture: selected apps, progress, and lock data stay on device.
- RevenueCat should manage purchases and entitlements. Do not introduce Supabase, Firebase Auth, a custom account system, or a server.
- There may be existing uncommitted changes. Read the repo and work with current code. Do not revert unrelated user/agent edits.
- Use apply_patch for manual file edits.

Product positioning:
- Mission: help people keep the apps they like without opening them automatically.
- Main tagline: Train your mind. Earn your scroll.
- Supporting line: Keep the apps you love. Break the reflex.
- Product angle: a small mental speed bump before scrolling, not a punishment or parental-control app.

RevenueCat model:
- Entitlement id: Cuewell Pro
- Offering id: default
- Products to configure in App Store Connect / RevenueCat:
  - monthly
  - yearly
  - lifetime
- Launch prices:
  - Monthly: $4.99
  - Annual: $29.99
  - Lifetime: $79.99
- The app should compile and remain usable if the RevenueCat API key is not configured. In that case, show a clear nonfatal paywall error and keep free-tier behavior.

Implementation requirements:

1. Add RevenueCat SDK
   - Add RevenueCat Purchases using Swift Package Manager.
   - Prefer the official SPM mirror URL:
     https://github.com/RevenueCat/purchases-ios-spm.git
   - Add the package only to the main Cuewell app target, not the Screen Time extensions unless there is a proven need.
   - Do not put a private secret in source. RevenueCat public iOS API keys are acceptable in app config, but structure the code so the key is easy to replace before release.
   - Use an Info.plist value such as RevenueCatAPIKey, or a small RevenueCatConfig.swift with an obvious placeholder. The app must not crash if the key is missing.

2. Add purchase state architecture
   - Create a small purchase layer, for example:
     - Cuewell/Purchases/PurchaseManager.swift
     - Cuewell/Purchases/PurchaseState.swift
     - Cuewell/Purchases/PurchaseManager.swift
     - Cuewell/Purchases/RevenueCatConfig.swift
   - Expose a main-actor ObservableObject with:
     - isConfigured
     - isPro
     - isLoading
     - currentOffering/packages
     - lastErrorMessage
     - configure()
     - refreshCustomerInfo()
     - purchase(package:)
     - restorePurchases()
   - Check entitlement `Cuewell Pro` from CustomerInfo.
   - Cache the last known `isPro` in UserDefaults/AppStorage so the UI does not flicker, but always refresh from RevenueCat when available.
   - Use anonymous RevenueCat app user IDs. Do not add login.

3. Wire purchase state into app launch
   - Instantiate the purchase manager in CuewellApp.
   - Configure it once on app launch.
   - Inject it into SwiftUI environment.
   - Keep Screen Time setup independent from purchases; purchase failures must not break lock enforcement.

4. Add free/pro gating
   - Free users can create and use one active lock.
   - Pro users can create unlimited locks.
   - Free users should still experience the core value before being asked to pay.
   - Show the paywall when a free user attempts to create a second lock.
   - Gate at least one premium capability behind Pro:
     - Random Mix challenge, or
     - Rest-of-day unlock mode, or
     - advanced stats/history if implemented.
   - Keep existing locks working if the user downgrades, but prevent creating additional locks beyond the free limit. If needed, show a clear upgrade prompt rather than deleting anything.

5. Add a native paywall
   - Create a SwiftUI paywall view that works without remote RevenueCat paywalls.
   - It should use the local brand language:
     - Title: Earn your scroll.
     - Subtitle: Add intentional friction to the apps you open on autopilot.
   - Benefits:
     - Unlimited app locks
     - All unlock challenges
     - Random Mix
     - Shareable progress
     - Private by design
   - Display monthly, annual, and lifetime packages from the RevenueCat offering.
   - Emphasize annual as best value.
   - Include:
     - Continue / purchase button
     - Restore Purchases
     - Terms link placeholder
     - Privacy link placeholder
     - Dismiss button if paywall is not mandatory
   - Handle purchase cancellation without showing a scary error.
   - Handle missing offerings with a calm retry state.

6. Add restore purchases access
   - Add Restore Purchases somewhere discoverable:
     - Paywall footer, and
     - a small Account/Pro section on Home or a simple Settings sheet.
   - After restore, refresh `isPro` and dismiss paywall if the entitlement is active.

7. Clean up challenge naming and copy
   - Keep existing raw values if changing them could break Codable persistence.
   - The `reflect` case currently acts like a Spanish word challenge. Keep the raw value if needed, but make displayed copy coherent:
     - Title: Spanish Word
     - Short title: Spanish
     - Description: Learn one quick Spanish word before you continue.
   - Make Random Mix sound intentional:
     - Title: Random Mix
     - Short title: Mix
     - Description: Get a different quick challenge each time.
   - Check AddLockView, LockCard, UnlockFlowView, and any method preview copy for consistency.

8. Add a shareable progress card
   - Add a simple local progress-share feature using SwiftUI ImageRenderer or an equivalent iOS-supported approach.
   - The share card should include:
     - Cuewell logo/name
     - Sessions paused today
     - Minutes earned today
     - Current streak
     - Tagline: Train your mind. Earn your scroll.
   - Do not include selected app names by default. Keep it privacy-safe.
   - Add a Share button to the TodayProgressCard or nearby.
   - Use the system share sheet.
   - If image export is too risky for the current iOS target, ship text sharing first and leave a clear TODO for image sharing.

9. Add a lightweight launch/settings surface
   - Add a small status surface on Home:
     - Current plan: Free or Pro
     - Upgrade / Manage / Restore action
   - Do not add account login.
   - Include copy reinforcing local-first privacy.

10. Add launch-safe analytics only if simple
   - Do not add a third-party analytics SDK in this pass.
   - Rely on App Store Connect and RevenueCat for launch metrics.
   - Optionally add local debug logging around:
     - Screen Time permission granted
     - first lock created
     - first unlock completed
     - paywall shown
     - purchase completed
   - Never log selected app names in production.

11. App Store release readiness
   - Add or update a privacy policy link placeholder in documentation.
   - Add a checklist in README or docs for:
     - Family Controls distribution entitlement
     - App Group configured for app and all extensions
     - RevenueCat API key set
     - App Store Connect products created
     - RevenueCat products/offering/entitlement configured
     - Restore purchases tested
     - Real-device Screen Time behavior tested
   - Do not hardcode claims that the app blocks usage perfectly. Screen Time can be disabled by the device owner, so copy should frame Cuewell as intentional friction, not absolute enforcement.

12. Verification
   - Run a command-line build if possible:
     xcodebuild -project Cuewell.xcodeproj -scheme Cuewell -configuration Debug -destination generic/platform=iOS -derivedDataPath /tmp/CuewellDerivedData CODE_SIGNING_ALLOWED=NO build
   - If RevenueCat SPM resolution requires network and fails, document the exact failure.
   - If Xcode signing/capabilities block command-line verification, report that clearly and still verify code structure as much as possible.
   - Test the app manually on a real device before release because FamilyControls, DeviceActivity, and ManagedSettings behavior is limited in Simulator.

Non-goals:
- Do not create a backend.
- Do not add login.
- Do not sync locks across devices.
- Do not expose selected app names to any server.
- Do not build an elaborate analytics stack.
- Do not refactor unrelated Screen Time internals unless required for paywall integration.

Expected outcome:
- Free users can install, grant Screen Time permission, create one lock, hit their limit, complete a challenge, and understand the product.
- Users who want more than one lock or premium challenge behavior see a clean paywall.
- Purchases and restores work through RevenueCat.
- The app remains local-first and privacy coherent.
- The build passes or any blocker is clearly documented.
```

## RevenueCat Setup Checklist

Do this outside the codebase before or during implementation.

1. Create a RevenueCat project named `Cuewell`.
2. Add the iOS app.
3. Copy the iOS public SDK API key into the app config.
4. In App Store Connect, create the in-app purchases:
   - `monthly`
   - `yearly`
   - `lifetime`
5. In RevenueCat, import or create matching products.
6. Create entitlement `Cuewell Pro`.
7. Create offering `default`.
8. Attach the monthly, yearly, and lifetime products to the offering.
9. Add App Store Connect API key to RevenueCat if you want product import and cleaner operations.
10. Test purchase and restore through sandbox/TestFlight.

Useful references:

- RevenueCat iOS install: https://www.revenuecat.com/docs/getting-started/installation/ios
- RevenueCat SDK configuration: https://www.revenuecat.com/docs/getting-started/configuring-sdk
- RevenueCat customer info and entitlement status: https://www.revenuecat.com/docs/customers/customer-info
- RevenueCat restore behavior: https://www.revenuecat.com/docs/projects/restore-behavior
- RevenueCat pricing: https://www.revenuecat.com/pricing
- Apple Small Business Program: https://developer.apple.com/app-store/small-business-program/
- Apple Family Controls entitlement: https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement

## Backend Decision

Do not build a backend for Cuewell V1.

RevenueCat can handle anonymous purchase state and restore purchases. A backend would add auth, support, privacy, and maintenance burden before the product has traction.

Use this architecture for V1:

- Device: locks, selected apps, unlock history, streaks, settings.
- RevenueCat: subscription status, purchases, restore purchases, revenue dashboard.
- App Store Connect: install, conversion, and product page analytics.
- Looprail: content operations, publishing, and weekly learnings.

Add a backend later only if a proven need appears:

- account-based cross-device sync
- web checkout
- referral attribution beyond App Store basics
- team/family plans
- server-side analytics or lifecycle email

## Free And Pro Packaging

Free should prove the value. Pro should expand the value.

Free:

- One active app lock.
- Basic daily limit.
- One or two unlock methods.
- Today stats.
- Restore purchases.
- Privacy/local-first behavior.

Pro:

- Unlimited app locks.
- All challenge methods.
- Random Mix.
- Rest-of-day unlock option.
- Shareable progress card.
- Future: challenge difficulty, history, widgets, custom challenge packs.

Initial prices:

- Monthly: $4.99.
- Annual: $29.99.
- Lifetime: $79.99.

Pricing principle:

- Annual is the primary offer.
- Monthly exists for comparison and low-commitment buyers.
- Lifetime gives early adopters a simple purchase path and cash collection.

## App Store Positioning

Primary category language:

- Screen time friction.
- Habit interruption.
- Intentional scrolling.
- Mindful app access.

Avoid relying only on "blocker" language. The app is not strongest as a hard blocker. It is strongest as a speed bump for autopilot behavior.

Short description:

> Cuewell adds a quick mental challenge before the apps you open on autopilot, helping you keep the apps you like while breaking the reflex to scroll.

App Store subtitle ideas:

- Earn your scroll.
- Break the scroll reflex.
- A speed bump for scrolling.
- Train before you scroll.
- Intentional screen time.

App Store screenshot sequence:

1. Pick the app you open on autopilot.
2. Set a daily limit.
3. Hit the limit and get a quick challenge.
4. Solve math, memory, breathing, or Spanish word.
5. Earn a short unlock and keep control.
6. Track your intentional sessions.

## Brand And Company Language

Company mission:

> Build calm tools that help people turn impulsive digital loops into intentional moments.

Cuewell mission:

> Help people keep the apps they like without opening them automatically.

Brand values:

- Private by design.
- Gentle friction over shame.
- Useful before paid.
- Small daily wins.
- Clear, quiet, reliable software.

Tone:

- Plainspoken.
- Calm.
- No guilt.
- No hustle-productivity language.
- No exaggerated claims.

Core taglines:

- Train your mind. Earn your scroll.
- Keep the apps. Break the reflex.
- A speed bump for doomscrolling.
- Learn before you scroll.
- The app that makes TikTok ask you a question.

Avoid:

- "Never waste time again."
- "Cure phone addiction."
- "Block anything forever."
- "Fix your life."

## Looprail Marketing Operating Plan

Use Looprail as the internal growth control plane for Cuewell. The goal is to build the content machine before paid spend.

Accounts to create:

- TikTok
- Instagram
- YouTube Shorts
- Facebook Reels

Preferred handles:

- `getcuewell`
- `cuewellapp`
- `earnyourscroll`
- `trycuewell`

Profile bio options:

- Keep the apps. Break the reflex.
- A tiny challenge before you scroll.
- Train your mind. Earn your scroll.

Link:

- Use the App Store URL when live.
- Before launch, use a simple landing page or TestFlight signup link.

Looprail should track:

- Post date/time.
- Platform.
- Hook.
- Script angle.
- Visual format.
- CTA.
- Views.
- Average watch time if available.
- Likes.
- Comments.
- Saves.
- Shares.
- Profile visits.
- Link clicks.
- Installs if App Store Connect attribution can be matched.
- Paid spend, if any.

## Content Strategy

The product should market itself through repeated, simple demonstrations.

Content pillars:

1. Product demo
   - Show opening a blocked app, receiving a challenge, completing it, and earning access.

2. Relatable pain
   - Show the automatic phone-open loop: unlock phone, tap TikTok/Instagram, realize it happened again.

3. Micro-learning
   - Show Spanish Word as the hook: "I learned one Spanish word before opening Instagram."

4. Build in public
   - Show the app being built and tested honestly.

5. Screen Time comparison
   - Explain that Apple Screen Time tells you what happened; Cuewell interrupts the reflex.

6. Privacy/local-first
   - Emphasize no account and local-first behavior without overexplaining technical details.

Formats:

- Faceless phone screen recording.
- Hand holding phone, over-the-shoulder.
- Text overlay with screen recording.
- AI voiceover on demo footage.
- Founder talking head only when useful.
- Build-in-public clips from Xcode or TestFlight.

Avoid:

- Generic productivity tips.
- Overproduced ads.
- Shame-heavy addiction language.
- Fake testimonials.
- Claims that Screen Time cannot be bypassed.

## First 30 Days Content Calendar

Posting target:

- 2 short videos per day.
- Cross-post to TikTok, Instagram Reels, and YouTube Shorts.
- Facebook Reels can receive the same content without extra effort.

Week 1: Product clarity

- 5 clips: "I made TikTok ask me a math question."
- 5 clips: "Screen Time never worked for me because I ignored it."
- 3 clips: "Keep the apps. Break the reflex."
- 1 clip: build-in-public intro.

Week 2: Challenge angles

- 4 clips: Spanish Word before scrolling.
- 4 clips: Mental Math before TikTok.
- 3 clips: Pattern Memory before Instagram.
- 2 clips: Guided Breathing before YouTube.
- 1 clip: daily progress card demo.

Week 3: Relatable loops

- 5 clips: opening the same app without thinking.
- 3 clips: "I opened this app 40 times yesterday."
- 3 clips: "I do not want to delete social media."
- 2 clips: "A speed bump, not a ban."
- 1 clip: TestFlight/App Store update.

Week 4: Conversion and proof

- 4 clips: before/after daily routine.
- 4 clips: demo of setting up first lock.
- 3 clips: progress card/streak.
- 2 clips: founder note on why it is local-first.
- 1 clip: App Store launch/purchase explanation.

## Hook Bank

- I made TikTok ask me a math question.
- I do not want to delete Instagram. I just want to stop opening it automatically.
- Apple Screen Time tells me I failed. This interrupts me before I do.
- Before I scroll, I have to learn one Spanish word.
- This is a speed bump for doomscrolling.
- I built an app that makes you earn your scroll.
- You can still open the app. You just have to wake your brain up first.
- I opened TikTok without thinking, so I built this.
- What if your bad habit taught you Spanish?
- This is not a blocker. It is friction.
- I kept bypassing Screen Time, so I changed the moment before the scroll.
- One tiny challenge before the infinite feed.
- Keep the apps. Break the reflex.
- My phone now asks: do you actually want to scroll?

## Example Short Scripts

Script 1: Product demo

> I kept opening TikTok without even thinking.  
> So I made Cuewell.  
> After my daily limit, TikTok does not just open.  
> I have to solve one quick challenge first.  
> If I still want to scroll, I can.  
> But now it is a choice.

Script 2: Spanish angle

> I do not want to delete Instagram.  
> I just want it to stop being automatic.  
> So before I open it, Cuewell teaches me one Spanish word.  
> Tiny friction. Tiny win.  
> Then I can decide if I still want to scroll.

Script 3: Screen Time comparison

> Apple Screen Time tells me I spent three hours scrolling.  
> That is too late.  
> I needed something at the moment I opened the app.  
> Cuewell adds a small challenge right there.  
> Not a punishment. Just a pause.

Script 4: Founder/build-in-public

> I am building a tiny app for one problem:  
> opening social apps automatically.  
> Not deleting them.  
> Not shaming myself.  
> Just adding a speed bump.  
> It is called Cuewell.

## Low-Spend Acquisition Plan

Month 1 budget:

- $0-$50 tools.
- $0 paid social.
- $50-$150 Apple Search Ads only after App Store page is ready.
- $0-$100 for one cheap UGC test only if a creator is clearly aligned.

Month 2 budget:

- $100-$300 total.
- Boost only posts that already perform organically.
- Consider 1-2 UGC videos at $100-$200 each.
- Keep Apple Search Ads small and keyword-specific.

Do not scale spend until these signals appear:

- 35% or more of installs grant Screen Time permission.
- 35% or more of permission-granted users create a first lock.
- 25% or more of first-lock users complete an unlock.
- 8% or more of paywall views start trial or purchase.
- Paid CAC looks plausibly below $10-$12.
- At least one organic format repeatedly gets traction.

If early paid metrics are weak, keep improving:

- onboarding clarity
- paywall timing
- App Store screenshots
- content hook quality
- first-lock creation flow

## Release Plan

Phase 1: Product readiness

- Finish RevenueCat integration.
- Add free/pro gating.
- Add paywall and restore.
- Clean challenge naming.
- Add shareable progress.
- Verify Screen Time flow on real device.

Phase 2: Store readiness

- Confirm Family Controls distribution entitlement.
- Confirm App Group across app and extensions.
- Create IAPs in App Store Connect.
- Configure RevenueCat.
- Add privacy policy and terms URLs.
- Create screenshots and app preview assets.
- Run TestFlight with sandbox purchase and restore.

Phase 3: Content system readiness

- Create social accounts.
- Connect accounts to Looprail.
- Build a 30-day content backlog.
- Create 20 raw demo clips.
- Generate hook/caption variants.
- Schedule first two weeks.

Phase 4: Soft launch

- Launch App Store or TestFlight depending on entitlement/status.
- Post 2 clips per day.
- Spend little or nothing on paid ads.
- Check metrics weekly.

Phase 5: Reassess

- After two weeks, review:
  - install volume
  - first lock creation
  - unlock completion
  - paywall conversion
  - content winners
  - user feedback
- Decide whether to improve product, increase content, or start small paid tests.

## Success Metrics

Product activation:

- Screen Time permission grant rate.
- First lock creation rate.
- First unlock completion rate.
- Day 1 and Day 7 retention.

Revenue:

- Paywall view rate.
- Paywall purchase/trial start rate.
- Trial-to-paid conversion.
- Annual vs monthly selection.
- Refund/cancel feedback.

Marketing:

- Views per post.
- Hook hold rate / average watch time.
- Saves and shares.
- Profile visits.
- App Store clicks.
- Install lift after posts.

Spend:

- CPI.
- CAC.
- Paid subscriber LTV.
- Payback period.

## Current Strategic Decision

Start with Cuewell only.

Do not spend much yet. The near-term win is to create a coherent paid app, launch it, and make Looprail useful by forcing it to operate against a real product.

If the product starts showing pull, spend can increase gradually. If it does not, the investment is still useful because the app, paywall pattern, content system, and Looprail workflow can be reused for ViaSync and BirdCherry later.
