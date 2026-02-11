------------------------------------------------------------------------
-- BarSmith: Modules/Macros.lua
-- User-defined macro slots for action bar placement
------------------------------------------------------------------------

local Macros = BarSmith:NewModule("Macros")

Macros.EMPTY_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
Macros.MAX_SLOTS = 12

local function GetMacroPrefs()
  if not BarSmith.chardb then return nil end
  BarSmith.chardb.macros = BarSmith.chardb.macros or {}
  BarSmith.chardb.macros.slots = BarSmith.chardb.macros.slots or {}
  if type(BarSmith.chardb.macros.slotCount) ~= "number" then
    BarSmith.chardb.macros.slotCount = 1
  end
  return BarSmith.chardb.macros
end

function Macros:SetSlotCount(count)
  local prefs = GetMacroPrefs()
  if not prefs then return end
  count = tonumber(count) or 1
  count = math.max(1, math.min(self.MAX_SLOTS, count))
  prefs.slotCount = count
end

function Macros:AssignMacroToSlot(slotIndex, macroID)
  local prefs = GetMacroPrefs()
  if not prefs then return false end
  slotIndex = tonumber(slotIndex)
  if not slotIndex or slotIndex < 1 then return false end
  local name = GetMacroInfo(macroID)
  if not name then
    return false
  end
  prefs.slots[slotIndex] = { macroID = macroID }
  if slotIndex > (prefs.slotCount or 1) then
    prefs.slotCount = slotIndex
  end
  return true
end

function Macros:GetNextSlotIndex()
  local prefs = GetMacroPrefs()
  if not prefs then return nil end
  local slots = prefs.slots or {}
  for i = 1, self.MAX_SLOTS do
    local entry = slots[i]
    if not entry or not entry.macroID then
      if i > (prefs.slotCount or 1) then
        prefs.slotCount = i
      end
      return i
    end
  end
  return nil
end

function Macros:AddMacroToNextSlot(macroID)
  local nextIndex = self:GetNextSlotIndex()
  if not nextIndex then
    return false, "Macro slots are full."
  end
  return self:AssignMacroToSlot(nextIndex, macroID)
end

function Macros:ClearSlot(slotIndex)
  local prefs = GetMacroPrefs()
  if not prefs then return end
  if not slotIndex then return end
  prefs.slots[slotIndex] = nil
end

function Macros:GetItems()
  local items = {}

  if not BarSmith.chardb.modules.macros then
    return items
  end

  local prefs = GetMacroPrefs()
  if not prefs then return items end
  local slots = prefs.slots or {}
  local slotCount = prefs.slotCount or 1
  local ordered = {}
  for i = 1, slotCount do
    local entry = slots[i]
    if entry and entry.macroID then
      table.insert(ordered, i)
    end
  end

  for _, i in ipairs(ordered) do
    local entry = slots[i]
    local macroID = entry and entry.macroID
    local name, icon, body
    local mName, mIcon, mBody = GetMacroInfo(macroID)
    if mName then
      name, icon, body = mName, mIcon, mBody
    else
      slots[i] = nil
    end

    table.insert(items, {
      type = "macro",
      slotIndex = i,
      macroID = macroID,
      macrotext = body,
      name = name or ("Macro Slot " .. i),
      icon = icon or self.EMPTY_ICON,
    })
  end

  if #items == 0 then
    table.insert(items, {
      type = "macro",
      slotIndex = 1,
      macroID = nil,
      macrotext = nil,
      name = "Macro Slot 1",
      icon = self.EMPTY_ICON,
    })
  end

  return items
end
