**Findings**

1. High: `boringNotch/components/Clipboard/ClipboardHistoryViewModel.swift:328-331` violates the documented storage cap when pinned images exceed the limit.
`pruneIfNeeded()` refuses to delete pinned images for the storage limit, so pinned image history can grow beyond `clipboardHistoryMaxStorageMB` indefinitely.
That contradicts `boringNotch/components/Clipboard/AGENTS.md:14-16`, which requires retention to be bounded by item count and storage size.

2. High: `boringNotch/components/Clipboard/ClipboardHistoryPanelView.swift:317`, `:368`, `:417`, `:425` nests pin/delete buttons inside a row-level copy button.
SwiftUI nested buttons are unreliable and can cause pin/delete clicks to also trigger row copy, mutating the system pasteboard while the user only meant to pin or delete.

3. Medium: `boringNotch/components/Clipboard/ClipboardHistoryViewModel.swift:152-160` clears the system pasteboard before confirming an image history item can be restored.
If the stored PNG is missing or unreadable, `copy(_:)` returns after `pasteboard.clearContents()`, destroying the user's current clipboard content.

4. Medium: `boringNotch/components/Settings/SettingsView.swift:1137-1153` updates max item/storage limits without pruning existing history.
`pruneIfNeeded()` only runs from insertion at `ClipboardHistoryViewModel.swift:311-314`, so lowering retention settings can leave over-limit data persisted until a later clipboard capture.

5. Medium: `boringNotch/components/Clipboard/ClipboardHistoryViewModel.swift:18`, `:267-296`, `:368-378` and `boringNotch/components/Clipboard/ClipboardHistoryStore.swift:53-59` do PNG conversion and disk writes synchronously on the main actor.
Large screenshots or image copies can block the app UI and menu bar panel during pasteboard polling.

6. Low: `boringNotch/components/Clipboard/ClipboardHistoryViewModel.swift:251`, `:275`, `:358-360` records `NSWorkspace.shared.frontmostApplication` at poll time as the source app.
Because polling is delayed by up to 0.75s, focus can change before capture, producing wrong app attribution and misleading privacy/source labels.

7. Low: `boringNotch/components/Clipboard/AGENTS.md:22-24` requires manual verification for text copy, image copy, copy-back, deletion, clearing, and relaunch persistence.
Reported verification only covers build and `git diff --check`, so required feature-level verification is still missing.

**Files Covered**

Reviewed with findings: `ClipboardHistoryStore.swift`, `ClipboardHistoryViewModel.swift`, `ClipboardHistoryPanelView.swift`, `Clipboard/AGENTS.md`, `SettingsView.swift`.

Reviewed with no additional findings: `ClipboardHistoryItem.swift`, `components/AGENTS.md`, `boringNotchApp.swift`, `Constants.swift`, `boringNotch.xcodeproj/project.pbxproj`.