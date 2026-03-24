------------------------------------------------------------------------
-- BarSmith: Config/SettingsButtons.lua
-- Simple Settings button template mixin
------------------------------------------------------------------------

BarSmithSettingsButtonMixin = {}

function BarSmithSettingsButtonMixin:Init(initializer)
  local data = initializer.data or {}
  if self.Label and data.text then
    self.Label:SetText(data.text)
  end
  if self.Button then
    self.Button:SetText(data.buttonText or data.text or "Run")
    self.Button:SetScript("OnClick", function()
      if data.OnClick then
        data.OnClick()
      end
    end)
  end
end

BarSmithSettingsNoteMixin = {}

function BarSmithSettingsNoteMixin:Init(initializer)
  local data = initializer.data or {}
  if self.Text and data.text then
    self.Text:SetText(data.text)
    self.Text:SetJustifyH("LEFT")
    self.Text:SetJustifyV("TOP")
    self.Text:SetWordWrap(true)
  end
end
