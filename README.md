# PPQ KissAssist Manager

PPQ KissAssist Manager is a MacroQuest Lua/ImGui control panel for managing boxed EverQuest characters that run KissAssist.

The goal is command amplification, not invisible automation. A manual driver can see the configured team, choose intended KissAssist profiles, and eventually send explicit DanNet commands such as start, pause, resume, end, and cleanup.

## Current Status

This repository is an initial scaffold only.

- Documentation exists for the intended architecture, commands, config, and roadmap.
- A bundled example config exists at `lua/ppqka/config/ppqka_config_example.lua`.
- User-owned config lives outside the Lua package at `config/ppqka/ppqka_config.lua`.
- A minimal ImGui script exists at `lua/ppqka/ppq_ka_manager.lua`.
- A companion reporter exists at `lua/ppqka/ppq_ka_reporter.lua`.
- The manager auto-starts reporters on known DanNet peers and reads their published `PPQKA_Status`.
- The status UI groups reported peers by their live EQ group state, with ungrouped peers collected beneath real groups.
- Target behavior dropdowns stage pending changes instead of firing commands immediately.
- `Apply` sends real per-character `/dex` commands for pending profile loads or manual `/end` targets.
- Debug controls may still show dry-run command previews.

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
|   +-- UI_ROADMAP.md
+-- lua/
+-- config/
|   +-- ppqka/
|       +-- ppqka_config.lua
+-- lua/
    +-- ppqka/
        +-- ppq_ka_manager.lua
        +-- ppq_ka_reporter.lua
        +-- config/
            +-- ppqka_config_example.lua
```

## MacroQuest Setup

For early testing, copy or sync the contents of this repository's `lua/` folder into your MacroQuest `lua/` folder. Copy your local config into MacroQuest's `config/ppqka/` folder.

The controller and reporter must both be present:

- `lua/ppqka/ppq_ka_manager.lua`
- `lua/ppqka/ppq_ka_reporter.lua`

Your local settings should be present at:

- `config/ppqka/ppqka_config.lua`

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
4. Open debug if needed and confirm reporters show as `seen` for peers.
5. Confirm live EQ groups appear by group leader, with ungrouped peers collected in `Ungrouped`.
6. Change target behavior dropdowns or stage a loadout, then confirm the pending count changes.
7. Only press `Apply` when you are ready for the staged characters to start or stop KissAssist.

See `docs/TESTING.md` for the current step-by-step testing workflow.

## Local Syntax Check

After installing LuaJIT, run this from the repository:

```powershell
.\scripts\check-lua.ps1
```

This catches basic Lua syntax errors. It does not run MacroQuest APIs.

## Design Principles

- Keep KissAssist untouched.
- Keep roster and command details in config.
- Send only explicit, visible commands.
- Treat dangerous commands like `/end`, `/camp`, `/quit`, and broad group commands carefully.
- Do not assume every character is online.
- Show live data where it can be detected, and make uncertain/local saved values obvious.
