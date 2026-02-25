------------------------------------------------------------------------
-- BarSmith: Modules/BarFrameSettings.lua
-- UI helpers for BarFrame settings and include/exclude lists
------------------------------------------------------------------------

local BarFrameSettings = BarSmith:NewModule("BarFrameSettings")

local MENU_ICON_SIZE = 16
local INCLUDE_EXCLUDE_FRAME_WIDTH = 340
local INCLUDE_EXCLUDE_FRAME_HEIGHT = 360
local INCLUDE_EXCLUDE_ROW_HEIGHT = 20
local INCLUDE_EXCLUDE_BUTTON_WIDTH = 88
local INCLUDE_EXCLUDE_HEADER_HEIGHT = 34

local function SortMenuEntriesByText(entries)
  table.sort(entries, function(a, b)
    local at = string.lower(tostring(a.text or ""))
    local bt = string.lower(tostring(b.text or ""))
    return at < bt
  end)
end

function BarFrameSettings:BuildIncludeExcludeList()
  local rows = {}

  local function addItem(target, text, icon, entryData)
    local entry = { text = text, icon = icon }
    if entryData then
      for k, v in pairs(entryData) do
        entry[k] = v
      end
    end
    table.insert(target, entry)
  end

  local function addTitle(text, color)
    table.insert(rows, { text = text, isTitle = true, color = color })
  end

  local function addSection(title, entries, color)
    addTitle(title, color)
    if #entries == 0 then
      table.insert(rows, { text = "None", disabled = true })
      return
    end
    SortMenuEntriesByText(entries)
    for _, entry in ipairs(entries) do
      table.insert(rows, entry)
    end
  end

  local includePotions = {}
  local includeFlasks = {}
  local includeFood = {}
  local includeBandages = {}
  local includeUtilities = {}
  local includeMounts = {}
  local includeSpells = {}
  local includeMacros = {}
  local excludeEntries = {}

  local chardb = BarSmith.chardb or {}
  local include = chardb.consumables and chardb.consumables.include or {}

  local function addItemEntry(target, itemID, fallbackLabel, entryData)
    if not itemID then return end
    local name, _, _, _, _, _, _, _, _, icon = C_Item.GetItemInfo(itemID)
    if not name then
      C_Item.RequestLoadItemDataByID(itemID)
    end
    local label = name or (fallbackLabel .. " " .. tostring(itemID))
    if name then
      label = name .. " (" .. tostring(itemID) .. ")"
    end
    addItem(target, label, icon, entryData)
  end

  local function addSpellEntry(target, spellID, entryData)
    if not spellID then return end
    local spellInfo = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellID)
    local name = spellInfo and spellInfo.name
    local icon = spellInfo and spellInfo.iconID
    local label = name or ("Spell " .. tostring(spellID))
    if name then
      label = name .. " (" .. tostring(spellID) .. ")"
    end
    addItem(target, label, icon, entryData)
  end

  for itemID, enabled in pairs(include.potions or {}) do
    if enabled then
      addItemEntry(includePotions, itemID, "Potion", { kind = "include_item", category = "potions", itemID = itemID })
    end
  end
  for itemID, enabled in pairs(include.flasks or {}) do
    if enabled then
      addItemEntry(includeFlasks, itemID, "Flask", { kind = "include_item", category = "flasks", itemID = itemID })
    end
  end
  for itemID, enabled in pairs(include.food or {}) do
    if enabled then
      addItemEntry(includeFood, itemID, "Food", { kind = "include_item", category = "food", itemID = itemID })
    end
  end
  for itemID, enabled in pairs(include.bandages or {}) do
    if enabled then
      addItemEntry(includeBandages, itemID, "Bandage", { kind = "include_item", category = "bandages", itemID = itemID })
    end
  end
  for itemID, enabled in pairs(include.utilities or {}) do
    if enabled then
      addItemEntry(includeUtilities, itemID, "Utility", { kind = "include_item", category = "utilities", itemID = itemID })
    end
  end

  local mountInclude = chardb.mounts and chardb.mounts.include or {}
  for mountID, enabled in pairs(mountInclude) do
    if enabled then
      local name, spellID, icon = C_MountJournal.GetMountInfoByID(mountID)
      local label = name or ("Mount " .. tostring(mountID))
      if name and spellID then
        label = name .. " (" .. tostring(spellID) .. ")"
      end
      addItem(includeMounts, label, icon, { kind = "include_mount", mountID = mountID })
    end
  end

  local customSpellIDs = chardb.classSpells and chardb.classSpells.customSpellIDs or {}
  for _, spellID in ipairs(customSpellIDs) do
    addSpellEntry(includeSpells, spellID, { kind = "include_spell", spellID = spellID })
  end

  local macroSlots = chardb.macros and chardb.macros.slots or {}
  for slotIndex, entry in pairs(macroSlots) do
    if entry and entry.macroID then
      local name, icon = GetMacroInfo(entry.macroID)
      local label = name or ("Macro " .. tostring(entry.macroID))
      label = label .. " (Slot " .. tostring(slotIndex) .. ")"
      addItem(includeMacros, label, icon, { kind = "include_macro", slotIndex = slotIndex })
    end
  end

  local exclude = chardb.exclude or {}
  for key, enabled in pairs(exclude) do
    if enabled and type(key) == "string" then
      local prefix, id = key:match("^(%w+):(.+)$")
      if prefix == "item" then
        addItemEntry(excludeEntries, tonumber(id), "Item", { kind = "exclude", key = key })
      elseif prefix == "spell" then
        addSpellEntry(excludeEntries, tonumber(id), { kind = "exclude", key = key })
      elseif prefix == "name" then
        addItem(excludeEntries, tostring(id), nil, { kind = "exclude", key = key })
      else
        addItem(excludeEntries, key, nil, { kind = "exclude", key = key })
      end
    end
  end

  addSection("Include: Potions", includePotions, { 0.35, 0.9, 0.55 })
  addSection("Include: Flasks/Elixirs", includeFlasks, { 0.72, 0.55, 1.0 })
  addSection("Include: Food/Drink", includeFood, { 1.0, 0.8, 0.45 })
  addSection("Include: Bandages", includeBandages, { 0.85, 0.85, 0.85 })
  addSection("Include: Utilities", includeUtilities, { 1.0, 0.65, 0.3 })
  addSection("Include: Mounts", includeMounts, { 0.5, 0.85, 0.6 })
  addSection("Include: Class Spells", includeSpells, { 0.5, 0.85, 1.0 })
  addSection("Macros", includeMacros, { 0.95, 0.9, 0.5 })
  addSection("Exclude", excludeEntries, { 1.0, 0.35, 0.35 })

  return rows
