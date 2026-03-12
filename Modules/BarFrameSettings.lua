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
local INCLUDE_EXCLUDE_FOOTER_HEIGHT = 28
local INCLUDE_EXCLUDE_FOOTER_SPACING = 6
local MODULE_LABELS = {
  questItems   = "Quest Items",
  consumables  = "Consumables",
  consumables_potions = "Potions",
  consumables_flask  = "Flasks / Elixirs",
  consumables_food   = "Food / Drink",
  consumables_bandage= "Bandages",
  consumables_utility= "Utilities",
  trinkets     = "Trinkets",
  classSpells  = "Class Spells",
  professions  = "Professions",
  mounts       = "Mounts",
  toys         = "Toys",
  hearthstones = "Hearthstones",
  macros       = "Macros",
}

local function SortMenuEntriesByText(entries)
  table.sort(entries, function(a, b)
    local at = string.lower(tostring(a.text or ""))
    local bt = string.lower(tostring(b.text or ""))
    return at < bt
  end)
end

local function ClampFrameToScreen(frame)
  if not frame or not frame.GetLeft then return end
  local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
  if not left or not right or not top or not bottom then return end
  local ui = UIParent
  local uiRight = ui:GetRight()
  local uiTop = ui:GetTop()
  if not uiRight or not uiTop then return end

  local dx = 0
  local dy = 0
  if left < 0 then
    dx = dx - left + 4
  elseif right > uiRight then
    dx = dx - (right - uiRight) - 4
  end
  if bottom < 0 then
    dy = dy - bottom + 4
  elseif top > uiTop then
    dy = dy - (top - uiTop) - 4
  end

  if dx ~= 0 or dy ~= 0 then
    local cx, cy = frame:GetCenter()
    if cx and cy then
      frame:ClearAllPoints()
      frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx + dx, cy + dy)
    end
  end
end

local function PrepareTooltip(owner, parentFrame, anchor)
  if not owner then return end
  GameTooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
  GameTooltip:SetFrameStrata("TOOLTIP")
  local ref = parentFrame or owner
  if ref and ref.GetFrameLevel then
    GameTooltip:SetFrameLevel(ref:GetFrameLevel() + 50)
  end
end

local function GetModuleKeyFromButton(btn)
  if not btn then return nil end
  if btn.groupData and btn.groupData.module then
    return btn.groupData.module
  end
  if btn.itemData and btn.itemData.module then
    return btn.itemData.module
  end
  if btn.parentButton and btn.parentButton.groupData and btn.parentButton.groupData.module then
    return btn.parentButton.groupData.module
  end
  if btn.parentButton and btn.parentButton.itemData and btn.parentButton.itemData.module then
    return btn.parentButton.itemData.module
  end
  return nil
end

local function BuildExcludeContext(moduleKey)
  if not moduleKey then
    return nil
  end

  local ctx = { moduleKey = moduleKey }
  if moduleKey == "mounts" then
    ctx.mountSpellIDs = {}
    local mounts = BarSmith:GetModule("Mounts")
    if mounts and mounts.RANDOM_FAVORITE_MOUNT then
      ctx.mountSpellIDs[mounts.RANDOM_FAVORITE_MOUNT] = true
    end
    local mountIDs = C_MountJournal.GetMountIDs()
    if mountIDs then
      for _, mountID in ipairs(mountIDs) do
        local _, spellID = C_MountJournal.GetMountInfoByID(mountID)
        if spellID then
          ctx.mountSpellIDs[spellID] = true
        end
      end
    end
  elseif moduleKey == "classSpells" then
    ctx.classSpellIDs = {}
    local classSpells = BarSmith:GetModule("ClassSpells")
    if classSpells and classSpells.GetItems then
      for _, entry in ipairs(classSpells:GetItems() or {}) do
        if entry.spellID then
          ctx.classSpellIDs[entry.spellID] = true
        end
      end
    end
    local custom = BarSmith.chardb and BarSmith.chardb.classSpells and BarSmith.chardb.classSpells.customSpellIDs
    if type(custom) == "table" then
      for _, id in ipairs(custom) do
        ctx.classSpellIDs[id] = true
      end
    end
  elseif moduleKey == "professions" then
    ctx.profSpellIDs = {}
    local prof = BarSmith:GetModule("Professions")
    if prof and prof.GetItems then
      for _, entry in ipairs(prof:GetItems() or {}) do
        if entry.spellID then
          ctx.profSpellIDs[entry.spellID] = true
        end
      end
    end
  elseif moduleKey == "hearthstones" then
    ctx.hearthstoneItems = {}
    ctx.hearthstoneToys = {}
    local hearth = BarSmith:GetModule("Hearthstones")
    if hearth then
      if hearth.HEARTHSTONE_ITEM then
        ctx.hearthstoneItems[hearth.HEARTHSTONE_ITEM] = true
      end
      if type(hearth.ENGINEER_ITEMS) == "table" then
        for _, id in ipairs(hearth.ENGINEER_ITEMS) do
          ctx.hearthstoneItems[id] = true
        end
      end
      if type(hearth.HEARTHSTONE_TOYS) == "table" then
        for _, id in ipairs(hearth.HEARTHSTONE_TOYS) do
          ctx.hearthstoneToys[id] = true
        end
      end
      local prefToy = BarSmith.chardb and BarSmith.chardb.hearthstones and BarSmith.chardb.hearthstones.preferredToyID
      if prefToy then
        ctx.hearthstoneToys[prefToy] = true
      end
    end
  end

  return ctx
