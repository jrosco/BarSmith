------------------------------------------------------------------------
-- BarSmith: Modules/QuickBar.lua
-- Dedicated quick-access bar with fixed slots and simple actions
------------------------------------------------------------------------

local QuickBar = BarSmith:NewModule("QuickBar")

local MAX_QUICKBAR_BUTTONS = 10
local DEFAULT_ICON_SIZE = 42
local BUTTON_PADDING = 3
local BAR_PADDING = 4
local HOVER_HIT_INSET = math.max(2, math.ceil(BUTTON_PADDING / 2))
local HIDE_DELAY = 0.3
local TOOLTIP_ICON = "|TInterface\\AddOns\\BarSmith\\Textures\\bs:14:14:0:0|t"
local TOOLTIP_TITLE_COLOR = "|cff33ccff"
local TOOLTIP_ACTION_REMOVE_COLOR = "|cffff9a9a"
local TOOLTIP_SHORTCUT_COLOR = "|cffffffff"
local PREVIEW_ICONS = {
  "Interface\\Icons\\INV_Potion_93",
  "Interface\\Icons\\INV_Misc_Food_60",
  "Interface\\Icons\\INV_Misc_Book_11",
  "Interface\\Icons\\INV_Misc_Gem_Bloodstone_01",
  "Interface\\Icons\\INV_Misc_Rune_01",
  "Interface\\Icons\\INV_Misc_EngGizmos_01",
  "Interface\\Icons\\INV_Misc_Herb_19",
  "Interface\\Icons\\INV_Misc_Bag_09",
  "Interface\\Icons\\INV_Misc_ArmorKit_17",
  "Interface\\Icons\\INV_Misc_Map_01",
}

local QUICKBAR_SECURE_SHOW = [[
  local bar = control and control:GetFrameRef("bs_quickbar")
  if not bar then return end
  if (control:GetAttribute("bs_preview") or 0) == 1 then
    if bar:IsShown() then return end
    bar:Show()
    return
  end
  control:SetAttribute("bs_sticky", 0)
  if bar:IsShown() then return end
  bar:Show()
]]
local QUICKBAR_SECURE_HIDE = [[
  local bar = control and control:GetFrameRef("bs_quickbar")
  if not bar or not bar:IsShown() then return end
  if (control:GetAttribute("bs_preview") or 0) == 1 then return end
  if (control:GetAttribute("bs_sticky") or 0) == 1 then return end
  local count = control:GetAttribute("bs_button_count") or 0
  for i = 1, count do
    local btn = control:GetFrameRef("bs_button" .. i)
    if btn and btn:IsUnderMouse(true) then
      return
    end
  end
  bar:Hide()
]]
local QUICKBAR_SECURE_TOGGLE = [[
  if self:GetAttribute("bs_enabled") == 0 then
    return
  end
  if self:GetAttribute("bs_has_items") == 0 then
    return
  end
  local bar = self:GetFrameRef("bs_quickbar")
  if not bar then
    return
  end
  if bar:IsShown() then
    bar:Hide()
    self:SetAttribute("bs_sticky", 0)
    return
  end
  local ui = self:GetFrameRef("UIParent")
  if not ui then
    return
  end
  local xRatio, yRatio = self:GetMousePosition()
  if not xRatio or not yRatio then
    return
  end
  local w = ui:GetWidth()
  local h = ui:GetHeight()
  local x = w * xRatio
  local y = h * yRatio
  bar:ClearAllPoints()
  bar:SetPoint("CENTER", ui, "BOTTOMLEFT", x, y)
  self:SetAttribute("bs_sticky", 1)
  bar:Show()
]]

function QuickBar:GetConfig()
  local chardb = BarSmith.chardb or {}
  chardb.quickBar = chardb.quickBar or {}
  return chardb.quickBar
end

function QuickBar:GetButtonSize()
  local cfg = self:GetConfig()
  local size = tonumber(cfg.iconSize) or DEFAULT_ICON_SIZE
  return math.max(24, math.min(64, size))
end

function QuickBar:GetColumns()
  local cfg = self:GetConfig()
  local cols = tonumber(cfg.columns) or MAX_QUICKBAR_BUTTONS
  cols = math.max(1, math.min(MAX_QUICKBAR_BUTTONS, math.floor(cols)))
  return cols
