------------------------------------------------------------------------
-- BarSmith: Config/Defaults.lua
-- Default configuration values and saved variable initialization
------------------------------------------------------------------------

BarSmith.DEFAULTS = {
  -- Global (account-wide) defaults
  global = {
    debug = false,
    minimap = { hide = false, angle = 225 },
  },

  -- Per-character defaults
  char = {
    enabled = true,
    autoFill = true,               -- auto-fill on login / zone change
    confirmBeforeFill = false,     -- prompt user before placing items

    -- Dedicated bar settings
    barLocked = true,                 -- lock bar position
    barColumns = 12,                  -- buttons per row (1-12)
    barIconSize = 38,                 -- button/icon size in pixels
    barShowBackdrop = true,           -- show the bar container background/border
    barAutoHideMouseover = false,     -- fade bar until mouseover
    barAlpha = 1,                     -- bar frame alpha (0.1 - 1.0)
    flyoutDirection = "TOP",          -- TOP, BOTTOM, LEFT, RIGHT
    barPosition = nil,                -- saved {point, relPoint, x, y}
    hideEmptyModules = true,          -- hide placeholder buttons for enabled but empty modules
    masqueEnabled = true,             -- allow Masque to skin BarSmith buttons

    -- QuickBar (separate quick-access bar)
    quickBar = {
      enabled = false,
      iconSize = 42,
      columns = 10,
      alpha = 1,
      showBackdrop = true,
      position = nil, -- {x, y} in UIParent space
      slots = {}, -- [index] = item data
    },

    -- Module toggles
    modules = {
      questItems   = true,
      consumables  = true,
      trinkets     = true,
      classSpells  = true,
      professions  = false,
      mounts       = true,
      hearthstones = true,
      macros       = false,
    },

    -- Priority order (lower = placed first, gets earlier slots)
    priority = {
      "questItems",
      "hearthstones",
      "consumables",
      "trinkets",
      "professions",
      "mounts",
      "classSpells",
      "macros",
    },

    -- Per-module remembered "last used" action identity.
    -- Used to choose each module group's primary icon/action.
    lastUsedByModule = {},
    exclude = {},

    -- Consumable sub-categories
    consumables = {
      potions       = true,
      flasks        = true,
      food          = true,
      bandages      = true,
      utilities     = true,
      currentExpansionOnly = false,
      split = {
        potions       = false,
        flasks        = false,
        food          = false,
        bandages      = false,
        utilities     = false,
      },
      splitCurrentExpansion = {
        potions       = false,
        flasks        = false,
        food          = false,
        bandages      = false,
        utilities     = false,
      },
      include = {
        potions   = {},
        flasks    = {},
        food      = {},
        bandages  = {},
        utilities = {},
      },
    },

    -- Class spells: auto-detected, but user can add custom spell IDs
    classSpells = {
      customSpellIDs = {},
    },

    -- Mount settings
    mounts = {
      favoriteOnly = true,         -- only place favorited mounts
      randomMount  = true,         -- use "Summon Random Favorite Mount"
      dragonriding = true,         -- include dragonriding / skyriding
      include      = {},           -- mountID -> true (always include)
      topFavorites = false,        -- add top favorite mounts
    },

    -- Hearthstone settings
    hearthstones = {
      includeEngineer = true,        -- Wormhole generators, etc.
      includeToys     = true,        -- Hearthstone toy variants
      preferredToyID  = nil,         -- specific toy ID to always place
    },

    -- Macro settings
    macros = {
      slotCount = 1,                 -- number of macro slots to create
      slots = {},                    -- slotIndex -> { macroID = X }
    },
  },
}

------------------------------------------------------------------------
-- Initialize saved variables
------------------------------------------------------------------------

function BarSmith:InitDB()
  -- Account-wide
  if not BarSmithDB then
    BarSmithDB = CopyTable(self.DEFAULTS.global)
  end
  self.db = BarSmithDB

  -- Per-character
  if not BarSmithCharDB then
    BarSmithCharDB = CopyTable(self.DEFAULTS.char)
  end
  self.chardb = BarSmithCharDB

  -- Migration: fill in any missing keys from defaults
  self:MigrateDefaults(self.db, self.DEFAULTS.global)
  self:MigrateDefaults(self.chardb, self.DEFAULTS.char)

  -- Ensure priority list contains any newly added default modules.
  self:SyncPriorityWithDefaults()
end

function BarSmith:MigrateDefaults(saved, defaults)
  for k, v in pairs(defaults) do
    if saved[k] == nil then
      if type(v) == "table" then
        saved[k] = CopyTable(v)
      else
        saved[k] = v
      end
    elseif type(v) == "table" and type(saved[k]) == "table" then
      self:MigrateDefaults(saved[k], v)
    end
  end
end

------------------------------------------------------------------------
-- Priority list helpers
------------------------------------------------------------------------

function BarSmith:SyncPriorityWithDefaults()
  local priority = self.chardb and self.chardb.priority
  local defaults = self.DEFAULTS and self.DEFAULTS.char and self.DEFAULTS.char.priority
  if type(priority) ~= "table" or type(defaults) ~= "table" then
    return
  end

  local seen = {}
  for _, v in ipairs(priority) do
    seen[v] = true
  end

  local changed = false
  for _, v in ipairs(defaults) do
    if not seen[v] then
      table.insert(priority, v)
      seen[v] = true
      changed = true
    end
  end

  if changed then
    BarSmith:Debug("Priority list updated with new default modules.")
  end
end

------------------------------------------------------------------------
-- Reset helpers
------------------------------------------------------------------------

function BarSmith:ResetCharacterSettings()
  BarSmithCharDB = CopyTable(self.DEFAULTS.char)
  self.chardb = BarSmithCharDB
  self:Print("Character settings reset to defaults.")
  self:FireCallback("SETTINGS_CHANGED")
end

function BarSmith:ResetCharacterSettingsKeepLists()
  local chardb = self.chardb or {}
  local keepExclude = chardb.exclude and CopyTable(chardb.exclude) or nil
  local keepConsumableInclude = chardb.consumables and chardb.consumables.include
    and CopyTable(chardb.consumables.include) or nil
  local keepMountInclude = chardb.mounts and chardb.mounts.include
    and CopyTable(chardb.mounts.include) or nil
  local keepClassSpells = chardb.classSpells and chardb.classSpells.customSpellIDs
    and CopyTable(chardb.classSpells.customSpellIDs) or nil
  local keepMacroSlots = chardb.macros and chardb.macros.slots
    and CopyTable(chardb.macros.slots) or nil

  BarSmithCharDB = CopyTable(self.DEFAULTS.char)
  self.chardb = BarSmithCharDB

  if keepExclude then
    self.chardb.exclude = keepExclude
  end
  if keepConsumableInclude then
    self.chardb.consumables.include = keepConsumableInclude
  end
  if keepMountInclude then
    self.chardb.mounts.include = keepMountInclude
  end
  if keepClassSpells then
    self.chardb.classSpells.customSpellIDs = keepClassSpells
  end
  if keepMacroSlots then
    self.chardb.macros.slots = keepMacroSlots
  end

  self:Print("Settings reset (includes/excludes preserved).")
  self:FireCallback("SETTINGS_CHANGED")
end

function BarSmith:ResetGlobalSettings()
  BarSmithDB = CopyTable(self.DEFAULTS.global)
  self.db = BarSmithDB
  self:Print("Global settings reset to defaults.")
  self:FireCallback("SETTINGS_CHANGED")
end
