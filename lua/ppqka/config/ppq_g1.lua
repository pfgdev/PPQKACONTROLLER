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

  profiles = {
    blanka = {
      default = { label = 'default', ini = 'KissAssist_Blanka.ini' },
    },
    boomkenzie = {
      default = { label = 'default', ini = 'KissAssist_Boomkenzie.ini' },
    },
    buffs = {
      default = { label = 'default', ini = 'KissAssist_Buffs.ini' },
    },
    essek = {
      default = { label = 'default', ini = 'KissAssist_Essek.ini' },
    },
    grog = {
      default = { label = 'default', ini = 'KissAssist_Grog.ini' },
    },
    kelthuzad = {
      default = { label = 'default', ini = 'KissAssist_Kelthuzad.ini' },
    },
    lagspike = {
      default = { label = 'default', ini = 'KissAssist_Lagspike.ini' },
    },
    lulu = {
      default = { label = 'default', ini = 'KissAssist_Lulu.ini' },
    },
    morrigan = {
      default = { label = 'default', ini = 'KissAssist_Morrigan.ini' },
    },
    nandarie = {
      default = { label = 'default', ini = 'KissAssist_Nandarie.ini' },
    },
    nandladin = {
      default = { label = 'default', ini = 'KissAssist_Nandladin.ini' },
    },
    nodance = {
      default = { label = 'default', ini = 'KissAssist_Nodance.ini' },
    },
    shadow = {
      default = { label = 'default', ini = 'KissAssist_Shadow.ini' },
      solo = { label = 'solo', ini = 'KissAssist_Shadow_Solo.ini' },
    },
  },

  active_profiles = {
    blanka = 'default',
    boomkenzie = 'default',
    buffs = 'default',
    essek = 'default',
    grog = 'default',
    kelthuzad = 'default',
    lagspike = 'default',
    lulu = 'default',
    morrigan = 'default',
    nandarie = 'default',
    nandladin = 'default',
    nodance = 'default',
    shadow = 'default',
  },

  loadouts = {
    {
      key = 'g1_normal',
      label = 'Group 1 - Normal',
      assist = 'Nandladin',
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
