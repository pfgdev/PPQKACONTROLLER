# Commands

This document records the intended command patterns for DanNet and KissAssist control/status.

The current Lua scaffold sends read-only DanNet status queries. Target behavior dropdowns stage changes locally; `Apply` sends the real per-character commands.

## Read-Only Status Queries

Ask a peer what macro is running:

```text
/dquery {character} -q Macro.Name -t 1000
```

Ask whether the peer's macro is paused:

```text
/dquery {character} -q Macro.Paused -t 1000
```

Ask KissAssist which INI file it has loaded, if that macro variable exists:

```text
/dquery {character} -q Macro.Variable[IniFile] -t 1000
```

The normal background status poll queries `Macro.Name`, `Macro.Paused`, `Macro.Variable[IniFile]`, and live group fields. The debug paused probe remains available as an isolated comparison tool.

The UI reads the returned values from DanNet query results and interprets them as:

- `active`: a macro with `kiss` in the name is running.
- `paused`: a macro with `kiss` in the name is running and `Macro.Paused` reports true.
- `inactive`: no macro is running, or a non-KissAssist macro is running.
- `unknown`: no usable response has been received yet.

Profile discovery is best-effort. If `Macro.Variable[IniFile]` returns an INI filename, the UI matches it to the configured profile list for that character. If it cannot match the INI, it shows the raw filename. If KissAssist does not expose that variable, the UI falls back to the locally saved intended active profile.

## Target Behavior Commands

Choosing a profile target does not immediately run a command. When `Apply` is clicked, each staged profile target updates the in-memory active profile and queues:

```text
/dex {character} /end
```

Then, after a short delay:

```text
/dex {character} /mac kissassist ini {profile} assist ma {assist}
```

This restart flow is intentional for now because it is predictable and avoids relying on mid-macro profile swapping.

Choosing `Manual` does not immediately run a command. When `Apply` is clicked, each staged manual target queues:

```text
/dex {character} /end
```

## Loadout Commands

Loadouts use per-character `/dex` commands, not group-wide KissAssist starts, because each character may use a different profile.

`Stage Loadout` stages profile targets for each character in the selected loadout. `Apply` then sends:

```text
/dex {character} /end
/dex {character} /mac kissassist ini {profile} assist ma {assist}
```

`Stage Unload` stages manual targets for each character in the selected loadout. `Apply` then sends:

```text
/dex {character} /end
```

Characters not listed in the loadout are not staged or affected.

The command queue clears pending commands for affected characters before scheduling a new profile/loadout action. It also waits between `/end` and `/mac kissassist` so an old `/end` does not finish after the new macro starts. The PPQ sample config uses a 2000ms end-to-start delay.

## Character Commands

These control commands are planned for broader buttons later. Some may appear in dry-run/debug previews.

Start KissAssist with the default assist:

```text
/dex {character} /mac kissassist assist ma {assist}
```

Start KissAssist with a specific INI profile:

```text
/dex {character} /mac kissassist ini {profile} assist ma {assist}
```

Pause a running macro:

```text
/dex {character} /mqp on
```

Resume a paused macro:

```text
/dex {character} /mqp off
```

End a running macro:

```text
/dex {character} /end
```

Character cleanup:

```text
/dex {character} /attack off
/dex {character} /stick off
/dex {character} /nav stop
/dex {character} /pet back off
```

## Group Commands

Start KissAssist on a DanNet group:

```text
/dgex {group} /mac kissassist assist ma {assist}
```

Pause a DanNet group:

```text
/dgex {group} /mqp on
```

Resume a DanNet group:

```text
/dgex {group} /mqp off
```

End macros on a DanNet group:

```text
/dgex {group} /end
```

Hard-stop a DanNet group:

```text
/dgex {group} /end
/dgex {group} /attack off
/dgex {group} /stick off
/dgex {group} /nav stop
/dgex {group} /pet back off
```

## Known DanNet Groups

The PPQ sample config includes:

- `g1`: all Group 1 members.
- `g1kiss`: characters intended to run KissAssist.
- `g1manual`: manual characters such as the tank and bard.
- `g1melee`: optional melee subgroup.
- `g1heal`: optional healer subgroup.
- `g1cast`: optional caster subgroup.
- `g1cc`: optional crowd-control subgroup.

## Safety Notes

- `/end` should be considered disruptive.
- Hard-stop group commands should be clearly labeled.
- Future real dispatch should support dry-run mode and confirmation options.