end

function QuickBar:GetActiveCount()
  local cfg = self:GetConfig()
  cfg.slots = cfg.slots or {}
  local count = 0
  for i = 1, MAX_QUICKBAR_BUTTONS do
    if cfg.slots[i] then
      count = count + 1
    end
  end
  return count
end

function QuickBar:Init()
  if self.frame then return end

  local cfg = self:GetConfig()

  self.frame = CreateFrame("Frame", "BarSmithQuickBarFrame", UIParent, "SecureHandlerBaseTemplate,BackdropTemplate")
  self.frame:SetClampedToScreen(true)
  self.frame:SetFrameStrata("DIALOG")
  self.frame:Hide()

  self.previewLabel = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  self.previewLabel:SetPoint("BOTTOMLEFT", self.frame, "TOPLEFT", 4, 6)
  self.previewLabel:SetText("QuickBar Preview")
  self.previewLabel:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
  self.previewLabel:Hide()

  self.toggleButton = CreateFrame("Button", "BarSmithQuickBarToggle", UIParent, "SecureHandlerClickTemplate")
  self.toggleButton:Hide()
  self.toggleButton:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
  self.toggleButton:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
  self.toggleButton:SetFrameRef("bs_quickbar", self.frame)
  self.toggleButton:SetFrameRef("UIParent", UIParent)
  self.toggleButton:SetAttribute("_onclick", QUICKBAR_SECURE_TOGGLE)
  self:UpdateToggleClickType()
  self.toggleButton:HookScript("OnClick", function()
    local enabled = self.toggleButton:GetAttribute("bs_enabled")
    local hasItems = self.toggleButton:GetAttribute("bs_has_items")
    if enabled == 0 then
      BarSmith:Print("QuickBar is disabled.")
      return
    end
    if hasItems == 0 then
      BarSmith:Print("QuickBar is empty. Alt-Left-click an item/spell on the BarSmith bar to add it.")
    end
  end)
  self:UpdateToggleState()
  self:UpdatePreviewState()
  self:UpdateKeybindOverrides()

  self.frame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  self:UpdateBackdropVisibility()

  self.buttons = {}
  for i = 1, MAX_QUICKBAR_BUTTONS do
    self.buttons[i] = self:CreateButton(i)
  end
  self.toggleButton:SetAttribute("bs_button_count", MAX_QUICKBAR_BUTTONS)
  for i = 1, MAX_QUICKBAR_BUTTONS do
    self.toggleButton:SetFrameRef("bs_button" .. i, self.buttons[i])
  end

  self:SeedDefaultSlots()
  self:UpdateLayout()

  self.frame:HookScript("OnEnter", function()
    self:CancelHideTimer()
  end)
  self.frame:HookScript("OnLeave", function()
    self:StartHideTimer()
  end)

  -- Cooldown update ticker
  self.cooldownTicker = C_Timer.NewTicker(0.5, function()
    self:UpdateCooldowns()
  end)

  self:Refresh()
end

