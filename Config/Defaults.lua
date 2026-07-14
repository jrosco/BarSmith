------------------------------------------------------------------------
-- BarSmith: Config/Defaults.lua
-- Default configuration values and saved variable initialization
------------------------------------------------------------------------

local DEFAULT_PROFILE_ID = "default"

local function TrimString(value)
  return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function NormalizeProfileName(value, fallback)
  local name = TrimString(value)
  if name == "" then
    return fallback or "Profile"
  end
  return name
end

BarSmith.DEFAULTS = {
  -- Global (account-wide) defaults
  global = {
    debug = false,
    minimap = { hide = false, angle = 225 },
  },

  -- Per-profile defaults
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
    flyoutMax = 12,                   -- max buttons per flyout (1-24)
    flyoutDirection = "TOP",          -- TOP, BOTTOM, LEFT, RIGHT
    flyoutDirectionByModule = {},     -- moduleKey -> TOP/BOTTOM/LEFT/RIGHT (nil = global)
    tooltipModifier = "NONE",         -- NONE, ALT, SHIFT, CTRL
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
      tooltipModifier = "NONE",       -- NONE, ALT, SHIFT, CTRL
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
      toys         = false,
      hearthstones = true,
      macros       = false,
      microMenu    = false,
    },

    -- Priority order (lower = placed first, gets earlier slots)
    priority = {
      "questItems",
      "hearthstones",
      "consumables",
      "trinkets",
      "professions",
      "mounts",
      "toys",
      "classSpells",
      "macros",
      "microMenu",
    },

    -- Per-module remembered "last used" action identity.
    -- Used to choose each module group's primary icon/action.
    lastUsedByModule = {},
    -- Per-module pinned primary action identity (overrides last used when set).
    pinnedByModule = {},
    exclude = {},
    filters = {
      battleground_only_items = true,
    },
    autoAdded = {},

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
      allFavorites = false,        -- add all favorite mounts
    },

    -- Toy settings
    toys = {
      include = {},                -- toyID -> true (always include)
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

    -- Micro menu settings
    microMenu = {
      hideDefault = false,           -- hide Blizzard micro menu when enabled
    },
  },

  -- Per-character saved state
  selection = {
    profile = DEFAULT_PROFILE_ID,
  },
}

------------------------------------------------------------------------
-- Initialize saved variables
------------------------------------------------------------------------

function BarSmith:GetCharacterKey()
  local name, realm = nil, nil
  if UnitFullName then
    name, realm = UnitFullName("player")
  end
  if not name and UnitName then
    name = UnitName("player")
  end
  if not realm and GetRealmName then
    realm = GetRealmName()
  end
  if realm and realm ~= "" then
    return tostring(name or "Player") .. "-" .. tostring(realm)
  end
  return tostring(name or "Player")
end

function BarSmith:GetProfileStore()
  if not self.db then return nil end
  self.db.profiles = self.db.profiles or {}
  return self.db.profiles
end

function BarSmith:GetProfileOrder()
  if not self.db then return {} end
  self.db.profileOrder = self.db.profileOrder or {}
  return self.db.profileOrder
end

function BarSmith:RebuildProfileOrder()
  local profiles = self:GetProfileStore()
  if not profiles then return end

  local order = {}
  if profiles[DEFAULT_PROFILE_ID] then
    table.insert(order, DEFAULT_PROFILE_ID)
  end

  local rest = {}
  for id, profile in pairs(profiles) do
    if id ~= DEFAULT_PROFILE_ID and type(profile) == "table" then
      table.insert(rest, { id = id, name = profile.name or id })
    end
  end

  table.sort(rest, function(a, b)
    local an = string.lower(tostring(a.name or a.id))
    local bn = string.lower(tostring(b.name or b.id))
    if an == bn then
      return tostring(a.id) < tostring(b.id)
    end
    return an < bn
  end)

  for _, entry in ipairs(rest) do
    table.insert(order, entry.id)
  end

  self.db.profileOrder = order
end

