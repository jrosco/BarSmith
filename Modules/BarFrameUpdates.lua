------------------------------------------------------------------------
-- BarSmith: Modules/BarFrameUpdates.lua
-- Cooldown and range updates for BarFrame.
------------------------------------------------------------------------

local BarFrame = BarSmith:GetModule("BarFrame")

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