end

local function IsTrinketItem(itemID)
  if not itemID then return false end
  local _, _, _, _, _, _, _, _, equipLoc = C_Item.GetItemInfo(itemID)
  if not equipLoc then
    local _, _, _, _, _, _, _, _, equipLocInstant = C_Item.GetItemInfoInstant(itemID)
    equipLoc = equipLocInstant
  end
  return equipLoc == "INVTYPE_TRINKET"
end

local function IsQuestItem(itemID)
  if not itemID then return false end
  if C_QuestLog and C_QuestLog.IsQuestItem and C_QuestLog.IsQuestItem(itemID) then
    return true
  end
  local _, _, _, _, _, _, _, _, _, _, _, classID = C_Item.GetItemInfoInstant(itemID)
  return classID == 12
end

local function ShouldShowExcludeEntry(moduleKey, key, ctx)
  if not moduleKey then
    return true
  end
  if not key or type(key) ~= "string" then
    return false
  end

  local prefix, id = key:match("^(%w+):(.+)$")
  if not prefix or not id then
    return false
  end

  if moduleKey == "consumables"
      or moduleKey == "consumables_potions"
      or moduleKey == "consumables_flask"
      or moduleKey == "consumables_food"
      or moduleKey == "consumables_bandage"
      or moduleKey == "consumables_utility" then
    if prefix ~= "item" then
      return false
    end
    local con = BarSmith:GetModule("Consumables")
    local category = con and con.ClassifyExtraCategory and con:ClassifyExtraCategory(tonumber(id))
    if not category then
      return false
    end
    if moduleKey == "consumables" then
      return true
    end
    return (moduleKey == "consumables_potions" and category == "potions")
      or (moduleKey == "consumables_flask" and category == "flasks")
      or (moduleKey == "consumables_food" and category == "food")
      or (moduleKey == "consumables_bandage" and category == "bandages")
      or (moduleKey == "consumables_utility" and category == "utilities")
  end

  if moduleKey == "toys" then
    return prefix == "toy"
  end
  if moduleKey == "mounts" then
    return prefix == "spell" and ctx and ctx.mountSpellIDs and ctx.mountSpellIDs[tonumber(id)] == true
  end
  if moduleKey == "classSpells" then
    return prefix == "spell" and ctx and ctx.classSpellIDs and ctx.classSpellIDs[tonumber(id)] == true
  end
  if moduleKey == "professions" then
    return prefix == "spell" and ctx and ctx.profSpellIDs and ctx.profSpellIDs[tonumber(id)] == true
  end
  if moduleKey == "hearthstones" then
    if prefix == "item" and ctx and ctx.hearthstoneItems then
      return ctx.hearthstoneItems[tonumber(id)] == true
    end
    if prefix == "toy" and ctx and ctx.hearthstoneToys then
      return ctx.hearthstoneToys[tonumber(id)] == true
    end
    return false
  end
  if moduleKey == "trinkets" then
    return prefix == "item" and IsTrinketItem(tonumber(id))
  end
  if moduleKey == "questItems" then
    return prefix == "item" and IsQuestItem(tonumber(id))
  end

  return false
