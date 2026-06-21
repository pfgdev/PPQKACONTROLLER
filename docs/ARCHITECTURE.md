# Architecture

PPQ KissAssist Manager is intended to be a small MacroQuest Lua application with an ImGui front end, a config-driven roster/group model, a status layer, and a command dispatch layer for DanNet/KissAssist commands.

## Components

### ImGui UI

The UI should lead with a compact status table: group, character, KissAssist status, and active profile. Deeper debug and command-preview details should live lower in the window and may eventually be hidden or removed.

The main status UI can send real per-character profile restart commands from the active profile dropdown. Debug-only controls may still log command previews without dispatching them.

### Config

The config defines:

- Display groups such as Group 1 and Group 2.
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

The status layer uses `mq.cmdf()` for read-only DanNet `/dquery` probes. Normal status polling queries `Macro.Name`; `Macro.Paused` is available through an isolated debug probe. Profile dropdown changes and loadout actions use a small queued dispatcher to send real per-character `/dex` commands without blocking ImGui rendering.

The command queue uses `mq.gettime()` millisecond timing. Before scheduling a profile or loadout action, it clears pending queued commands for the affected characters and leaves a delay between `/end` and `/mac kissassist`.

Current scaffold behavior:

- Read-only DanNet status query dispatch.
- Per-character active profile dropdown dispatch: end KissAssist, then start KissAssist with the selected INI.
- Loadout dispatch: per-character end/start for included characters.
- No group start, group pause, group resume, hard stop, cleanup, movement, attack, or pet command dispatch from the main UI.
- Debug buttons log dry-run command text only.

### Status Layer

Live status is intentionally out of scope for the first scaffold, but it is the first major feature after command dispatch is proven.

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
DanNet peer groups -> compact status table -> debug/details lower in the window
Lua config -> saved profile choices and command groups -> command builder later
```

## Safety Boundaries

The manager should not silently start, stop, or alter character behavior. Broad commands and dangerous actions should be visually distinct. Confirmation prompts are not planned for the default flow because the UI needs to be fast during play, but an optional safety mode can be reconsidered later.
