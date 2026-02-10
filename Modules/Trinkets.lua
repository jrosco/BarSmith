------------------------------------------------------------------------
-- BarSmith: Modules/Trinkets.lua
-- Detects equipped trinkets with "Use:" effects for action bar placement
------------------------------------------------------------------------

local Trinkets = BarSmith:NewModule("Trinkets")

-- Equipment slot IDs for trinkets
local TRINKET_SLOT_1 = 13 -- INVSLOT_TRINKET1
local TRINKET_SLOT_2 = 14 -- INVSLOT_TRINKET2

------------------------------------------------------------------------
-- Gather trinkets for the action bar
------------------------------------------------------------------------

function Trinkets:GetItems()
  local items = {}

  if not BarSmith.chardb.modules.trinkets then
    return items
  end

  -- Check equipped trinket slots
  self:CheckSlot(TRINKET_SLOT_1, items)
  self:CheckSlot(TRINKET_SLOT_2, items)

  BarSmith:Debug("Trinkets found: " .. #items)
  return items
end

------------------------------------------------------------------------
-- Check a specific equipment slot for a usable trinket
------------------------------------------------------------------------

function Trinkets:CheckSlot(slotID, items)
  local itemID = GetInventoryItemID("player", slotID)
  if not itemID then return end

  -- Check if the trinket has a Use: effect
  local scanner = BarSmith:GetModule("Scanner")
  if not scanner or not scanner:IsUsableItem(itemID) then
    return
  end

  local itemName, _, itemQuality, _, _, _, _, _, _, itemTexture = C_Item.GetItemInfo(itemID)

  table.insert(items, {
    itemID = itemID,
    name = itemName or "Trinket",
    icon = itemTexture or GetInventoryItemTexture("player", slotID),
    quality = itemQuality,
    slotID = slotID,
    type = "trinket",
  })
end
