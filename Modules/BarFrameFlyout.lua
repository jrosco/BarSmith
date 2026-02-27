------------------------------------------------------------------------
-- BarSmith: Modules/BarFrameFlyout.lua
-- Flyout management for BarFrame.
------------------------------------------------------------------------

local BarFrame = BarSmith:GetModule("BarFrame")
local C = BarFrame.constants

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
    local offset = C.BUTTON_PADDING + ((i - 1) * (buttonSize + C.BUTTON_PADDING))
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
  self._flyoutAutoCloseTimer = C_Timer.NewTimer(C.FLYOUT_AUTO_CLOSE, function()
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
  if not C.VALID_FLYOUT_DIRECTIONS[direction] then
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
