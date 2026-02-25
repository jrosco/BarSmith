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
local PIN_ICON_ATLAS = "Waypoint-MapPin-Minimap-Tracked"
local PIN_ICON_SCALE = 0.4
local PIN_ICON_MIN_SIZE = 8
local PIN_ICON_MAX_SIZE = 0 -- 0 disables max clamp
local PIN_ICON_INSET_SCALE = 0.05
local PIN_ICON_MIN_INSET = 0
local PIN_ICON_OFFSET_X = -2
local PIN_ICON_OFFSET_Y = 2
local PIN_ICON_ALPHA = 0.8
local OVERLAY_ICON_SCALE = 0.5
local OVERLAY_ICON_MIN_SIZE = 10
local OVERLAY_ICON_MAX_SIZE = 0 -- 0 disables max clamp
local OVERLAY_ICON_OFFSET_X = 0
local OVERLAY_ICON_OFFSET_Y = 0
local OVERLAY_ICON_ALPHA = 1
-- Per-item overlay usage (optional):
-- data.overlay = {
--   atlas = "AtlasName", -- required to show
--   texture = 123456,   -- fileID or path (optional alternative to atlas)
--   scale = 0.35,        -- relative to button size (optional)
--   size = 14,           -- absolute size (optional, overrides scale)
--   minSize = 8,         -- clamp minimum (optional)
--   maxSize = 0,         -- clamp maximum; 0 disables max (optional)
--   offsetX = 0,         -- center offset (optional)
--   offsetY = 0,
--   alpha = 0.9,         -- opacity (optional)
-- }
-- data.overlayAtlas = "AtlasName" still works as a simple shorthand.

local FLYOUT_AUTO_CLOSE = 0.5 -- seconds before flyout auto-closes
local AUTO_HIDE_ALPHA = 0
local MOUSE_LEAVE_CHECK_DELAY = 1
local DEFAULT_FONT_SCALE = 36
local HOVER_HIT_INSET = BUTTON_PADDING
local TOOLTIP_ICON = "|TInterface\\AddOns\\BarSmith\\Textures\\bs:14:14:0:0|t"
local TOOLTIP_TITLE_COLOR = "|cff33ccff"
local TOOLTIP_ACTION_MENU_COLOR = "|cffdddddd"
local TOOLTIP_ACTION_ADD_COLOR = "|cff7fd9ff"
local TOOLTIP_ACTION_PIN_COLOR = "|cffb7a6ff"
local TOOLTIP_ACTION_REMOVE_COLOR = "|cffff9a9a"
local TOOLTIP_SHORTCUT_COLOR = "|cffffffff"
local TOOLTIP_NOTE_COLOR = "|cffb3b3b3"
local FLYOUT_SECURE_SHOW = [[
  local count = self:GetAttribute("bs_flyout_count") or 0
  if count <= 1 then return end
  for i = 1, count do
    local child = self:GetFrameRef("bs_flyout" .. i)
    if child then
      child:Show()
    end
  end
]]
local FLYOUT_SECURE_HIDE = [[
  local count = self:GetAttribute("bs_flyout_count") or 0
  if count <= 1 then return end
  if self:IsUnderMouse(true) then return end
  for i = 1, count do
    local child = self:GetFrameRef("bs_flyout" .. i)
    if child and child:IsUnderMouse(true) then return end
  end
  for i = 1, count do
    local child = self:GetFrameRef("bs_flyout" .. i)
    if child then
      child:Hide()
    end
  end
]]
local FLYOUT_SECURE_SHOW_CHILD = [[
  local owner = control
  local count = owner:GetAttribute("bs_flyout_count") or 0
  if count <= 1 then return end
  for i = 1, count do
    local child = owner:GetFrameRef("bs_flyout" .. i)
    if child then
      child:Show()
    end
  end
]]
local FLYOUT_SECURE_HIDE_CHILD = [[
  local owner = control
  local count = owner:GetAttribute("bs_flyout_count") or 0
  if count <= 1 then return end
  if owner:IsUnderMouse(true) then return end
  for i = 1, count do
    local child = owner:GetFrameRef("bs_flyout" .. i)
    if child and child:IsUnderMouse(true) then return end
  end
  for i = 1, count do
    local child = owner:GetFrameRef("bs_flyout" .. i)
    if child then
      child:Hide()
    end
  end
]]

