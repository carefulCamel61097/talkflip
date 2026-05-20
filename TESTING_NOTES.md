# Real-user testing checklist

Items deferred from milestones (M9 in particular) to be revisited once we have real users testing the app on their own devices. Each one was either "probably fine" or "won't know until we see it in the wild" — the right call is to gather real-use data before spending effort.

## Bugs / edge cases to verify

- **Translation failure on first launch when offline.** `connectivityProvider` is a `StreamProvider` — there's a brief window between app mount and the first connectivity result. If the user immediately speaks during that window while actually offline, the bubble may attempt translation and fail. Check whether this happens in practice and whether the existing "tap to retry" affordance covers it.
- **Language picker error states.** Currently the Continue button disables when no language is picked or both are the same — that covers the main cases. Test for: rapidly switching the same dropdown value, network drop during save, etc.

## Polish items to gather feedback on

- **Active-side highlight clarity.** Current style is a 2px teal border at 0.7 alpha on the active side's bubbles, plus the chip filling teal. Does this read clearly enough? Are users able to tell at a glance which side is active? If not, consider stronger color, a side-strip indicator, or a subtle background tint on the active half.
- **Animation refinement.** No animations currently on chip activation, bubble entry, or side transitions. Worth observing whether the lack feels abrupt or whether it actually feels appropriately fast/snappy. Possible additions: subtle bubble fade-in on commit (~150ms), chip color crossfade on activation, smooth scroll behavior already in place.
- **Larger text accessibility toggle.** Translation font is currently 20sp (bumped up from 18sp in M7). For elderly "other side" users, this may still be too small. Decide between a binary "Larger text" toggle vs. a slider once we see how often it's actually needed and how much bigger users want it.
- **Mic permission denied flow UX.** Added in M9 — verify the dialog reads clearly, that "Open Settings" actually lands on the right OS settings page on each platform, and that the user successfully recovers after granting permission and returning to the app.

## Process notes

When you start gathering real-user feedback, treat each item here as a separate ticket. Don't try to fix all of them in one pass — most will turn out to be fine, and the ones that aren't will tell you what they actually need rather than what we guessed.
