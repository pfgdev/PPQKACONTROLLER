# Testing

This project is developed outside the MacroQuest folder so early work stays isolated.

The first testing workflow is:

1. Edit files in this repository.
2. Copy this repository's `lua/` folder contents into the MacroQuest `lua/` folder.
3. Copy your local `ppqka_config.lua` into the MacroQuest config folder.
4. Run the script in-game.
5. Record what worked or failed.
6. Make one small change and repeat.

## Manual Copy Test

From this repository, copy:

```text
lua/ppqka/
```

Into the MacroQuest Lua folder so MacroQuest sees:

```text
MacroQuest/lua/ppqka/ppq_ka_manager.lua
MacroQuest/lua/ppqka/ppq_ka_reporter.lua
MacroQuest/lua/ppqka/config/ppqka_config_example.lua
MacroQuest/config/ppqka_config.lua
```

Then run:

```text
/lua run ppqka/ppq_ka_manager
```

Stop the script with:

```text
/lua stop ppq_ka_manager
```

If MacroQuest does not match by basename, use:

```text
/lua stop ppqka/ppq_ka_manager
```

## First DanNet Discovery Test

Goal: prove the ImGui window can read DanNet locally and list known peers.

Before running the Lua script:

1. Make sure MQ2DanNet is loaded.
2. Make sure your boxes are online and connected through DanNet.
3. Confirm the groups you care about exist, such as `g1`, `g1kiss`, `g2`, and `g2kiss`.

Useful in-game commands:

```text
/dnet
```

Expected result in PPQ KissAssist Manager:

- Local DanNet name appears.
- Peer count appears.
- Joined groups appear if DanNet reports them.
- Reporters show as `seen` in debug after the manager auto-starts them.
- Live EQ groups appear by leader name, such as `Nandladin's Group`.
- Ungrouped peers appear together in a final `Ungrouped` section.
- Your own grouped EQ group appears first when you are grouped.
- The top table shows manual/inactive, active profile, paused profile, or unknown/checking after DanNet status queries return.

This test uses a per-client reporter. The manager starts `ppqka/ppq_ka_reporter` on known DanNet peers, observes each peer's `PPQKA_Status` variable through DanNet, and keeps read-only `/dquery` polling as a fallback.

If a reporter does not show as `seen`, make sure `ppq_ka_reporter.lua` was copied into that client's MacroQuest `lua/ppqka/` folder. You can manually start it on a client with:

```text
/lua run ppqka/ppq_ka_reporter
```

To compare `Macro.Paused` in isolation, open debug and press `Probe Macro.Paused only`. That button submits only paused queries so the raw paused results are easier to inspect.

If group rows or profile labels look wrong, open debug and inspect `Reporter`, `Macro.Name`, `Macro.Paused`, `IniFile`, `Group.Members`, `Leader`, `MA`, `Ungroup reads`, and `Roster` for the affected peer.

Changing a target behavior dropdown only stages a pending change. It does not send commands until `Apply` is clicked.

`Stage Loadout` and `Stage Unload` only stage pending changes. `Apply` sends the real `/dex` commands for the staged characters. Characters not included in the staged loadout are not affected.

If a character starts KissAssist and then immediately prints that the macro ended, the end/start delay may still be too short for that character or server conditions. Report which character did it and whether it happened after pressing `Apply` for a profile target or after applying a manual target and then a profile target.

## Local Syntax Check

Install LuaJIT:

```powershell
winget install DEVCOM.LuaJIT
```

Then run this from the repository:

```powershell
.\scripts\check-lua.ps1
```

If running the raw `luajit -e ...` command manually, first change into the repository folder:

```powershell
cd C:\Users\pmfel\repos\PPQKAController
```

The syntax check can catch basic Lua syntax errors, but it cannot validate MacroQuest-only APIs such as `mq`, `ImGui`, or DanNet TLO behavior.

## When Something Fails

Write down:

- Which character ran `/lua run ppqka/ppq_ka_manager`.
- Whether the window opened.
- Any MQ chat error text.
- Whether `/dnet` shows peers.
- Whether the configured groups are joined.