local function IsSettingsClick(button)
  return button == "RightButton" and IsShiftKeyDown() and not IsControlKeyDown() and not IsAltKeyDown()
end

local function IsQuickBarAddClick(button)
  return button == "LeftButton" and IsAltKeyDown()
end

local function IsExcludeRemoveClick(button)
  return button == "RightButton" and IsShiftKeyDown() and IsControlKeyDown()
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
  self.frame:SetFrameStrata("DIALOG")
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

  -- Allow dropping icon anywhere on the bar frame
  self.frame:SetScript("OnReceiveDrag", function()
    self:HandleReceiveDrag(nil)
  end)

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
  self.secureFlyoutHover = true
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
    local quickBar = BarSmith:GetModule("QuickBar")
    if quickBar and quickBar.UpdateKeybindOverrides then
      quickBar:UpdateKeybindOverrides()
    end
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
    "macros",
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
  local btn = CreateFrame("Button", btnName, self.frame, "SecureActionButtonTemplate,SecureHandlerEnterLeaveTemplate")

  local buttonSize = self:GetButtonSize()
  btn:SetSize(buttonSize, buttonSize)
  btn:RegisterForClicks("AnyUp", "AnyDown")
  btn:SetHitRectInsets(-HOVER_HIT_INSET, -HOVER_HIT_INSET, -HOVER_HIT_INSET, -HOVER_HIT_INSET)

  -- Custom fields
  btn.index = index
  btn.itemData = nil   -- reference to the BarSmith item data
  btn.overlayConfig = nil

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

  -- Pinned indicator
  btn.pinIcon = btn.pinIcon or btn:CreateTexture(btnName .. "Pin", "OVERLAY")
  btn.pinIcon:SetPoint("TOPLEFT", 0, 0)
  btn.pinIcon:SetDrawLayer("OVERLAY", 7)
  btn.pinIcon:SetAlpha(PIN_ICON_ALPHA)
  btn.pinIcon:Hide()
  self:ApplyPinIconStyle(btn)

  -- Overlay indicator (e.g. faction crest)
  btn.overlayIcon = btn.overlayIcon or btn:CreateTexture(btnName .. "Overlay", "OVERLAY")
  btn.overlayIcon:SetDrawLayer("OVERLAY", 6)
  btn.overlayIcon:SetAlpha(OVERLAY_ICON_ALPHA)
  btn.overlayIcon:Hide()
  self:ApplyOverlayIconStyle(btn)

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

  if BarSmith.MasqueAddButton then

    BarSmith:MasqueAddButton(btn)

  end

  -- Flyout child button pool
  btn.flyoutButtons = {}
  btn.flyoutItems = nil
  btn.flyoutOpen = false
  self:CreateFlyoutButtons(btn)

  btn:SetAttribute("bs_flyout_count", 0)

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

  SecureHandlerWrapScript(btn, "OnEnter", btn, FLYOUT_SECURE_SHOW)
  SecureHandlerWrapScript(btn, "OnLeave", btn, FLYOUT_SECURE_HIDE)

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
    if IsQuickBarAddClick(button) then
      return
    end
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
    child:SetHitRectInsets(-HOVER_HIT_INSET, -HOVER_HIT_INSET, -HOVER_HIT_INSET, -HOVER_HIT_INSET)

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

    child.overlayIcon = child.overlayIcon or child:CreateTexture(prefix .. i .. "Overlay", "OVERLAY")
    child.overlayIcon:SetDrawLayer("OVERLAY", 6)
    child.overlayIcon:SetAlpha(OVERLAY_ICON_ALPHA)
    child.overlayIcon:Hide()
    self:ApplyOverlayIconStyle(child)

    child.parentButton = parentBtn
    child.itemData = nil
    child.overlayConfig = nil

    if BarSmith.MasqueAddButton then

      BarSmith:MasqueAddButton(child)

    end

    child:SetScript("OnEnter", function(b)
      self:NotifyMouseEnter()
      self:CancelAutoCloseTimer()
      self:ShowButtonTooltip(b, true)
    end)
    child:SetScript("OnLeave", function()
      self:NotifyMouseLeave()
      GameTooltip:Hide()
      self:StartAutoCloseTimer()
    end)
    child:SetScript("OnReceiveDrag", function(b)
      self:HandleReceiveDrag(b)
    end)
    child:HookScript("OnMouseUp", function(b, button)
      if IsExcludeRemoveClick(button) then
        return
      end
      if button == "LeftButton" and IsControlKeyDown() then
        self:TogglePinnedForButton(b)
        return
      end
      if IsQuickBarAddClick(button) and b and b.itemData then
        local quickBar = BarSmith:GetModule("QuickBar")
        if quickBar and quickBar.AddFromItemData then
          quickBar:AddFromItemData(b.itemData)
        end
      end
    end)
    child:SetScript("PostClick", function(b, button)
      if IsQuickBarAddClick(button) then
        return
      end
      self:HandleButtonPostClick(b, button)
      if not (button == "LeftButton" and IsControlKeyDown()) then
        local moduleName = b.itemData and b.itemData.module
        local pinned = moduleName and BarSmith:GetPinnedForModule(moduleName)
        if not pinned or BarSmith:GetActionIdentityKey(b.itemData) == pinned then
          self:PromoteChildAsPrimary(b.parentButton, b.itemData)
        end
      end
      -- No timer restart here; OnLeave handles it when mouse actually leaves
    end)

    SecureHandlerWrapScript(child, "OnEnter", parentBtn, FLYOUT_SECURE_SHOW_CHILD)
    SecureHandlerWrapScript(child, "OnLeave", parentBtn, FLYOUT_SECURE_HIDE_CHILD)
    parentBtn:SetFrameRef("bs_flyout" .. i, child)
    child:Hide()
    table.insert(parentBtn.flyoutButtons, child)
  end
