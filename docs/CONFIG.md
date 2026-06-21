# Config

The first config format is a Lua module that returns a table.

Sample:

```lua
return {
  name = 'PPQ Group 1',
  assist = 'Nandladin',
  groups = {
    all = 'g1',
    kiss = 'g1kiss',
  },
  characters = {
    {
      name = 'Shadow',
      class = 'Ranger',
      role = 'Assist DPS',
      default_profile = 'KissAssist_Shadow.ini',
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

Named DanNet groups. The code should refer to logical keys such as `kiss` and `all`, while the config provides real group names such as `g1kiss` and `g1`.

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

`profiles`

List of profile options with `label`, `ini`, and optional `notes`.

`notes`

Free-text display or documentation notes.

## Template Tokens

The scaffold supports these tokens for dry-run preview:

- `{assist}`
- `{character}`
- `{group}`
- `{profile}`

More tokens can be added when real command dispatch is implemented.