function BarSmith:SanitizeProfileRecord(profile, fallbackName)
  if type(profile) ~= "table" then
    return nil
  end

  if type(profile.blacklist) == "table" and type(profile.exclude) ~= "table" then
    profile.exclude = CopyTable(profile.blacklist)
  end

  self:MigrateDefaults(profile, self.DEFAULTS.char)

  for key in pairs(profile) do
    if type(key) == "string" and key:sub(1, 1) == "_" then
      profile[key] = nil
    end
  end

  profile.name = NormalizeProfileName(profile.name, fallbackName or "Profile")
  profile.blacklist = nil
  profile._autoHideBeforeUnlock = nil
  return profile
end

function BarSmith:EnsureProfileRecord(profileID, source, fallbackName)
  local profiles = self:GetProfileStore()
  if not profiles or not profileID then return nil end

  local profile = profiles[profileID]
  if type(profile) ~= "table" then
    profile = CopyTable(source or self.DEFAULTS.char)
    profiles[profileID] = profile
  end

  self:SanitizeProfileRecord(profile, fallbackName or profileID)
  return profile
end

function BarSmith:GetProfileByID(profileID)
  local profiles = self:GetProfileStore()
  if not profiles then return nil end
  if not profileID or profileID == "" then
    profileID = DEFAULT_PROFILE_ID
  end
  return profiles[profileID]
end

function BarSmith:GetProfileDisplayName(profileID)
  local profile = self:GetProfileByID(profileID)
  if profile and profile.name then
    return profile.name
  end
  if profileID == DEFAULT_PROFILE_ID then
    return "Default"
  end
  return tostring(profileID or "Profile")
end

function BarSmith:GetActiveProfileID()
  if self.profileCharDB and self.profileCharDB.profile and self.profileCharDB.profile ~= "" then
    return self.profileCharDB.profile
  end
  return DEFAULT_PROFILE_ID
end

function BarSmith:GetActiveProfileName()
  return self:GetProfileDisplayName(self:GetActiveProfileID())
end

function BarSmith:FindProfileIDByName(profileName)
  local target = string.lower(NormalizeProfileName(profileName, ""))
  if target == "" then
    return nil
  end

  local profiles = self:GetProfileStore()
  if not profiles then
    return nil
  end
  local order = self:GetProfileOrder()
  for _, id in ipairs(order) do
    local profile = profiles[id]
    if profile and string.lower(tostring(profile.name or "")) == target then
      return id
    end
  end

  for id, profile in pairs(profiles) do
    if profile and string.lower(tostring(profile.name or "")) == target then
      return id
    end
  end

  return nil
end

function BarSmith:ResolveProfileID(value)
  local text = NormalizeProfileName(value, "")
  if text == "" then
    return self:GetActiveProfileID()
  end

  local profiles = self:GetProfileStore()
  if not profiles then
    return nil
  end
  if profiles[text] then
    return text
  end

  local byName = self:FindProfileIDByName(text)
  if byName then
    return byName
  end

  return nil
end

function BarSmith:IsProfileNameAvailable(profileName, ignoreID)
  local target = string.lower(NormalizeProfileName(profileName, ""))
  if target == "" then
    return false
  end

  local profiles = self:GetProfileStore()
  if not profiles then
    return true
  end
  for id, profile in pairs(profiles or {}) do
    if id ~= ignoreID and profile and string.lower(tostring(profile.name or "")) == target then
      return false
    end
  end
  return true
end

function BarSmith:GenerateProfileID()
  local profiles = self:GetProfileStore()
  if not profiles then
    return DEFAULT_PROFILE_ID
  end

  local nextID = tonumber(self.db.profileNextID) or 1
  local profileID = nil
  repeat
    profileID = "profile" .. tostring(nextID)
    nextID = nextID + 1
  until not profiles[profileID]

  self.db.profileNextID = nextID
  return profileID
end