end

local function ShouldShowSection(moduleKey, sectionKey)
  if sectionKey == "exclude" then
    return true
  end
  if not moduleKey then
    return true
  end
  if moduleKey == "consumables" then
    return sectionKey == "potions"
      or sectionKey == "flasks"
      or sectionKey == "food"
      or sectionKey == "bandages"
      or sectionKey == "utilities"
  end
  if moduleKey == "consumables_potions" then
    return sectionKey == "potions"
  elseif moduleKey == "consumables_flask" then
    return sectionKey == "flasks"
  elseif moduleKey == "consumables_food" then
    return sectionKey == "food"
  elseif moduleKey == "consumables_bandage" then
    return sectionKey == "bandages"
  elseif moduleKey == "consumables_utility" then
    return sectionKey == "utilities"
  end

  if moduleKey == "mounts" then
    return sectionKey == "mounts"
  elseif moduleKey == "toys" then
    return sectionKey == "toys"
  elseif moduleKey == "classSpells" then
    return sectionKey == "classSpells"
  elseif moduleKey == "macros" then
    return sectionKey == "macros"
  end

  return false
end

local function GetModuleLabel(moduleKey)
  if not moduleKey then
    return "all"
  end
  return MODULE_LABELS[moduleKey] or moduleKey
end

local function ClearConsumableIncludes(include, category)
  if not include then return false end
  if category then
    include[category] = {}
    return true
  end

  include.potions = {}
  include.flasks = {}
  include.food = {}
  include.bandages = {}
  include.utilities = {}
  return true
end

function BarFrameSettings:ClearIncludesForModule(moduleKey)
  if not moduleKey then return false end
  local chardb = BarSmith.chardb
  if not chardb then return false end

  if moduleKey == "consumables"
      or moduleKey == "consumables_potions"
      or moduleKey == "consumables_flask"
      or moduleKey == "consumables_food"
      or moduleKey == "consumables_bandage"
      or moduleKey == "consumables_utility" then
    chardb.consumables = chardb.consumables or {}
    chardb.consumables.include = chardb.consumables.include or {}
    local category = nil
    if moduleKey == "consumables_potions" then
      category = "potions"
    elseif moduleKey == "consumables_flask" then
      category = "flasks"
    elseif moduleKey == "consumables_food" then
      category = "food"
    elseif moduleKey == "consumables_bandage" then
      category = "bandages"
    elseif moduleKey == "consumables_utility" then
      category = "utilities"
    end
    return ClearConsumableIncludes(chardb.consumables.include, category)
  elseif moduleKey == "mounts" then
    chardb.mounts = chardb.mounts or {}
    chardb.mounts.include = {}
    return true
  elseif moduleKey == "toys" then
    chardb.toys = chardb.toys or {}
    chardb.toys.include = {}
    return true
  elseif moduleKey == "classSpells" then
    chardb.classSpells = chardb.classSpells or {}
    chardb.classSpells.customSpellIDs = {}
    return true
  elseif moduleKey == "macros" then
    chardb.macros = chardb.macros or {}
    chardb.macros.slots = {}
    return true
  end

  return false
end

function BarFrameSettings:ClearExcludesForModule(moduleKey)
  if not moduleKey then return false end
  local chardb = BarSmith.chardb
  if not chardb or type(chardb.exclude) ~= "table" then
    return false
  end

  local exclude = chardb.exclude
  local ctx = BuildExcludeContext(moduleKey)
  local removed = false
  for key in pairs(exclude) do
    if ShouldShowExcludeEntry(moduleKey, key, ctx) then
      exclude[key] = nil
      removed = true
    end
  end

  return removed
end

