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
lua/ppq_ka_manager.lua
lua/ppqka/
```

Into the MacroQuest Lua folder so MacroQuest sees:

```text
MacroQuest/lua/ppq_ka_manager.lua
MacroQuest/lua/ppqka/config/ppq_g1.lua
```

Then run:

```text
/lua run ppq_ka_manager
```

Stop the script with:

```text
/lua stop ppq_ka_manager
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

This test does not send commands to any character.

## When Something Fails

Write down:

- Which character ran `/lua run ppq_ka_manager`.
- Whether the window opened.
- Any MQ chat error text.
- Whether `/dnet` shows peers.
- Whether the configured groups are joined.