function BarSmith:CreateProfile(profileName, source)
  local profiles = self:GetProfileStore()
  if not profiles then return nil end

  local profileID = self:GenerateProfileID()
  local sourceTable = self:GetProfileByID(source)
  if type(source) == "table" then
    sourceTable = source
  end

  local profile = CopyTable(sourceTable or self.DEFAULTS.char)
  local baseName = NormalizeProfileName(profileName, "Profile")
  local uniqueName = baseName
  local suffix = 2
  while not self:IsProfileNameAvailable(uniqueName) do
    uniqueName = baseName .. " (" .. tostring(suffix) .. ")"
    suffix = suffix + 1
  end
  profile.name = uniqueName
  profile.created = time and time() or nil
  profile.updated = time and time() or nil
  profile.blacklist = nil
  profile._autoHideBeforeUnlock = nil
  self:SanitizeProfileRecord(profile, profile.name)
  profiles[profileID] = profile
  self:RebuildProfileOrder()
  return profileID, profile
end

function BarSmith:CloneProfile(sourceProfileID, newProfileName)
  local source = self:GetProfileByID(sourceProfileID)
  if not source then
    source = self:GetProfileByID(DEFAULT_PROFILE_ID) or self.DEFAULTS.char
  end
  return self:CreateProfile(newProfileName, source)
end

function BarSmith:RenameProfile(profileID, newProfileName)
  local profiles = self:GetProfileStore()
  if not profiles or not profileID or profileID == DEFAULT_PROFILE_ID then
    return false, "Default cannot be renamed."
  end

  local profile = profiles[profileID]
  if not profile then
    return false, "Profile not found."
  end

  local name = NormalizeProfileName(newProfileName, "")
  if name == "" then
    return false, "Profile name cannot be blank."
  end
  if not self:IsProfileNameAvailable(name, profileID) then
    return false, "A profile with that name already exists."
  end

  profile.name = name
  profile.updated = time and time() or nil
  self:SanitizeProfileRecord(profile, name)
  self:RebuildProfileOrder()
  return true
end

function BarSmith:DeleteProfile(profileID)
  local profiles = self:GetProfileStore()
  if not profiles or not profileID or profileID == DEFAULT_PROFILE_ID then
    return false, "Default cannot be deleted."
  end
  if not profiles[profileID] then
    return false, "Profile not found."
  end

  profiles[profileID] = nil
  self:RebuildProfileOrder()

  if self.profileCharDB and self.profileCharDB.profile == profileID then
    self:SetActiveProfile(DEFAULT_PROFILE_ID, true)
  end

  return true
end

function BarSmith:SetActiveProfile(profileID, silent)
  local requestedID = NormalizeProfileName(profileID, "")
  local resolvedID = nil
  if requestedID == "" then
    resolvedID = DEFAULT_PROFILE_ID
  else
    resolvedID = self:ResolveProfileID(requestedID)
    if not resolvedID then
      return false, "Profile not found."
    end
  end
  local profiles = self:GetProfileStore()
  if not profiles then
    return false, "Profile store unavailable."
  end

  local profile = self:EnsureProfileRecord(resolvedID, self.DEFAULTS.char, resolvedID == DEFAULT_PROFILE_ID and "Default" or resolvedID)
  if not profile then
    return false, "Unable to load profile."
  end

  self.profileCharDB = self.profileCharDB or {}
  self.profileCharDB.profile = resolvedID
  BarSmithCharDB = self.profileCharDB

  self.chardb = profile
  self.activeProfileID = resolvedID

  local barFrame = self:GetModule("BarFrame")
  if barFrame then
    barFrame._autoHideBeforeUnlock = nil
  end

  if self.SyncFiltersFromSettings then
    self:SyncFiltersFromSettings()
  end
  if self.RefreshSettingsProxy then
    self:RefreshSettingsProxy()
  end

  local quickBar = self:GetModule("QuickBar")
  if quickBar and quickBar.Refresh then
    quickBar:Refresh()
  end

  if not silent then
    self:Print("Active profile: " .. self:GetActiveProfileName())
    self:FireCallback("SETTINGS_CHANGED")
  end

  return true
end

function BarSmith:GetProfileList()
  local profiles = self:GetProfileStore()
  if not profiles then
    return {}
  end
  local order = self:GetProfileOrder()
  local activeID = self:GetActiveProfileID()
  local list = {}

  for _, id in ipairs(order) do
    local profile = profiles[id]
    if profile then
      table.insert(list, {
        id = id,
        name = profile.name or id,
        active = (id == activeID),
      })
    end
  end

  return list
end

