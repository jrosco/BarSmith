------------------------------------------------------------------------
-- BarSmith: Modules/BarFrame.lua
-- A dedicated floating action bar with SecureActionButton buttons.
-- Completely independent of Blizzard's 8 action bars.
-- Supports items, spells, toys, and trinkets via secure attributes.
-- Draggable in Edit Mode and via unlock. Keybindable via /click.
------------------------------------------------------------------------

local BarFrame = BarSmith:NewModule("BarFrame")

local MAX_FLYOUT_BUTTONS = 12
local VALID_FLYOUT_DIRECTIONS = {
  TOP = true,
  BOTTOM = true,
  LEFT = true,
  RIGHT = true,
}

-- Button size and spacing
local DEFAULT_BUTTON_SIZE = 36
local BUTTON_PADDING = 3
local BAR_PADDING = 4
local FLYOUT_AUTO_CLOSE = 0.5 -- seconds before flyout auto-closes
local AUTO_HIDE_ALPHA = 0
local MOUSE_LEAVE_CHECK_DELAY = 1
local DEFAULT_FONT_SCALE = 36

local function IsSettingsClick(button)
  return button == "RightButton" and IsShiftKeyDown()
end


local function GetConfiguredModuleCount()
  local chardb = BarSmith.chardb
  local priority = (BarSmith.GetExpandedPriority and BarSmith:GetExpandedPriority()) or (chardb and chardb.priority)
  local enabledModules = chardb and chardb.modules
  if type(priority) ~= "table" then
    return 1
  end

  local function isEnabled(modName)
    if modName:match("^consumables_") then
      return enabledModules and enabledModules.consumables == true
    end
    return enabledModules and enabledModules[modName]
  end

  local count = 0
  for _, modName in ipairs(priority) do
    if isEnabled(modName) then
      count = count + 1
    end
  end

  return math.max(1, count)
end

local function ClampPositiveInt(value, fallback)
  local num = tonumber(value)
  if not num then
    return fallback
  end
  return math.max(1, math.floor(num))
end

------------------------------------------------------------------------
-- Create the bar container and all buttons
------------------------------------------------------------------------

function BarFrame:Init()
  if self.frame then return end

  -- Main container frame (not secure, just a visual parent)
  self.frame = CreateFrame("Frame", "BarSmithBarFrame", UIParent, "BackdropTemplate")
  self.frame:SetClampedToScreen(true)
  self.frame:SetFrameStrata("MEDIUM")
  self.frame:SetMovable(true)

  -- Backdrop
  self.frame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  self.frame:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
  self.frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.9)
  self:UpdateBackdropVisibility()

  -- Drag anchor (shown only when unlocked)
  self.dragAnchor = CreateFrame("Frame", "BarSmithDragAnchor", self.frame, "BackdropTemplate")
  self.dragAnchor:SetSize(32, 32)
  self.dragAnchor:SetPoint("BOTTOMLEFT", self.frame, "TOPLEFT", 0, 4)
  self.dragAnchor:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 8,
    edgeSize = 8,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  self.dragAnchor:SetBackdropColor(0.1, 0.8, 0.1, 0.9)
  self.dragAnchor:SetBackdropBorderColor(0.1, 0.5, 0.1, 0.9)
  self.dragAnchor:Hide()

  -- Create the button pool
  self.buttons = {}
  local configuredMax = self:GetMaxButtons()
  for i = 1, configuredMax do
    self.buttons[i] = self:CreateButton(i)
  end
  self.layoutButtonCount = configuredMax

  -- Apply layout
  self:UpdateLayout()

  -- Restore saved position
  self:RestorePosition()

  -- Dragging (only when unlocked)
  self.frame:SetScript("OnDragStart", function(f)
    if not BarSmith.chardb.barLocked then
      f:StartMoving()
    end
  end)
  self.frame:SetScript("OnDragStop", function(f)
    f:StopMovingOrSizing()
    self:SavePosition()
  end)

  self.dragAnchor:SetScript("OnMouseDown", function(_, button)
    if button == "LeftButton" and not BarSmith.chardb.barLocked then
      self.frame:StartMoving()
    end
  end)
  self.dragAnchor:SetScript("OnMouseUp", function(_, button)
    if button == "LeftButton" then
      self.frame:StopMovingOrSizing()
      self:SavePosition()
    end
  end)
  self.dragAnchor:EnableMouse(true)

  -- Shift+Right-click anywhere on the bar to open menu
  self.frame:SetScript("OnMouseUp", function(f, button)
    if IsSettingsClick(button) then
      local settings = BarSmith:GetModule("BarFrameSettings")
      if settings and settings.ToggleIncludeExcludeFrame then
        settings:ToggleIncludeExcludeFrame(f)
      end
    end
  end)
  self.frame:HookScript("OnEnter", function()
    self:NotifyMouseEnter()
  end)
  self.frame:HookScript("OnLeave", function()
    self:NotifyMouseLeave()
  end)

  -- Cooldown update ticker
  self.ticker = C_Timer.NewTicker(0.5, function()
    self:UpdateCooldowns()
  end)

  -- Range check ticker (every 0.2s for color updates)
  self.rangeTicker = C_Timer.NewTicker(0.2, function()
    self:UpdateRangeIndicators()
  end)

  self:UpdateAutoHideState()
  BarSmith:Debug("BarFrame initialized with " .. self:GetMaxButtons() .. " buttons.")

  -- Rebuild bar when settings change (module toggles, split options, etc.)
  BarSmith:RegisterCallback("SETTINGS_CHANGED", self, self.OnSettingsChanged)
  BarSmith:RegisterEvent("UPDATE_BINDINGS", function()
    self:UpdateAllHotkeys()
  end)

  -- Module keybind buttons (hidden, for key bindings)
  self:EnsureModuleButtons()
