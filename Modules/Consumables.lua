------------------------------------------------------------------------
-- BarSmith: Modules/Consumables.lua
-- Detects usable consumables: potions, flasks, food, bandages, utility
------------------------------------------------------------------------

local Consumables = BarSmith:NewModule("Consumables")

------------------------------------------------------------------------
-- Well-known consumable item IDs (Midnight / TWW era)
-- These act as a priority whitelist; bag-scanned items fill the rest
------------------------------------------------------------------------

Consumables.KNOWN_POTIONS = {
  -- Midnight tier (placeholder IDs - update with real item IDs at launch)
  -- TWW tier
  211880,   -- Algari Healing Potion
  212240,   -- Cavedweller's Delight
  211878,   -- Algari Mana Potion
}

Consumables.KNOWN_UTILITY = {
  -- Drums, augment runes, etc.
  194817,   -- Buzzing Rune
  201325,   -- Dreambound Augment Rune
}

------------------------------------------------------------------------
-- Gather consumable items for the action bar
------------------------------------------------------------------------

local function GetSplitFlags()
  local prefs = BarSmith.chardb and BarSmith.chardb.consumables
  return (prefs and prefs.split) or {}
end

local function GetIncludeLists()
  local prefs = BarSmith.chardb and BarSmith.chardb.consumables
  return (prefs and prefs.include) or {}
end

function Consumables:ClassifyExtraCategory(itemID)
  if not itemID then return nil end
  local _, _, _, _, _, itemType, _, _, _, _, _, classID, subclassID = C_Item.GetItemInfo(itemID)
  local scanner = BarSmith:GetModule("Scanner")
  if not scanner or classID ~= scanner.ITEM_CLASS.CONSUMABLE then
    return nil
  end
  if subclassID == scanner.CONSUMABLE_SUBCLASS.POTION then
    return "potions"
  elseif subclassID == scanner.CONSUMABLE_SUBCLASS.FLASK or subclassID == scanner.CONSUMABLE_SUBCLASS.ELIXIR then
    return "flasks"
  elseif subclassID == scanner.CONSUMABLE_SUBCLASS.FOOD_DRINK then
    return "food"
  elseif subclassID == scanner.CONSUMABLE_SUBCLASS.BANDAGE then
    return "bandages"
  else
    return "utilities"
  end
end

function Consumables:AddExtraItem(itemID)
  local category = self:ClassifyExtraCategory(itemID)
  if not category then
    BarSmith:Print("That item isn't a consumable.")
    return false
  end

  local include = GetIncludeLists()
  include[category] = include[category] or {}
  include[category][itemID] = true
  BarSmith:Print("Included in " .. category .. ".")
  return true
end

function Consumables:RemoveExtraItem(itemID, subtype)
  if not itemID then return false end

  local category
  if subtype == "potion" then
    category = "potions"
  elseif subtype == "flask" then
    category = "flasks"
  elseif subtype == "food" then
    category = "food"
  elseif subtype == "bandage" then
    category = "bandages"
  elseif subtype == "utility" then
    category = "utilities"
  else
    category = self:ClassifyExtraCategory(itemID)
  end

  if not category then
    return false
  end

  local include = GetIncludeLists()
  if include[category] and include[category][itemID] then
    include[category][itemID] = nil
    return true
  end

  return false
end

function Consumables:ApplyIncludes(bagResults)
  local include = GetIncludeLists()
  if not include or not bagResults or not bagResults.byItemID then
    return
  end

  local function insertIncludes(targetList, includeList)
    if not targetList or not includeList then return end
    for itemID, enabled in pairs(includeList) do
      if enabled then
        local entry = bagResults.byItemID[itemID]
        if entry then
          table.insert(targetList, entry)
        end
      end
    end
  end

  insertIncludes(bagResults.potions, include.potions)
  insertIncludes(bagResults.flasks, include.flasks)
  insertIncludes(bagResults.food, include.food)
  insertIncludes(bagResults.bandages, include.bandages)
  insertIncludes(bagResults.utilities, include.utilities)