function BarSmith:EnsureProfileStore()
  if not self.db then return end

  self.db.profiles = self.db.profiles or {}
  self.db.profileNextID = tonumber(self.db.profileNextID) or 1

  local profiles = self.db.profiles
  local defaultProfile = profiles[DEFAULT_PROFILE_ID]
  if type(defaultProfile) ~= "table" then
    defaultProfile = CopyTable(self.DEFAULTS.char)
    profiles[DEFAULT_PROFILE_ID] = defaultProfile
  end
  self:SanitizeProfileRecord(defaultProfile, "Default")
  defaultProfile.name = "Default"

  for id, profile in pairs(profiles) do
    if type(profile) == "table" then
      self:SanitizeProfileRecord(profile, id == DEFAULT_PROFILE_ID and "Default" or id)
    else
      profiles[id] = CopyTable(self.DEFAULTS.char)
      self:SanitizeProfileRecord(profiles[id], id == DEFAULT_PROFILE_ID and "Default" or id)
    end
  end

  self:RebuildProfileOrder()
end

function BarSmith:NormalizeLegacyCharacterDB(source)
  local legacy = {}
  local sourceTable = type(source) == "table" and source or {}
  for k, v in pairs(sourceTable) do
    if k ~= "profile" and k ~= "profileVersion" and not (type(k) == "string" and k:sub(1, 1) == "_") then
      legacy[k] = v
    end
  end

  if type(legacy.blacklist) == "table" and type(legacy.exclude) ~= "table" then
    legacy.exclude = CopyTable(legacy.blacklist)
  end

  return legacy
end

function BarSmith:MigrateLegacyCharacterProfile()
  self.profileCharDB = BarSmithCharDB or {}
  BarSmithCharDB = self.profileCharDB

  local selectedProfileID = self.profileCharDB.profile
  if selectedProfileID and self:GetProfileByID(selectedProfileID) then
    self.profileCharDB = {
      profile = selectedProfileID,
    }
    BarSmithCharDB = self.profileCharDB
    self:SetActiveProfile(selectedProfileID, true)
    return
  end

  local legacy = self:NormalizeLegacyCharacterDB(self.profileCharDB)
  local hasLegacyData = next(legacy) ~= nil
  local profileID = DEFAULT_PROFILE_ID

  if hasLegacyData then
    local profileName = self:GetCharacterKey()
    profileID = self:GenerateProfileID()
    local profile = CopyTable(self.DEFAULTS.char)
    for k, v in pairs(legacy) do
      profile[k] = v
    end
    profile.name = profileName
    profile.blacklist = nil
    profile._autoHideBeforeUnlock = nil
    self:SanitizeProfileRecord(profile, profileName)
    self.db.profiles[profileID] = profile
    self:RebuildProfileOrder()
  end

  self.profileCharDB = {
    profile = profileID,
  }
  BarSmithCharDB = self.profileCharDB
  self:SetActiveProfile(profileID, true)
end

function BarSmith:InitDB()
  -- Account-wide
  if not BarSmithDB then
    BarSmithDB = CopyTable(self.DEFAULTS.global)
  end
  self.db = BarSmithDB

  self:EnsureProfileStore()

  -- Migration: fill in any missing keys from defaults
  self:MigrateDefaults(self.db, self.DEFAULTS.global)
  self:MigrateLegacyCharacterProfile()

  if type(self.chardb.modules) ~= "table" then
    self.chardb.modules = CopyTable(self.DEFAULTS.char.modules)
  end
  if type(self.chardb.priority) ~= "table" or #self.chardb.priority == 0 then
    self.chardb.priority = CopyTable(self.DEFAULTS.char.priority)
  end

  -- Normalize module toggles to strict booleans (guards against legacy non-boolean values).
  do
    local defaults = self.DEFAULTS and self.DEFAULTS.char and self.DEFAULTS.char.modules or {}
    for key, defaultValue in pairs(defaults) do
      local value = self.chardb.modules[key]
      if value == nil then
        self.chardb.modules[key] = (defaultValue == true)
      else
        self.chardb.modules[key] = (value == true)
      end
    end
  end

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
  local activeID = self:GetActiveProfileID()
  local profile = self:EnsureProfileRecord(activeID, self.DEFAULTS.char, activeID == DEFAULT_PROFILE_ID and "Default" or activeID)
  if not profile then return end

  local profileName = profile.name or self:GetProfileDisplayName(activeID)
  local created = profile.created
  local resetProfile = CopyTable(self.DEFAULTS.char)
  resetProfile.name = profileName
  resetProfile.created = created
  resetProfile.updated = time and time() or nil
  if activeID == DEFAULT_PROFILE_ID then
    resetProfile.name = "Default"
  end
  self.db.profiles[activeID] = resetProfile
  self.chardb = resetProfile
  local barFrame = self:GetModule("BarFrame")
  if barFrame then
    barFrame._autoHideBeforeUnlock = nil
  end
  if self.SyncFiltersFromSettings then
    self:SyncFiltersFromSettings()
  end
  self:Print("Profile reset to defaults: " .. resetProfile.name)
  if self.RefreshSettingsProxy then
    self:RefreshSettingsProxy()
  end
  local quickBar = self:GetModule("QuickBar")
  if quickBar and quickBar.Refresh then
    quickBar:Refresh()
  end
  self:FireCallback("SETTINGS_CHANGED")