end

function BarFrame:GetMaxButtons()
  return GetConfiguredModuleCount()
end

function BarFrame:EnsureButtonPoolSize(requiredCount)
  local needed = ClampPositiveInt(requiredCount, 1)
  local current = #(self.buttons or {})
  if current >= needed then
    return
  end

  for i = current + 1, needed do
    self.buttons[i] = self:CreateButton(i)
  end
end

function BarFrame:SetLayoutButtonCount(count)
  self.layoutButtonCount = ClampPositiveInt(count, 1)
end

function BarFrame:GetButtonSize()
  local size = tonumber(BarSmith.chardb and BarSmith.chardb.barIconSize) or DEFAULT_BUTTON_SIZE
  return math.max(24, math.min(64, size))
end

function BarFrame:EnsureModuleButtons()
  if self.moduleButtons then return end

  self.moduleButtons = {}
  local moduleKeys = {
    "questItems",
    "consumables",
    "consumables_potions",
    "consumables_flask",
    "consumables_food",
    "consumables_bandage",
    "consumables_utility",
    "trinkets",
    "classSpells",
    "professions",
    "mounts",
    "hearthstones",
  }

  for _, key in ipairs(moduleKeys) do
    local frameName = "BarSmithModule_" .. key
    local btn = CreateFrame("Button", frameName, UIParent, "SecureActionButtonTemplate")
    btn:Hide()
    self.moduleButtons[key] = btn
  end
end

function BarFrame:GetConfiguredAlpha()
  local alpha = tonumber(BarSmith.chardb and BarSmith.chardb.barAlpha) or 1
  return math.max(0.1, math.min(1, alpha))
end

function BarFrame:UpdateBackdropVisibility()
  if not self.frame then return end

  local showBackdrop = (BarSmith.chardb.barShowBackdrop ~= false)
  if showBackdrop then
    self.frame:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
    self.frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.9)
  else
    -- Keep a tiny non-zero alpha so the frame continues to receive mouse clicks.
    self.frame:SetBackdropColor(0, 0, 0, 0.001)
    self.frame:SetBackdropBorderColor(0, 0, 0, 0.001)
  end
end

function BarFrame:IsAutoHideEnabled()
  return BarSmith.chardb and BarSmith.chardb.barAutoHideMouseover == true
end

function BarFrame:IsAnyBarElementMouseOver()
  if not self.frame or not self.frame:IsShown() then
    return false
  end
  if self.frame:IsMouseOver() then
    return true
  end

  for _, btn in ipairs(self.buttons or {}) do
    if btn:IsShown() and btn:IsMouseOver() then
      return true
    end
    if btn.flyoutOpen then
      for _, childBtn in ipairs(btn.flyoutButtons or {}) do
        if childBtn:IsShown() and childBtn:IsMouseOver() then
          return true
        end
      end
    end
  end

  return false
end

function BarFrame:CancelMouseLeaveCheck()
  if self._mouseLeaveCheckTimer then
    self._mouseLeaveCheckTimer:Cancel()
    self._mouseLeaveCheckTimer = nil
  end
end

function BarFrame:StartMouseLeaveCheck()
  self:CancelMouseLeaveCheck()
  self._mouseLeaveCheckTimer = C_Timer.NewTimer(MOUSE_LEAVE_CHECK_DELAY, function()
    self._mouseLeaveCheckTimer = nil
    self:UpdateAutoHideState()
  end)
end

function BarFrame:NotifyMouseEnter()
  self:CancelMouseLeaveCheck()
  if self.frame then
    self.frame:SetAlpha(1)
  end
end

function BarFrame:NotifyMouseLeave()
  if self:IsAutoHideEnabled() then
    self:StartMouseLeaveCheck()
  elseif self.frame then
    self.frame:SetAlpha(self:GetConfiguredAlpha())
  end
end

function BarFrame:UpdateAutoHideState()
  if not self.frame then return end
  if not self:IsAutoHideEnabled() then
    self.frame:SetAlpha(self:GetConfiguredAlpha())
    return
  end

  if self:IsAnyBarElementMouseOver() then
    self.frame:SetAlpha(self:GetConfiguredAlpha())
  else
    self.frame:SetAlpha(AUTO_HIDE_ALPHA)
  end
end

------------------------------------------------------------------------
-- Create a single secure action button which makes it clickable
------------------------------------------------------------------------