function QuickBar:UpdateCooldowns()
  if not self.frame or self.previewMode then
    return
  end

  local barFrame = BarSmith:GetModule("BarFrame")
  local hearthstones = BarSmith:GetModule("Hearthstones")
  local housingReturnActive = hearthstones and hearthstones.housingReturnActive == true
  local housingIcon = hearthstones and hearthstones.HOUSING_ICON or nil
  local housingReturnAtlas = hearthstones and hearthstones.HOUSING_ICON_RETURN_ATLAS or nil

  local function updateButtonCooldown(btn)
    if not btn or not btn:IsShown() or not btn.itemData then
      return
    end

    local data = btn.itemData
    local durationObject
    local start, duration, enable = 0, 0, 1

    if data.type == "housing_teleport" then
      if hearthstones then
        local changed = false
        if housingReturnActive then
          if data.iconAtlas ~= housingReturnAtlas then
            data.iconAtlas = housingReturnAtlas
            changed = true
          end
          if data.icon ~= nil then
            data.icon = nil
            changed = true
          end
          if data.hideCooldown ~= true then
            data.hideCooldown = true
            changed = true
          end
        else
          if data.iconAtlas ~= nil then
            data.iconAtlas = nil
            changed = true
          end
          if housingIcon and data.icon ~= housingIcon then
            data.icon = housingIcon
            changed = true
          end
          if data.hideCooldown ~= false and data.hideCooldown ~= nil then
            data.hideCooldown = nil
            changed = true
          end
        end
        if changed and barFrame and barFrame.ApplyButtonVisuals then
          barFrame:ApplyButtonVisuals(btn, data)
        end
      end

      if data.hideCooldown then
        if btn.cooldown then
          btn.cooldown:Clear()
        end
        return
      end
      if C_Housing and C_Housing.GetVisitCooldownInfo then
        local info = C_Housing.GetVisitCooldownInfo()
        if info and info.isEnabled then
          start = info.startTime or 0
          duration = info.duration or 0
          enable = 1
        else
          start, duration, enable = 0, 0, 0
        end
      end
    elseif data.spellID then
      durationObject = C_Spell.GetSpellCooldownDuration(data.spellID)
    elseif data.itemID then
      start, duration, enable = C_Item.GetItemCooldown(data.itemID)
    elseif data.toyID then
      start, duration, enable = C_Item.GetItemCooldown(data.toyID)
    end

    if btn.cooldown and durationObject then
      btn.cooldown:SetCooldownFromDurationObject(durationObject)
    elseif btn.cooldown and duration and duration > 0 then
      CooldownFrame_Set(btn.cooldown, start, duration, enable)
    elseif btn.cooldown then
      btn.cooldown:Clear()
    end
  end

  for _, btn in ipairs(self.buttons or {}) do
    updateButtonCooldown(btn)
  end
end

function QuickBar:UpdateBackdropVisibility()
  if not self.frame then return end
  local cfg = self:GetConfig()
  local showBackdrop = (cfg.showBackdrop ~= false)
  local alpha = tonumber(cfg.alpha) or 1
  alpha = math.max(0.1, math.min(1, alpha))
  if showBackdrop then
    self.frame:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
    self.frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.9)
  else
    self.frame:SetBackdropColor(0, 0, 0, 0.001)
    self.frame:SetBackdropBorderColor(0, 0, 0, 0.001)
  end
  self.frame:SetAlpha(alpha)
end

function QuickBar:UpdateToggleState()
  if not self.toggleButton then return end
  if InCombatLockdown() then return end
  local cfg = self:GetConfig()
  local enabled = (cfg.enabled ~= false) and 1 or 0
  local hasItems = (self:GetActiveCount() > 0) and 1 or 0
  self.toggleButton:SetAttribute("bs_enabled", enabled)
  self.toggleButton:SetAttribute("bs_has_items", hasItems)
  if enabled == 0 and self.frame and self.frame:IsShown() then
    self:Hide()
  end
end

function QuickBar:UpdatePreviewState()
  if not self.toggleButton then return end
  if InCombatLockdown() then return end
  if self.previewMode then
    self.toggleButton:SetAttribute("bs_preview", 1)
    if self.previewLabel then
      self.previewLabel:Show()
    end
  else
    self.toggleButton:SetAttribute("bs_preview", 0)
    if self.previewLabel then
      self.previewLabel:Hide()
    end
  end
end

function QuickBar:GetPreviewCount()
  return MAX_QUICKBAR_BUTTONS
end

function QuickBar:ShowPreview()
  if InCombatLockdown() then
    BarSmith:Print("Cannot show QuickBar preview during combat.")
    return
  end
  if not self.frame then
    self:Init()
  end
  self.previewMode = true
  self:UpdatePreviewState()
  self:CancelHideTimer()
  self.frame:ClearAllPoints()
  self.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  self:UpdateLayout(self:GetPreviewCount())
  self:UpdateBackdropVisibility()
  self:ApplyPreviewButtons()
  self.frame:Show()
end

function QuickBar:HidePreview()
  if not self.frame then return end
  if InCombatLockdown() then
    BarSmith:Print("Cannot hide QuickBar preview during combat.")
    return
  end
  self.previewMode = false
  self:UpdatePreviewState()
  self:CancelHideTimer()
  self.frame:Hide()
  self:RestorePosition()
  self:Refresh()
end

