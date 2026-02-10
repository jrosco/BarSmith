------------------------------------------------------------------------
-- BarSmith: Modules/Scanner.lua
-- Bag and inventory scanning utilities shared by other modules
------------------------------------------------------------------------

local Scanner = BarSmith:NewModule("Scanner")

-- Item classification constants (WoW item classes)
Scanner.ITEM_CLASS = {
  CONSUMABLE    = 0,
  CONTAINER     = 1,
  WEAPON        = 2,
  ARMOR         = 4,
  REAGENT       = 5,
  QUEST         = 12,
  MISCELLANEOUS = 15,
}

Scanner.CONSUMABLE_SUBCLASS = {
  POTION     = 1,
  ELIXIR     = 2,
  FLASK      = 3,
  FOOD_DRINK = 5,
  BANDAGE    = 7,
  OTHER      = 8,
}

------------------------------------------------------------------------
-- Scan all bag slots and return categorized items
------------------------------------------------------------------------

function Scanner:ScanBags()
  local results = {
    byItemID  = {},
    questItems = {},
    potions    = {},
    flasks     = {},
    food       = {},
    bandages   = {},
    utilities  = {},
    trinkets   = {},
    other      = {},
  }

  for bag = 0, NUM_BAG_SLOTS do
    local numSlots = C_Container.GetContainerNumSlots(bag)
    for slot = 1, numSlots do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and info.itemID then
        self:ClassifyItem(info, bag, slot, results)
      end
    end
  end

  return results
end

------------------------------------------------------------------------
-- Classify a single item into the results table
------------------------------------------------------------------------

function Scanner:ClassifyItem(info, bag, slot, results)
  local itemID = info.itemID
  local itemLink = info.hyperlink

  -- Use C_Item.GetItemInfo for classification (12.0 namespace)
  local itemName, _, itemQuality, itemLevel, itemMinLevel, itemType,
  itemSubType, itemStackCount, itemEquipLoc, itemTexture,
  sellPrice, classID, subclassID, bindType, expacID = C_Item.GetItemInfo(itemID)

  -- Item info may not be cached yet
  if not classID then
    -- Fallback: check if it's a quest item via tooltip
    if info.isQuestItem or C_QuestLog.IsQuestItem(itemID) then
      table.insert(results.questItems, {
        itemID = itemID,
        name = info.itemName or itemName or "Unknown",
        icon = info.iconFileID or itemTexture,
        bag = bag,
        slot = slot,
        count = info.stackCount or 1,
      })
    end
    return
  end

  local entry = {
    itemID = itemID,
    name = itemName or info.itemName or "Unknown",
    icon = itemTexture or info.iconFileID,
    bag = bag,
    slot = slot,
    count = info.stackCount or 1,
    quality = itemQuality,
    classID = classID,
    subclassID = subclassID,
    expacID = expacID,
  }
  if not results.byItemID[itemID] then
    results.byItemID[itemID] = entry
  end

  -- Quest items
  if classID == self.ITEM_CLASS.QUEST or info.isQuestItem then
    table.insert(results.questItems, entry)
    return
  end

  -- Consumables
  if classID == self.ITEM_CLASS.CONSUMABLE then
    if subclassID == self.CONSUMABLE_SUBCLASS.POTION then
      table.insert(results.potions, entry)
    elseif subclassID == self.CONSUMABLE_SUBCLASS.FLASK or subclassID == self.CONSUMABLE_SUBCLASS.ELIXIR then
      table.insert(results.flasks, entry)
    elseif subclassID == self.CONSUMABLE_SUBCLASS.FOOD_DRINK then
      table.insert(results.food, entry)
    elseif subclassID == self.CONSUMABLE_SUBCLASS.BANDAGE then
      table.insert(results.bandages, entry)
    else
      table.insert(results.utilities, entry)
    end
    return
  end

  -- Trinkets (equipped trinkets handled in Trinkets module)
  if classID == self.ITEM_CLASS.ARMOR and itemEquipLoc == "INVTYPE_TRINKET" then
    table.insert(results.trinkets, entry)
    return
  end

  -- Everything else
  table.insert(results.other, entry)
end

------------------------------------------------------------------------
-- Check if an item is usable (has a Use: effect)
------------------------------------------------------------------------

function Scanner:IsUsableItem(itemID)
  -- C_Item.GetItemSpell returns the spell associated with "Use:" effect
  local spellName, spellID = C_Item.GetItemSpell(itemID)
  return spellName ~= nil
end

------------------------------------------------------------------------
-- Sort items by quality (descending), then by name
------------------------------------------------------------------------

function Scanner:SortByQuality(items)
  table.sort(items, function(a, b)
    if (a.quality or 0) == (b.quality or 0) then
      return (a.name or "") < (b.name or "")
    end
    return (a.quality or 0) > (b.quality or 0)
  end)
  return items
end