end

function BarFrameSettings:CreateIncludeExcludeFrame()
  if self.includeExcludeFrame then return end

  local frame = CreateFrame("Frame", "BarSmithIncludeExcludeFrame", UIParent, "BackdropTemplate")
  frame:SetSize(INCLUDE_EXCLUDE_FRAME_WIDTH, INCLUDE_EXCLUDE_FRAME_HEIGHT)
  frame:SetClampedToScreen(true)
  frame:SetFrameStrata("TOOLTIP")
  frame:Hide()

  frame:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  frame:SetBackdropColor(0.03, 0.03, 0.035, 0.95)

  frame.header = frame:CreateTexture(nil, "BACKGROUND")
  frame.header:SetPoint("TOPLEFT", 4, -4)
  frame.header:SetPoint("TOPRIGHT", -4, -4)
  frame.header:SetHeight(INCLUDE_EXCLUDE_HEADER_HEIGHT)
  frame.header:SetColorTexture(0.08, 0.08, 0.1, 0.9)

  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  frame.title:SetPoint("TOPLEFT", 12, -10)
  frame.title:SetText("Includes / Excludes")

  frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.subtitle:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -2)
  frame.subtitle:SetText("Click an entry to remove it")

  frame.divider = frame:CreateTexture(nil, "ARTWORK")
  frame.divider:SetPoint("TOPLEFT", 6, -(INCLUDE_EXCLUDE_HEADER_HEIGHT + 6))
  frame.divider:SetPoint("TOPRIGHT", -6, -(INCLUDE_EXCLUDE_HEADER_HEIGHT + 6))
  frame.divider:SetHeight(1)
  frame.divider:SetColorTexture(1, 1, 1, 0.08)

  frame.close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  frame.close:SetPoint("TOPRIGHT", -6, -6)

  frame.settingsButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.settingsButton:SetSize(INCLUDE_EXCLUDE_BUTTON_WIDTH, 20)
  frame.settingsButton:SetPoint("TOPRIGHT", -40, -10)
  frame.settingsButton:SetText("Settings")
  frame.settingsButton:SetScript("OnClick", function()
    BarSmith:OpenSettings()
  end)
  frame.settingsButton:SetScript("OnEnter", function(btn)
    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
    GameTooltip:SetText("Open BarSmith settings", 1, 1, 1)
    GameTooltip:Show()
  end)
  frame.settingsButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  frame.lockButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.lockButton:SetSize(INCLUDE_EXCLUDE_BUTTON_WIDTH, 20)
  frame.lockButton:SetPoint("BOTTOMLEFT", 10, 8)
  frame.lockButton:SetScript("OnClick", function()
    local barFrame = BarSmith:GetModule("BarFrame")
    if barFrame and barFrame.SetLocked then
      barFrame:SetLocked(not BarSmith.chardb.barLocked)
    end
    frame.lockButton:SetText(BarSmith.chardb.barLocked and "Unlock" or "Lock")
  end)
  frame.lockButton:SetScript("OnEnter", function(btn)
    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
    GameTooltip:SetText(BarSmith.chardb.barLocked and "Unlock the bar" or "Lock the bar", 1, 1, 1)
    GameTooltip:Show()
  end)
  frame.lockButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  frame.clearExcludeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.clearExcludeButton:SetSize(INCLUDE_EXCLUDE_BUTTON_WIDTH, 20)
  frame.clearExcludeButton:SetPoint("BOTTOMRIGHT", -10, 8)
  frame.clearExcludeButton:SetText("Clear Exclude")
  frame.clearExcludeButton:SetScript("OnClick", function()
    StaticPopupDialogs["BARSMITH_CLEAR_EXCLUDE"] = StaticPopupDialogs["BARSMITH_CLEAR_EXCLUDE"] or {
      text = "Clear all excluded items/spells?",
      button1 = "Yes",
      button2 = "No",
      OnAccept = function()
        if BarSmith.chardb then
          BarSmith.chardb.exclude = {}
        end
        BarSmith:FireCallback("SETTINGS_CHANGED")
        BarFrameSettings:UpdateIncludeExcludeFrame()
      end,
      timeout = 0,
      whileDead = true,
      hideOnEscape = true,
      preferredIndex = 3,
    }
    StaticPopup_Show("BARSMITH_CLEAR_EXCLUDE")
  end)
  frame.clearExcludeButton:SetScript("OnEnter", function(btn)
    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
    GameTooltip:SetText("Clear all excluded items/spells", 1, 1, 1)
    GameTooltip:Show()
  end)
  frame.clearExcludeButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  frame.clearIncludeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.clearIncludeButton:SetSize(INCLUDE_EXCLUDE_BUTTON_WIDTH, 20)
  frame.clearIncludeButton:SetPoint("RIGHT", frame.clearExcludeButton, "LEFT", -6, 0)
  frame.clearIncludeButton:SetText("Clear Include")
  frame.clearIncludeButton:SetScript("OnClick", function()
    StaticPopupDialogs["BARSMITH_CLEAR_INCLUDE"] = StaticPopupDialogs["BARSMITH_CLEAR_INCLUDE"] or {
      text = "Clear all included items/spells?",
      button1 = "Yes",
      button2 = "No",
      OnAccept = function()
        BarSmith:ClearInclude()
        BarSmith:FireCallback("SETTINGS_CHANGED")
        BarFrameSettings:UpdateIncludeExcludeFrame()
      end,
      timeout = 0,
      whileDead = true,
      hideOnEscape = true,
      preferredIndex = 3,
    }
    StaticPopup_Show("BARSMITH_CLEAR_INCLUDE")
  end)
  frame.clearIncludeButton:SetScript("OnEnter", function(btn)
    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
    GameTooltip:SetText("Clear all included items/spells", 1, 1, 1)
    GameTooltip:Show()
  end)
  frame.clearIncludeButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", 8, -(INCLUDE_EXCLUDE_HEADER_HEIGHT + 14))
  scrollFrame:SetPoint("BOTTOMRIGHT", -28, 32)

  local content = CreateFrame("Frame", nil, scrollFrame)
  content:SetSize(1, 1)
  scrollFrame:SetScrollChild(content)

  frame.scrollFrame = scrollFrame
  frame.content = content
  frame.rows = {}

  self.includeExcludeFrame = frame