function BarFrame:CreateButton(index)
  local btnName = "BarSmithButton" .. index
  local btn = CreateFrame("Button", btnName, self.frame, "SecureActionButtonTemplate")

  local buttonSize = self:GetButtonSize()
  btn:SetSize(buttonSize, buttonSize)
  btn:RegisterForClicks("AnyUp", "AnyDown")

  -- Custom fields
  btn.index = index
  btn.itemData = nil   -- reference to the BarSmith item data

  -- Pushed/highlight feedback (no normal texture border)
  btn:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
  btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

  -- Icon texture
  btn.icon = btn:CreateTexture(btnName .. "Icon", "BACKGROUND")
  btn.icon:SetAllPoints()
  btn.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)   -- trim default icon border

  -- Cooldown frame (reuse from ActionButtonTemplate if available)
  btn.cooldown = btn.cooldown or CreateFrame("Cooldown", btnName .. "Cooldown", btn, "CooldownFrameTemplate")
  btn.cooldown:SetAllPoints()

  -- Count text (stack count)
  btn.count = btn.count or btn:CreateFontString(btnName .. "Count", "OVERLAY", "NumberFontNormalSmallGray")
  btn.count:SetPoint("BOTTOMRIGHT", -2, 2)
  btn.count:SetText("")

  -- Hotkey text
  btn.hotkey = btn.hotkey or btn:CreateFontString(btnName .. "HotKey", "OVERLAY", "NumberFontNormalSmallGray")
  btn.hotkey:SetPoint("TOPRIGHT", -2, -2)
  btn.hotkey:SetTextColor(1, 0.82, 0)
  btn.hotkey:SetText("")

  -- Border highlight for usability
  btn.border = btn:CreateTexture(btnName .. "Border", "OVERLAY")
  btn.border:SetAllPoints()
  btn.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  btn.border:SetBlendMode("ADD")
  btn.border:SetAlpha(0)

  -- Flyout indicator text (shown when this button represents a group)
  btn.flyoutIndicator = btn:CreateFontString(btnName .. "FlyoutIndicator", "OVERLAY", "GameFontHighlightSmall")
  btn.flyoutIndicator:SetPoint("BOTTOMLEFT", 2, 2)
  btn.flyoutIndicator:SetText("")

  -- Flyout child button pool
  btn.flyoutButtons = {}
  btn.flyoutItems = nil
  btn.flyoutOpen = false
  self:CreateFlyoutButtons(btn)

  -- Tooltip and flyout hover tracking
  btn:SetScript("OnEnter", function(b)
    self:NotifyMouseEnter()
    if b.flyoutOpen then
      self:CancelAutoCloseTimer()
    end
    if b.flyoutItems and #b.flyoutItems > 1 and not b.flyoutOpen then
      self:ShowFlyout(b)
    end
    self:ShowButtonTooltip(b)
  end)
  btn:SetScript("OnLeave", function(b)
    self:NotifyMouseLeave()
    GameTooltip:Hide()
    if b.flyoutOpen then
      self:StartAutoCloseTimer()
    end
  end)
  btn:SetScript("OnReceiveDrag", function(b)
    self:HandleReceiveDrag(b)
  end)

  -- HookScript preserves ActionButtonTemplate's existing OnMouseUp handler
  btn:HookScript("OnMouseUp", function(b, button)
    if IsSettingsClick(button) then
      local settings = BarSmith:GetModule("BarFrameSettings")
      if settings and settings.ToggleIncludeExcludeFrame then
        settings:ToggleIncludeExcludeFrame(b)
      end
      return
    end
  end)
  btn:HookScript("PostClick", function(b, button)
    self:HandleButtonPostClick(b, button)
  end)

  -- Start hidden
  btn:Hide()

  return btn
end

function BarFrame:CreateFlyoutButtons(parentBtn)
  local prefix = parentBtn:GetName() .. "Flyout"
  for i = 1, MAX_FLYOUT_BUTTONS do
    local child = CreateFrame("Button", prefix .. i, self.frame, "SecureActionButtonTemplate")
    local buttonSize = self:GetButtonSize()
    child:SetSize(buttonSize, buttonSize)
    child:RegisterForClicks("AnyUp", "AnyDown")

    child:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    child:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

    child.icon = child:CreateTexture(prefix .. i .. "Icon", "BACKGROUND")
    child.icon:SetAllPoints()
    child.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    child.cooldown = child.cooldown or CreateFrame("Cooldown", prefix .. i .. "Cooldown", child, "CooldownFrameTemplate")
    child.cooldown:SetAllPoints()

    child.count = child.count or child:CreateFontString(prefix .. i .. "Count", "OVERLAY", "NumberFontNormalSmallGray")
    child.count:SetPoint("BOTTOMLEFT", 2, 2)
    child.count:SetText("")

    child.hotkey = child.hotkey or child:CreateFontString(prefix .. i .. "HotKey", "OVERLAY", "NumberFontNormalSmallGray")
    child.hotkey:SetPoint("TOPRIGHT", -2, -2)
    child.hotkey:SetTextColor(1, 0.82, 0)
    child.hotkey:SetText("")

    child.parentButton = parentBtn
    child.itemData = nil

    child:SetScript("OnEnter", function(b)
      self:NotifyMouseEnter()
      self:CancelAutoCloseTimer()
      self:ShowButtonTooltip(b)
    end)
    child:SetScript("OnLeave", function()
      self:NotifyMouseLeave()
      GameTooltip:Hide()
      self:StartAutoCloseTimer()
    end)
    child:SetScript("OnReceiveDrag", function(b)
      self:HandleReceiveDrag(b)
    end)
    child:HookScript("OnMouseUp", function(_, button)
      if IsSettingsClick(button) then
        local settings = BarSmith:GetModule("BarFrameSettings")
        if settings and settings.ToggleIncludeExcludeFrame then
          settings:ToggleIncludeExcludeFrame(parentBtn)
        end
      end
    end)
    child:SetScript("PostClick", function(b, button)
      self:HandleButtonPostClick(b, button)
      self:PromoteChildAsPrimary(b.parentButton, b.itemData)
      -- No timer restart here; OnLeave handles it when mouse actually leaves
    end)

    child:Hide()
    table.insert(parentBtn.flyoutButtons, child)
  end
