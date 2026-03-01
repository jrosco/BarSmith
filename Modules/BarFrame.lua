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
local DEFAULT_TOY_ICON = "Interface\\Icons\\INV_Misc_Toy_02"
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

BarFrame.constants = {
  MAX_FLYOUT_BUTTONS = MAX_FLYOUT_BUTTONS,
  VALID_FLYOUT_DIRECTIONS = VALID_FLYOUT_DIRECTIONS,
  DEFAULT_BUTTON_SIZE = DEFAULT_BUTTON_SIZE,
  BUTTON_PADDING = BUTTON_PADDING,
  BAR_PADDING = BAR_PADDING,
  PIN_ICON_ATLAS = PIN_ICON_ATLAS,
  PIN_ICON_SCALE = PIN_ICON_SCALE,
  PIN_ICON_MIN_SIZE = PIN_ICON_MIN_SIZE,
  PIN_ICON_MAX_SIZE = PIN_ICON_MAX_SIZE,
  PIN_ICON_INSET_SCALE = PIN_ICON_INSET_SCALE,
  PIN_ICON_MIN_INSET = PIN_ICON_MIN_INSET,
  PIN_ICON_OFFSET_X = PIN_ICON_OFFSET_X,
  PIN_ICON_OFFSET_Y = PIN_ICON_OFFSET_Y,
  PIN_ICON_ALPHA = PIN_ICON_ALPHA,
  DEFAULT_TOY_ICON = DEFAULT_TOY_ICON,
  OVERLAY_ICON_SCALE = OVERLAY_ICON_SCALE,
  OVERLAY_ICON_MIN_SIZE = OVERLAY_ICON_MIN_SIZE,
  OVERLAY_ICON_MAX_SIZE = OVERLAY_ICON_MAX_SIZE,
  OVERLAY_ICON_OFFSET_X = OVERLAY_ICON_OFFSET_X,
  OVERLAY_ICON_OFFSET_Y = OVERLAY_ICON_OFFSET_Y,
  OVERLAY_ICON_ALPHA = OVERLAY_ICON_ALPHA,
  FLYOUT_AUTO_CLOSE = FLYOUT_AUTO_CLOSE,
  AUTO_HIDE_ALPHA = AUTO_HIDE_ALPHA,
  MOUSE_LEAVE_CHECK_DELAY = MOUSE_LEAVE_CHECK_DELAY,
  DEFAULT_FONT_SCALE = DEFAULT_FONT_SCALE,
  HOVER_HIT_INSET = HOVER_HIT_INSET,
  TOOLTIP_ICON = TOOLTIP_ICON,
  TOOLTIP_TITLE_COLOR = TOOLTIP_TITLE_COLOR,
  TOOLTIP_ACTION_MENU_COLOR = TOOLTIP_ACTION_MENU_COLOR,
  TOOLTIP_ACTION_ADD_COLOR = TOOLTIP_ACTION_ADD_COLOR,
  TOOLTIP_ACTION_PIN_COLOR = TOOLTIP_ACTION_PIN_COLOR,
  TOOLTIP_ACTION_REMOVE_COLOR = TOOLTIP_ACTION_REMOVE_COLOR,
  TOOLTIP_SHORTCUT_COLOR = TOOLTIP_SHORTCUT_COLOR,
  TOOLTIP_NOTE_COLOR = TOOLTIP_NOTE_COLOR,
}

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
    "toys",
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
  if BarSmith.UpdateSettingsProxy then
    BarSmith:UpdateSettingsProxy("BarSmith_Locked", locked)
    BarSmith:UpdateSettingsProxy("BarSmith_AutoHideMouseover", BarSmith.chardb.barAutoHideMouseover == true)
  end
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
