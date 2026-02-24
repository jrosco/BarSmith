------------------------------------------------------------------------
-- BarSmith: Modules/QuestItems.lua
-- Detects usable quest items from active quests in the player's bags
------------------------------------------------------------------------

local QuestItems = BarSmith:NewModule("QuestItems")

------------------------------------------------------------------------
-- Gather quest items eligible for action bar placement
------------------------------------------------------------------------

function QuestItems:GetItems()
  local items = {}

  if not BarSmith.chardb.modules.questItems then
    return items
  end

  -- Method 1: Scan quest log for items with "use" abilities
  for i = 1, C_QuestLog.GetNumQuestLogEntries() do
    local questInfo = C_QuestLog.GetInfo(i)
    if questInfo and not questInfo.isHeader and not questInfo.isHidden then
      local questID = questInfo.questID
      local link, icon, charges, showWhenComplete = GetQuestLogSpecialItemInfo(i)
      if link then
        local itemID = GetItemInfoFromHyperlink(link)
        if itemID then
          table.insert(items, {
            itemID = itemID,
            name = questInfo.title or "Quest Item",
            icon = icon,
            questID = questID,
            charges = charges,
            type = "quest_item",
          })
        end
      end
    end
  end

  -- Method 2: Check for quest items on the world map quest POI
  local mapID = C_Map.GetBestMapForUnit("player")
  if mapID then
    local quests = C_QuestLog.GetQuestsOnMap(mapID)
    if quests then
      for _, questData in ipairs(quests) do
        self:CheckQuestForItem(questData.questID, items)
      end
    end
  end

  -- Method 3: Scan bags for items flagged as quest items
  local scanner = BarSmith:GetModule("Scanner")
  if scanner then
    local bagResults = scanner:ScanBags()
    for _, entry in ipairs(bagResults.questItems) do
      if scanner:IsUsableItem(entry.itemID, entry.bag, entry.slot) then
        entry.type = "quest_item"
        table.insert(items, entry)
      end
    end
  end

  BarSmith:Debug("QuestItems found: " .. #items)
  return items
end

------------------------------------------------------------------------
-- Check a specific quest for usable items
------------------------------------------------------------------------

function QuestItems:CheckQuestForItem(questID, items)
  if not questID or not C_QuestLog.IsOnQuest(questID) then return end

  local questLogIndex = C_QuestLog.GetLogIndexForQuestID(questID)
  if not questLogIndex then return end

  local link, icon, charges = GetQuestLogSpecialItemInfo(questLogIndex)
  if link then
    local itemID = GetItemInfoFromHyperlink(link)
    if itemID then
      local questInfo = C_QuestLog.GetInfo(questLogIndex)
      table.insert(items, {
        itemID = itemID,
        name = (questInfo and questInfo.title) or "Quest Item",
        icon = icon,
        questID = questID,
        charges = charges,
        type = "quest_item",
      })
    end
  end
end

