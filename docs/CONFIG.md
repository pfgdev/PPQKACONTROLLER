# Config

The first config format is a Lua module that returns a table.

Sample:

```lua
return {
  name = 'PPQ Boxing Setup',
  assist = 'Nandladin',
  groups = {
    all = 'g1',
    kiss = 'g1kiss',
    group2 = 'g2',
    group2kiss = 'g2kiss',
  },
  characters = {
    {
      name = 'Shadow',
      class = 'Ranger',
      role = 'Assist DPS',
      default_profile = 'KissAssist_Shadow.ini',
      default_commands = {
        group = '/mac kissassist ini KissAssist_Shadow.ini assist ma Nandladin',
        raid = '/mac kissassist ini KissAssist_Shadow_Raid.ini assist ma Nandladin',
      },
      profiles = {
        { label = 'Default DPS', ini = 'KissAssist_Shadow.ini' },
      },
    },
  },
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

Named DanNet groups. The user may define groups such as `g1`, `g1kiss`, `g2`, `g2kiss`, or any future group name. Code should read these from config and not assume a fixed list.

`characters`

Ordered list of character definitions.

`command_templates`

String templates for single commands.

`command_sequences`

Named lists of command templates for multi-step actions.

## Character Fields

`name`

Character name used by DanNet.

`class`

EverQuest class label for display.

`role`

Short role label for display.

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

## Group Defaults

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
