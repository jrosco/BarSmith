------------------------------------------------------------------------
-- BarSmith: Modules/ClassSpells.lua
-- Detects class-specific utility spells for action bar placement
-- (Interrupts, defensives, utility, racials, etc.)
------------------------------------------------------------------------

local ClassSpells = BarSmith:NewModule("ClassSpells")

------------------------------------------------------------------------
-- Class utility spells that are good candidates for a utility bar
-- Format: [CLASS] = { { spellID = X, name = "...", category = "..." }, ... }
-- These are non-rotational utility spells players often forget to bind
------------------------------------------------------------------------

ClassSpells.CLASS_SPELLS = {
  WARRIOR = {
    { spellID = 100,   category = "mobility" },        -- Charge
    { spellID = 6552,  category = "interrupt" },       -- Pummel
    { spellID = 52174, category = "mobility" },        -- Heroic Leap
    { spellID = 97462, category = "raid_cd" },         -- Rallying Cry
    { spellID = 18499, category = "defensive" },       -- Berserker Rage
  },
  PALADIN = {
    { spellID = 633,   category = "utility" },         -- Lay on Hands
    { spellID = 1022,  category = "utility" },         -- Blessing of Protection
    { spellID = 6940,  category = "utility" },         -- Blessing of Sacrifice
    { spellID = 96231, category = "interrupt" },       -- Rebuke
    { spellID = 642,   category = "defensive" },       -- Divine Shield
  },
  HUNTER = {
    { spellID = 187650, category = "interrupt" },      -- Freezing Trap
    { spellID = 109248, category = "utility" },        -- Binding Shot
    { spellID = 186265, category = "defensive" },      -- Aspect of the Turtle
    { spellID = 34477,  category = "utility" },        -- Misdirection
    { spellID = 5384,   category = "utility" },        -- Feign Death
  },
  ROGUE = {
    { spellID = 1766,  category = "interrupt" },       -- Kick
    { spellID = 2094,  category = "utility" },         -- Blind
    { spellID = 1856,  category = "defensive" },       -- Vanish
    { spellID = 31224, category = "defensive" },       -- Cloak of Shadows
    { spellID = 57934, category = "utility" },         -- Tricks of the Trade
  },
  PRIEST = {
    { spellID = 15487, category = "interrupt" },       -- Silence (Shadow)
    { spellID = 33206, category = "utility" },         -- Pain Suppression
    { spellID = 47788, category = "utility" },         -- Guardian Spirit
    { spellID = 73325, category = "mobility" },        -- Leap of Faith
    { spellID = 586,   category = "defensive" },       -- Fade
  },
  DEATHKNIGHT = {
    { spellID = 47528, category = "interrupt" },       -- Mind Freeze
    { spellID = 49576, category = "utility" },         -- Death Grip
    { spellID = 48707, category = "defensive" },       -- Anti-Magic Shell
    { spellID = 48265, category = "mobility" },        -- Death's Advance
    { spellID = 61999, category = "utility" },         -- Raise Ally
  },
  SHAMAN = {
    { spellID = 57994,  category = "interrupt" },      -- Wind Shear
    { spellID = 108271, category = "defensive" },      -- Astral Shift
    { spellID = 198103, category = "utility" },        -- Earth Elemental
    { spellID = 51514,  category = "utility" },        -- Hex
    { spellID = 79206,  category = "utility" },        -- Spiritwalker's Grace
  },
  MAGE = {
    { spellID = 2139,  category = "interrupt" },       -- Counterspell
    { spellID = 45438, category = "defensive" },       -- Ice Block
    { spellID = 1953,  category = "mobility" },        -- Blink
    { spellID = 80353, category = "utility" },         -- Time Warp
    { spellID = 130,   category = "utility" },         -- Slow Fall
  },
  WARLOCK = {
    { spellID = 19647,  category = "interrupt" },      -- Spell Lock (pet)
    { spellID = 104773, category = "defensive" },      -- Unending Resolve
    { spellID = 20707,  category = "utility" },        -- Soulstone
    { spellID = 698,    category = "utility" },        -- Ritual of Summoning
    { spellID = 6201,   category = "utility" },        -- Healthstone
  },
  MONK = {
    { spellID = 116705, category = "interrupt" },      -- Spear Hand Strike
    { spellID = 115078, category = "utility" },        -- Paralysis
    { spellID = 116849, category = "utility" },        -- Life Cocoon
    { spellID = 119381, category = "utility" },        -- Leg Sweep
    { spellID = 101643, category = "utility" },        -- Transcendence
  },
  DRUID = {
    { spellID = 106839, category = "interrupt" },      -- Skull Bash
    { spellID = 22812,  category = "defensive" },      -- Barkskin
    { spellID = 29166,  category = "utility" },        -- Innervate
    { spellID = 20484,  category = "utility" },        -- Rebirth
    { spellID = 102793, category = "utility" },        -- Ursol's Vortex
  },
  DEMONHUNTER = {
    { spellID = 183752, category = "interrupt" },      -- Disrupt
    { spellID = 198589, category = "defensive" },      -- Blur
    { spellID = 196718, category = "utility" },        -- Darkness
    { spellID = 179057, category = "utility" },        -- Chaos Nova
    { spellID = 195072, category = "mobility" },       -- Fel Rush
  },
  EVOKER = {
    { spellID = 351338, category = "interrupt" },      -- Quell
    { spellID = 363916, category = "defensive" },      -- Obsidian Scales
    { spellID = 374348, category = "utility" },        -- Renewing Blaze
    { spellID = 358267, category = "utility" },        -- Hover
    { spellID = 370553, category = "utility" },        -- Tip the Scales
  },
}

