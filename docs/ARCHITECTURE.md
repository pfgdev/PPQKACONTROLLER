# Architecture

PPQ KissAssist Manager is intended to be a small MacroQuest Lua application with an ImGui front end, a config-driven roster/group model, a status layer, and a command dispatch layer for DanNet/KissAssist commands.

## Components

### ImGui UI

The UI should lead with a compact status table: group, character, current behavior, and target behavior. Deeper debug and command-preview details should live lower in the window and may eventually be hidden or removed.

The main status UI stages target behavior changes first. Real per-character commands are only sent when `Apply` is clicked. Debug-only controls may still log command previews without dispatching them.

### Config

The config defines:

- Display groups such as Group 1 and Group 2, used as fallback when live group membership is unavailable.
- DanNet peer groups used to discover character names.
- DanNet control groups for future quick commands.
- Locally saved active profile choices. An active profile is the profile this manager intends to load for a character.
- Default profiles or full default command lines per character or group.
- Command templates.
- Command sequences for multi-step actions.

The first config format is a Lua table returned from a module. This avoids adding a parser dependency in MacroQuest Lua while keeping project behavior data separate from core logic.

### Command Builder

The command builder expands command templates such as:

```text
/dex {character} /mac kissassist ini {profile} assist ma {assist}
```

The MVP will build strings from templates, show those strings in the UI where useful, and dispatch them only from explicit button presses.

### Command Dispatcher

The status layer uses live MacroQuest `Group` TLOs for the currently grouped characters where available. It uses `mq.cmdf()` for read-only DanNet `/dquery` probes. Normal status polling queries `Macro.Name`; `Macro.Paused` is available through an isolated debug probe. Applying staged target behavior changes uses a small queued dispatcher to send real per-character `/dex` commands without blocking ImGui rendering.

The command queue uses `mq.gettime()` millisecond timing. Before scheduling a profile or loadout action, it clears pending queued commands for the affected characters and leaves a delay between `/end` and `/mac kissassist`.

Current scaffold behavior:

- Read-only DanNet status query dispatch.
- Live current-group display with configured DanNet display groups as fallback.
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

Later versions may use:

- MacroQuest TLOs where available.
- DanNet queries.
- A lightweight per-character agent script.
- Explicit heartbeat/status messages.

## Data Flow

```text
MacroQuest Group TLO or DanNet peer groups -> compact status table -> debug/details lower in the window
Lua config -> saved profile choices and command groups -> staged target behavior -> command dispatcher
```

## Safety Boundaries

The manager should not silently start, stop, or alter character behavior. Broad commands and dangerous actions should be visually distinct. Confirmation prompts are not planned for the default flow because the UI needs to be fast during play, but an optional safety mode can be reconsidered later.
