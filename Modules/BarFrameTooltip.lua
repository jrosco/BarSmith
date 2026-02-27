------------------------------------------------------------------------
-- BarSmith: Modules/BarFrameTooltip.lua
-- Tooltip handling for BarFrame buttons.
------------------------------------------------------------------------

local BarFrame = BarSmith:GetModule("BarFrame")
local C = BarFrame.constants

local function NormalizeTooltipModifier(mod)
  mod = string.upper(tostring(mod or "NONE"))
  if mod ~= "ALT" and mod ~= "SHIFT" and mod ~= "CTRL" and mod ~= "NONE" then
    mod = "NONE"
  end
  return mod
end

function BarFrame:IsTooltipModifierActive()
  local mod = NormalizeTooltipModifier(BarSmith.chardb and BarSmith.chardb.tooltipModifier)
  if mod == "ALT" then
    return IsAltKeyDown()
  elseif mod == "SHIFT" then
    return IsShiftKeyDown()
  elseif mod == "CTRL" then
    return IsControlKeyDown()
  end
  return true
end

function BarFrame:UpdateTooltipState(btn, isFlyoutChild)
  if not btn then return end
  local allowed = self:IsTooltipModifierActive()
  if allowed then
    if not btn.__bsTooltipShown then
      self:ShowButtonTooltip(btn, isFlyoutChild)
      btn.__bsTooltipShown = true
    end
  elseif btn.__bsTooltipShown then
    GameTooltip:Hide()
    btn.__bsTooltipShown = false
  end
end

function BarFrame:HandleTooltipEnter(btn, isFlyoutChild)
  if not btn then return end
  btn.__bsTooltipShown = false
  self:UpdateTooltipState(btn, isFlyoutChild)
  btn:SetScript("OnUpdate", function(b)
    self:UpdateTooltipState(b, isFlyoutChild)
  end)
end

function BarFrame:HandleTooltipLeave(btn)
  if btn then
    btn.__bsTooltipShown = false
    btn:SetScript("OnUpdate", nil)
  end
  GameTooltip:Hide()
end

------------------------------------------------------------------------
-- Tooltip
------------------------------------------------------------------------

function BarFrame:ShowButtonTooltip(btn, isFlyoutChild)
  if not btn.itemData then return end

  GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
  local data = btn.itemData
  local TYPE_INFO = {
    quest_item = { label = "Quest Item", color = { 0.85, 0.8, 0.35 } },
    potion = { label = "Potion", color = { 0.4, 0.9, 0.6 } },
    flask = { label = "Flask / Elixir", color = { 0.9, 0.6, 1.0 } },
    food = { label = "Food / Drink", color = { 1.0, 0.8, 0.4 } },
    bandage = { label = "Bandage", color = { 0.9, 0.9, 0.9 } },
    utility = { label = "Utility", color = { 1.0, 0.6, 0.2 } },
    trinket = { label = "Trinket", color = { 1.0, 0.85, 0.2 } },
    class_spell = { label = "Class Spell", color = { 0.5, 0.9, 1.0 } },
    mount = { label = "Mount", color = { 0.6, 0.9, 0.6 } },
    toy = { label = "Toy", color = { 0.9, 0.75, 0.25 } },
    hearthstone_item = { label = "Hearthstone", color = { 0.9, 0.6, 0.2 } },
    hearthstone_toy = { label = "Hearthstone (Toy)", color = { 0.9, 0.6, 0.2 } },
    engineer_teleport = { label = "Engineer Teleport", color = { 0.6, 0.9, 0.9 } },
    housing_teleport = { label = "Housing Teleport", color = { 0.6, 0.9, 0.9 } },
    profession = { label = "Profession", color = { 0.8, 0.8, 1.0 } },
    placeholder = { label = "Empty Module", color = { 0.6, 0.6, 0.6 } },
    macro = { label = "Macro", color = { 0.9, 0.9, 0.5 } },
  }

  local function GetTypeLabelAndColor(item)
    local t = item and item.type
    if not t then return nil, nil end
    local info = TYPE_INFO[t]
    if info then
      return info.label, info.color
    end
    return t, { 0.5, 0.5, 0.5 }
  end

  if data.toyID then
    GameTooltip:SetToyByItemID(data.toyID)
  elseif data.itemID then
    GameTooltip:SetItemByID(data.itemID)
  elseif data.spellID then
    GameTooltip:SetSpellByID(data.spellID)
  else
    GameTooltip:SetText(data.name or "Unknown", 1, 1, 1)
  end

  -- Add BarSmith source line
  GameTooltip:AddLine(" ")
  local typeLabel, typeColor = GetTypeLabelAndColor(data)
  if typeLabel then
    local r, g, b = 0.5, 0.5, 0.5
    if typeColor then
      r, g, b = unpack(typeColor)
    end
    GameTooltip:AddLine(C.TOOLTIP_ICON .. " |cff33ccff[BarSmith]|r " .. typeLabel, r, g, b)
  else
    GameTooltip:AddLine(C.TOOLTIP_ICON .. " |cff33ccff[BarSmith]|r", 0.5, 0.5, 0.5)
  end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine(C.TOOLTIP_TITLE_COLOR .. "Actions|r", 1, 1, 1)
  if not isFlyoutChild then
    GameTooltip:AddLine(C.TOOLTIP_ACTION_MENU_COLOR .. "Open Menu|r: " ..
      C.TOOLTIP_SHORTCUT_COLOR .. "Shift + Right Click|r", 0.8, 0.8, 0.8)
    -- local groupLabel = (btn.groupData and btn.groupData.name) or (#btn.flyoutItems .. " items")
    -- GameTooltip:AddLine(groupLabel, 0.8, 0.8, 0.8)
  end
  if isFlyoutChild then
    GameTooltip:AddLine(C.TOOLTIP_ACTION_ADD_COLOR .. "Add to QuickBar|r: " ..
      C.TOOLTIP_SHORTCUT_COLOR .. "Alt + Left Click|r", 0.8, 0.8, 0.8)
    GameTooltip:AddLine(C.TOOLTIP_ACTION_PIN_COLOR .. "Pin / Unpin|r: " ..
      C.TOOLTIP_SHORTCUT_COLOR .. "Ctrl + Left Click|r", 0.8, 0.8, 0.8)
  end
  if data.isPlaceholder then
    GameTooltip:AddLine("No items available in this category.", 0.8, 0.8, 0.8)
  else
    if isFlyoutChild then
      local isAuto = data.autoAdded
      if isAuto == nil then
        isAuto = BarSmith:IsAutoAdded(data)
      end
      if isAuto then
        GameTooltip:AddLine(C.TOOLTIP_ACTION_REMOVE_COLOR .. "Exclude|r: " ..
          C.TOOLTIP_SHORTCUT_COLOR .. "Ctrl + Shift + Right Click|r", 0.8, 0.8, 0.8)
      else
        GameTooltip:AddLine(C.TOOLTIP_ACTION_REMOVE_COLOR .. "Remove|r: " ..
          C.TOOLTIP_SHORTCUT_COLOR .. "Ctrl + Shift + Right Click|r", 0.8, 0.8, 0.8)
      end
    end
    if data.type == "macro" then
      GameTooltip:AddLine("Drag a macro to assign it to this slot", 0.8, 0.8, 0.8)
    else
      GameTooltip:AddLine(C.TOOLTIP_NOTE_COLOR ..
        "Note: Drag a consumable, toy, mount, or spell to include|r", 0.8, 0.8, 0.8)
    end
  end
  GameTooltip:Show()
end
