------------------------------------------------------------------------
-- BarSmith: Modules/Hearthstones.lua
-- Hearthstone, hearthstone toy variants, and engineering teleports
------------------------------------------------------------------------

local Hearthstones = BarSmith:NewModule("Hearthstones")

-- The original Hearthstone item ID
Hearthstones.HEARTHSTONE_ITEM = 6948

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
-- Gather hearthstone entries for the action bar
------------------------------------------------------------------------

function Hearthstones:GetItems()
  local items = {}

  if not BarSmith.chardb.modules.hearthstones then
    return items
  end

  local prefs = BarSmith.chardb.hearthstones

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

  BarSmith:Debug("Hearthstones found: " .. #items)
  return items
end
