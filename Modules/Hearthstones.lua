------------------------------------------------------------------------
-- BarSmith: Modules/Hearthstones.lua
-- Hearthstone, hearthstone toy variants, and engineering teleports
------------------------------------------------------------------------

local Hearthstones = BarSmith:NewModule("Hearthstones")

-- The original Hearthstone item ID
Hearthstones.HEARTHSTONE_ITEM = 6948
Hearthstones.HOUSING_BUTTON_PREFIX = "BarSmithHousingTeleport"
Hearthstones.HOUSING_ICON = 7252953
Hearthstones.HOUSING_ICON_RETURN_ATLAS = "dashboard-panel-homestone-teleport-out-button"
Hearthstones.HOUSING_OVERLAY_ALLIANCE = "UI-HUD-UnitFrame-Player-PVP-AllianceIcon"
Hearthstones.HOUSING_OVERLAY_HORDE = "UI-HUD-UnitFrame-Player-PVP-HordeIcon"

-- Known hearthstone toy IDs (all function identically to hearthstone)
Hearthstones.HEARTHSTONE_TOYS = {
  54452,    -- Ethereal Portal
  64488,    -- The Innkeeper's Daughter
  93672,    -- Dark Portal
  142542,   -- Tome of Town Portal
  162973,   -- Greatfather Winter's Hearthstone
  163045,   -- Headless Horseman's Hearthstone
  163206,   -- Weary Spirit Binding
  165669,   -- Lunar Elder's Hearthstone
  165670,   -- Peddlefeet's Lovely Hearthstone
  165802,   -- Noble Gardener's Hearthstone
  166746,   -- Fire Eater's Hearthstone
  166747,   -- Brewfest Reveler's Hearthstone
  168907,   -- Holographic Digitalization Hearthstone
  172179,   -- Eternal Traveler's Hearthstone
  182773,   -- Necrolord Hearthstone
  183716,   -- Venthyr Sinstone
  184353,   -- Kyrian Hearthstone
  188952,   -- Dominated Hearthstone
  190237,   -- Broker Translocation Matrix
  193588,   -- Timewalker's Hearthstone
  200630,   -- Ohn'ir Windsage's Hearthstone
  206195,   -- Path of the Naaru
  208704,   -- Deepdweller's Earthen Hearthstone
  209035,   -- Hearthstone of the Flame
  210455,   -- Draenic Hologem
  212337,   -- Stone of the Hearth
  228940,   -- Notorious Thread's Hearthstone
}

-- Engineering wormhole / teleport items
Hearthstones.ENGINEER_ITEMS = {
  18984,    -- Dimensional Ripper - Everlook
  18986,    -- Ultrasafe Transporter: Gadgetzan
  30542,    -- Dimensional Ripper - Area 52
  30544,    -- Ultrasafe Transporter: Toshley's Station
  48933,    -- Wormhole Generator: Northrend
  87215,    -- Wormhole Generator: Pandaria
  112059,   -- Wormhole Centrifuge (Draenor)
  151652,   -- Wormhole Generator: Argus
  168807,   -- Wormhole Generator: Kul Tiras
  168808,   -- Wormhole Generator: Zandalar
  172924,   -- Wormhole Generator: Shadowlands
  198156,   -- Wormhole Generator: Dragon Isles
  221966,   -- Wormhole Generator: Khaz Algar
}

------------------------------------------------------------------------
-- Housing teleport secure button
------------------------------------------------------------------------

local function GetHousingHomeEntries(houseInfoList)
  if not houseInfoList or #houseInfoList == 0 then
    return {}
  end

  local entries = {}
  for _, info in ipairs(houseInfoList) do
    local uiMapID = C_Housing and C_Housing.GetUIMapIDForNeighborhood
      and C_Housing.GetUIMapIDForNeighborhood(info.neighborhoodGUID)
    local districtLabel
    local overlayAtlas
    if uiMapID == 2352 then
      districtLabel = "Alliance"
      overlayAtlas = Hearthstones.HOUSING_OVERLAY_ALLIANCE
    elseif uiMapID == 2351 then
      districtLabel = "Horde"
      overlayAtlas = Hearthstones.HOUSING_OVERLAY_HORDE
    end
    local overlay = overlayAtlas and {
      atlas = overlayAtlas,
      scale = 0.5,
      offsetX = 0,
      offsetY = 0,
      alpha = 0.9,
    } or nil

    local baseName = info.houseName or info.ownerName or "Home"
    local name = districtLabel and (baseName .. " (" .. districtLabel .. ")") or baseName

    table.insert(entries, {
      neighborhoodGUID = info.neighborhoodGUID,
      houseGUID = info.houseGUID,
      plotID = info.plotID,
      houseName = info.houseName,
      ownerName = info.ownerName,
      uiMapID = uiMapID,
      label = districtLabel,
      overlay = overlay,
      displayName = name,
    })
  end

  table.sort(entries, function(a, b)
    if a.uiMapID and b.uiMapID and a.uiMapID ~= b.uiMapID then
      return a.uiMapID < b.uiMapID
    end
    return (a.displayName or "") < (b.displayName or "")
  end)

  return entries
