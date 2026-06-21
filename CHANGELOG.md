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
- Added config-defined loadouts with per-character Load and Unload actions.
- Improved profile/loadout command queue timing to avoid `/end` racing after a new KissAssist start.
- Moved profile/loadout command timing into config with a 2000ms end-to-start baseline.
- Added live MacroQuest group display.
- Changed profile/loadout controls to stage pending target behavior changes before `Apply` sends commands.
- Added a short checking state for newly visible peers and made target choices that match current behavior clear back to `No Change`.
- Prevented loadout staging from creating pending changes for targets that already match the current behavior.
- Replaced configured display-group organization with live EQ group panels plus a final `Ungrouped` section.
- Smoothed live group assignment to avoid transient DanNet group-query flicker and rejected numeric group leader/main-assist values.
- Reconciled live groups from each client's reported `Group.Member[0..5].Name` roster instead of trusting only each peer's individual leader result.
