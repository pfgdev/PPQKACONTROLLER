# Decisions

## Use a Lua Config First

Decision: Use a Lua module that returns a table for initial config.

Reason: MacroQuest Lua can load this with `require()` without adding JSON/YAML dependencies.

Tradeoff: Lua config is executable code, so users should treat config files as trusted local files.

## Dry-Run First

Decision: The first UI logs intended commands only.

Reason: The project controls multiple characters and may eventually expose disruptive actions. Dry-run mode lets the layout, config, and command templates be reviewed before real command dispatch exists.

## Do Not Edit KissAssist

Decision: Build a wrapper/manager around KissAssist.

Reason: KissAssist remains the behavior engine. This project should orchestrate clear user-triggered commands and avoid modifying macro behavior unless explicitly requested later.

## No Fake Status

Decision: The first UI displays configured labels only, not live online/running/paused status.

Reason: Status should not be shown as authoritative until it is backed by reliable detection or reporting.

## Keep PPQ Data in Sample Config

Decision: The core Lua script should not hardcode the PPQ roster.

Reason: The first version can be PPQ-specific in config, while the architecture remains usable by other rosters.