end

------------------------------------------------------------------------
-- Assign an item/spell/toy/trinket to a button
------------------------------------------------------------------------

function BarFrame:SetButtonAction(btn, data, clickButton)
  -- Reset all action attributes first
  btn:SetAttribute("type", nil)
  btn:SetAttribute("spell", nil)
  btn:SetAttribute("item", nil)
  btn:SetAttribute("toy", nil)
  btn:SetAttribute("macrotext", nil)
  btn:SetAttribute("type1", nil)
  btn:SetAttribute("spell1", nil)
  btn:SetAttribute("item1", nil)
  btn:SetAttribute("toy1", nil)
  btn:SetAttribute("macrotext1", nil)
  btn:SetAttribute("type2", nil)
  btn:SetAttribute("spell2", nil)
  btn:SetAttribute("item2", nil)
  btn:SetAttribute("toy2", nil)
  btn:SetAttribute("alt-type1", nil)
  btn:SetAttribute("alt-macrotext1", nil)
  btn:SetAttribute("shift-type2", nil)
  btn:SetAttribute("shift-macrotext2", nil)
  btn:SetAttribute("macrotext2", nil)
  btn:SetAttribute("alt-type1", nil)
  btn:SetAttribute("alt-macrotext1", nil)
  btn:SetAttribute("shift-type2", nil)
  btn:SetAttribute("shift-macrotext2", nil)

  if not data then
    return
  end

  -- clickButton: nil/"" = any click, "1" = left only, "2" = right only
  local attrPrefix = clickButton or ""

  if data.macrotext then
    btn:SetAttribute("type" .. attrPrefix, "macro")
    btn:SetAttribute("macrotext" .. attrPrefix, data.macrotext)
    -- Reserve modified clicks for menu/exclude without triggering the macro.
    btn:SetAttribute("alt-type1", "macro")
    btn:SetAttribute("alt-macrotext1", "/stopmacro")
    btn:SetAttribute("shift-type2", "macro")
    btn:SetAttribute("shift-macrotext2", "/stopmacro")
    return
  end

  if data.type == "hearthstone_toy" and data.toyID then
    btn:SetAttribute("type" .. attrPrefix, "toy")
    btn:SetAttribute("toy" .. attrPrefix, data.toyID)
  elseif data.type == "trinket" and data.slotID then
    local itemRef = data.name or (data.itemID and ("item:" .. data.itemID))
    if itemRef then
      btn:SetAttribute("type" .. attrPrefix, "item")
      btn:SetAttribute("item" .. attrPrefix, itemRef)
    end
  elseif data.type == "mount" or data.type == "class_spell" or data.type == "profession" then
    btn:SetAttribute("type" .. attrPrefix, "spell")
    btn:SetAttribute("spell" .. attrPrefix, data.name or data.spellID)
  elseif data.type == "quest_item" or data.type == "hearthstone_item"
      or data.type == "engineer_teleport"
      or data.type == "potion"
      or data.type == "flask" or data.type == "food"
      or data.type == "bandage" or data.type == "utility" then
    local itemRef = data.name or (data.itemID and ("item:" .. data.itemID))
    if itemRef then
      btn:SetAttribute("type" .. attrPrefix, "item")
      btn:SetAttribute("item" .. attrPrefix, itemRef)
    end
  end

  -- Reserve modified clicks for menu/exclude without triggering the action.
  btn:SetAttribute("alt-type1", "macro")
  btn:SetAttribute("alt-macrotext1", "/stopmacro")
  btn:SetAttribute("shift-type2", "macro")
  btn:SetAttribute("shift-macrotext2", "/stopmacro")
end

function BarFrame:ApplyButtonVisuals(btn, data)
  if not data then
    btn.icon:SetTexture(nil)
    btn.count:SetText("")
    return
  end

  if data.icon then
    btn.icon:SetTexture(data.icon)
    btn.icon:SetDesaturated(false)
    btn.icon:SetVertexColor(1, 1, 1)
  else
    btn.icon:SetTexture(nil)
  end

  if data.count and data.count > 1 then
    btn.count:SetText(data.count)
  else
    btn.count:SetText("")
  end
end

function BarFrame:UpdateButtonFontSizes()
  local size = self:GetButtonSize()
  local scale = size / DEFAULT_FONT_SCALE
  local countSize = math.max(8, math.floor(10 * scale))
  local hotkeySize = math.max(8, math.floor(10 * scale))

  local function applyFont(fs, fontSize)
    if not fs then return end
    local font, _, flags = fs:GetFont()
    if not font then return end
    fs:SetFont(font, fontSize, flags)
  end

  for _, btn in ipairs(self.buttons or {}) do
    applyFont(btn.count, countSize)
    applyFont(btn.hotkey, hotkeySize)
    for _, child in ipairs(btn.flyoutButtons or {}) do
      applyFont(child.count, countSize)
      applyFont(child.hotkey, hotkeySize)
    end
  end
end

function BarFrame:GetBindingNameForModule(moduleKey)
  if not moduleKey then return nil end
  return "CLICK BarSmithModule_" .. moduleKey .. ":LeftButton"
end

