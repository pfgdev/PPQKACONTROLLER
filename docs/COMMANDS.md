# Commands

This document records the intended command patterns for DanNet and KissAssist control.

The current Lua scaffold does not send any of these commands. It only logs dry-run command previews.

## Character Commands

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