end

------------------------------------------------------------------------
-- Assign an item/spell/toy/trinket to a button
------------------------------------------------------------------------

function BarFrame:SetButtonAction(btn, data, clickButton, allowRightClick)
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
  btn:SetAttribute("alt-type", nil)
  btn:SetAttribute("alt-macrotext", nil)
  btn:SetAttribute("alt-type1", nil)
  btn:SetAttribute("alt-macrotext1", nil)
  btn:SetAttribute("shift-type2", nil)
  btn:SetAttribute("shift-macrotext2", nil)
  btn:SetAttribute("alt-type2", nil)
  btn:SetAttribute("alt-macrotext2", nil)
  btn:SetAttribute("ctrl-type", nil)
  btn:SetAttribute("ctrl-macrotext", nil)
  btn:SetAttribute("ctrl-type1", nil)
  btn:SetAttribute("ctrl-macrotext1", nil)
  btn:SetAttribute("ctrl-type2", nil)
  btn:SetAttribute("ctrl-macrotext2", nil)
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
  local allowRight = allowRightClick == true

  local function setAction(prefix)
    if data.macrotext then
      btn:SetAttribute("type" .. prefix, "macro")
      btn:SetAttribute("macrotext" .. prefix, data.macrotext)
      return true
    end

    if data.type == "hearthstone_toy" and data.toyID then
      btn:SetAttribute("type" .. prefix, "toy")
      btn:SetAttribute("toy" .. prefix, data.toyID)
      return true
    elseif data.type == "trinket" and data.slotID then
      local itemRef = data.name or (data.itemID and ("item:" .. data.itemID))
      if itemRef then
        btn:SetAttribute("type" .. prefix, "item")
        btn:SetAttribute("item" .. prefix, itemRef)
        return true
      end
    elseif data.type == "mount" or data.type == "class_spell" or data.type == "profession" then
      btn:SetAttribute("type" .. prefix, "spell")
      btn:SetAttribute("spell" .. prefix, data.name or data.spellID)
      return true
    elseif data.type == "quest_item" or data.type == "hearthstone_item"
        or data.type == "engineer_teleport"
        or data.type == "potion"
        or data.type == "flask" or data.type == "food"
        or data.type == "bandage" or data.type == "utility" then
      local itemRef = data.name or (data.itemID and ("item:" .. data.itemID))
      if itemRef then
        btn:SetAttribute("type" .. prefix, "item")
        btn:SetAttribute("item" .. prefix, itemRef)
        return true
      end
    end
    return false
  end

  setAction(attrPrefix)

  -- Reserve or mirror right-click behavior.
  if allowRight and attrPrefix == "" then
    setAction("2")
  elseif not allowRight and attrPrefix ~= "2" then
    btn:SetAttribute("type2", "macro")
    btn:SetAttribute("macrotext2", "/stopmacro")
  end

  -- Reserve modified clicks for menu/exclude without triggering the action.
  btn:SetAttribute("alt-type", "macro")
  btn:SetAttribute("alt-macrotext", "/stopmacro")
  btn:SetAttribute("alt-type1", "macro")
  btn:SetAttribute("alt-macrotext1", "/stopmacro")
  btn:SetAttribute("alt-type2", "macro")
  btn:SetAttribute("alt-macrotext2", "/stopmacro")
  btn:SetAttribute("shift-type2", "macro")
  btn:SetAttribute("shift-macrotext2", "/stopmacro")
  btn:SetAttribute("ctrl-type", "macro")
  btn:SetAttribute("ctrl-macrotext", "/stopmacro")
  btn:SetAttribute("ctrl-type1", "macro")
  btn:SetAttribute("ctrl-macrotext1", "/stopmacro")
  btn:SetAttribute("ctrl-type2", "macro")
  btn:SetAttribute("ctrl-macrotext2", "/stopmacro")