function BarFrame:UpdateButtonHotkey(btn)
  if not btn or not btn.hotkey then return end
  local moduleKey = nil
  if btn.groupData and btn.groupData.module then
    moduleKey = btn.groupData.module
  elseif btn.itemData and btn.itemData.module then
    moduleKey = btn.itemData.module
  end

  if not moduleKey then
    btn.hotkey:SetText("")
    return
  end

  local bindingName = self:GetBindingNameForModule(moduleKey)
  if not bindingName then
    btn.hotkey:SetText("")
    return
  end

  local key1 = GetBindingKey(bindingName)
  if key1 then
    btn.hotkey:SetText(GetBindingText(key1, "KEY_") or key1)
  else
    btn.hotkey:SetText("")
  end
end

function BarFrame:UpdateAllHotkeys()
  for _, btn in ipairs(self.buttons or {}) do
    self:UpdateButtonHotkey(btn)
  end
end

function BarFrame:SetFlyoutItems(btn, children)
  btn.flyoutItems = children
  btn.flyoutOpen = false

  local childCount = children and #children or 0
  if childCount > 1 then
    btn.flyoutIndicator:SetText("+" .. (childCount - 1))
  else
    btn.flyoutIndicator:SetText("")
  end

  for i, childBtn in ipairs(btn.flyoutButtons or {}) do
    local childData = children and children[i]

    childBtn:SetAttribute("type", nil)
    childBtn:SetAttribute("spell", nil)
    childBtn:SetAttribute("item", nil)
    childBtn:SetAttribute("toy", nil)
    childBtn:SetAttribute("type1", nil)
    childBtn:SetAttribute("spell1", nil)
    childBtn:SetAttribute("item1", nil)
    childBtn:SetAttribute("toy1", nil)
    childBtn:SetAttribute("type2", nil)
    childBtn:SetAttribute("spell2", nil)
    childBtn:SetAttribute("item2", nil)
    childBtn:SetAttribute("toy2", nil)
    childBtn.itemData = nil

    if childBtn.cooldown then
      childBtn.cooldown:Clear()
    end

    if childData then
      self:SetButtonAction(childBtn, childData, nil)
      self:ApplyButtonVisuals(childBtn, childData)
      childBtn.itemData = childData
      if childBtn.hotkey then
        childBtn.hotkey:SetText("")
      end
    else
      childBtn.icon:SetTexture(nil)
      childBtn.count:SetText("")
      if childBtn.hotkey then
        childBtn.hotkey:SetText("")
      end
      childBtn:Hide()
    end
  end
end

function BarFrame:StartAutoCloseTimer()
  self:CancelAutoCloseTimer()
  self._flyoutAutoCloseTimer = C_Timer.NewTimer(FLYOUT_AUTO_CLOSE, function()
    self._flyoutAutoCloseTimer = nil
    if not InCombatLockdown() then
      self:HideAllFlyouts()
    end
  end)
end

function BarFrame:CancelAutoCloseTimer()
  if self._flyoutAutoCloseTimer then
    self._flyoutAutoCloseTimer:Cancel()
    self._flyoutAutoCloseTimer = nil
  end
end

function BarFrame:HandleButtonPostClick(btn, button)
  if not btn or not btn.itemData then return end

  -- Group parents use left-click to toggle flyout, not to execute an action.
  if btn.groupData and btn.flyoutItems and #btn.flyoutItems > 1 and button == "LeftButton" then
    return
  end

  if button == "LeftButton" and IsAltKeyDown and IsAltKeyDown() then
    if InCombatLockdown() then
    BarSmith:Print("Cannot exclude during combat.")
      return
    end
    BarSmith:AddToExclude(btn.itemData)
    BarSmith:Print("Excluded: " .. (btn.itemData.name or "Unknown"))
    BarSmith:RunAutoFill(true)
    return
  end

  local moduleName = btn.itemData.module or (btn.groupData and btn.groupData.module)
  if moduleName then
    BarSmith:SetLastUsedForModule(moduleName, btn.itemData)
  end
end

------------------------------------------------------------------------
-- Drag & drop support for consumable includes
------------------------------------------------------------------------

function BarFrame:HandleReceiveDrag()
  if InCombatLockdown() then
    BarSmith:Print("Cannot add includes during combat.")
    ClearCursor()
    return
  end

  local cursorType, id, subType, spellID = GetCursorInfo()
  if not cursorType or not id then
    ClearCursor()
    return
  end

  if cursorType == "item" then
    BarSmith:RemoveFromExcludeForItemID(id)
    local con = BarSmith:GetModule("Consumables")
    if con and con:AddExtraItem(id) then
      BarSmith:RunAutoFill(true)
    end
  elseif cursorType == "mount" then
    local _, spellID = C_MountJournal.GetMountInfoByID(id)
    BarSmith:RemoveFromExcludeForSpellID(spellID)
    local mounts = BarSmith:GetModule("Mounts")
    if mounts and mounts:AddExtraMount(id) then
      BarSmith:RunAutoFill(true)
    end
  elseif cursorType == "spell" then
    local resolvedSpellID = spellID or id
    BarSmith:RemoveFromExcludeForSpellID(resolvedSpellID)
    local classSpells = BarSmith:GetModule("ClassSpells")
    if classSpells and classSpells:AddCustomSpell(resolvedSpellID) then
      BarSmith:RunAutoFill(true)
    end
  end
  ClearCursor()
end

