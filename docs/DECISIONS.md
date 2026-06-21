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

## Character Names Are Config Data

Decision: Character names matter only as configured targets or displayed status rows. They are not part of the core architecture.

Reason: The user may run more than one boxed group, may add or remove characters, and wants one UI that can show KissAssist status across all configured or discoverable characters.

## Support Multiple Groups

Decision: The manager should support multiple DanNet groups such as `g1`, `g1kiss`, `g2`, and `g2kiss`, plus user-defined group names.

Reason: Group names will change over time. The code should operate on configured group definitions instead of assuming a fixed set of names.

## Any Character Can Run The Manager

Decision: The UI should be usable from any character, although Nandladin is the expected primary driver.

Reason: The manager is a control surface for the team, not a feature tied to one character.

## Fast Controls Over Confirmation Prompts

Decision: The default UI should not require confirmation for every `/end` or hard-stop action.

Reason: The manager is meant to be a fast in-game control panel opened when the user needs to manage characters quickly.

Tradeoff: Dangerous actions should still be clearly labeled. Optional safety modes can be considered later if real use shows they are needed.

## First Real Status Goal

Decision: The first live status target is character name, group organization where practical, KissAssist running/not running/paused, and current active profile.

Reason: This directly supports the user's main need: seeing the KissAssist state of all boxed characters in one window.

## Config Editing Later

Decision: Config editing from the UI is out of scope until the concept is proven.

Reason: File-based config is enough for early testing and avoids spending too much time on tooling before the core workflow works.