function QuickBar:ApplyPreviewButtons()
  if not self.frame then return end
  if InCombatLockdown() then return end
  local previewCount = self:GetPreviewCount()
  local iconCount = #PREVIEW_ICONS
  for i, btn in ipairs(self.buttons) do
    btn.itemData = nil
    if i <= previewCount then
      btn:SetAttribute("type", nil)
      btn:SetAttribute("spell", nil)
      btn:SetAttribute("item", nil)
      btn:SetAttribute("toy", nil)
      btn:SetAttribute("macrotext", nil)
      local iconIndex = ((i - 1) % iconCount) + 1
      btn.icon:SetTexture(PREVIEW_ICONS[iconIndex])
      btn.count:SetText("")
      btn:Show()
    else
      btn:Hide()
    end
  end
end

function QuickBar:UpdateToggleClickType()
  if not self.toggleButton then return end
  if InCombatLockdown() then return end
  local useKeyDown = GetCVarBool and GetCVarBool("ActionButtonUseKeyDown")
  if useKeyDown then
    self.toggleButton:RegisterForClicks("LeftButtonDown")
  else
    self.toggleButton:RegisterForClicks("LeftButtonUp")
  end
end

function QuickBar:UpdateKeybindOverrides()
  if not self.toggleButton then return end
  if InCombatLockdown() then return end
  ClearOverrideBindings(self.toggleButton)
  local key1, key2 = GetBindingKey("BARSMITH_TOGGLE_QUICKBAR")
  if key1 and key1 ~= "" then
    SetOverrideBindingClick(self.toggleButton, true, key1, "BarSmithQuickBarToggle", "LeftButton")
  end
  if key2 and key2 ~= "" then
    SetOverrideBindingClick(self.toggleButton, true, key2, "BarSmithQuickBarToggle", "LeftButton")
  end
end

function QuickBar:CreateButton(index)
  local btnName = "BarSmithQuickBarButton" .. index
  local btn = CreateFrame("Button", btnName, self.frame, "SecureActionButtonTemplate,SecureHandlerEnterLeaveTemplate")

  local buttonSize = self:GetButtonSize()
  btn:SetSize(buttonSize, buttonSize)
  btn:RegisterForClicks("AnyUp", "AnyDown")
  btn:SetHitRectInsets(-HOVER_HIT_INSET, -HOVER_HIT_INSET, -HOVER_HIT_INSET, -HOVER_HIT_INSET)

  btn.index = index
  btn.itemData = nil

  btn:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
  btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

  btn.icon = btn:CreateTexture(btnName .. "Icon", "BACKGROUND")
  btn.icon:SetAllPoints()
  btn.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

  btn.cooldown = btn.cooldown or CreateFrame("Cooldown", btnName .. "Cooldown", btn, "CooldownFrameTemplate")
  btn.cooldown:SetAllPoints()

  btn.count = btn.count or btn:CreateFontString(btnName .. "Count", "OVERLAY", "NumberFontNormalSmallGray")
  btn.count:SetPoint("BOTTOMRIGHT", -2, 2)
  btn.count:SetText("")

  if BarSmith.MasqueAddButton then

    BarSmith:MasqueAddButton(btn, "QuickBar")

  end

  btn:SetScript("OnEnter", function()
    self:CancelHideTimer()
    self:HandleTooltipEnter(btn)
  end)
  btn:SetScript("OnLeave", function(b)
    self:HandleTooltipLeave(b)
    self:StartHideTimer()
  end)

  btn:HookScript("OnMouseUp", function(b, button)
    if button == "RightButton" and IsAltKeyDown() then
      self:ClearSlot(b.index)
    end
  end)

  SecureHandlerWrapScript(btn, "OnEnter", self.toggleButton, QUICKBAR_SECURE_SHOW)
  SecureHandlerWrapScript(btn, "OnLeave", self.toggleButton, QUICKBAR_SECURE_HIDE)

  btn:Hide()
  return btn
end

function QuickBar:ShowButtonTooltip(btn)
  if not btn or not btn.itemData then return end
  GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
  local data = btn.itemData
  if data.toyID then
    GameTooltip:SetToyByItemID(data.toyID)
  elseif data.itemID then
    GameTooltip:SetItemByID(data.itemID)
  elseif data.spellID then
    GameTooltip:SetSpellByID(data.spellID)
  else
    GameTooltip:SetText(data.name or "Unknown", 1, 1, 1)
  end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine(TOOLTIP_ICON .. " |cff33ccff[BarSmith QuickBar]|r", 0.5, 0.5, 0.5)
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine(TOOLTIP_TITLE_COLOR .. "Actions|r", 1, 1, 1)
  GameTooltip:AddLine(TOOLTIP_ACTION_REMOVE_COLOR .. "Remove|r: " ..
    TOOLTIP_SHORTCUT_COLOR .. "Alt + Right Click|r", 0.8, 0.8, 0.8)
  GameTooltip:Show()
