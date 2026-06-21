# Commands

This document records the intended command patterns for DanNet and KissAssist control/status.

The current Lua scaffold sends read-only DanNet status queries. It also sends real per-character commands when an active profile dropdown is changed.

## Read-Only Status Queries

Ask a peer what macro is running:

```text
/dquery {character} -q Macro.Name -t 1000
```

Ask whether the peer's macro is paused:

```text
/dquery {character} -q Macro.Paused -t 1000
```

The normal background status poll only queries `Macro.Name`. `Macro.Paused` is queried only from the debug button so it can be tested without mixing it with the regular status poll.

The UI reads the returned values from DanNet query results and interprets them as:

- `active`: a macro with `kiss` in the name is running.
- `inactive`: no macro is running, or a non-KissAssist macro is running.
- `unknown`: no usable response has been received yet.

`Macro.Paused` is not used for the main status yet. The debug view has a `Probe Macro.Paused only` button that briefly pauses normal `Macro.Name` polling, submits isolated paused queries, and shows the raw returned values.

Active profile discovery is not wired yet.

## Profile Dropdown Commands

Changing a character's active profile dropdown updates the in-memory active profile and queues:

```text
/dex {character} /end
```

Then, after a short delay:

```text
/dex {character} /mac kissassist ini {profile} assist ma {assist}
```

This restart flow is intentional for now because it is predictable and avoids relying on mid-macro profile swapping.

## Loadout Commands

Loadouts use per-character `/dex` commands, not group-wide KissAssist starts, because each character may use a different profile.

Load sends, for each character in the selected loadout:

```text
/dex {character} /end
/dex {character} /mac kissassist ini {profile} assist ma {assist}
```

Unload sends, for each character in the selected loadout:

```text
/dex {character} /end
```

Characters not listed in the loadout are not affected.

The command queue clears pending commands for affected characters before scheduling a new profile/loadout action. It also waits between `/end` and `/mac kissassist` so an old `/end` does not finish after the new macro starts.

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
