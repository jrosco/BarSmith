------------------------------------------------------------------------
-- BarSmith: Config/ForeverData.lua
-- WoW: Forever (vanilla 60-cap) content data.
--
-- Forever ("camelot") uses the Mainline UI/API, so all the C_* calls in the
-- modules work unchanged. What differs is the *game data*: classes, spells,
-- mounts and items are the 2004 vanilla set, not the Midnight set the retail
-- tables assume. This file holds that data and is consulted only when
-- BarSmith.IsForever is true (retail keeps its own inline tables).
--
-- NOTE: These spell IDs are curated from the Classic 1.12/1.13-spell-era set.
-- They are checked with IsSpellKnown, so an ID the client does not recognise
-- is simply skipped (never an error). Verify/expand in-game with:
--   /dump C_Spell.GetSpellInfo(<id>)   (name, iconID)
------------------------------------------------------------------------

BarSmith.ForeverData = BarSmith.ForeverData or {}

------------------------------------------------------------------------
-- Class utility spells (non-rotational, commonly unbound). Categories match
-- the retail "category" vocabulary so tooltips/sorting behave identically.
------------------------------------------------------------------------

BarSmith.ForeverData.classSpells = {
  WARRIOR = {
    { spellID = 100,    category = "mobility"  }, -- Charge
    { spellID = 6552,   category = "interrupt" }, -- Pummel
    { spellID = 18499,  category = "defensive" }, -- Berserker Rage
    { spellID = 20252,  category = "mobility"  }, -- Intercept
    { spellID = 6343,   category = "utility"   }, -- Thunder Clap
  },
  PALADIN = {
    { spellID = 633,   category = "utility"   }, -- Lay on Hands
    { spellID = 1022,  category = "utility"   }, -- Blessing of Protection
    { spellID = 6940,  category = "utility"   }, -- Blessing of Sacrifice
    { spellID = 642,   category = "defensive" }, -- Divine Shield
    { spellID = 853,   category = "utility"   }, -- Hammer of Justice
  },
  HUNTER = {
    { spellID = 5384,  category = "defensive" }, -- Feign Death
    { spellID = 5116,  category = "utility"   }, -- Concussive Shot
    { spellID = 1543,  category = "utility"   }, -- Flare
    { spellID = 1499,  category = "utility"   }, -- Freezing Trap
    { spellID = 1130,  category = "utility"   }, -- Hunter's Mark
  },
  ROGUE = {
    { spellID = 1766,  category = "interrupt" }, -- Kick
    { spellID = 2094,  category = "utility"   }, -- Blind
    { spellID = 1856,  category = "defensive" }, -- Vanish
    { spellID = 5277,  category = "defensive" }, -- Evasion
    { spellID = 2983,  category = "mobility"  }, -- Sprint
  },
  PRIEST = {
    { spellID = 15487, category = "interrupt" }, -- Silence
    { spellID = 586,   category = "defensive" }, -- Fade
    { spellID = 8122,  category = "utility"   }, -- Psychic Scream
    { spellID = 528,   category = "utility"   }, -- Dispel Magic
    { spellID = 19236, category = "utility"   }, -- Desperate Prayer
  },
  SHAMAN = {
    { spellID = 8042,  category = "interrupt" }, -- Earth Shock
    { spellID = 8177,  category = "utility"   }, -- Grounding Totem
    { spellID = 370,   category = "utility"   }, -- Purge
    { spellID = 2645,  category = "mobility"  }, -- Ghost Wolf
    { spellID = 8056,  category = "utility"   }, -- Frost Shock
  },
  MAGE = {
    { spellID = 2139,  category = "interrupt" }, -- Counterspell
    { spellID = 1953,  category = "mobility"  }, -- Blink
    { spellID = 122,   category = "utility"   }, -- Frost Nova
    { spellID = 118,   category = "utility"   }, -- Polymorph
    { spellID = 130,   category = "utility"   }, -- Slow Fall
  },
  WARLOCK = {
    { spellID = 698,   category = "utility"  }, -- Ritual of Summoning
    { spellID = 710,   category = "utility"  }, -- Banish
    { spellID = 6201,  category = "utility"  }, -- Create Healthstone
    { spellID = 5784,  category = "mobility" }, -- Summon Felsteed
    { spellID = 23161, category = "mobility" }, -- Summon Dreadsteed
  },
  DRUID = {
    { spellID = 22812, category = "defensive" }, -- Barkskin
    { spellID = 29166, category = "utility"   }, -- Innervate
    { spellID = 20484, category = "utility"   }, -- Rebirth
    { spellID = 5211,  category = "interrupt" }, -- Bash
    { spellID = 770,   category = "utility"   }, -- Faerie Fire
  },
}

------------------------------------------------------------------------
-- Mounts. Forever has no mount journal; mounts are spells learned from items.
-- Detection uses C_SpellBook.IsSpellKnown(spellID), so unrecognised entries
-- are harmless. Class mounts are reliable; the racial trainer mounts are a
-- representative starter set (verify/expand in-game).
------------------------------------------------------------------------

BarSmith.ForeverData.mounts = {
  -- Class mounts (Paladin)
  { spellID = 13819 }, -- Summon Warhorse (40)
  { spellID = 23214 }, -- Summon Charger  (60)
  -- Class mounts (Warlock)
  { spellID = 5784  }, -- Summon Felsteed   (40)
  { spellID = 23161 }, -- Summon Dreadsteed (60)
  -- Racial trainer mounts (level 40) -- verify IDs
  { spellID = 458   }, -- Human: Horse
  { spellID = 6896  }, -- Dwarf: Ram
  { spellID = 10789 }, -- Night Elf: Nightsaber
  { spellID = 17453 }, -- Gnome: Mechanostrider
  { spellID = 6653  }, -- Orc: Wolf
  { spellID = 18989 }, -- Tauren: Kodo
  { spellID = 8394  }, -- Troll: Raptor
  { spellID = 8980  }, -- Undead: Skeletal Horse
}

------------------------------------------------------------------------
-- Hearthstones. Vanilla has a single Hearthstone item (6948) and no hearthstone
-- toys, engineering teleporters, or player housing.
------------------------------------------------------------------------

BarSmith.ForeverData.hearthstones = {
  hearthstoneItem = 6948, -- Hearthstone
  hearthstoneToys = {},    -- none in vanilla
  engineerItems  = {},     -- none in vanilla
}