end

local function NormalizeTooltipModifier(mod)
  mod = string.upper(tostring(mod or "NONE"))
  if mod ~= "ALT" and mod ~= "SHIFT" and mod ~= "CTRL" and mod ~= "NONE" then
    mod = "NONE"
  end
  return mod
end

function QuickBar:IsTooltipModifierActive()
  local mod = NormalizeTooltipModifier(BarSmith.chardb and BarSmith.chardb.quickBar
    and BarSmith.chardb.quickBar.tooltipModifier)
  if mod == "ALT" then
    return IsAltKeyDown()
  elseif mod == "SHIFT" then
    return IsShiftKeyDown()
  elseif mod == "CTRL" then
    return IsControlKeyDown()
  end
  return true
end

function QuickBar:UpdateTooltipState(btn)
  if not btn then return end
  local allowed = self:IsTooltipModifierActive()
  if allowed then
    if not btn.__bsTooltipShown then
      self:ShowButtonTooltip(btn)
      btn.__bsTooltipShown = true
    end
  elseif btn.__bsTooltipShown then
    GameTooltip:Hide()
    btn.__bsTooltipShown = false
  end
end

function QuickBar:HandleTooltipEnter(btn)
  if not btn then return end
  btn.__bsTooltipShown = false
  self:UpdateTooltipState(btn)
  btn:SetScript("OnUpdate", function(b)
    self:UpdateTooltipState(b)
  end)
end

function QuickBar:HandleTooltipLeave(btn)
  if btn then
    btn.__bsTooltipShown = false
    btn:SetScript("OnUpdate", nil)
  end
  GameTooltip:Hide()
end

function QuickBar:UpdateLayout(forcedCount)
  if not self.frame then return end
  if InCombatLockdown() then return end
  local activeCount = forcedCount or (self.previewMode and self:GetPreviewCount()) or self:GetActiveCount()
  local cols = self:GetColumns()
  if activeCount <= 0 then
    self.frame:SetSize(1, 1)
    for _, btn in ipairs(self.buttons) do
      btn:Hide()
    end
    return
  end
  cols = math.min(cols, activeCount)
  local size = self:GetButtonSize()
  local rows = math.ceil(activeCount / cols)
  local totalWidth = (cols * size) + ((cols - 1) * BUTTON_PADDING) + (BAR_PADDING * 2)
  local totalHeight = (rows * size) + ((rows - 1) * BUTTON_PADDING) + (BAR_PADDING * 2)

  self.frame:SetSize(totalWidth, totalHeight)

  for i, btn in ipairs(self.buttons) do
    btn:ClearAllPoints()
    if i <= activeCount then
      local col = (i - 1) % cols
      local row = math.floor((i - 1) / cols)
      local x = BAR_PADDING + (col * (size + BUTTON_PADDING))
      local y = -(BAR_PADDING + (row * (size + BUTTON_PADDING)))
      btn:SetPoint("TOPLEFT", self.frame, "TOPLEFT", x, y)
      btn:SetSize(size, size)
    end
  end
  if BarSmith.MasqueReSkin then
    BarSmith:MasqueReSkin("QuickBar")
  end
end

function QuickBar:IsMouseOverAny()
  if not self.frame or not self.frame:IsShown() then
    return false
  end
  for _, btn in ipairs(self.buttons or {}) do
    if btn:IsShown() and btn:IsMouseOver() then
      return true
    end
  end
  return false
end

function QuickBar:CancelHideTimer()
  if self._hideTimer then
    self._hideTimer:Cancel()
    self._hideTimer = nil
  end
end

function QuickBar:StartHideTimer()
  self:CancelHideTimer()
  if self.previewMode then return end
  if InCombatLockdown() then return end
  self._hideTimer = C_Timer.NewTimer(HIDE_DELAY, function()
    self._hideTimer = nil
    if self.previewMode then
      return
    end
    if InCombatLockdown() then
      return
    end
    if self:IsMouseOverAny() then
      return
    end
    self:Hide()
  end)