end

function BarFrame:ApplyButtonVisuals(btn, data)
  if not data then
    btn.icon:SetTexture(nil)
    if btn.icon.SetAtlas then
      btn.icon:SetAtlas(nil)
    end
    btn.count:SetText("")
    btn.overlayConfig = nil
    if btn.overlayIcon then
      btn.overlayIcon:SetTexture(nil)
      if btn.overlayIcon.SetAtlas then
        btn.overlayIcon:SetAtlas(nil)
      end
      btn.overlayIcon:Hide()
    end
    return
  end

  if data.iconAtlas and btn.icon.SetAtlas then
    btn.icon:SetAtlas(data.iconAtlas, true)
    btn.icon:SetDesaturated(false)
    btn.icon:SetVertexColor(1, 1, 1)
  elseif data.icon then
    btn.icon:SetTexture(data.icon)
    btn.icon:SetDesaturated(false)
    btn.icon:SetVertexColor(1, 1, 1)
  else
    btn.icon:SetTexture(nil)
    if btn.icon.SetAtlas then
      btn.icon:SetAtlas(nil)
    end
  end

  if data.count and data.count > 1 then
    btn.count:SetText(data.count)
  else
    btn.count:SetText("")
  end

  local overlay = nil
  if type(data.overlay) == "table" then
    overlay = data.overlay
  elseif data.overlayAtlas then
    overlay = { atlas = data.overlayAtlas }
  end
  btn.overlayConfig = overlay

  if btn.overlayIcon then
    if overlay and overlay.atlas and btn.overlayIcon.SetAtlas then
      btn.overlayIcon:SetAtlas(overlay.atlas, true)
      btn.overlayIcon:SetDesaturated(false)
      btn.overlayIcon:SetVertexColor(1, 1, 1)
      btn.overlayIcon:Show()
    else
      btn.overlayIcon:SetTexture(nil)
      if btn.overlayIcon.SetAtlas then
        btn.overlayIcon:SetAtlas(nil)
      end
      btn.overlayIcon:Hide()
    end
  end
  self:ApplyOverlayIconStyle(btn)
end

