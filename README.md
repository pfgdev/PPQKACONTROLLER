# PPQ KissAssist Manager

PPQ KissAssist Manager is a MacroQuest Lua/ImGui control panel for managing boxed EverQuest characters that run KissAssist.

The goal is command amplification, not invisible automation. A manual driver can see the configured team, choose intended KissAssist profiles, and eventually send explicit DanNet commands such as start, pause, resume, end, and cleanup.

## Current Status

This repository is an initial scaffold only.

- Documentation exists for the intended architecture, commands, config, and roadmap.
- A sample PPQ Group 1 config exists at `lua/ppqka/config/ppq_g1.lua`.
- A minimal ImGui script exists at `lua/ppqka/ppq_ka_manager.lua`.
- The current UI is dry-run only. It prints intended commands and does not send real `/dex`, `/dgex`, `/mac`, `/mqp`, `/end`, movement, attack, or pet commands.

## File Layout

```text
.
+-- README.md
+-- CHANGELOG.md
+-- docs/
|   +-- ARCHITECTURE.md
|   +-- COMMANDS.md
|   +-- CONFIG.md
|   +-- DECISIONS.md
|   +-- ROADMAP.md
|   +-- TESTING.md
+-- lua/
    +-- ppqka/
        +-- ppq_ka_manager.lua
        +-- config/
            +-- ppq_g1.lua
```

## MacroQuest Setup

For early testing, copy or sync the contents of this repository's `lua/` folder into your MacroQuest `lua/` folder.

Then run:

```text
/lua run ppqka/ppq_ka_manager
```

Stop it with:

```text
/lua stop ppq_ka_manager
```

If MacroQuest does not match by basename, use:

```text
/lua stop ppqka/ppq_ka_manager
```

## First Test

1. Start MacroQuest with Lua and ImGui support loaded.
2. Run `/lua run ppqka/ppq_ka_manager`.
3. Confirm the `PPQ KissAssist Manager` window opens.
4. Press a dry-run button.
5. Confirm a dry-run line prints to MQ chat and appears in the window log.

See `docs/TESTING.md` for the current step-by-step testing workflow.

## Design Principles

- Keep KissAssist untouched.
- Keep roster and command details in config.
- Send only explicit, visible commands.
- Treat dangerous commands like `/end`, `/camp`, `/quit`, and broad group commands carefully.
- Do not assume every character is online.
- Do not claim live status until the project can actually detect it.