end

function QuickBar:MoveToCursor()
  if not self.frame then return end
  local x, y = GetCursorPosition()
  local scale = UIParent:GetEffectiveScale()
  x = x / scale
  y = y / scale
  self.frame:ClearAllPoints()
  self.frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)

  local cfg = self:GetConfig()
  cfg.position = { x = x, y = y }
end

function QuickBar:RestorePosition()
  if not self.frame then return end
  local cfg = self:GetConfig()
  if cfg.position and cfg.position.x and cfg.position.y then
    self.frame:ClearAllPoints()
    self.frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cfg.position.x, cfg.position.y)
  else
    self.frame:ClearAllPoints()
    self.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  end
end

function QuickBar:SetButtonFromData(btn, data)
  local barFrame = BarSmith:GetModule("BarFrame")
  if barFrame and barFrame.SetButtonAction then
    barFrame:SetButtonAction(btn, data, nil, true)
    barFrame:ApplyButtonVisuals(btn, data)
  end
end

function QuickBar:Refresh()
  if not self.frame then return end
  local cfg = self:GetConfig()
  cfg.slots = cfg.slots or {}
  local inCombat = InCombatLockdown()
  if self.previewMode and not inCombat then
    self:UpdateLayout(self:GetPreviewCount())
    self:UpdateBackdropVisibility()
    self:ApplyPreviewButtons()
    return
  end
  local activeCount = self:GetActiveCount()
  if activeCount <= 0 then
    if not inCombat then
      for _, btn in ipairs(self.buttons) do
        btn:Hide()
      end
      self:Hide()
      self:UpdateToggleState()
    end
    return
  end
  for i, btn in ipairs(self.buttons) do
    local data = cfg.slots[i]
    btn.itemData = data
    if data then
      if not inCombat then
        self:SetButtonFromData(btn, data)
        btn:Show()
      end
    else
      if not inCombat then
        btn:SetAttribute("type", nil)
        btn:SetAttribute("spell", nil)
        btn:SetAttribute("item", nil)
        btn:SetAttribute("toy", nil)
        btn:SetAttribute("macrotext", nil)
        btn.icon:SetTexture(nil)
        btn.count:SetText("")
        btn:Hide()
      end
    end
  end
  if not inCombat then
    self:UpdateLayout()
    self:UpdateToggleState()
    self:UpdateCooldowns()
  end
end

function QuickBar:ShowAtCursor()
  if not self.frame then
    self:Init()
  end
  local cfg = self:GetConfig()
  if cfg.enabled == false then
    BarSmith:Print("QuickBar is disabled.")
    return
  end
  if self:GetActiveCount() <= 0 then
    BarSmith:Print("QuickBar is empty. Alt-Left-click an item/spell on the BarSmith bar to add it.")
    return
  end
  if InCombatLockdown() then
    BarSmith:Print("QuickBar toggle is protected in combat. Use the keybind.")
    return
  end
  self.previewMode = false
  self:UpdatePreviewState()
  if self.toggleButton then
    self.toggleButton:SetAttribute("bs_sticky", 0)
  end
  self:MoveToCursor()
  self:UpdateLayout()
  self:UpdateBackdropVisibility()
  self:Refresh()
  self.frame:Show()
  self:StartHideTimer()
end

function QuickBar:Hide()
  if self.frame then
    self:CancelHideTimer()
    if InCombatLockdown() then
      return
    end
    self.frame:Hide()
  end
end

function QuickBar:Toggle()
  local cfg = self:GetConfig()
  if cfg.enabled == false then
    BarSmith:Print("QuickBar is disabled.")
    return
  end
  if InCombatLockdown() then
    BarSmith:Print("QuickBar toggle is protected in combat. Use the keybind.")
    return
  end
  if not self.frame or not self.frame:IsShown() then
    self:ShowAtCursor()
  else
    self:Hide()
  end
end

local function CopyQuickBarData(data)
  if not data then return nil end
  return {
    name = data.name,
    icon = data.icon,
    type = data.type,
    count = data.count,
    itemID = data.itemID,
    spellID = data.spellID,
    toyID = data.toyID,
    slotID = data.slotID,
    macrotext = data.macrotext,
  }
