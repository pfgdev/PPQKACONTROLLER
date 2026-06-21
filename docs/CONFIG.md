# Config

The first config format is a Lua module that returns a table.

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
  profiles = {
    shadow = {
      default = { label = 'default', ini = 'KissAssist_Shadow.ini' },
      solo = { label = 'solo', ini = 'KissAssist_Shadow_Solo.ini' },
    },
  },
  active_profiles = {
    shadow = 'default',
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

Ordered groups to show in the main status table. `peers` is the DanNet group used to list characters. `control` is the DanNet group likely used later for quick commands.

`active_profiles`

Local saved active profile key by character name. This means "the profile this manager intends to load for that character," not necessarily a live value detected from KissAssist.

`profiles`

Profile choices by character name. Each profile has a key, display label, and KissAssist INI filename.

`characters`

Optional legacy/configured character definitions. The main status table should not depend on this list.

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

## Character Fields

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
      Shadow = 'KissAssist_Shadow.ini',
      Nandarie = 'KissAssist_Nandarie.ini',
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
