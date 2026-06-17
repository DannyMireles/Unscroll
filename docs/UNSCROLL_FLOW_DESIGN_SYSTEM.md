# Unscroll Flow Design System

Unscroll should feel calm, premium, and fluid. The UI language is built around rounded system typography, airy spacing, glass surfaces, and restrained motion that helps users understand state changes without feeling busy.

## Principles

- Use rounded system typography app-wide through `unscrollTypography()` and `AppTheme.Typography`.
- Use glass surfaces for cards, sheets, popups, and bottom bars through `glassCard`, `flowSheetPresentation`, `flowNavigationChrome`, and `glassBottomBarChrome`.
- Animate at the section level first. Prefer `flowItem(_:)` for major sections and avoid animating every small child.
- Use delayed emphasis text only when it clarifies a key idea or result. Do not color random words for decoration.
- Keep color highlights restrained: brand green for actions, success, and selected states; red only for errors.
- Respect Reduce Motion. Decorative loops should pause or simplify when `accessibilityReduceMotion` is enabled.

## SwiftUI Patterns

Use this for screen sections:

```swift
hero.flowItem(0)
stats.flowItem(1)
content.flowItem(2)
```

Use this for sheet views:

```swift
NavigationStack {
    ...
}
.flowNavigationChrome()
```

Use this when presenting a sheet:

```swift
.flowSheetPresentation()
```

Use this for fixed bottom actions inside sheets:

```swift
PrimaryButton(...)
    .glassBottomBarChrome()
```

Use `FlowHeadlineText` for onboarding-style copy where the emphasis should appear after the setup phrase.
