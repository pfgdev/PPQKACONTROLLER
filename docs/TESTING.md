# Testing

This project is developed outside the MacroQuest folder so early work stays isolated.

The first testing workflow is:

1. Edit files in this repository.
2. Copy this repository's `lua/` folder contents into the MacroQuest `lua/` folder.
3. Run the script in-game.
4. Record what worked or failed.
5. Make one small change and repeat.

## Manual Copy Test

From this repository, copy:

```text
lua/ppqka/
```

Into the MacroQuest Lua folder so MacroQuest sees:

```text
MacroQuest/lua/ppqka/ppq_ka_manager.lua
MacroQuest/lua/ppqka/config/ppq_g1.lua
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
- Configured groups show peer names if DanNet reports peers for those groups.
- The top table shows `active`, `paused`, `inactive`, or `unknown` after DanNet status queries return.

This test uses read-only `/dquery` status probes for `Macro.Name`.

To test `Macro.Paused`, open debug and press `Probe Macro.Paused only`. That button briefly pauses normal `Macro.Name` polling and submits only paused queries so the raw paused results are easier to inspect.

Changing a profile dropdown is not read-only. It sends `/dex {character} /end`, then `/dex {character} /mac kissassist ini {profile} assist ma {assist}`.

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
