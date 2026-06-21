# Architecture

PPQ KissAssist Manager is intended to be a small MacroQuest Lua application with an ImGui front end, a companion per-client reporter, a config-driven loadout/profile model, and a command dispatch layer for DanNet/KissAssist commands.

## Components

### ImGui UI

The UI should lead with a compact status table: group, character, current behavior, and target behavior. Deeper debug and command-preview details should live lower in the window and may eventually be hidden or removed.

The main status UI stages target behavior changes first. Real per-character commands are only sent when `Apply` is clicked. Debug-only controls may still log command previews without dispatching them.

### Config

The config defines:

- DanNet peer discovery used to find online characters.
- DanNet peer groups used to discover character names.
- DanNet control groups for future quick commands.
- Locally saved active profile choices. An active profile is the profile this manager intends to load for a character.
- Default profiles or full default command lines per character or group.
- Command templates.
- Command sequences for multi-step actions.

The first config format is a Lua table returned from a module. This avoids adding a parser dependency in MacroQuest Lua while keeping project behavior data separate from core logic.

### Reporter

`ppq_ka_reporter.lua` runs on each EQ client. It reads local MacroQuest TLOs for that client, builds one coherent status payload, and publishes it to the global MQ variable `PPQKA_Status`.

The manager attempts to start the reporter on all known DanNet peers with `/lua run ppqka/ppq_ka_reporter`. The reporter has a heartbeat guard so repeated start attempts should not create duplicate active reporters.

### Command Builder

The command builder expands command templates such as:

```text
/dex {character} /mac kissassist ini {profile} assist ma {assist}
```

The MVP will build strings from templates, show those strings in the UI where useful, and dispatch them only from explicit button presses.

### Command Dispatcher

The status layer reads each client's `PPQKA_Status` through DanNet `/dquery`. The payload includes the client's macro state, best-effort KissAssist INI, group leader, main assist, and group roster. Applying staged target behavior changes uses a small queued dispatcher to send real per-character `/dex` commands without blocking ImGui rendering.

The command queue uses `mq.gettime()` millisecond timing. Before scheduling a profile or loadout action, it clears pending queued commands for the affected characters and leaves a delay between `/end` and `/mac kissassist`.

Current scaffold behavior:

- Reporter auto-start and read-only DanNet status query dispatch.
- Live EQ group display by group leader, plus a final `Ungrouped` bucket.
- Client-reported KissAssist running/paused status and best-effort active INI/profile display.
- Per-character target behavior dropdowns that stage `No Change`, `Manual`, or a configured profile.
- Apply dispatch: per-character end/start for profile targets, or `/end` for manual targets.
- No group start, group pause, group resume, hard stop, cleanup, movement, attack, or pet command dispatch from the main UI.
- Debug buttons log dry-run command text only.

### Status Layer

The first desired live status view is:

- Character names.
- Group organization where practical.
- KissAssist running, not running, or paused.
- Current active profile.

Later versions may refine the reporter payload, replace the global-variable handoff if a cleaner transport appears, or add explicit profile/loadout persistence.

## Data Flow

```text
DanNet peers -> PPQ reporter status payloads -> compact status table -> debug/details lower in the window
Lua config -> saved profile choices and command groups -> staged target behavior -> command dispatcher
```

## Safety Boundaries

The manager should not silently start, stop, or alter character behavior. Broad commands and dangerous actions should be visually distinct. Confirmation prompts are not planned for the default flow because the UI needs to be fast during play, but an optional safety mode can be reconsidered later.
