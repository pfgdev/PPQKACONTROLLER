# Architecture

PPQ KissAssist Manager is intended to be a small MacroQuest Lua application with an ImGui front end, a config-driven roster model, and a command dispatch layer for DanNet/KissAssist commands.

## Components

### ImGui UI

The UI displays configured characters, roles, labels, and profile names. It will eventually expose per-character and group-level buttons for start, pause, resume, end, cleanup, movement, and assist workflows.

The initial UI is intentionally dry-run only. It renders placeholder rows and logs the command that would be sent.

### Config

The config defines:

- Characters.
- Class, role, and labels.
- DanNet group names.
- KissAssist profiles per character.
- Default profiles.
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

The dispatcher will eventually call `mq.cmd()` or `mq.cmdf()` for real commands.

Current scaffold behavior:

- No command dispatch.
- Buttons log dry-run command text only.

### Status Layer

Live status is intentionally out of scope for the first scaffold.

Later versions may use:

- MacroQuest TLOs where available.
- DanNet queries.
- A lightweight per-character agent script.
- Explicit heartbeat/status messages.

## Data Flow

```text
Lua config -> UI rows -> command builder -> dry-run log now -> real dispatcher later
```

## Safety Boundaries

The manager should not silently start, stop, or alter character behavior. Broad commands and dangerous actions should be visually distinct and may need confirmation before real dispatch is enabled.