function BarFrame:UpdateButtonPinnedIndicator(btn)
  if not btn or not btn.pinIcon then return end
  self:ApplyPinIconStyle(btn)
  local moduleKey = nil
  if btn.groupData and btn.groupData.module then
    moduleKey = btn.groupData.module
  elseif btn.itemData and btn.itemData.module then
    moduleKey = btn.itemData.module
  end
  if not moduleKey then
    btn.pinIcon:Hide()
    return
  end
  local pinned = BarSmith:GetPinnedForModule(moduleKey)
  if pinned then
    btn.pinIcon:Show()
  else
    btn.pinIcon:Hide()
  end
end

function BarFrame:ApplyPinIconStyle(btn)
  if not btn or not btn.pinIcon then return end
  local baseSize = (btn.GetWidth and btn:GetWidth()) or self:GetButtonSize() or DEFAULT_BUTTON_SIZE
  local iconSize = math.floor(baseSize * PIN_ICON_SCALE)
  local maxSize = (PIN_ICON_MAX_SIZE and PIN_ICON_MAX_SIZE > 0) and PIN_ICON_MAX_SIZE or iconSize
  iconSize = math.max(PIN_ICON_MIN_SIZE, math.min(maxSize, iconSize))
  local inset = math.max(PIN_ICON_MIN_INSET, math.floor(baseSize * PIN_ICON_INSET_SCALE))
  if btn.pinIcon.SetAtlas then
    btn.pinIcon:SetAtlas(PIN_ICON_ATLAS, true)
  else
    btn.pinIcon:SetTexture("Interface\\Minimap\\ObjectIcons")
  end
  btn.pinIcon:ClearAllPoints()
  btn.pinIcon:SetPoint("TOPLEFT", PIN_ICON_OFFSET_X * inset, PIN_ICON_OFFSET_Y * inset)
  btn.pinIcon:SetSize(iconSize, iconSize)
end

function BarFrame:ApplyOverlayIconStyle(btn)
  if not btn or not btn.overlayIcon then return end
  local overlay = btn.overlayConfig
  local baseSize = (btn.GetWidth and btn:GetWidth()) or self:GetButtonSize() or DEFAULT_BUTTON_SIZE
  local scale = overlay and tonumber(overlay.scale) or OVERLAY_ICON_SCALE
  local iconSize = overlay and tonumber(overlay.size) or math.floor(baseSize * scale)
  local minSize = overlay and tonumber(overlay.minSize) or OVERLAY_ICON_MIN_SIZE
  local maxSize = overlay and tonumber(overlay.maxSize) or OVERLAY_ICON_MAX_SIZE
  local clampMax = (maxSize and maxSize > 0) and maxSize or iconSize
  iconSize = math.max(minSize, math.min(clampMax, iconSize))
  local offsetX = overlay and tonumber(overlay.offsetX) or OVERLAY_ICON_OFFSET_X
  local offsetY = overlay and tonumber(overlay.offsetY) or OVERLAY_ICON_OFFSET_Y
  local alpha = overlay and tonumber(overlay.alpha) or OVERLAY_ICON_ALPHA
  btn.overlayIcon:ClearAllPoints()
  btn.overlayIcon:SetPoint("CENTER", offsetX, offsetY)
  btn.overlayIcon:SetSize(iconSize, iconSize)
  btn.overlayIcon:SetAlpha(alpha)
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
    self:ApplyPinIconStyle(btn)
    self:ApplyOverlayIconStyle(btn)
    for _, child in ipairs(btn.flyoutButtons or {}) do
      applyFont(child.count, countSize)
      applyFont(child.hotkey, hotkeySize)
      self:ApplyOverlayIconStyle(child)
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

function BarFrame:TogglePinnedForButton(btn)
  if not btn or not btn.itemData then return end
  local moduleName = btn.itemData.module or (btn.groupData and btn.groupData.module)
  if not moduleName then return end
  local key = BarSmith:GetActionIdentityKey(btn.itemData)
  if not key then return end

  local pinned = BarSmith:GetPinnedForModule(moduleName)
  if pinned and pinned == key then
    BarSmith:ClearPinnedForModule(moduleName)
  else
    BarSmith:SetPinnedForModule(moduleName, btn.itemData)
  end

  if InCombatLockdown() then
    BarSmith.pendingFill = true
  else
    BarSmith:RunAutoFill(true)
  end
