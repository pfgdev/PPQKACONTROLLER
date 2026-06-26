# Config

The config format is a Lua file that returns a table.

The manager loads user-owned config first:

```text
config/ppqka/ppqka_config.lua
```

If that file is missing, it falls back to the bundled example:

```text
lua/ppqka/config/ppqka_config_example.lua
```

The bundled example is safe to overwrite during controller updates. The user-owned config should not be overwritten by controller updates.

Sample:

```lua
return {
  name = 'PPQ Boxing Setup',
  assist = 'Nandladin',
  display_groups = {
    { label = 'Group 1', peers = 'g1', control = 'g1kiss' },
    { label = 'Group 2', peers = 'g2', control = 'g2kiss' },
  },
  groups = {
    all = 'g1',
    kiss = 'g1kiss',
    group2 = 'g2',
    group2kiss = 'g2kiss',
  },
  command_timing = {
    end_to_start_delay_ms = 2000,
    loadout_end_spacing_ms = 250,
    loadout_start_spacing_ms = 750,
  },
  profiles = {
    shadow = {
      default = { label = 'default', ini = 'KissAssist_Shadow.ini' },
      solo = { label = 'solo', ini = 'KissAssist_Shadow_Solo.ini' },
    },
  },
  active_profiles = {
    shadow = 'default',
  },
  character_meta = {
    shadow = { class = 'RNG', class_color = '#b6e07a' },
  },
  loadouts = {
    {
      key = 'g1_normal',
      label = 'Group 1 - Normal',
      assist_policy = { mode = 'group_ma', fallback = 'Nandladin' },
      characters = {
        boomkenzie = 'default',
        lagspike = 'default',
        nandarie = 'default',
        shadow = 'default',
      },
    },
  },
  characters = {},
}
```

## Top-Level Fields

`version`

Schema version for future migrations.

`name`

Human-readable config name.

`assist`

Default main assist character used by command templates.

`groups`

Named DanNet groups for debug display and future command templates. The user may define groups such as `g1`, `g1kiss`, `g2`, `g2kiss`, or any future group name. Code should read these from config and not assume a fixed list.

`display_groups`

Legacy configured display groups. The main table no longer uses this for organization; it groups known DanNet peers by live EQ group state instead. These values may remain useful later for debug or command-group experiments.

`active_profiles`

Local saved active profile key by character name. This means "the profile this manager intends to load for that character," not necessarily a live value detected from KissAssist.

Applying a staged profile target updates this value in memory for the running script and restarts KissAssist on that character with the selected profile. It does not write the config file back to disk yet.

`profiles`

Profile choices by character name. Each profile has a key, display label, and KissAssist INI filename.

`characters`

Optional legacy/configured character definitions. The main status table should not depend on this list.

`character_meta`

Optional display metadata keyed by lower-case character name. This is used for visual polish such as class chips and should not be required for core behavior.

`loadouts`

Named profile mappings that can be applied with per-character DanNet commands.

`command_timing`

Timing values, in milliseconds, used by the command queue.

`command_templates`

String templates for single commands.

`command_sequences`

Named lists of command templates for multi-step actions.

## Display Group Fields

`label`

Human-friendly group label, such as `Group 1`.

`peers`

DanNet group used to discover visible characters for the table, such as `g1`.

`control`

DanNet group intended for future quick commands, such as `g1kiss`.

## Profile Fields

Profile choices are keyed by lower-case character name:

```lua
profiles = {
  shadow = {
    default = { label = 'default', ini = 'KissAssist_Shadow.ini' },
    solo = { label = 'solo', ini = 'KissAssist_Shadow_Solo.ini' },
  },
}
```

The active profile points to one of those profile keys:

```lua
active_profiles = {
  shadow = 'default',
}
```

Later, when the UI can launch KissAssist, this active profile should decide which INI is loaded.

## Loadout Fields

Loadouts are explicit character-to-profile mappings:

```lua
loadouts = {
    {
      key = 'g1_normal',
      label = 'Group 1 - Normal',
      assist_policy = { mode = 'group_ma', fallback = 'Nandladin' },
      characters = {
      boomkenzie = 'default',
      lagspike = 'default',
      nandarie = 'default',
      shadow = 'default',
    },
  },
}
```

`key`

Stable internal loadout identifier.

`label`

UI label shown in the loadout dropdown.

`assist`

Legacy/simple default main assist used when loading this loadout. Prefer `assist_policy` for new loadouts.

`assist_policy`

Optional assist policy used when loading this loadout:

```lua
assist_policy = { mode = 'group_ma', fallback = 'Nandladin' }
assist_policy = { mode = 'raid_ma', fallback = 'Nandladin' }
assist_policy = { mode = 'character', character = 'Grog' }
```

The header `Assist` dropdown can temporarily override this policy before Apply.

`characters`

Map of lower-case character names to profile keys:

```lua
shadow = 'default'
```

Characters not listed are visible in the status table but are not affected when the loadout is staged and applied.

Assist resolution order is:

1. Header assist override, if selected
2. Loadout `assist_policy`
3. Loadout `assist`
4. Top-level config `assist`

## Command Timing Fields

`end_to_start_delay_ms`

Delay between `/end` and `/mac kissassist`. The PPQ sample uses `2000`, matching the observed KissAssist DanNet delay baseline of 20 tenths of a second.

`loadout_end_spacing_ms`

Small stagger between `/end` commands when applying or unloading a loadout.

`loadout_start_spacing_ms`

Small stagger between `/mac kissassist` start commands when loading multiple characters.

## Character Fields

`character_meta`

Optional display metadata for live status rows:

```lua
character_meta = {
  nandladin = { class = 'WAR', class_color = '#d9c18e' },
  nodance = { class = 'BRD', class_color = '#f2a7ef' },
}
```

`class`

Short class label used in the character column, such as `WAR`, `BRD`, `CLR`, or `DRU`.

`class_color`

Hex color used for the class chip text. If this is missing or invalid, the UI falls back to white.

Character fields are currently deprioritized. The main view reads character names from DanNet groups instead of requiring a hardcoded roster.

`name`

Character name used by DanNet.

`manual`

Boolean. Indicates a character is normally controlled manually.

`kiss_enabled`

Boolean. Indicates a character is normally expected to run KissAssist.

`default_profile`

INI filename to use as the default explicit KissAssist profile. This can be `nil` for manual characters.

`default_commands`

Optional named command lines for different contexts such as group or raid defaults. This is useful when the best start command is not just a profile filename.

`profiles`

List of profile options with `label`, `ini`, and optional `notes`.

## Future Group Defaults

Later config can add group-level or raid-level defaults so Group 1 and Group 2 can start with different commands. A likely shape is:

```lua
sets = {
  group1_default = {
    label = 'Group 1 Default',
    group = 'g1kiss',
    assist = 'Nandladin',
    characters = {
      shadow = 'default',
      nandarie = 'default',
    },
  },
  raid_default = {
    label = 'Raid Default',
    group = 'raidkiss',
    assist = 'Nandladin',
    characters = {},
  },
}
```

`notes`

Free-text display or documentation notes.

## Template Tokens

The scaffold supports these tokens for dry-run preview:

- `{assist}`
- `{character}`
- `{group}`
- `{profile}`

More tokens can be added when real command dispatch is implemented.
