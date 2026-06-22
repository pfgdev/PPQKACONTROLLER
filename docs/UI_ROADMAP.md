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
- Replace debug-style status prefixes with colored status-dot indicators.
- Add optional config-backed character metadata.
- Show compact class chips in the character column when metadata exists.
- Apply softer manual row striping.
- Use a clearer warm pending row highlight.
- Add a subtle left pending marker.
- Use slightly taller, consistent status rows.
- Repeat `Clear` and `Apply N Changes` in a bottom footer action row.
- Demote `Debug` and hide reporter/source details unless debug is open.
- Remove old dry-run group actions and configured-character lists from the visible debug path.

## Next Steps

### 1. Cull Or Hide Debug Plumbing

Debug still matters while the tool is young, but the normal view should not feel like a debug panel.

Possible direction:

- Keep `Debug` small and secondary.
- Decide whether the action log and DanNet discovery should remain in the manager or move to a separate debug-only view later.
- Remove obsolete dry-run helper functions once real apply behavior has had more testing.

### 2. Manage Loadouts Placeholder

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