end

function BarFrame:SetFlyoutItems(btn, children)
  btn.flyoutItems = children
  btn.flyoutOpen = false

  local childCount = children and #children or 0
  if not InCombatLockdown() then
    btn:SetAttribute("bs_flyout_count", childCount)
  end
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
    childBtn:SetAttribute("macrotext", nil)
    childBtn:SetAttribute("type1", nil)
    childBtn:SetAttribute("spell1", nil)
    childBtn:SetAttribute("item1", nil)
    childBtn:SetAttribute("toy1", nil)
    childBtn:SetAttribute("macrotext1", nil)
    childBtn:SetAttribute("type2", nil)
    childBtn:SetAttribute("spell2", nil)
    childBtn:SetAttribute("item2", nil)
    childBtn:SetAttribute("toy2", nil)
    childBtn:SetAttribute("macrotext2", nil)
    childBtn.itemData = nil

    if childBtn.cooldown then
      childBtn.cooldown:Clear()
    end

    if childData then
      self:SetButtonAction(childBtn, childData, nil, true)
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
      childBtn.overlayConfig = nil
      if childBtn.overlayIcon then
        childBtn.overlayIcon:SetTexture(nil)
        if childBtn.overlayIcon.SetAtlas then
          childBtn.overlayIcon:SetAtlas(nil)
        end
        childBtn.overlayIcon:Hide()
      end
      childBtn:Hide()
    end
  end

  self:UpdateFlyoutPositions(btn)
end

function BarFrame:UpdateFlyoutPositions(btn)
  if not btn or InCombatLockdown() then return end

  local topLevel = self.frame:GetFrameLevel() + 50
  local direction = self:GetFlyoutDirection()
  local buttonSize = self:GetButtonSize()

  for i, childBtn in ipairs(btn.flyoutButtons or {}) do
    local offset = BUTTON_PADDING + ((i - 1) * (buttonSize + BUTTON_PADDING))
    childBtn:SetFrameLevel(topLevel + i)
    childBtn:ClearAllPoints()
    if direction == "TOP" then
      childBtn:SetPoint("BOTTOM", btn, "TOP", 0, offset)
    elseif direction == "BOTTOM" then
      childBtn:SetPoint("TOP", btn, "BOTTOM", 0, -offset)
    elseif direction == "LEFT" then
      childBtn:SetPoint("RIGHT", btn, "LEFT", -offset, 0)
    else
      childBtn:SetPoint("LEFT", btn, "RIGHT", offset, 0)
    end
    childBtn:SetSize(buttonSize, buttonSize)
    self:ApplyOverlayIconStyle(childBtn)
  end
end

function BarFrame:StartAutoCloseTimer()
  if self.secureFlyoutHover then
    return
  end
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
  if btn.itemData.isPlaceholder then return end

  if IsSettingsClick(button) then
    return
  end

  if button == "LeftButton" and IsControlKeyDown() then
    return
  end

  -- Group parents use left-click to toggle flyout, not to execute an action.
  if btn.groupData and btn.flyoutItems and #btn.flyoutItems > 1 and button == "LeftButton" then
    return
  end

  if IsExcludeRemoveClick(button) then
    if not btn.parentButton then
      return
    end
    if InCombatLockdown() then
    BarSmith:Print("Cannot exclude during combat.")
      return
    end
    local data = btn.itemData
    local isAuto = data.autoAdded
    if isAuto == nil then
      isAuto = BarSmith:IsAutoAdded(data)
    end

    if isAuto then
      BarSmith:AddToExclude(data)
      BarSmith:Print("Excluded: " .. (data.name or "Unknown"))
    else
      local removed = false
      local macros = BarSmith:GetModule("Macros")
      if data.type == "macro" or data.slotIndex then
        if macros and data.slotIndex then
          macros:ClearSlot(data.slotIndex)
          removed = true
        end
      end

      if data.type == "class_spell" and data.spellID then
        local classSpells = BarSmith:GetModule("ClassSpells")
        if classSpells and classSpells.RemoveCustomSpell then
          removed = classSpells:RemoveCustomSpell(data.spellID) or removed
        end
      end

      if data.type == "mount" and data.mountID then
        local mounts = BarSmith:GetModule("Mounts")
        if mounts and mounts.RemoveExtraMount then
          removed = mounts:RemoveExtraMount(data.mountID) or removed
        end
      end

      if data.itemID then
        local con = BarSmith:GetModule("Consumables")
        if con and con.RemoveExtraItem then
          removed = con:RemoveExtraItem(data.itemID, data.type) or removed
        end
      end

      if removed then
        BarSmith:Print("Removed from manual list.")
      else
        BarSmith:Print("Nothing to remove for that item.")
      end
    end

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

