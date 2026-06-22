# UI Roadmap

This tracks the mock-driven UI polish for the main PPQ KissAssist Manager view.

## Current Direction

The normal view should feel like a compact control panel, not a diagnostics panel.

Primary goals:

- Keep the main view compact and readable.
- Preserve the live group table as the core information surface.
- Make current state, target state, and pending changes obvious at a glance.
- Push debugging and implementation plumbing out of the normal workflow.
- Prefer fixed, predictable ImGui layout constants over dynamic resizing.

## Completed

- Separate `Current` loadout state from `Target` loadout planning.
- Use `No Change`, saved loadouts, and `Unload All` as target choices.
- Show `Modified / Unsaved` when row-level edits no longer match a saved target.
- Keep pending changes staged until `Apply` is clicked.
- Use a compact fixed-width main layout.
- Reshape the top header from the HTML mock:
  - `Current` and `Target` stacked on the left.
  - `Manage Loadouts` on the upper right.
  - `Clear` and `Apply N Changes` on the lower right.
- Frame live group sections with a darker group header band.
- Show group title, peer count, and main assist/control metadata in the group header.
- Tint rows with pending changes.

## Next Steps

### 1. Replace Status Prefixes With Status Dots

Current behavior still reads like debug text:

```text
[MAN] Manual
[RUN] default
[CHG] -> default
```

Move toward the mock style:

```text
blue dot   Manual
green dot  default
yellow dot Changing -> default
red dot    Unknown / Stale
```

Notes:

- Keep hover text for INI/config details.
- Keep enough text that status is understandable without relying only on color.
- Use simple ImGui text/color primitives first; do not overbuild a custom drawing system unless needed.

### 2. Add Optional Character Metadata

Add config-backed metadata so the character column can eventually show class chips like the mock.

Suggested config shape:

```lua
character_meta = {
  nandladin = { class = 'WAR', class_color = '#d9c18e' },
  nodance = { class = 'BRD', class_color = '#f2a7ef' },
}
```

Use cases:

- Class chip before character name.
- Future role or warning tooltip if useful.
- Avoid hardcoding PPQ roster details in the manager script.

### 3. Add Class Chips

Once metadata exists, update the character column:

```text
[WAR] Nandladin (you)
[BRD] Nodance
```

Notes:

- Keep chips compact.
- Use config-provided colors.
- If metadata is missing, show only the character name.

### 4. Improve Table Polish

Continue moving the table toward the mock:

- Slightly taller, consistent rows if needed.
- Softer row striping.
- Pending row highlight with a clearer warm tint.
- Consider a subtle left marker for pending rows.
- Reduce any remaining spreadsheet-like visual noise.

### 5. Clean Up Footer Actions

The normal footer should become purposeful:

- `Refresh` as the primary left-side utility action.
- `Clear` and `Apply N Changes` repeated on the right, matching the header.
- Hide or demote `Show debug` and `Close Script`.
- Keep reporter/debug details out of the normal reading path.

### 6. Cull Or Hide Debug Plumbing

Debug still matters while the tool is young, but the normal view should not feel like a debug panel.

Possible direction:

- Keep `Show debug` small and secondary.
- Move reporter source, dry-run log, DanNet discovery, and probe details behind debug.
- Remove obsolete dry-run controls once real apply behavior is stable.

### 7. Manage Loadouts Placeholder

Keep `Manage Loadouts` as a visible placeholder for now.

Later it should support:

- Creating new named loadouts from current staged targets.
- Editing saved loadouts.
- Possibly duplicating or renaming loadouts.

Do not start this until the main view is comfortable.

## Design Guardrails

- The live table should remain the main surface.
- Do not make the table wider just to satisfy the top controls.
- Use fixed layout constants that are easy to tune.
- Avoid complex responsive behavior unless the need becomes unavoidable.
- Prefer one small visual improvement at a time, then test in-game.