end

local function GetQuickBarKey(data)
  if not data then return nil end
  local key = BarSmith:GetActionIdentityKey(data)
  if key then
    return key
  end
  if data.macrotext then
    return "macrotext:" .. tostring(data.macrotext)
  end
  return nil
end

function QuickBar:SeedDefaultSlots()
  local cfg = self:GetConfig()
  if cfg.seededDefaults then
    return
  end

  cfg.slots = cfg.slots or {}
  if self:GetActiveCount() > 0 then
    cfg.seededDefaults = true
    return
  end

  local defaults = {}

  local function addFirstItem(modName, picker)
    local mod = BarSmith:GetModule(modName)
    if not mod or not mod.GetItems then
      return
    end
    local ok, items = pcall(mod.GetItems, mod)
    if not ok or type(items) ~= "table" or #items == 0 then
      return
    end
    local chosen = picker and picker(items) or items[1]
    if chosen then
      table.insert(defaults, chosen)
    end
  end

  -- Main Hearthstone
  addFirstItem("Hearthstones")

  -- Main Consumable
  addFirstItem("Consumables")

  -- Main Trinket
  addFirstItem("Trinkets")

  -- Main Mount (Random Favorite if available)
  addFirstItem("Mounts", function(items)
    local mountMod = BarSmith:GetModule("Mounts")
    local randomSpellID = mountMod and mountMod.RANDOM_FAVORITE_MOUNT
    if randomSpellID then
      for _, item in ipairs(items) do
        if item.spellID == randomSpellID then
          return item
        end
      end
    end
    return items[1]
  end)

  -- Main Class Spell
  addFirstItem("ClassSpells")

  local function hasKey(key)
    if not key then return false end
    for _, entry in ipairs(cfg.slots) do
      if GetQuickBarKey(entry) == key then
        return true
      end
    end
    return false
  end

  for _, data in ipairs(defaults) do
    local key = GetQuickBarKey(data)
    if not hasKey(key) then
      for i = 1, MAX_QUICKBAR_BUTTONS do
        if not cfg.slots[i] then
          cfg.slots[i] = CopyQuickBarData(data)
          break
        end
      end
    end
  end

  cfg.seededDefaults = true
end

function QuickBar:CompactSlots()
  local cfg = self:GetConfig()
  cfg.slots = cfg.slots or {}
  local compacted = {}
  for i = 1, MAX_QUICKBAR_BUTTONS do
    local entry = cfg.slots[i]
    if entry then
      table.insert(compacted, entry)
    end
  end
  cfg.slots = compacted
end

function QuickBar:ResetDefaults()
  if InCombatLockdown() then
    BarSmith:Print("Cannot reset QuickBar during combat.")
    return
  end
  local cfg = self:GetConfig()
  cfg.slots = {}
  cfg.seededDefaults = false
  self:SeedDefaultSlots()
  self:Refresh()
  BarSmith:Print("QuickBar defaults restored.")
end

function QuickBar:AddFromItemData(data)
  if InCombatLockdown() then
    BarSmith:Print("Cannot modify QuickBar during combat.")
    return
  end
  local cfg = self:GetConfig()
  if cfg.enabled == false then
    BarSmith:Print("QuickBar is disabled.")
    return
  end
  if not data then return end

  cfg.slots = cfg.slots or {}
  local newKey = GetQuickBarKey(data)
  if newKey then
    for _, existing in ipairs(cfg.slots) do
      if GetQuickBarKey(existing) == newKey then
        BarSmith:Print("QuickBar already has: " .. (data.name or "Unknown"))
        return
      end
    end
  end

  for i = 1, MAX_QUICKBAR_BUTTONS do
    if not cfg.slots[i] then
      cfg.slots[i] = CopyQuickBarData(data)
      self:Refresh()
      BarSmith:Print("Added to QuickBar: " .. (data.name or "Unknown"))
      return
    end
  end

  BarSmith:Print("QuickBar is full.")
end

function QuickBar:ClearSlot(index)
  if InCombatLockdown() then
    BarSmith:Print("Cannot modify QuickBar during combat.")
    return
  end
  local cfg = self:GetConfig()
  cfg.slots = cfg.slots or {}
  cfg.slots[index] = nil
  self:CompactSlots()
  self:Refresh()
end

