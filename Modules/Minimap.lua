------------------------------------------------------------------------
-- BarSmith: Modules/Minimap.lua
-- Minimap icon and interactions
------------------------------------------------------------------------

local MinimapMod = BarSmith:NewModule("Minimap")

local function ClampAngle(angle)
  angle = angle % 360
  if angle < 0 then angle = angle + 360 end
  return angle
end

function MinimapMod:UpdateButton()
  if not self.button or not BarSmith.db or not BarSmith.db.minimap then
    return
  end

  if BarSmith.db.minimap.hide then
    self.button:Hide()
    return
  end

  local angle = ClampAngle(BarSmith.db.minimap.angle or 225)
  local rad = math.rad(angle)
  local radius = 80
  local x = math.cos(rad) * radius
  local y = math.sin(rad) * radius
  self.button:SetPoint("CENTER", Minimap, "CENTER", x, y)
  self.button:Show()
end

function MinimapMod:Init()
  if BarSmith.db and BarSmith.db.minimap and BarSmith.db.minimap.hide then
    if self.button then
      self.button:Hide()
    end
    return
  end

  if self.button then
    self:UpdateButton()
    return
  end

  local btn = CreateFrame("Button", "BarSmithMinimapButton", Minimap)
  btn:SetSize(32, 32)
  btn:SetFrameStrata("MEDIUM")
  btn:SetMovable(true)
  btn:EnableMouse(true)
  btn:RegisterForClicks("AnyUp")
  btn:RegisterForDrag("LeftButton")

  btn.icon = btn:CreateTexture(nil, "BACKGROUND")
  btn.icon:SetTexture("Interface\\AddOns\\BarSmith\\Textures\\bs")
  btn.icon:SetAllPoints()

  btn.border = btn:CreateTexture(nil, "OVERLAY")
  btn.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  btn.border:SetAllPoints()

  btn:SetScript("OnEnter", function()
    GameTooltip:SetOwner(btn, "ANCHOR_LEFT")
    GameTooltip:SetText("BarSmith")
    GameTooltip:AddLine("Left-click: Open settings", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Right-click: Lock/Unlock bar", 0.8, 0.8, 0.8)
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  btn:SetScript("OnClick", function(_, button)
    if button == "LeftButton" then
      BarSmith:OpenSettings()
    elseif button == "RightButton" then
      local barFrame = BarSmith:GetModule("BarFrame")
      if barFrame and barFrame.SetLocked then
        barFrame:SetLocked(not BarSmith.chardb.barLocked)
      end
    end
  end)

  btn:SetScript("OnDragStart", function()
    btn:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local cx, cy = GetCursorPosition()
      local scale = Minimap:GetEffectiveScale()
      cx, cy = cx / scale, cy / scale
      local angle = math.deg(math.atan2(cy - my, cx - mx))
      BarSmith.db.minimap.angle = ClampAngle(angle)
      MinimapMod:UpdateButton()
    end)
  end)
  btn:SetScript("OnDragStop", function()
    btn:SetScript("OnUpdate", nil)
  end)

  self.button = btn
  self:UpdateButton()
end