end

function BarSmith:ResetCharacterSettingsKeepLists()
  local chardb = self.chardb or {}
  local keepExclude = chardb.exclude and CopyTable(chardb.exclude) or nil
  local keepConsumableInclude = chardb.consumables and chardb.consumables.include
    and CopyTable(chardb.consumables.include) or nil
  local keepMountInclude = chardb.mounts and chardb.mounts.include
    and CopyTable(chardb.mounts.include) or nil
  local keepToyInclude = chardb.toys and chardb.toys.include
    and CopyTable(chardb.toys.include) or nil
  local keepClassSpells = chardb.classSpells and chardb.classSpells.customSpellIDs
    and CopyTable(chardb.classSpells.customSpellIDs) or nil
  local keepMacroSlots = chardb.macros and chardb.macros.slots
    and CopyTable(chardb.macros.slots) or nil

  local activeID = self:GetActiveProfileID()
  local profile = self:EnsureProfileRecord(activeID, self.DEFAULTS.char, activeID == DEFAULT_PROFILE_ID and "Default" or activeID)
  if not profile then return end

  local profileName = profile.name or self:GetProfileDisplayName(activeID)
  local created = profile.created
  local resetProfile = CopyTable(self.DEFAULTS.char)
  resetProfile.name = profileName
  resetProfile.created = created
  resetProfile.updated = time and time() or nil
  if keepExclude then
    resetProfile.exclude = keepExclude
  end
  if keepConsumableInclude then
    resetProfile.consumables.include = keepConsumableInclude
  end
  if keepMountInclude then
    resetProfile.mounts.include = keepMountInclude
  end
  if keepToyInclude then
    resetProfile.toys.include = keepToyInclude
  end
  if keepClassSpells then
    resetProfile.classSpells.customSpellIDs = keepClassSpells
  end
  if keepMacroSlots then
    resetProfile.macros.slots = keepMacroSlots
  end

  self.db.profiles[activeID] = resetProfile
  self.chardb = resetProfile
  local barFrame = self:GetModule("BarFrame")
  if barFrame then
    barFrame._autoHideBeforeUnlock = nil
  end
  if self.SyncFiltersFromSettings then
    self:SyncFiltersFromSettings()
  end

  self:Print("Profile reset (includes/excludes preserved): " .. resetProfile.name)
  if self.RefreshSettingsProxy then
    self:RefreshSettingsProxy()
  end
  local quickBar = self:GetModule("QuickBar")
  if quickBar and quickBar.Refresh then
    quickBar:Refresh()
  end
  self:FireCallback("SETTINGS_CHANGED")
end

function BarSmith:ResetGlobalSettings()
  BarSmithDB = CopyTable(self.DEFAULTS.global)
  self.db = BarSmithDB
  self:Print("Global settings reset to defaults.")
  if self.RefreshSettingsProxy then
    self:RefreshSettingsProxy()
  end
  self:FireCallback("SETTINGS_CHANGED")
end
