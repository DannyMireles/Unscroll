# Cuewell RevenueCat Setup

This integration uses RevenueCat for subscription status and RevenueCat Paywalls for remotely controlled pricing, product mix, and paywall layout.

## App-Side Contract

- Public SDK key build setting: `REVENUECAT_API_KEY`
- Info.plist key: `RevenueCatAPIKey`
- Entitlement identifier: `Cuewell Pro`
- Legacy entitlement fallback accepted by the app: `pro`
- Free rule: one active lock
- Pro rule: unlimited active locks

The app never hardcodes prices. It renders RevenueCat's current Offering through `RevenueCatUI.PaywallView`, so the dashboard controls monthly-only, annual-only, mixed plans, pricing experiments, and paywall layout experiments without an app update.

## Security Rules

- Use only the public RevenueCat iOS SDK key in `REVENUECAT_API_KEY`.
- Never put a RevenueCat secret key beginning with `sk_` in the app, Git, CI logs, or an `.xcconfig` committed to the repo.
- The app refuses to configure RevenueCat if a key beginning with `sk_` is provided.
- Debug builds can use RevenueCat Test Store keys beginning with `test_`.
- Release builds refuse to configure RevenueCat with a `test_` key so the Test Store key cannot ship by accident.
- Keep any local key file named `RevenueCatSecrets.xcconfig` or `*.local.xcconfig`; both are ignored by Git.

RevenueCat public SDK keys are meant to be embedded in client apps. Secret keys are server-side only and are not needed for this app flow.

## RevenueCat Dashboard Checklist

1. Create the iOS app in RevenueCat.
2. Add App Store Connect credentials and products.
3. Create entitlement `Cuewell Pro`.
4. Attach all paid subscription/lifetime products to the `Cuewell Pro` entitlement.
5. Create the default Offering and set it as current.
6. Add packages for the products you want to test:
   - Monthly: `monthly`
   - Yearly: `yearly`
   - Lifetime: `lifetime`
7. Attach a RevenueCat Paywall to the current Offering.
8. Use RevenueCat Experiments or Targeting to test:
   - monthly only
   - annual only
   - monthly plus annual
   - lifetime included or excluded
   - different paywall templates, copy, and layout

If a product is not already created and approved in App Store Connect, it cannot be sold just by changing RevenueCat. Create the product in App Store Connect first, then add it to an Offering.

## Local Configuration

Set `REVENUECAT_API_KEY` on the main app target in Xcode, or provide it through an ignored local xcconfig.

Example local file name:

```xcconfig
REVENUECAT_API_KEY = appl_your_public_ios_sdk_key
```

The project Debug configuration currently uses the RevenueCat Test Store key. The Release configuration remains empty until you add the production public iOS SDK key. Do not ship a Test Store key.

## Test Plan

1. Launch with no RevenueCat key and confirm the app still works with one active lock.
2. Try to add a second active lock and confirm the upgrade sheet appears with a setup notice.
3. Add the public iOS SDK key and configure a current Offering in RevenueCat.
4. Relaunch, add one active lock, then try to add another.
5. Confirm the RevenueCat Paywall loads from the dashboard.
6. Complete a sandbox/Test Store purchase and confirm the second lock can be created.
7. Delete/reinstall or log out/in as needed and confirm Restore Purchases unlocks Pro.
8. Open Manage Purchases and confirm RevenueCat Customer Center loads after it is configured in the RevenueCat dashboard.
