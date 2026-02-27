------------------------------------------------------------------------
-- BarSmith: Modules/BarFrameButtons.lua
-- Button creation, visuals, and input handling for BarFrame.
------------------------------------------------------------------------

local BarFrame = BarSmith:GetModule("BarFrame")
local C = BarFrame.constants

local function IsSettingsClick(button)
  return button == "RightButton" and IsShiftKeyDown() and not IsControlKeyDown() and not IsAltKeyDown()
end

local function IsQuickBarAddClick(button)
  return button == "LeftButton" and IsAltKeyDown()
end

local function IsExcludeRemoveClick(button)
  return button == "RightButton" and IsShiftKeyDown() and IsControlKeyDown()
end

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

------------------------------------------------------------------------
-- Create a single secure action button which makes it clickable
------------------------------------------------------------------------

function BarFrame:CreateButton(index)
  local btnName = "BarSmithButton" .. index
  local btn = CreateFrame("Button", btnName, self.frame, "SecureActionButtonTemplate,SecureHandlerEnterLeaveTemplate")

  local buttonSize = self:GetButtonSize()
  btn:SetSize(buttonSize, buttonSize)
  btn:RegisterForClicks("AnyUp", "AnyDown")
  btn:SetHitRectInsets(-C.HOVER_HIT_INSET, -C.HOVER_HIT_INSET, -C.HOVER_HIT_INSET, -C.HOVER_HIT_INSET)

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
  btn.pinIcon:SetAlpha(C.PIN_ICON_ALPHA)
  btn.pinIcon:Hide()
  self:ApplyPinIconStyle(btn)

  -- Overlay indicator (e.g. faction crest)
  btn.overlayIcon = btn.overlayIcon or btn:CreateTexture(btnName .. "Overlay", "OVERLAY")
  btn.overlayIcon:SetDrawLayer("OVERLAY", 6)
  btn.overlayIcon:SetAlpha(C.OVERLAY_ICON_ALPHA)
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
    self:HandleTooltipEnter(b, false)
  end)
  btn:SetScript("OnLeave", function(b)
    self:NotifyMouseLeave()
    self:HandleTooltipLeave(b)
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
  for i = 1, C.MAX_FLYOUT_BUTTONS do
    local child = CreateFrame("Button", prefix .. i, self.frame, "SecureActionButtonTemplate")
    local buttonSize = self:GetButtonSize()
    child:SetSize(buttonSize, buttonSize)
    child:RegisterForClicks("AnyUp", "AnyDown")
    child:SetHitRectInsets(-C.HOVER_HIT_INSET, -C.HOVER_HIT_INSET, -C.HOVER_HIT_INSET, -C.HOVER_HIT_INSET)

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
    child.overlayIcon:SetAlpha(C.OVERLAY_ICON_ALPHA)
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
      self:HandleTooltipEnter(b, true)
    end)
    child:SetScript("OnLeave", function(b)
      self:NotifyMouseLeave()
      self:HandleTooltipLeave(b)
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
  end

  if (data.type == "hearthstone_toy" or data.type == "toy") and data.toyID then
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

  local icon = data.icon
  if icon == 0 or icon == "" or icon == false then
    icon = nil
  end
  if not icon and data.toyID then
    icon = C.DEFAULT_TOY_ICON
  end

  local iconAtlas = data.iconAtlas
  if not iconAtlas and type(icon) == "string" and C_Texture and C_Texture.GetAtlasInfo then
    if C_Texture.GetAtlasInfo(icon) then
      iconAtlas = icon
      icon = nil
    end
  end

  if iconAtlas and btn.icon.SetAtlas then
    btn.icon:SetAtlas(iconAtlas, true)
    btn.icon:SetDesaturated(false)
    btn.icon:SetVertexColor(1, 1, 1)
  elseif icon then
    btn.icon:SetTexture(icon)
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
  local baseSize = (btn.GetWidth and btn:GetWidth()) or self:GetButtonSize() or C.DEFAULT_BUTTON_SIZE
  local iconSize = math.floor(baseSize * C.PIN_ICON_SCALE)
  local maxSize = (C.PIN_ICON_MAX_SIZE and C.PIN_ICON_MAX_SIZE > 0) and C.PIN_ICON_MAX_SIZE or iconSize
  iconSize = math.max(C.PIN_ICON_MIN_SIZE, math.min(maxSize, iconSize))
  local inset = math.max(C.PIN_ICON_MIN_INSET, math.floor(baseSize * C.PIN_ICON_INSET_SCALE))
  if btn.pinIcon.SetAtlas then
    btn.pinIcon:SetAtlas(C.PIN_ICON_ATLAS, true)
  else
    btn.pinIcon:SetTexture("Interface\\Minimap\\ObjectIcons")
  end
  btn.pinIcon:ClearAllPoints()
  btn.pinIcon:SetPoint("TOPLEFT", C.PIN_ICON_OFFSET_X * inset, C.PIN_ICON_OFFSET_Y * inset)
  btn.pinIcon:SetSize(iconSize, iconSize)
end

function BarFrame:ApplyOverlayIconStyle(btn)
  if not btn or not btn.overlayIcon then return end
  local overlay = btn.overlayConfig
  local baseSize = (btn.GetWidth and btn:GetWidth()) or self:GetButtonSize() or C.DEFAULT_BUTTON_SIZE
  local scale = overlay and tonumber(overlay.scale) or C.OVERLAY_ICON_SCALE
  local iconSize = overlay and tonumber(overlay.size) or math.floor(baseSize * scale)
  local minSize = overlay and tonumber(overlay.minSize) or C.OVERLAY_ICON_MIN_SIZE
  local maxSize = overlay and tonumber(overlay.maxSize) or C.OVERLAY_ICON_MAX_SIZE
  local clampMax = (maxSize and maxSize > 0) and maxSize or iconSize
  iconSize = math.max(minSize, math.min(clampMax, iconSize))
  local offsetX = overlay and tonumber(overlay.offsetX) or C.OVERLAY_ICON_OFFSET_X
  local offsetY = overlay and tonumber(overlay.offsetY) or C.OVERLAY_ICON_OFFSET_Y
  local alpha = overlay and tonumber(overlay.alpha) or C.OVERLAY_ICON_ALPHA
  btn.overlayIcon:ClearAllPoints()
  btn.overlayIcon:SetPoint("CENTER", offsetX, offsetY)
  btn.overlayIcon:SetSize(iconSize, iconSize)
  btn.overlayIcon:SetAlpha(alpha)
end

function BarFrame:UpdateButtonFontSizes()
  local size = self:GetButtonSize()
  local scale = size / C.DEFAULT_FONT_SCALE
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

      if data.type == "toy" and data.toyID then
        local toys = BarSmith:GetModule("Toys")
        if toys and toys.RemoveExtraToy then
          removed = toys:RemoveExtraToy(data.toyID) or removed
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
-- Drag and drop support for includes
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

  local function isToyItem(itemID)
    if not itemID then return false end
    if C_ToyBox and C_ToyBox.IsToyItem and C_ToyBox.IsToyItem(itemID) then
      return true
    end
    if PlayerHasToy and PlayerHasToy(itemID) then
      return true
    end
    return false
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
  elseif cursorType == "toy" then
    local removed = BarSmith:RemoveFromExcludeForToyID(id)
    local toys = BarSmith:GetModule("Toys")
    local added = (toys and toys:AddExtraToy(id)) == true
    if added or removed then
      BarSmith:RunAutoFill(true)
    end
  elseif cursorType == "item" then
    if isToyItem(id) then
      local removed = BarSmith:RemoveFromExcludeForToyID(id)
      local toys = BarSmith:GetModule("Toys")
      local added = (toys and toys:AddExtraToy(id)) == true
      if added or removed then
        BarSmith:RunAutoFill(true)
      end
    else
      local removed = BarSmith:RemoveFromExcludeForItemID(id)
      local con = BarSmith:GetModule("Consumables")
      local added = (con and con:AddExtraItem(id)) == true
      if added or removed then
        BarSmith:RunAutoFill(true)
      end
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
