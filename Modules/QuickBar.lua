------------------------------------------------------------------------
-- BarSmith: Modules/QuickBar.lua
-- Dedicated quick-access bar with fixed slots and simple actions
------------------------------------------------------------------------

local QuickBar = BarSmith:NewModule("QuickBar")

local MAX_QUICKBAR_BUTTONS = 8
local DEFAULT_ICON_SIZE = 32
local BUTTON_PADDING = 3
local BAR_PADDING = 4
local HIDE_DELAY = 0.3
local TOOLTIP_ICON = "|TInterface\\AddOns\\BarSmith\\Textures\\bs:14:14:0:0|t"

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

  self.frame = CreateFrame("Frame", "BarSmithQuickBarFrame", UIParent, "BackdropTemplate")
  self.frame:SetClampedToScreen(true)
  self.frame:SetFrameStrata("DIALOG")
  self.frame:Hide()

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

  self:UpdateLayout()

  self.frame:HookScript("OnEnter", function()
    self:CancelHideTimer()
  end)
  self.frame:HookScript("OnLeave", function()
    self:StartHideTimer()
  end)

  self:Refresh()
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

function QuickBar:CreateButton(index)
  local btnName = "BarSmithQuickBarButton" .. index
  local btn = CreateFrame("Button", btnName, self.frame, "SecureActionButtonTemplate")

  local buttonSize = self:GetButtonSize()
  btn:SetSize(buttonSize, buttonSize)
  btn:RegisterForClicks("AnyUp", "AnyDown")

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

  btn:SetScript("OnEnter", function()
    self:CancelHideTimer()
    self:ShowButtonTooltip(btn)
  end)
  btn:SetScript("OnLeave", function()
    GameTooltip:Hide()
    self:StartHideTimer()
  end)

  btn:HookScript("OnMouseUp", function(b, button)
    if button == "RightButton" and IsAltKeyDown() then
      self:ClearSlot(b.index)
    end
  end)

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
  GameTooltip:AddLine("Alt-Right-click to remove", 0.8, 0.8, 0.8)
  GameTooltip:Show()
end

function QuickBar:UpdateLayout()
  if not self.frame then return end
  local activeCount = self:GetActiveCount()
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
end

function QuickBar:IsMouseOverAny()
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
  self._hideTimer = C_Timer.NewTimer(HIDE_DELAY, function()
    self._hideTimer = nil
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
    barFrame:SetButtonAction(btn, data, nil)
    barFrame:ApplyButtonVisuals(btn, data)
  end
end

function QuickBar:Refresh()
  if not self.frame then return end
  local cfg = self:GetConfig()
  cfg.slots = cfg.slots or {}
  local activeCount = self:GetActiveCount()
  if activeCount <= 0 then
    for _, btn in ipairs(self.buttons) do
      btn:Hide()
    end
    self:Hide()
    return
  end
  for i, btn in ipairs(self.buttons) do
    local data = cfg.slots[i]
    btn.itemData = data
    if data then
      if not InCombatLockdown() then
        self:SetButtonFromData(btn, data)
      end
      btn:Show()
    else
      if not InCombatLockdown() then
        btn:SetAttribute("type", nil)
        btn:SetAttribute("spell", nil)
        btn:SetAttribute("item", nil)
        btn:SetAttribute("toy", nil)
        btn:SetAttribute("macrotext", nil)
      end
      btn.icon:SetTexture(nil)
      btn.count:SetText("")
      btn:Hide()
    end
  end
  self:UpdateLayout()
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
  if InCombatLockdown() then
    self:RestorePosition()
  else
    self:MoveToCursor()
  end
  self:UpdateLayout()
  self:UpdateBackdropVisibility()
  self:Refresh()
  self.frame:Show()
  self:StartHideTimer()
end

function QuickBar:Hide()
  if self.frame then
    self:CancelHideTimer()
    self.frame:Hide()
  end
end

function QuickBar:Toggle()
  local cfg = self:GetConfig()
  if cfg.enabled == false then
    BarSmith:Print("QuickBar is disabled.")
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