function BarFrame:HandleReceiveDrag(btn)
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

  if cursorType == "macro" then
    local target = btn and btn.itemData
    local macros = BarSmith:GetModule("Macros")
    if macros then
      if target and target.type == "macro" then
        if not target.macroID then
          if macros:AssignMacroToSlot(target.slotIndex, id) then
            BarSmith:RunAutoFill(true)
          else
            BarSmith:Print("Could not assign macro to that slot.")
          end
        else
          local ok, err = macros:AddMacroToNextSlot(id)
          if ok then
            BarSmith:RunAutoFill(true)
          else
            BarSmith:Print(err or "Could not add macro.")
          end
        end
      else
        local ok, err = macros:AddMacroToNextSlot(id)
        if ok then
          BarSmith:RunAutoFill(true)
        else
          BarSmith:Print(err or "Could not add macro.")
        end
      end
    end
  elseif cursorType == "item" then
    local removed = BarSmith:RemoveFromExcludeForItemID(id)
    local con = BarSmith:GetModule("Consumables")
    local added = (con and con:AddExtraItem(id)) == true
    if added or removed then
      BarSmith:RunAutoFill(true)
    end
  elseif cursorType == "mount" then
    local _, spellID = C_MountJournal.GetMountInfoByID(id)
    local removed = BarSmith:RemoveFromExcludeForSpellID(spellID)
    local mounts = BarSmith:GetModule("Mounts")
    local added = (mounts and mounts:AddExtraMount(id)) == true
    if added or removed then
      BarSmith:RunAutoFill(true)
    end
  elseif cursorType == "spell" then
    local resolvedSpellID = spellID or id
    local removed = BarSmith:RemoveFromExcludeForSpellID(resolvedSpellID)
    local classSpells = BarSmith:GetModule("ClassSpells")
    local added = (classSpells and classSpells:AddCustomSpell(resolvedSpellID)) == true
    if added or removed then
      BarSmith:RunAutoFill(true)
    end
  end
  ClearCursor()
end