function ClassSpells:AddCustomSpell(spellID)
  if not spellID or not BarSmith.chardb or not BarSmith.chardb.classSpells then
    return false
  end
  local list = BarSmith.chardb.classSpells.customSpellIDs
  if type(list) ~= "table" then
    BarSmith.chardb.classSpells.customSpellIDs = {}
    list = BarSmith.chardb.classSpells.customSpellIDs
  end
  for _, id in ipairs(list) do
    if id == spellID then
      return false
    end
  end
  table.insert(list, spellID)
  BarSmith:Print("Added custom spell: " .. tostring(spellID))
  return true
end

function ClassSpells:RemoveCustomSpell(spellID)
  if not spellID or not BarSmith.chardb or not BarSmith.chardb.classSpells then
    return false
  end

  local list = BarSmith.chardb.classSpells.customSpellIDs
  if type(list) ~= "table" then
    return false
  end

  for i, id in ipairs(list) do
    if id == spellID then
      table.remove(list, i)
      return true
    end
  end

  return false
end

------------------------------------------------------------------------
-- Gather class spells for the action bar
------------------------------------------------------------------------

function ClassSpells:GetItems()
  local items = {}

  if not BarSmith.chardb.modules.classSpells then
    return items
  end

  local class = BarSmith:GetPlayerClass()
  local classData = self.CLASS_SPELLS[class]

  if classData then
    for _, spellEntry in ipairs(classData) do
      if self:IsSpellKnown(spellEntry.spellID) then
        local spellInfo = C_Spell.GetSpellInfo(spellEntry.spellID)
        local name = spellInfo and spellInfo.name
        local icon = spellInfo and spellInfo.iconID
        if name then
          table.insert(items, {
            spellID = spellEntry.spellID,
            name = name,
            icon = icon,
            category = spellEntry.category,
            type = "class_spell",
          })
        end
      end
    end
  end

  -- Add user-defined custom spell IDs
  local customIDs = BarSmith.chardb.classSpells.customSpellIDs
  if customIDs then
    for _, spellID in ipairs(customIDs) do
      if self:IsSpellKnown(spellID) then
        local spellInfo = C_Spell.GetSpellInfo(spellID)
        local name = spellInfo and spellInfo.name
        local icon = spellInfo and spellInfo.iconID
        if name then
          table.insert(items, {
            spellID = spellID,
            name = name,
            icon = icon,
            category = "custom",
            type = "class_spell",
          })
        end
      end
    end
  end

  BarSmith:Debug("ClassSpells found: " .. #items)
  return items
end

------------------------------------------------------------------------
-- Check if a spell is known to the player
------------------------------------------------------------------------

function ClassSpells:IsSpellKnown(spellID)
  if not spellID or not C_SpellBook then
    return false
  end
  if C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(spellID) then
    return true
  end
  if C_SpellBook.IsSpellInSpellBook and C_SpellBook.IsSpellInSpellBook(spellID) then
    return true
  end
  return false
end