function BarFrameSettings:BuildIncludeExcludeList(moduleKey)
  local rows = {}
  local excludeCtx = BuildExcludeContext(moduleKey)

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
  local includeToys = {}
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

  local function addToyEntry(target, toyID, entryData)
    if not toyID then return end
    local toyName, toyIcon
    if C_ToyBox and C_ToyBox.GetToyInfo then
      local name, icon = C_ToyBox.GetToyInfo(toyID)
      if type(name) == "table" then
        toyName = name.name
        toyIcon = name.icon
      else
        toyName = name
        toyIcon = icon
      end
    end
    if not toyName then
      local name, _, _, _, _, _, _, _, _, icon = C_Item.GetItemInfo(toyID)
      toyName = name
      toyIcon = toyIcon or icon
      if not name then
        C_Item.RequestLoadItemDataByID(toyID)
      end
    end
    local label = toyName or ("Toy " .. tostring(toyID))
    if toyName then
      label = toyName .. " (" .. tostring(toyID) .. ")"
    end
    addItem(target, label, toyIcon, entryData)
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

  local toyInclude = chardb.toys and chardb.toys.include or {}
  for toyID, enabled in pairs(toyInclude) do
    if enabled then
      addToyEntry(includeToys, toyID, { kind = "include_toy", toyID = toyID })
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
    if enabled and type(key) == "string" and ShouldShowExcludeEntry(moduleKey, key, excludeCtx) then
      local prefix, id = key:match("^(%w+):(.+)$")
      if prefix == "item" then
        addItemEntry(excludeEntries, tonumber(id), "Item", { kind = "exclude", key = key })
      elseif prefix == "toy" then
        addToyEntry(excludeEntries, tonumber(id), { kind = "exclude", key = key })
      elseif prefix == "spell" then
        addSpellEntry(excludeEntries, tonumber(id), { kind = "exclude", key = key })
      elseif prefix == "name" then
        addItem(excludeEntries, tostring(id), nil, { kind = "exclude", key = key })
      else
        addItem(excludeEntries, key, nil, { kind = "exclude", key = key })
      end
    end
  end

  if ShouldShowSection(moduleKey, "potions") then
    addSection("Include: Potions", includePotions, { 0.35, 0.9, 0.55 })
  end
  if ShouldShowSection(moduleKey, "flasks") then
    addSection("Include: Flasks/Elixirs", includeFlasks, { 0.72, 0.55, 1.0 })
  end
  if ShouldShowSection(moduleKey, "food") then
    addSection("Include: Food/Drink", includeFood, { 1.0, 0.8, 0.45 })
  end
  if ShouldShowSection(moduleKey, "bandages") then
    addSection("Include: Bandages", includeBandages, { 0.85, 0.85, 0.85 })
  end
  if ShouldShowSection(moduleKey, "utilities") then
    addSection("Include: Utilities", includeUtilities, { 1.0, 0.65, 0.3 })
  end
  if ShouldShowSection(moduleKey, "mounts") then
    addSection("Include: Mounts", includeMounts, { 0.5, 0.85, 0.6 })
  end
  if ShouldShowSection(moduleKey, "toys") then
    addSection("Include: Toys", includeToys, { 0.9, 0.75, 0.25 })
  end
  if ShouldShowSection(moduleKey, "classSpells") then
    addSection("Include: Class Spells", includeSpells, { 0.5, 0.85, 1.0 })
  end
  if ShouldShowSection(moduleKey, "macros") then
    addSection("Macros", includeMacros, { 0.95, 0.9, 0.5 })
  end
  if ShouldShowSection(moduleKey, "exclude") then
    addSection("Exclude", excludeEntries, { 1.0, 0.35, 0.35 })
  end

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

  frame.showAllCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
  frame.showAllCheck:SetPoint("TOPRIGHT", -30, -8)
  frame.showAllCheck.Text:SetText("Show All")
  frame.showAllCheck:SetScript("OnClick", function(btn)
    frame.showAll = btn:GetChecked() == true
    BarFrameSettings:UpdateIncludeExcludeFrame()
  end)
  frame.showAllCheck:SetScript("OnEnter", function(btn)
    PrepareTooltip(btn, frame)
    GameTooltip:SetText("Show all includes and excludes for every module", 1, 1, 1)
    GameTooltip:Show()
  end)
  frame.showAllCheck:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  frame.divider = frame:CreateTexture(nil, "ARTWORK")
  frame.divider:SetPoint("TOPLEFT", 6, -(INCLUDE_EXCLUDE_HEADER_HEIGHT + 6))
  frame.divider:SetPoint("TOPRIGHT", -6, -(INCLUDE_EXCLUDE_HEADER_HEIGHT + 6))
  frame.divider:SetHeight(1)
  frame.divider:SetColorTexture(1, 1, 1, 0.08)

  frame.close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  frame.close:SetPoint("TOPRIGHT", -6, -6)

  frame.footer = CreateFrame("Frame", nil, frame)
  frame.footer:SetPoint("BOTTOMLEFT", 6, 6)
  frame.footer:SetPoint("BOTTOMRIGHT", -6, 6)
  frame.footer:SetHeight(INCLUDE_EXCLUDE_FOOTER_HEIGHT)

  local footerWidth = INCLUDE_EXCLUDE_FRAME_WIDTH - 12
  local buttonCount = 5
  local buttonWidth = math.floor((footerWidth - (INCLUDE_EXCLUDE_FOOTER_SPACING * (buttonCount - 1))) / buttonCount)

  frame.settingsButton = CreateFrame("Button", nil, frame.footer, "UIPanelButtonTemplate")
  frame.settingsButton:SetSize(buttonWidth, 20)
  frame.settingsButton:SetPoint("LEFT", frame.footer, "LEFT", 0, 0)
  frame.settingsButton:SetText("Settings")
  frame.settingsButton:SetScript("OnClick", function()
    BarSmith:OpenSettings()
    frame:Hide()
  end)
  frame.settingsButton:SetScript("OnEnter", function(btn)
    PrepareTooltip(btn, frame)
    GameTooltip:SetText("Open BarSmith settings", 1, 1, 1)
    GameTooltip:Show()
  end)
  frame.settingsButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  frame.lockButton = CreateFrame("Button", nil, frame.footer, "UIPanelButtonTemplate")
  frame.lockButton:SetSize(buttonWidth, 20)
  frame.lockButton:SetPoint("LEFT", frame.settingsButton, "RIGHT", INCLUDE_EXCLUDE_FOOTER_SPACING, 0)
  frame.lockButton:SetScript("OnClick", function()
    local barFrame = BarSmith:GetModule("BarFrame")
    if barFrame and barFrame.SetLocked then
      barFrame:SetLocked(not BarSmith.chardb.barLocked)
    end
    frame.lockButton:SetText(BarSmith.chardb.barLocked and "Unlock" or "Lock")
  end)
  frame.lockButton:SetScript("OnEnter", function(btn)
    PrepareTooltip(btn, frame)
    GameTooltip:SetText(BarSmith.chardb.barLocked and "Unlock the bar" or "Lock the bar", 1, 1, 1)
    GameTooltip:Show()
  end)
  frame.lockButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  frame.refillButton = CreateFrame("Button", nil, frame.footer, "UIPanelButtonTemplate")
  frame.refillButton:SetSize(buttonWidth, 20)
  frame.refillButton:SetPoint("LEFT", frame.lockButton, "RIGHT", INCLUDE_EXCLUDE_FOOTER_SPACING, 0)
  frame.refillButton:SetText("Refill")
  frame.refillButton:SetScript("OnClick", function()
    BarSmith:RunAutoFill(true)
  end)
  frame.refillButton:SetScript("OnEnter", function(btn)
    PrepareTooltip(btn, frame)
    GameTooltip:SetText("Refill the bar now", 1, 1, 1)
    GameTooltip:Show()
  end)
  frame.refillButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  frame.clearIncludeButton = CreateFrame("Button", nil, frame.footer, "UIPanelButtonTemplate")
  frame.clearIncludeButton:SetSize(buttonWidth, 20)
  frame.clearIncludeButton:SetPoint("LEFT", frame.refillButton, "RIGHT", INCLUDE_EXCLUDE_FOOTER_SPACING, 0)
  frame.clearIncludeButton:SetText("Clr Incl")
  frame.clearIncludeButton:SetScript("OnClick", function()
    local targetKey = nil
    if not frame.showAll then
      targetKey = frame.moduleKey
    end
    local dialog = StaticPopupDialogs["BARSMITH_CLEAR_INCLUDE"]
    if not dialog then
      dialog = {
        button1 = "Yes",
        button2 = "No",
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
      }
      StaticPopupDialogs["BARSMITH_CLEAR_INCLUDE"] = dialog
    end
    dialog.text = targetKey and ("Clear included entries for " .. GetModuleLabel(targetKey) .. "?")
      or "Clear all included items/spells?"
    dialog.OnAccept = function()
      if targetKey then
        BarFrameSettings:ClearIncludesForModule(targetKey)
      else
        BarSmith:ClearInclude()
      end
      BarSmith:FireCallback("SETTINGS_CHANGED")
      BarFrameSettings:UpdateIncludeExcludeFrame()
    end
    StaticPopup_Show("BARSMITH_CLEAR_INCLUDE")
  end)
  frame.clearIncludeButton:SetScript("OnEnter", function(btn)
    PrepareTooltip(btn, frame)
    local targetKey = nil
    if not frame.showAll then
      targetKey = frame.moduleKey
    end
    if targetKey then
      GameTooltip:SetText("Clear included entries for " .. GetModuleLabel(targetKey), 1, 1, 1)
    else
      GameTooltip:SetText("Clear all included items/spells", 1, 1, 1)
    end
    GameTooltip:Show()
  end)
  frame.clearIncludeButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  frame.clearExcludeButton = CreateFrame("Button", nil, frame.footer, "UIPanelButtonTemplate")
  frame.clearExcludeButton:SetSize(buttonWidth, 20)
  frame.clearExcludeButton:SetPoint("LEFT", frame.clearIncludeButton, "RIGHT", INCLUDE_EXCLUDE_FOOTER_SPACING, 0)
  frame.clearExcludeButton:SetText("Clr Excl")
  frame.clearExcludeButton:SetScript("OnClick", function()
    local targetKey = nil
    if not frame.showAll then
      targetKey = frame.moduleKey
    end
    local dialog = StaticPopupDialogs["BARSMITH_CLEAR_EXCLUDE"]
    if not dialog then
      dialog = {
        button1 = "Yes",
        button2 = "No",
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
      }
      StaticPopupDialogs["BARSMITH_CLEAR_EXCLUDE"] = dialog
    end
    dialog.text = targetKey and ("Clear excluded entries for " .. GetModuleLabel(targetKey) .. "?")
      or "Clear all excluded items/spells?"
    dialog.OnAccept = function()
      if targetKey then
        BarFrameSettings:ClearExcludesForModule(targetKey)
      elseif BarSmith.chardb then
        BarSmith.chardb.exclude = {}
      end
      BarSmith:FireCallback("SETTINGS_CHANGED")
      BarFrameSettings:UpdateIncludeExcludeFrame()
    end
    StaticPopup_Show("BARSMITH_CLEAR_EXCLUDE")
  end)
  frame.clearExcludeButton:SetScript("OnEnter", function(btn)
    PrepareTooltip(btn, frame)
    local targetKey = nil
    if not frame.showAll then
      targetKey = frame.moduleKey
    end
    if targetKey then
      GameTooltip:SetText("Clear excluded entries for " .. GetModuleLabel(targetKey), 1, 1, 1)
    else
      GameTooltip:SetText("Clear all excluded items/spells", 1, 1, 1)
    end
    GameTooltip:Show()
  end)
  frame.clearExcludeButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", 8, -(INCLUDE_EXCLUDE_HEADER_HEIGHT + 14))
  scrollFrame:SetPoint("BOTTOMRIGHT", -28, INCLUDE_EXCLUDE_FOOTER_HEIGHT + 12)

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
  local moduleKey = frame.moduleKey
  if frame.showAll then
    moduleKey = nil
  end
  local title = "Includes / Excludes"
  if frame.showAll then
    title = title .. ": All"
  elseif moduleKey then
    title = title .. ": " .. (MODULE_LABELS[moduleKey] or moduleKey)
  end
  frame.title:SetText(title)
  if frame.showAllCheck then
    frame.showAllCheck:SetChecked(frame.showAll == true)
  end
  frame.lockButton:SetText(BarSmith.chardb.barLocked and "Unlock" or "Lock")
  local rows = self:BuildIncludeExcludeList(moduleKey)
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
        elseif data.kind == "include_toy" and data.toyID then
          local toys = BarSmith.chardb and BarSmith.chardb.toys and BarSmith.chardb.toys.include
          if toys then
            toys[data.toyID] = nil
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
        PrepareTooltip(r, frame)
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

  frame.moduleKey = GetModuleKeyFromButton(anchor)
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
  ClampFrameToScreen(frame)
end