-- When a flyout child button is clicked, promote that child to be the new primary for the parent group.
function BarFrame:PromoteChildAsPrimary(parentBtn, childData)
  if not parentBtn or not childData then return end
  if not parentBtn.groupData or not parentBtn.flyoutItems or #parentBtn.flyoutItems <= 1 then
    return
  end

  local moduleName = parentBtn.groupData.module
  if moduleName then
    self:SetModuleButton(moduleName, childData)
  end

  -- Keep the last-used child at the top of the flyout list.
  -- Delay this until after the click processing finishes.
  C_Timer.After(0.2, function()
    if not parentBtn or not parentBtn.flyoutItems then return end
    for i, entry in ipairs(parentBtn.flyoutItems) do
      if entry == childData then
        if i > 1 then
          table.remove(parentBtn.flyoutItems, i)
          table.insert(parentBtn.flyoutItems, 1, entry)
        end
        break
      end
    end
    self:SetFlyoutItems(parentBtn, parentBtn.flyoutItems)
  end)

  parentBtn.groupData.primary = childData
  parentBtn.groupData.icon = childData.icon
  parentBtn.groupData.itemID = childData.itemID
  parentBtn.groupData.spellID = childData.spellID
  parentBtn.groupData.toyID = childData.toyID

  parentBtn.itemData = childData
  self:SetButtonAction(parentBtn, childData, "2")
  self:ApplyButtonVisuals(parentBtn, childData)
end

function BarFrame:GetFlyoutDirection()
  local direction = string.upper(tostring(BarSmith.chardb.flyoutDirection or "TOP"))
  if not VALID_FLYOUT_DIRECTIONS[direction] then
    return "TOP"
  end
  return direction
end

function BarFrame:ShowFlyout(btn)
  if InCombatLockdown() then return end
  if not btn.flyoutItems or #btn.flyoutItems <= 1 then return end

  self:HideAllFlyouts(btn)
  btn.flyoutOpen = true

  -- Raise flyout children above all main buttons so they receive clicks
  local topLevel = self.frame:GetFrameLevel() + 50
  local direction = self:GetFlyoutDirection()
  local buttonSize = self:GetButtonSize()

  for i, childBtn in ipairs(btn.flyoutButtons or {}) do
    local childData = btn.flyoutItems[i]
    if childData then
      local offset = BUTTON_PADDING + ((i - 1) * (buttonSize + BUTTON_PADDING))
      childBtn:SetFrameLevel(topLevel + i)
      childBtn:ClearAllPoints()
      if direction == "TOP" then
        childBtn:SetPoint("BOTTOM", btn, "TOP", 0, offset)
      elseif direction == "BOTTOM" then
        childBtn:SetPoint("TOP", btn, "BOTTOM", 0, -offset)
      elseif direction == "LEFT" then
        childBtn:SetPoint("RIGHT", btn, "LEFT", -offset, 0)
      else       -- RIGHT
        childBtn:SetPoint("LEFT", btn, "RIGHT", offset, 0)
      end
      childBtn:SetSize(buttonSize, buttonSize)
      childBtn:Show()
    else
      childBtn:Hide()
    end
  end
end

function BarFrame:HideFlyout(btn)
  if not btn then return end
  btn.flyoutOpen = false
  self:CancelAutoCloseTimer()
  for _, childBtn in ipairs(btn.flyoutButtons or {}) do
    childBtn:Hide()
  end
end

function BarFrame:HideAllFlyouts(exceptBtn)
  for _, button in ipairs(self.buttons or {}) do
    if button ~= exceptBtn then
      self:HideFlyout(button)
    end
  end
end

function BarFrame:ToggleFlyout(btn)
  if InCombatLockdown() then return end
  if btn.flyoutOpen then
    self:HideFlyout(btn)
  else
    self:ShowFlyout(btn)
  end
end

function BarFrame:SetButton(index, itemData)
  local btn = self.buttons[index]
  if not btn then return end

  -- Cannot change secure attributes in combat
  if InCombatLockdown() then
    BarSmith:Debug("Cannot update button " .. index .. " in combat.")
    return false
  end

  -- Clear previous state
  self:ClearButton(index)

  if not itemData then
    btn:Hide()
    return true
  end

  local actionData = itemData
  if itemData.isFlyoutGroup and itemData.primary then
    actionData = itemData.primary
    btn.groupData = itemData
    self:SetFlyoutItems(btn, itemData.children or {})
    self:SetButtonAction(btn, actionData, nil)
  else
    btn.groupData = nil
    self:SetFlyoutItems(btn, nil)
    self:SetButtonAction(btn, actionData, nil)
  end

  btn.itemData = actionData
  self:ApplyButtonVisuals(btn, actionData)
  self:UpdateButtonHotkey(btn)

  btn:Show()
  return true
end

function BarFrame:SetModuleButtons(modulePrimary)
  if not self.moduleButtons then
    self:EnsureModuleButtons()
  end
  if not self.moduleButtons then return end

  for key, btn in pairs(self.moduleButtons) do
    local data = modulePrimary and modulePrimary[key] or nil
    self:SetButtonAction(btn, data, nil)
  end
end

function BarFrame:SetModuleButton(moduleKey, data)
  if not moduleKey then return end
  if not self.moduleButtons then
    self:EnsureModuleButtons()
  end
  if not self.moduleButtons then return end
  local btn = self.moduleButtons[moduleKey]
  if not btn then return end
  self:SetButtonAction(btn, data, nil)