end

function BarFrameSettings:UpdateIncludeExcludeFrame()
  self:CreateIncludeExcludeFrame()

  local frame = self.includeExcludeFrame
  frame.lockButton:SetText(BarSmith.chardb.barLocked and "Unlock" or "Lock")
  local rows = self:BuildIncludeExcludeList()
  local content = frame.content

  local needed = #rows
  for i = 1, needed do
    local row = frame.rows[i]
    if not row then
      row = CreateFrame("Frame", nil, content)
      row:SetHeight(INCLUDE_EXCLUDE_ROW_HEIGHT)
      row:SetPoint("TOPLEFT", 0, -((i - 1) * INCLUDE_EXCLUDE_ROW_HEIGHT))
      row:SetPoint("RIGHT", content, "RIGHT", 0, 0)
      row:EnableMouse(true)

      row.bg = row:CreateTexture(nil, "BACKGROUND")
      row.bg:SetAllPoints()
      row.bg:SetColorTexture(0.2, 0.2, 0.25, 0)

      row.icon = row:CreateTexture(nil, "ARTWORK")
      row.icon:SetSize(MENU_ICON_SIZE, MENU_ICON_SIZE)
      row.icon:SetPoint("LEFT", 6, 0)

      row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
      row.text:SetPoint("RIGHT", row, "RIGHT", -6, 0)
      row.text:SetJustifyH("LEFT")

      frame.rows[i] = row
      row:SetScript("OnMouseUp", function(r, button)
        local data = r.data
        if button ~= "LeftButton" or not data or data.isTitle or data.disabled then
          return
        end
        if data.kind == "include_item" and data.category and data.itemID then
          local include = BarSmith.chardb and BarSmith.chardb.consumables and BarSmith.chardb.consumables.include
          if include and include[data.category] then
            include[data.category][data.itemID] = nil
          end
        elseif data.kind == "include_mount" and data.mountID then
          local mounts = BarSmith.chardb and BarSmith.chardb.mounts and BarSmith.chardb.mounts.include
          if mounts then
            mounts[data.mountID] = nil
          end
        elseif data.kind == "include_spell" and data.spellID then
          local spells = BarSmith.chardb and BarSmith.chardb.classSpells and BarSmith.chardb.classSpells.customSpellIDs
          if spells then
            for idx, id in ipairs(spells) do
              if id == data.spellID then
                table.remove(spells, idx)
                break
              end
            end
          end
        elseif data.kind == "include_macro" and data.slotIndex then
          local macros = BarSmith.chardb and BarSmith.chardb.macros and BarSmith.chardb.macros.slots
          if macros then
            macros[data.slotIndex] = nil
          end
        elseif data.kind == "exclude" and data.key then
          BarSmith:RemoveFromExcludeByKey(data.key)
        end

        BarSmith:FireCallback("SETTINGS_CHANGED")
        BarFrameSettings:UpdateIncludeExcludeFrame()
      end)
      row:SetScript("OnEnter", function(r)
        if not r.data or r.data.isTitle or r.data.disabled then
          return
        end
        r.bg:SetAlpha(0.2)
        GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
        GameTooltip:SetText("Click to remove", 1, 1, 1)
        GameTooltip:Show()
      end)
      row:SetScript("OnLeave", function(r)
        r.bg:SetAlpha(0)
        GameTooltip:Hide()
      end)
    else
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", 0, -((i - 1) * INCLUDE_EXCLUDE_ROW_HEIGHT))
      row:SetPoint("RIGHT", content, "RIGHT", 0, 0)
    end

    local data = rows[i]
    row.data = data
    row:Show()
    row.text:SetText(data.text or "")
    row.text:SetTextColor(1, 1, 1)
    row.text:SetFontObject(data.isTitle and "GameFontNormal" or "GameFontHighlightSmall")
    if data.disabled then
      row.text:SetTextColor(0.6, 0.6, 0.6)
    elseif data.isTitle and data.color then
      row.text:SetTextColor(data.color[1], data.color[2], data.color[3])
    end

    if data.icon and not data.isTitle then
      row.icon:SetTexture(data.icon)
      row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
      row.icon:Show()
    else
      row.icon:Hide()
    end

    if data.isTitle or data.disabled then
      row:EnableMouse(false)
      row.bg:SetAlpha(0)
    else
      row:EnableMouse(true)
    end
  end

  for i = needed + 1, #frame.rows do
    frame.rows[i]:Hide()
  end

  local height = math.max(1, needed * INCLUDE_EXCLUDE_ROW_HEIGHT)
  content:SetSize(INCLUDE_EXCLUDE_FRAME_WIDTH - 40, height)
end

function BarFrameSettings:ToggleIncludeExcludeFrame(anchor)
  self:CreateIncludeExcludeFrame()

  local frame = self.includeExcludeFrame
  if frame:IsShown() then
    frame:Hide()
    return
  end

  frame:ClearAllPoints()
  local barFrame = BarSmith:GetModule("BarFrame")
  if anchor then
    frame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -6)
  elseif barFrame and barFrame.frame then
    frame:SetPoint("TOPLEFT", barFrame.frame, "BOTTOMLEFT", 0, -6)
  else
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  end

  self:UpdateIncludeExcludeFrame()
  frame:Show()
end
