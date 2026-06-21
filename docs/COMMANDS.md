# Commands

This document records the intended command patterns for DanNet and KissAssist control/status.

The current Lua scaffold sends read-only DanNet status queries. It does not start, pause, resume, end, or otherwise control KissAssist yet.

## Read-Only Status Queries

Ask a peer what macro is running:

```text
/dquery {character} -q Macro.Name -t 1000
```

Ask whether the peer's macro is paused:

```text
/dquery {character} -q Macro.Paused -t 1000
```

The UI reads the returned values from DanNet query results and interprets them as:

- `active`: a macro with `kiss` in the name is running.
- `inactive`: no macro is running, or a non-KissAssist macro is running.
- `unknown`: no usable response has been received yet.

`Macro.Paused` is still shown in debug, but it is not used for the main status yet. KissAssist can appear to pause its macro internally while doing work such as memorizing spells or buffing, so treating that as a user-facing paused state is misleading.

Active profile discovery is not wired yet.

## Character Commands

These control commands are planned but are not dispatched by the main UI yet. They may appear in dry-run/debug previews.

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