end

------------------------------------------------------------------------
-- Clear a button's secure attributes and visuals
------------------------------------------------------------------------

function BarFrame:ClearButton(index)
  local btn = self.buttons[index]
  if not btn then return end
  if InCombatLockdown() then return end

  btn:SetAttribute("type", nil)
  btn:SetAttribute("spell", nil)
  btn:SetAttribute("item", nil)
  btn:SetAttribute("toy", nil)
  btn:SetAttribute("type1", nil)
  btn:SetAttribute("spell1", nil)
  btn:SetAttribute("item1", nil)
  btn:SetAttribute("toy1", nil)
  btn:SetAttribute("type2", nil)
  btn:SetAttribute("spell2", nil)
  btn:SetAttribute("item2", nil)
  btn:SetAttribute("toy2", nil)

  btn.icon:SetTexture(nil)
  btn.count:SetText("")
  if btn.hotkey then
    btn.hotkey:SetText("")
  end
  btn.flyoutIndicator:SetText("")
  btn.border:SetAlpha(0)
  btn.itemData = nil
  btn.groupData = nil
  btn.flyoutItems = nil
  self:HideFlyout(btn)

  if btn.cooldown then
    btn.cooldown:Clear()
  end

  btn:Hide()
end

------------------------------------------------------------------------
-- Clear all buttons
------------------------------------------------------------------------

function BarFrame:ClearAll()
  if InCombatLockdown() then return end
  for i = 1, #self.buttons do
    self:ClearButton(i)
  end
end

------------------------------------------------------------------------
-- Update layout (horizontal / vertical, button count)
------------------------------------------------------------------------

