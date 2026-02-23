------------------------------------------------------------------------
-- BarSmith: Init.lua
-- Entry point: wires events, slash commands, and kicks off first fill
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Slash Commands
------------------------------------------------------------------------

SLASH_BARSMITH1 = "/barsmith"
SLASH_BARSMITH2 = "/bs"

SlashCmdList["BARSMITH"] = function(msg)
  msg = strtrim(msg or ""):lower()

  if msg == "fill" or msg == "run" then
    BarSmith:RunAutoFill()
  elseif msg == "clear" then
    if not InCombatLockdown() then
      local barFrame = BarSmith:GetModule("BarFrame")
      if barFrame then
        barFrame:ClearAll()
        barFrame:Hide()
        BarSmith:Print("Bar cleared.")
      end
    else
      BarSmith:Print("Cannot clear bar during combat.")
    end
  elseif msg == "lock" then
    local barFrame = BarSmith:GetModule("BarFrame")
    if barFrame then
      barFrame:SetLocked(not BarSmith.chardb.barLocked)
    end
  elseif msg == "show" then
    local barFrame = BarSmith:GetModule("BarFrame")
    if barFrame then barFrame:Show() end
  elseif msg == "hide" then
    local barFrame = BarSmith:GetModule("BarFrame")
    if barFrame then barFrame:Hide() end
  elseif msg == "config" or msg == "options" or msg == "settings" then
    BarSmith:OpenSettings()
  elseif msg == "reset" then
    BarSmith:ResetCharacterSettings()
  elseif msg == "debug" then
    BarSmith.db.debug = not BarSmith.db.debug
    BarSmith:Print("Debug mode: " .. (BarSmith.db.debug and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
  elseif msg == "exclude" or msg == "exclude list" or msg == "ex" or msg == "ex list"
      or msg == "blacklist" or msg == "blacklist list" or msg == "bl" or msg == "bl list" then
    local exclude = BarSmith.chardb.exclude or BarSmith.chardb.blacklist or {}
    local count = 0
    BarSmith:Print("Excluded items:")
    for key in pairs(exclude) do
      BarSmith:Print("  " .. key)
      count = count + 1
    end
    if count == 0 then
      BarSmith:Print("  (none)")
    end
  elseif msg == "clearexclude" or msg == "exclude clear" or msg == "ex clear"
      or msg == "clearblacklist" or msg == "blacklist clear" or msg == "bl clear" then
    BarSmith.chardb.exclude = {}
    BarSmith.chardb.blacklist = nil
    BarSmith:Print("Exclude list cleared.")
    BarSmith:RunAutoFill(true)
  elseif msg == "clearinclude" or msg == "include clear"
      or msg == "clearextras" or msg == "extras clear" then
    BarSmith:ClearInclude()
    BarSmith:Print("Include list cleared.")
    BarSmith:RunAutoFill(true)
  elseif msg == "status" then
    BarSmith:PrintStatus()
  else
    BarSmith:Print("Commands:")
    BarSmith:Print("  |cff00ccff/bs fill|r — Scan and fill the bar now")
    BarSmith:Print("  |cff00ccff/bs clear|r — Clear all buttons")
    BarSmith:Print("  |cff00ccff/bs lock|r — Toggle bar lock/unlock")
    BarSmith:Print("  |cff00ccff/bs show|r / |cff00ccff/bs hide|r — Show or hide the bar")
    BarSmith:Print("  |cff00ccff/bs config|r — Open settings panel")
    BarSmith:Print("  |cff00ccff/bs status|r — Show current module status")
    BarSmith:Print("  |cff00ccff/bs reset|r — Reset character settings")
    BarSmith:Print("  |cff00ccff/bs exclude|r / |cff00ccff/bs ex|r — Show excluded items")
    BarSmith:Print("  |cff00ccff/bs clearexclude|r / |cff00ccff/bs ex clear|r — Clear excluded items")
    BarSmith:Print("  |cff00ccff/bs clearinclude|r — Clear included items/spells")
    BarSmith:Print("  |cff00ccff/bs debug|r — Toggle debug output")
  end
end

------------------------------------------------------------------------
-- Public fill entry point
------------------------------------------------------------------------

function BarSmith:RunAutoFill(force)
  if not self.chardb.enabled then
    self:Print("BarSmith is disabled for this character. Use |cff00ccff/bs config|r to enable.")
    return
  end

  local placer = self:GetModule("ActionBarPlacer")
  if placer then
    placer:Fill(force)
  end
end

------------------------------------------------------------------------
-- Quick access toggle (temporary bar at cursor)
------------------------------------------------------------------------

function BarSmith:ToggleQuickBar()
  local quickBar = self:GetModule("QuickBar")
  if quickBar and quickBar.Toggle then
    quickBar:Toggle()
  end
end

------------------------------------------------------------------------
-- Status display
------------------------------------------------------------------------

function BarSmith:PrintStatus()
  self:Print("--- BarSmith Status ---")
  self:Print("Enabled: " .. (self.chardb.enabled and "|cff00ff00Yes|r" or "|cffff0000No|r"))
  self:Print("Auto-fill: " .. (self.chardb.autoFill and "|cff00ff00On|r" or "|cffff0000Off|r"))
  self:Print("Bar locked: " .. (self.chardb.barLocked and "Yes" or "No"))
  self:Print("Columns: " .. (self.chardb.barColumns or 12))
  self:Print("Button icon size: " .. (self.chardb.barIconSize or 36) .. "px")

  local barFrame = self:GetModule("BarFrame")
  if barFrame then
    self:Print("Active buttons: " .. barFrame:GetActiveCount())
  end

  self:Print("Modules:")
  for _, modName in ipairs(self.chardb.priority) do
    local state = self.chardb.modules[modName]
    local color = state and "|cff00ff00" or "|cffff0000"
    self:Print("  " .. color .. modName .. "|r")
  end
end

------------------------------------------------------------------------
-- Event Handling
------------------------------------------------------------------------

BarSmith:RegisterEvent("ADDON_LOADED", function(self, event, addonName)
  if addonName ~= self.name then return end

  -- Initialize saved variables
  self:InitDB()

  -- Initialize the dedicated bar frame
  local barFrame = self:GetModule("BarFrame")
  if barFrame then
    barFrame:Init()
    if self.chardb and self.chardb.enabled == false then
      barFrame:Hide()
    end
  end

  local quickBar = self:GetModule("QuickBar")
  if quickBar then
    quickBar:Init()
  end

  -- Initialize settings panel
  local settingsMod = self:GetModule("Settings")
  if settingsMod then
    settingsMod:Init()
  end

  -- Initialize minimap button
  local minimapMod = self:GetModule("Minimap")
  if minimapMod then
    minimapMod:Init()
  end

  self:UnregisterEvent("ADDON_LOADED")
  self:Print("v" .. self.version .. " loaded. Type |cff00ccff/bs|r for commands.")
end)

-- Auto-fill on login (delayed to let bags load)
BarSmith:RegisterEvent("PLAYER_ENTERING_WORLD", function(self, event, isLogin, isReload)
  if not self.chardb or not self.chardb.enabled or not self.chardb.autoFill then
    return
  end

  -- Delay the first fill to let item cache populate
  C_Timer.After(3, function()
    if not InCombatLockdown() then
      BarSmith:RunAutoFill()
    end
  end)
end)

-- Re-fill when bags change (throttled)
BarSmith:RegisterEvent("BAG_UPDATE_DELAYED", function(self)
  if not self.chardb or not self.chardb.enabled or not self.chardb.autoFill then
    return
  end

  -- Debounce: wait a beat for multiple bag events to settle
  if self._bagTimer then return end
  self._bagTimer = C_Timer.After(1.5, function()
    self._bagTimer = nil
    if not InCombatLockdown() then
      BarSmith:RunAutoFill()
    end
  end)
end)

-- Fill after quest accepted/completed (quest items may appear/disappear)
BarSmith:RegisterEvent("QUEST_ACCEPTED", function(self)
  if not self.chardb or not self.chardb.enabled or not self.chardb.autoFill then
    return
  end
  C_Timer.After(1, function()
    if not InCombatLockdown() then
      BarSmith:RunAutoFill()
    end
  end)
end)

BarSmith:RegisterEvent("QUEST_REMOVED", function(self)
  if not self.chardb or not self.chardb.enabled or not self.chardb.autoFill then
    return
  end
  C_Timer.After(1, function()
    if not InCombatLockdown() then
      BarSmith:RunAutoFill()
    end
  end)
end)

-- Fill after combat ends if a fill was pending
BarSmith:RegisterEvent("PLAYER_REGEN_ENABLED", function(self)
  if self.pendingFill then
    local force = (self.pendingFillForce == true)
    self.pendingFill = false
    self.pendingFillForce = nil
    C_Timer.After(0.5, function()
      BarSmith:RunAutoFill(force)
    end)
  end

  local hearthstones = self:GetModule("Hearthstones")
  if hearthstones and hearthstones.ApplyPendingHousingUpdate then
    hearthstones:ApplyPendingHousingUpdate()
  end
end)

-- Re-fill when talent spec changes (class spells may change)
BarSmith:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", function(self)
  if not self.chardb or not self.chardb.enabled or not self.chardb.autoFill then
    return
  end
  C_Timer.After(2, function()
    if not InCombatLockdown() then
      BarSmith:RunAutoFill()
    end
  end)
end)

-- Re-fill when equipment changes (trinkets may swap)
BarSmith:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", function(self, event, equipSlot)
  -- Only care about trinket slots (13 and 14)
  if equipSlot ~= 13 and equipSlot ~= 14 then return end
  if not self.chardb or not self.chardb.enabled or not self.chardb.autoFill then
    return
  end
  C_Timer.After(1, function()
    if not InCombatLockdown() then
      BarSmith:RunAutoFill()
    end
  end)
end)