end

function Consumables:Collect(items, bagResults, prefs, splitFlags, categoryKey, subtype)
  if not prefs or not prefs[categoryKey] then
    return
  end

  -- When splitFlags is provided, the caller decides what to include.
  if not splitFlags or not splitFlags[categoryKey] then
    self:AddUsable(items, bagResults, subtype, prefs and prefs.currentExpansionOnly == true)
  end
end

function Consumables:GetItems()
  local items = {}

  if not BarSmith.chardb.modules.consumables then
    return items
  end

  local scanner = BarSmith:GetModule("Scanner")
  if not scanner then return items end

  local bagResults = scanner:ScanBags()
  self:ApplyIncludes(bagResults)
  local prefs = BarSmith.chardb.consumables
  local splitFlags = GetSplitFlags()

  -- Potions (all)
  self:Collect(items, bagResults.potions, prefs, splitFlags, "potions", "potion")

  -- Flasks / Elixirs
  self:Collect(items, bagResults.flasks, prefs, splitFlags, "flasks", "flask")

  -- Food / Drink
  self:Collect(items, bagResults.food, prefs, splitFlags, "food", "food")

  -- Bandages
  self:Collect(items, bagResults.bandages, prefs, splitFlags, "bandages", "bandage")

  -- Utility (drums, runes)
  self:Collect(items, bagResults.utilities, prefs, splitFlags, "utilities", "utility")

  -- Sort by quality descending
  scanner:SortByQuality(items)

  BarSmith:Debug("Consumables found: " .. #items)
  return items
end

function Consumables:GetItemsForCategory(subtype)
  local items = {}

  if not BarSmith.chardb.modules.consumables then
    return items
  end

  local scanner = BarSmith:GetModule("Scanner")
  if not scanner then return items end

  local bagResults = scanner:ScanBags()
  self:ApplyIncludes(bagResults)
  local prefs = BarSmith.chardb.consumables
  local split = (prefs and prefs.split) or {}
  local splitCur = (prefs and prefs.splitCurrentExpansion) or {}

  if subtype == "potion" then
    if split.potions or prefs.potions then
      self:AddUsable(items, bagResults.potions, "potion", splitCur.potions == true)
    end
  elseif subtype == "flask" then
    if split.flasks or prefs.flasks then
      self:AddUsable(items, bagResults.flasks, "flask", splitCur.flasks == true)
    end
  elseif subtype == "food" then
    if split.food or prefs.food then
      self:AddUsable(items, bagResults.food, "food", splitCur.food == true)
    end
  elseif subtype == "bandage" then
    if split.bandages or prefs.bandages then
      self:AddUsable(items, bagResults.bandages, "bandage", splitCur.bandages == true)
    end
  elseif subtype == "utility" then
    if split.utilities or prefs.utilities then
      self:AddUsable(items, bagResults.utilities, "utility", splitCur.utilities == true)
    end
  end

  scanner:SortByQuality(items)
  return items
end

------------------------------------------------------------------------
-- Add usable items from a scanned category
------------------------------------------------------------------------

local function IsCurrentExpansionItem(entry)
  if not entry or entry.expacID == nil then
    return true
  end
  if not GetExpansionLevel then
    return true
  end
  local current = GetExpansionLevel()
  return entry.expacID == current
end

function Consumables:AddUsable(items, scannedList, subtype, currentExpansionOnly)
  local scanner = BarSmith:GetModule("Scanner")
  for _, entry in ipairs(scannedList) do
    if currentExpansionOnly and not IsCurrentExpansionItem(entry) then
      -- skip non-current expansion items
    elseif scanner:IsUsableItem(entry.itemID, entry.bag, entry.slot) then
      entry.type = subtype
      table.insert(items, entry)
    end
  end
end