function BarFrame:UpdateLayout()
  if not self.frame then return end
  self:HideAllFlyouts()

  local maxButtons = self:GetMaxButtons()
  self:EnsureButtonPoolSize(maxButtons)

  local layoutCount = ClampPositiveInt(self.layoutButtonCount, maxButtons)
  layoutCount = math.min(layoutCount, maxButtons, #(self.buttons or {}))

  local columns = math.max(1, math.min(BarSmith.chardb.barColumns or layoutCount, layoutCount))
  local buttonSize = self:GetButtonSize()
  local rows = math.ceil(layoutCount / columns)
  local totalWidth = (columns * buttonSize) + ((columns - 1) * BUTTON_PADDING) + (BAR_PADDING * 2)
  local totalHeight = (rows * buttonSize) + ((rows - 1) * BUTTON_PADDING) + (BAR_PADDING * 2)

  self.frame:SetSize(totalWidth, totalHeight)

  -- Enable drag if unlocked
  if BarSmith.chardb.barLocked then
    self.frame:EnableMouse(false)
    self.frame:RegisterForDrag()
    if self.dragAnchor then
      self.dragAnchor:Hide()
    end
  else
    self.frame:EnableMouse(true)
    self.frame:RegisterForDrag("LeftButton")
    if self.dragAnchor then
      self.dragAnchor:Show()
    end
  end

  -- Position each button in a grid
  for i, btn in ipairs(self.buttons) do
    btn:ClearAllPoints()
    local col = (i - 1) % columns
    local row = math.floor((i - 1) / columns)
    local x = BAR_PADDING + (col * (buttonSize + BUTTON_PADDING))
    local y = -(BAR_PADDING + (row * (buttonSize + BUTTON_PADDING)))
    btn:SetPoint("TOPLEFT", self.frame, "TOPLEFT", x, y)
    btn:SetSize(buttonSize, buttonSize)
  end

  self:UpdateButtonFontSizes()
  self:UpdateAutoHideState()
end

------------------------------------------------------------------------
-- Rebuild on settings changes
------------------------------------------------------------------------

function BarFrame:Rebuild()
  if InCombatLockdown() then
    BarSmith.pendingFill = true
    BarSmith.pendingFillForce = true
    return
  end

  if not self.frame then
    self:Init()
  end

  local maxButtons = self:GetMaxButtons()
  if self.lastMaxButtons and BarSmith.chardb and BarSmith.chardb.barColumns then
    if BarSmith.chardb.barColumns >= self.lastMaxButtons then
      BarSmith.chardb.barColumns = maxButtons
    end
  end
  self.lastMaxButtons = maxButtons
  self:EnsureButtonPoolSize(maxButtons)
  self:SetLayoutButtonCount(maxButtons)
  self:UpdateLayout()

  BarSmith:RunAutoFill(true)
end

function BarFrame:OnSettingsChanged()
  self:Rebuild()
end

------------------------------------------------------------------------
-- Update cooldown spinners on all visible buttons
------------------------------------------------------------------------

function BarFrame:UpdateCooldowns()
  local function updateButtonCooldown(btn)
    if not btn:IsShown() or not btn.itemData then return end

    local start, duration, enable = 0, 0, 1
    local data = btn.itemData

    if data.spellID then
      local info = C_Spell.GetSpellCooldown(data.spellID)
      if info then
        start = info.startTime or 0
        duration = info.duration or 0
        enable = info.isEnabled and 1 or 0
      end
    elseif data.itemID then
      start, duration, enable = C_Item.GetItemCooldown(data.itemID)
    elseif data.toyID then
      start, duration, enable = C_Item.GetItemCooldown(data.toyID)
    end

    if btn.cooldown and duration and duration > 0 then
      CooldownFrame_Set(btn.cooldown, start, duration, enable)
    elseif btn.cooldown then
      btn.cooldown:Clear()
    end
  end

  for _, btn in ipairs(self.buttons) do
    updateButtonCooldown(btn)
    if btn.flyoutOpen then
      for _, childBtn in ipairs(btn.flyoutButtons or {}) do
        updateButtonCooldown(childBtn)
      end
    end
  end
end

------------------------------------------------------------------------
-- Update range indicators (desaturate icon if out of range)
------------------------------------------------------------------------

function BarFrame:UpdateRangeIndicators()
  local function updateRange(btn)
    if not btn:IsShown() or not btn.itemData then return end

    local data = btn.itemData
    local inRange = true

    if data.spellID and IsSpellInRange then
      local rangeResult = IsSpellInRange(data.spellID, "target")
      if rangeResult == 0 then
        inRange = false
      end
    elseif data.itemID and IsItemInRange then
      local rangeResult = IsItemInRange(data.itemID, "target")
      if rangeResult == false then
        inRange = false
      end
    end

    if btn.icon then
      btn.icon:SetDesaturated(not inRange)
      if inRange then
        btn.icon:SetVertexColor(1, 1, 1)
      else
        btn.icon:SetVertexColor(0.6, 0.6, 0.6)
      end
    end
  end

  for _, btn in ipairs(self.buttons) do
    updateRange(btn)
    if btn.flyoutOpen then
      for _, childBtn in ipairs(btn.flyoutButtons or {}) do
        updateRange(childBtn)
      end
    end
  end
end

------------------------------------------------------------------------
-- Tooltip
------------------------------------------------------------------------

function BarFrame:ShowButtonTooltip(btn)
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
    hearthstone_item = { label = "Hearthstone", color = { 0.9, 0.6, 0.2 } },
    hearthstone_toy = { label = "Hearthstone (Toy)", color = { 0.9, 0.6, 0.2 } },
    engineer_teleport = { label = "Engineer Teleport", color = { 0.6, 0.9, 0.9 } },
    profession = { label = "Profession", color = { 0.8, 0.8, 1.0 } },
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
    GameTooltip:AddLine("|cff33ccff[BarSmith]|r " .. typeLabel, r, g, b)
  else
    GameTooltip:AddLine("|cff33ccff[BarSmith]|r", 0.5, 0.5, 0.5)
  end
  if btn.flyoutItems and #btn.flyoutItems > 1 then
    GameTooltip:AddLine("Shift-Right-click to open menu", 0.8, 0.8, 0.8)
    -- local groupLabel = (btn.groupData and btn.groupData.name) or (#btn.flyoutItems .. " items")
    -- GameTooltip:AddLine(groupLabel, 0.8, 0.8, 0.8)
  end
  GameTooltip:AddLine("Alt-Left-click to exclude", 0.8, 0.8, 0.8)
  GameTooltip:AddLine("Drag a consumable, mount, or spell to include (clears exclude)", 0.8, 0.8, 0.8)
  GameTooltip:Show()
end

------------------------------------------------------------------------
-- Position save/restore
------------------------------------------------------------------------

function BarFrame:SavePosition()
  if not self.frame then return end
  local point, _, relPoint, x, y = self.frame:GetPoint()
  BarSmith.chardb.barPosition = {
    point = point,
    relPoint = relPoint,
    x = x,
    y = y,
  }
end

function BarFrame:RestorePosition()
  if not self.frame then return end
  local pos = BarSmith.chardb.barPosition
  if pos and pos.point then
    self.frame:ClearAllPoints()
    self.frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
  else
    -- Default: bottom center, above the main bar
    self.frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 180)
  end
end

------------------------------------------------------------------------
-- Show / Hide
------------------------------------------------------------------------

function BarFrame:Show()
  if self.frame then
    self.frame:Show()
    self:UpdateAutoHideState()
  end
end

function BarFrame:Hide()
  if self.frame then
    self:CancelMouseLeaveCheck()
    self:HideAllFlyouts()
    self.frame:Hide()
  end
end

function BarFrame:IsVisible()
  return self.frame and self.frame:IsShown()
end

------------------------------------------------------------------------
-- Lock / Unlock bar movement
------------------------------------------------------------------------

function BarFrame:SetLocked(locked)
  if not BarSmith.chardb then return end
  if not locked then
    if BarSmith.chardb._autoHideBeforeUnlock == nil then
      BarSmith.chardb._autoHideBeforeUnlock = BarSmith.chardb.barAutoHideMouseover
    end
    BarSmith.chardb.barAutoHideMouseover = false
  elseif BarSmith.chardb._autoHideBeforeUnlock ~= nil then
    BarSmith.chardb.barAutoHideMouseover = BarSmith.chardb._autoHideBeforeUnlock
    BarSmith.chardb._autoHideBeforeUnlock = nil
  end
  BarSmith.chardb.barLocked = locked
  self:UpdateLayout()
  self:UpdateAutoHideState()

  if locked then
    BarSmith:Print("Bar locked.")
  else
    BarSmith:Print("Bar unlocked. Drag to reposition, shift-right-click for menu.")
  end
end

------------------------------------------------------------------------
-- Get the number of active (visible) buttons
------------------------------------------------------------------------

function BarFrame:GetActiveCount()
  local count = 0
  for _, btn in ipairs(self.buttons) do
    if btn:IsShown() then
      count = count + 1
    end
  end
  return count
end
