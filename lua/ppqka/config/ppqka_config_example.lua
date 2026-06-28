return {
  version = 1,
  name = 'PPQ KA Example Config - user config not loaded',
  assist = '',
  dry_run = true,

  command_timing = {
    end_to_start_delay_ms = 2000,
    loadout_end_spacing_ms = 250,
    loadout_start_spacing_ms = 750,
  },

  command_templates = {
    character_start_profile = '/dex {character} /mac kissassist assist {assist} ini {profile}',
  },

  groups = {},
  profiles = {},
  loadouts = {},
  character_meta = {},
}
