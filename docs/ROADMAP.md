# Roadmap

## Phase 0: Scaffold

- Create documentation.
- Create sample PPQ Group 1 config.
- Create a minimal ImGui window.
- Render placeholder character rows.
- Log dry-run command previews only.
- Add a read-only DanNet discovery view.
- Put a compact live-group status table at the top of the UI.

## Phase 1: MVP Command UI

- Add per-character action buttons.
- Add selected profile controls.
- Add group-level actions.
- Add a global dry-run toggle.
- Clearly label hard-stop and `/end` actions.
- Dispatch commands through MacroQuest only after review.

## Phase 2: First Status View

- Show discovered character names from DanNet peers.
- Organize characters by live EQ group leader, with ungrouped peers collected together.
- Show KissAssist running, not running, or paused if detectable.
- Query `Macro.Name` and `Macro.Paused` through DanNet as the first status probe.
- Show current active KissAssist profile if detectable.
- Avoid fake certainty when status cannot be detected.

## Phase 3: Better Config and UX

- Add config validation.
- Add clearer command preview panels.
- Add per-character default command lines.
- Add group, raid, zone, dungeon, boss, or routine-grinding profile sets.
- Add optional per-character notes and warning labels.

## Phase 4: Stronger Status

- Detect online/offline state where possible.
- Consider a lightweight per-character Lua agent for reliable state reporting.
- Show status without pretending uncertain data is known.

## Phase 5: Integrations

- MQ2Melee controls.
- MQ2Twist controls for bard workflows.
- Chase, camp, movement, and navigation commands.
- XTarget or assist target display.
- HP, mana, endurance, and role summaries.

## Phase 6: Editing

- Edit profile choices from the UI.
- Save config changes intentionally.
- Consider controlled KissAssist INI editing only if explicitly requested.
