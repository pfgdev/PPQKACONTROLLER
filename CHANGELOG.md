# Changelog

## Unreleased

- Added initial documentation scaffold.
- Added PPQ Group 1 sample config.
- Added dry-run-only MacroQuest Lua/ImGui placeholder window.
- Added read-only DanNet peer discovery.
- Moved the main UI toward a compact group status table.
- Added read-only DanNet status probes for `Macro.Name` and `Macro.Paused`.
- Added configured active profile selections and labels.
- Changed main status to ignore transient `Macro.Paused` values and treat a running KissAssist macro as active.
- Added active profile dropdowns that restart KissAssist on the selected character.
- Isolated `Macro.Paused` into a debug-only probe instead of mixing it with normal status polling.
