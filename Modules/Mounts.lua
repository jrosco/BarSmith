------------------------------------------------------------------------
-- BarSmith: Modules/Mounts.lua
-- Provides mount spells for action bar placement
------------------------------------------------------------------------

local Mounts = BarSmith:NewModule("Mounts")

-- Well-known spell IDs
Mounts.RANDOM_FAVORITE_MOUNT = 150544 -- Summon Random Favorite Mount

function Mounts:AddExtraMount(mountID)
  if not mountID then return false end
  local name, spellID, icon, isActive, isUsable, sourceType,
  isFavorite, isFactionSpecific, faction, shouldHideOnChar,
  isCollected = C_MountJournal.GetMountInfoByID(mountID)

  if not isCollected or shouldHideOnChar then
    BarSmith:Print("That mount isn't collected.")
    return false
  end

  local prefs = BarSmith.chardb.mounts
  prefs.include = prefs.include or {}
  prefs.include[mountID] = true
  BarSmith:Print("Included mount.")
  return true
end

------------------------------------------------------------------------
-- Gather mount entries for the action bar
------------------------------------------------------------------------

function Mounts:GetItems()
  local items = {}

  if not BarSmith.chardb.modules.mounts then
    return items
  end

  local prefs = BarSmith.chardb.mounts
  local includes = prefs.include or {}

  local function addMount(mountID, name, spellID, icon, isDragonriding)
    if not spellID then return end
    local macrotext = "/dismount [mounted]\n/cast " .. (name or "Mount")
    table.insert(items, {
      spellID = spellID,
      mountID = mountID,
      name = name or "Mount",
      icon = icon,
      isDragonriding = isDragonriding,
      macrotext = macrotext,
      type = "mount",
    })
  end

  local seenSpellIDs = {}
  local function markSeen(spellID)
    if spellID then
      seenSpellIDs[spellID] = true
    end
  end

  -- Always include includes first
  for mountID, enabled in pairs(includes) do
    if enabled then
      local name, spellID, icon, isActive, isUsable, sourceType,
      isFavorite, isFactionSpecific, faction, shouldHideOnChar,
      isCollected = C_MountJournal.GetMountInfoByID(mountID)

      if isCollected and not shouldHideOnChar then
        local _, _, _, _, mountTypeID = C_MountJournal.GetMountInfoExtraByID(mountID)
        local isDragonriding = (mountTypeID == 402 or mountTypeID == 424)
        addMount(mountID, name, spellID, icon, isDragonriding)
        markSeen(spellID)
      end
    end
  end

  -- Option 1: Use "Summon Random Favorite Mount"
  if prefs.randomMount then
    local spellID = self.RANDOM_FAVORITE_MOUNT
    BarSmith:Debug("Mounts: using Random Favorite Mount spellID=" .. tostring(spellID))
    if not seenSpellIDs[spellID] then
      table.insert(items, {
        spellID = self.RANDOM_FAVORITE_MOUNT,
        name = "Summon Random Favorite Mount",
        icon = 853211,       -- mount icon
        macrotext = "/dismount [mounted]\n/run if C_MountJournal and C_MountJournal.SummonByID then C_MountJournal.SummonByID(0) end",
        type = "mount",
      })
      markSeen(spellID)
    end
    BarSmith:Debug("Mounts: added Random Favorite Mount")
  end

  -- Option 2: Place top favorite mounts (optional)
  if prefs.topFavorites then
    local mountIDs = C_MountJournal.GetMountIDs()
    if not mountIDs then return items end

    local favoritesAdded = 0
    local limit = 5

    for _, mountID in ipairs(mountIDs) do
      local name, spellID, icon, isActive, isUsable, sourceType,
      isFavorite, isFactionSpecific, faction, shouldHideOnChar,
      isCollected = C_MountJournal.GetMountInfoByID(mountID)

      if isCollected and not shouldHideOnChar then
        local shouldAdd = false

        if prefs.favoriteOnly then
          shouldAdd = isFavorite
        else
          shouldAdd = isUsable
        end

        if shouldAdd then
          -- Check mount type for dragonriding filter
          local _, _, _, _, mountTypeID = C_MountJournal.GetMountInfoExtraByID(mountID)

          -- mountTypeID 402 = Dragonriding, 424 = Dynamic flying
          local isDragonriding = (mountTypeID == 402 or mountTypeID == 424)

          if isDragonriding and not prefs.dragonriding then
            shouldAdd = false
          end

          if shouldAdd and spellID and not seenSpellIDs[spellID] then
            addMount(mountID, name, spellID, icon, isDragonriding)
            markSeen(spellID)
            favoritesAdded = favoritesAdded + 1
            if favoritesAdded >= limit then break end
          end
        end
      end
    end
  end

  BarSmith:Debug("Mounts found: " .. #items)
  return items
end
