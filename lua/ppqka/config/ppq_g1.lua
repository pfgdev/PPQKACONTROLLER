return {
  version = 1,
  name = 'PPQ KA Controller',
  assist = 'Nandladin',
  dry_run = true,

  display_groups = {
    {
      label = 'Group 1',
      peers = 'g1',
      control = 'g1kiss',
    },
    {
      label = 'Group 2',
      peers = 'g2',
      control = 'g2kiss',
    },
  },

  groups = {
    all = 'g1',
    kiss = 'g1kiss',
    group2 = 'g2',
    group2kiss = 'g2kiss',
    manual = 'g1manual',
    melee = 'g1melee',
    heal = 'g1heal',
    cast = 'g1cast',
    cc = 'g1cc',
  },

  command_templates = {
    character_start_default = '/dex {character} /mac kissassist assist ma {assist}',
    character_start_profile = '/dex {character} /mac kissassist ini {profile} assist ma {assist}',
    character_pause = '/dex {character} /mqp on',
    character_resume = '/dex {character} /mqp off',
    character_end = '/dex {character} /end',
    group_start = '/dgex {group} /mac kissassist assist ma {assist}',
    group_pause = '/dgex {group} /mqp on',
    group_resume = '/dgex {group} /mqp off',
    group_end = '/dgex {group} /end',
  },

  command_sequences = {
    character_cleanup = {
      '/dex {character} /attack off',
      '/dex {character} /stick off',
      '/dex {character} /nav stop',
      '/dex {character} /pet back off',
    },
    group_hard_stop = {
      '/dgex {group} /end',
      '/dgex {group} /attack off',
      '/dgex {group} /stick off',
      '/dgex {group} /nav stop',
      '/dgex {group} /pet back off',
    },
  },

  active_profiles = {},
  characters = {},
}