-- When a flyout child button is clicked, promote that child to be the new primary for the parent group.
function BarFrame:PromoteChildAsPrimary(parentBtn, childData)
  if not parentBtn or not childData then return end
  if InCombatLockdown() then return end
  if not parentBtn.groupData or not parentBtn.flyoutItems or #parentBtn.flyoutItems <= 1 then
    return
  end

  local moduleName = parentBtn.groupData.module
  if moduleName then
    local pinned = BarSmith:GetPinnedForModule(moduleName)
    if pinned and BarSmith:GetActionIdentityKey(childData) ~= pinned then
      return
    end
  end

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
  self:SetButtonAction(parentBtn, childData, nil, true)
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

  self:UpdateFlyoutPositions(btn)

  for i, childBtn in ipairs(btn.flyoutButtons or {}) do
    local childData = btn.flyoutItems[i]
    if childData then
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
    self:SetButtonAction(btn, actionData, nil, true)
  else
    btn.groupData = nil
    self:SetFlyoutItems(btn, nil)
    self:SetButtonAction(btn, actionData, nil, true)
  end

  btn.itemData = actionData
  self:ApplyButtonVisuals(btn, actionData)
  self:UpdateButtonHotkey(btn)
  self:UpdateButtonPinnedIndicator(btn)

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
  btn:SetAttribute("macrotext2", nil)

  btn.icon:SetTexture(nil)
  btn.count:SetText("")
  if btn.hotkey then
    btn.hotkey:SetText("")
  end
  if btn.pinIcon then
    btn.pinIcon:Hide()
  end
  btn.overlayConfig = nil
  if btn.overlayIcon then
    btn.overlayIcon:SetTexture(nil)
    if btn.overlayIcon.SetAtlas then
      btn.overlayIcon:SetAtlas(nil)
    end
    btn.overlayIcon:Hide()
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
    self:UpdateFlyoutPositions(btn)
  end

  self:UpdateButtonFontSizes()
  self:UpdateAutoHideState()
  if BarSmith.MasqueReSkin then
    BarSmith:MasqueReSkin()
  end
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

    local data = btn.itemData
    local durationObject
    local start, duration, enable = 0, 0, 1

    if data.type == "housing_teleport" then
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

  for _, btn in ipairs(self.buttons) do
    updateButtonCooldown(btn)
    for _, childBtn in ipairs(btn.flyoutButtons or {}) do
      if childBtn:IsShown() then
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
    elseif data.itemID then
      if UnitExists("target") and not InCombatLockdown() then
        if C_Item and C_Item.IsItemInRange then
          local rangeResult = C_Item.IsItemInRange(data.itemID, "target")
          if rangeResult == false then
            inRange = false
          end
        elseif IsItemInRange then
          local rangeResult = IsItemInRange(data.itemID, "target")
          if rangeResult == false then
            inRange = false
          end
        end
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
    for _, childBtn in ipairs(btn.flyoutButtons or {}) do
      if childBtn:IsShown() then
        updateRange(childBtn)
      end
    end
  end
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
    GameTooltip:AddLine(TOOLTIP_ICON .. " |cff33ccff[BarSmith]|r " .. typeLabel, r, g, b)
  else
    GameTooltip:AddLine(TOOLTIP_ICON .. " |cff33ccff[BarSmith]|r", 0.5, 0.5, 0.5)
  end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine(TOOLTIP_TITLE_COLOR .. "Actions|r", 1, 1, 1)
  if not isFlyoutChild then
    GameTooltip:AddLine(TOOLTIP_ACTION_MENU_COLOR .. "Open Menu|r: " ..
      TOOLTIP_SHORTCUT_COLOR .. "Shift + Right Click|r", 0.8, 0.8, 0.8)
    -- local groupLabel = (btn.groupData and btn.groupData.name) or (#btn.flyoutItems .. " items")
    -- GameTooltip:AddLine(groupLabel, 0.8, 0.8, 0.8)
  end
  if isFlyoutChild then
    GameTooltip:AddLine(TOOLTIP_ACTION_ADD_COLOR .. "Add to QuickBar|r: " ..
      TOOLTIP_SHORTCUT_COLOR .. "Alt + Left Click|r", 0.8, 0.8, 0.8)
    GameTooltip:AddLine(TOOLTIP_ACTION_PIN_COLOR .. "Pin / Unpin|r: " ..
      TOOLTIP_SHORTCUT_COLOR .. "Ctrl + Left Click|r", 0.8, 0.8, 0.8)
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
        GameTooltip:AddLine(TOOLTIP_ACTION_REMOVE_COLOR .. "Exclude|r: " ..
          TOOLTIP_SHORTCUT_COLOR .. "Ctrl + Shift + Right Click|r", 0.8, 0.8, 0.8)
      else
        GameTooltip:AddLine(TOOLTIP_ACTION_REMOVE_COLOR .. "Remove|r: " ..
          TOOLTIP_SHORTCUT_COLOR .. "Ctrl + Shift + Right Click|r", 0.8, 0.8, 0.8)
      end
    end
    if data.type == "macro" then
      GameTooltip:AddLine("Drag a macro to assign it to this slot", 0.8, 0.8, 0.8)
    else
      GameTooltip:AddLine(TOOLTIP_NOTE_COLOR ..
        "Note: Drag a consumable, mount, or spell to include|r", 0.8, 0.8, 0.8)
    end
  end
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