end

function Hearthstones:EnsureHousingButtons(count)
  if not self.housingButtons then
    self.housingButtons = {}
  end

  for i = 1, count do
    if not self.housingButtons[i] then
      local name = self.HOUSING_BUTTON_PREFIX .. i
      local btn = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
      btn:SetSize(1, 1)
      btn:SetPoint("BOTTOMRIGHT", UIParent, "TOPLEFT", -1, -1)
      btn:RegisterForClicks("AnyDown", "AnyUp")
      self.housingButtons[i] = btn
    end
  end
end

function Hearthstones:ApplyHousingTeleport()
  if not self.housingHomes or #self.housingHomes == 0 then
    if self.housingButtons then
      for _, btn in ipairs(self.housingButtons) do
        btn:SetAttribute("type", nil)
        btn:SetAttribute("house-neighborhood-guid", nil)
        btn:SetAttribute("house-guid", nil)
        btn:SetAttribute("house-plot-id", nil)
      end
    end
    self.housingReturnActive = false
    self.housingPendingUpdate = false
    return
  end

  self:EnsureHousingButtons(#self.housingHomes)
  if not self.housingButtons then return end

  if InCombatLockdown() then
    self.housingPendingUpdate = true
    return
  end

  self.housingPendingUpdate = false
  local canReturn = C_HousingNeighborhood
    and C_HousingNeighborhood.CanReturnAfterVisitingHouse
    and C_HousingNeighborhood.CanReturnAfterVisitingHouse()
  self.housingReturnActive = canReturn == true
  for i, home in ipairs(self.housingHomes) do
    local btn = self.housingButtons[i]
    if btn then
      if self.housingReturnActive then
        btn:SetAttribute("type", "returnhome")
        btn:SetAttribute("house-neighborhood-guid", nil)
        btn:SetAttribute("house-guid", nil)
        btn:SetAttribute("house-plot-id", nil)
      else
        btn:SetAttribute("type", "teleporthome")
        btn:SetAttribute("house-neighborhood-guid", home.neighborhoodGUID)
        btn:SetAttribute("house-guid", home.houseGUID)
        btn:SetAttribute("house-plot-id", home.plotID)
      end
    end
  end
end

function Hearthstones:ApplyPendingHousingUpdate()
  if self.housingPendingUpdate then
    self:ApplyHousingTeleport()
  end
end

function Hearthstones:OnHouseListUpdated(houseInfoList)
  self.housingHomes = GetHousingHomeEntries(houseInfoList)
  self:ApplyHousingTeleport()

  if BarSmith.chardb and BarSmith.chardb.enabled and BarSmith.chardb.autoFill then
    if InCombatLockdown() then
      BarSmith.pendingFill = true
    else
      BarSmith:RunAutoFill()
    end
  end
end

function Hearthstones:OnHousingStateChanged()
  self:ApplyHousingTeleport()
  if BarSmith.chardb and BarSmith.chardb.enabled and BarSmith.chardb.autoFill then
    if InCombatLockdown() then
      BarSmith.pendingFill = true
    else
      BarSmith:RunAutoFill()
    end
  end
  self:QueueHousingStateRefresh()
end

function Hearthstones:QueueHousingStateRefresh()
  if self.housingStateTimer then return end

  local function refresh()
    self.housingStateTimer = nil
    local wasReturn = self.housingReturnActive
    self:ApplyHousingTeleport()
    if wasReturn ~= self.housingReturnActive and BarSmith.chardb and BarSmith.chardb.enabled and BarSmith.chardb.autoFill then
      if InCombatLockdown() then
        BarSmith.pendingFill = true
      else
        BarSmith:RunAutoFill()
      end
    end
  end

  self.housingStateTimer = C_Timer.NewTimer(0.5, function()
    refresh()
    if not self.housingReturnActive then
      self.housingStateTimer = C_Timer.NewTimer(1.0, refresh)
    end
  end)
end

if C_Housing and C_Housing.GetPlayerOwnedHouses then
  BarSmith:RegisterEvent("PLAYER_HOUSE_LIST_UPDATED", function(self, event, houseInfoList)
    local mod = self:GetModule("Hearthstones")
    if mod then
      mod:OnHouseListUpdated(houseInfoList)
    end
  end)
end

if C_HousingNeighborhood and C_HousingNeighborhood.CanReturnAfterVisitingHouse then
  BarSmith:RegisterEvent("HOUSE_PLOT_ENTERED", function(self)
    local mod = self:GetModule("Hearthstones")
    if mod then
      mod:OnHousingStateChanged()
    end
  end)
  BarSmith:RegisterEvent("HOUSE_PLOT_EXITED", function(self)
    local mod = self:GetModule("Hearthstones")
    if mod then
      mod:OnHousingStateChanged()
    end
  end)
end

------------------------------------------------------------------------
-- Gather hearthstone entries for the action bar
------------------------------------------------------------------------

function Hearthstones:GetItems()
  local items = {}

  if not BarSmith.chardb.modules.hearthstones then
    return items
  end

  local prefs = BarSmith.chardb.hearthstones

  if not self.housingRequested and C_Housing and C_Housing.GetPlayerOwnedHouses then
    self.housingRequested = true
    C_Housing.GetPlayerOwnedHouses()
  end

  local function AddToyHearthstone(toyID)
    if not (PlayerHasToy(toyID) and C_ToyBox.IsToyUsable(toyID)) then
      return false
    end

    local toyName, toyIcon
    local toyInfo = C_ToyBox.GetToyInfo(toyID)
    if type(toyInfo) == "table" then
      toyName = toyInfo.name
      toyIcon = toyInfo.icon
    else
      local _, name, icon = C_ToyBox.GetToyInfo(toyID)
      toyName = name
      toyIcon = icon
    end

    table.insert(items, {
      toyID = toyID,
      name = toyName or "Hearthstone",
      icon = toyIcon,
      type = "hearthstone_toy",
    })
    return true
  end

  -- 1. Put the base Hearthstone first so the group uses it as the main icon.
  local count = C_Item.GetItemCount(self.HEARTHSTONE_ITEM)
  if count > 0 then
    local name, _, _, _, _, _, _, _, _, icon = C_Item.GetItemInfo(self.HEARTHSTONE_ITEM)
    table.insert(items, {
      itemID = self.HEARTHSTONE_ITEM,
      name = name or "Hearthstone",
      icon = icon or 134414,
      type = "hearthstone_item",
    })
  end

  local preferredAdded = false

  -- 2. Preferred toy first (if configured)
  if prefs.preferredToyID and prefs.includeToys then
    preferredAdded = AddToyHearthstone(prefs.preferredToyID)
  end

  -- 3. Add every owned hearthstone toy
  if prefs.includeToys then
    for _, toyID in ipairs(self.HEARTHSTONE_TOYS) do
      if not (preferredAdded and toyID == prefs.preferredToyID) then
        AddToyHearthstone(toyID)
      end
    end
  end

  -- 4. Engineering items
  if prefs.includeEngineer then
    for _, itemID in ipairs(self.ENGINEER_ITEMS) do
      if C_Item.GetItemCount(itemID) > 0 then
        local scanner = BarSmith:GetModule("Scanner")
        if scanner and scanner:IsUsableItem(itemID) then
          local name, _, _, _, _, _, _, _, _, icon = C_Item.GetItemInfo(itemID)
          if name then
            table.insert(items, {
              itemID = itemID,
              name = name,
              icon = icon,
              type = "engineer_teleport",
            })
          end
        end
      end
    end
  end

  -- 5. Housing teleports
  if self.housingHomes and #self.housingHomes > 0 then
    for i, home in ipairs(self.housingHomes) do
      local housingName
      if self.housingReturnActive then
        housingName = "Leave Home"
      else
        housingName = "Teleport Home"
      end
      if home.displayName then
        housingName = housingName .. ": " .. home.displayName
      end
      table.insert(items, {
        name = housingName,
        icon = self.housingReturnActive and nil or self.HOUSING_ICON,
        iconAtlas = self.housingReturnActive and self.HOUSING_ICON_RETURN_ATLAS or nil,
        overlay = home.overlay,
        macrotext = "/click " .. self.HOUSING_BUTTON_PREFIX .. i,
        type = "housing_teleport",
        hideCooldown = self.housingReturnActive == true,
      })
    end
  end

  BarSmith:Debug("Hearthstones found: " .. #items)
  return items
end
