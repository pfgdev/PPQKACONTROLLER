return {
  version = 1,
  name = 'PPQ KA Controller',
  assist = 'Nandladin',
  dry_run = true,

  command_timing = {
    end_to_start_delay_ms = 2000,
    loadout_end_spacing_ms = 250,
    loadout_start_spacing_ms = 750,
  },

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
    character_start_default = '/dex {character} /mac kissassist assist {assist}',
    character_start_profile = '/dex {character} /mac kissassist assist {assist} ini {profile}',
    character_pause = '/dex {character} /mqp on',
    character_resume = '/dex {character} /mqp off',
    character_end = '/dex {character} /end',
    group_start = '/dgex {group} /mac kissassist assist {assist}',
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

  active_assists = {
    blanka = 'Nandladin',
    boomkenzie = 'Nandladin',
    buffs = 'Nandladin',
    essek = 'Nandladin',
    grog = 'Nandladin',
    kelthuzad = 'Nandladin',
    lagspike = 'Nandladin',
    lulu = 'Nandladin',
    morrigan = 'Nandladin',
    nandarie = 'Nandladin',
    nandladin = 'Nandladin',
    nodance = 'Nandladin',
    shadow = 'Nandladin',
  },

  character_meta = {
    blanka = { class = 'SHM', class_color = '#79d7c7' },
    boomkenzie = { class = 'DRU', class_color = '#9de3a3' },
    chetney = { class = 'ROG', class_color = '#f0b070' },
    essek = { class = 'WIZ', class_color = '#8fd0ff' },
    grog = { class = 'BST', class_color = '#d6a25e' },
    kelthuzad = { class = 'NEC', class_color = '#c79cff' },
    lagspike = { class = 'CLR', class_color = '#d7e7ff' },
    lulu = { class = 'CLR', class_color = '#d7e7ff' },
    morrigan = { class = 'MAG', class_color = '#f0a66a' },
    nandarie = { class = 'ENC', class_color = '#d2a7ff' },
    nandladin = { class = 'WAR', class_color = '#d9c18e' },
    nodance = { class = 'BRD', class_color = '#f2a7ef' },
    shadow = { class = 'RNG', class_color = '#b6e07a' },
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
