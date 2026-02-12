------------------------------------------------------------------------
-- BarSmith: Config/Settings.lua
-- Native Blizzard Settings Panel (Settings API introduced in 10.0)
------------------------------------------------------------------------

local Settings = Settings
local mod = BarSmith:NewModule("Settings")

------------------------------------------------------------------------
-- Addon Compartment (minimap button for 10.x+)
------------------------------------------------------------------------

function BarSmith_OnAddonCompartmentClick(_, button)
  if button == "LeftButton" then
    BarSmith:OpenSettings()
  elseif button == "RightButton" then
    BarSmith:RunAutoFill()
  end
end

function BarSmith:OpenSettings()
  local target = self.settingsCategoryID or "BarSmith"

  -- Open twice to handle Blizzard Settings focus quirks on some clients.
  Settings.OpenToCategory(target, "BarSmith")
  C_Timer.After(0, function()
    Settings.OpenToCategory(target, "BarSmith")
  end)
end

------------------------------------------------------------------------
-- Proxy table for Settings API
-- RegisterAddOnSetting requires a table to read/write values from.
-- We use a proxy keyed by variable name and sync changes back to chardb/db.
------------------------------------------------------------------------

local settingsProxy = {}

local function BuildDirectionDropdownOptions()
  local container = Settings.CreateControlTextContainer()
  container:Add("TOP", "Top")
  container:Add("BOTTOM", "Bottom")
  container:Add("LEFT", "Left")
  container:Add("RIGHT", "Right")
  return container:GetData()
end

------------------------------------------------------------------------
-- Build Settings Panel
------------------------------------------------------------------------

function mod:Init()
  local title = "BarSmith"
  if BarSmith and BarSmith.version then
    title = "BarSmith |cff00ff00v" .. tostring(BarSmith.version) .. "|r"
  end
  local category, layout                      = Settings.RegisterVerticalLayoutCategory(title)
  BarSmith.settingsCategoryID                 = category:GetID()

  -- Seed proxy with current values
  settingsProxy["BarSmith_Enabled"]           = BarSmith.chardb.enabled
  settingsProxy["BarSmith_AutoFill"]          = BarSmith.chardb.autoFill
  settingsProxy["BarSmith_Confirm"]           = BarSmith.chardb.confirmBeforeFill
  settingsProxy["BarSmith_Locked"]            = BarSmith.chardb.barLocked
  settingsProxy["BarSmith_Columns"]           = BarSmith.chardb.barColumns
  settingsProxy["BarSmith_IconSize"]          = BarSmith.chardb.barIconSize or 36
  settingsProxy["BarSmith_Alpha"]             = BarSmith.chardb.barAlpha or 1
  settingsProxy["BarSmith_ShowBackdrop"]      = (BarSmith.chardb.barShowBackdrop ~= false)
  settingsProxy["BarSmith_AutoHideMouseover"] = (BarSmith.chardb.barAutoHideMouseover == true)
  settingsProxy["BarSmith_FlyoutDirection"]   = BarSmith.chardb.flyoutDirection or "TOP"
  settingsProxy["BarSmith_QB_Enabled"]        = (BarSmith.chardb.quickBar.enabled ~= false)
  settingsProxy["BarSmith_QB_IconSize"]       = BarSmith.chardb.quickBar.iconSize or 32
  settingsProxy["BarSmith_QB_Columns"]        = BarSmith.chardb.quickBar.columns or 6
  settingsProxy["BarSmith_QB_Alpha"]          = BarSmith.chardb.quickBar.alpha or 1
  settingsProxy["BarSmith_QB_ShowBackdrop"]   = (BarSmith.chardb.quickBar.showBackdrop ~= false)
  settingsProxy["BarSmith_Mounts_Random"]     = BarSmith.chardb.mounts.randomMount
  settingsProxy["BarSmith_Mounts_TopFavs"]    = BarSmith.chardb.mounts.topFavorites
  settingsProxy["BarSmith_Debug"]             = BarSmith.db.debug
  settingsProxy["BarSmith_Con_Potions"]       = BarSmith.chardb.consumables.potions
  settingsProxy["BarSmith_Con_Flasks"]        = BarSmith.chardb.consumables.flasks
  settingsProxy["BarSmith_Con_Food"]          = BarSmith.chardb.consumables.food
  settingsProxy["BarSmith_Con_Bandages"]      = BarSmith.chardb.consumables.bandages
  settingsProxy["BarSmith_Con_Utilities"]     = BarSmith.chardb.consumables.utilities
  settingsProxy["BarSmith_Con_CurrentOnly"]   = BarSmith.chardb.consumables.currentExpansionOnly
  settingsProxy["BarSmith_Con_Split_Potions"] = BarSmith.chardb.consumables.split.potions
  settingsProxy["BarSmith_Con_Split_Flasks"]  = BarSmith.chardb.consumables.split.flasks
  settingsProxy["BarSmith_Con_Split_Food"]    = BarSmith.chardb.consumables.split.food
  settingsProxy["BarSmith_Con_Split_Bandages"]= BarSmith.chardb.consumables.split.bandages
  settingsProxy["BarSmith_Con_Split_Utilities"]= BarSmith.chardb.consumables.split.utilities

  local moduleLabels                          = {
    questItems   = "Quest Items",
    consumables  = "Consumables (Potions, Food, Flasks)",
    trinkets     = "Trinkets",
    classSpells  = "Class Special Spells",
    professions  = "Professions",
    mounts       = "Mounts",
    hearthstones = "Hearthstones",
    macros       = "Macros",
  }

  for key, _ in pairs(moduleLabels) do
    settingsProxy["BarSmith_Mod_" .. key] = BarSmith.chardb.modules[key]
  end

  ---------- General ----------
  layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("General"))

  -- Enable addon
  do
    local variable = "BarSmith_Enabled"
    local name = "Enable BarSmith"
    local tooltip = "Toggle the addon on or off for this character."
    local setting = Settings.RegisterAddOnSetting(category, variable, variable, settingsProxy, "boolean", name, true)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.enabled = val
      BarSmith:FireCallback("SETTINGS_CHANGED")
    end)
    Settings.CreateCheckbox(category, setting, tooltip)
  end

  -- Auto-fill on events
  do
    local variable = "BarSmith_AutoFill"
    local name = "Auto-Fill on Login/Zone Change"
    local tooltip = "Automatically scan and place items when you log in, change zones, or update your bags."
    local setting = Settings.RegisterAddOnSetting(category, variable, variable, settingsProxy, "boolean", name, true)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.autoFill = val
    end)
    Settings.CreateCheckbox(category, setting, tooltip)
  end

  -- Confirm before fill
  do
    local variable = "BarSmith_Confirm"
    local name = "Confirm Before Placing"
    local tooltip = "Show a confirmation popup before items are placed on the bar."
    local setting = Settings.RegisterAddOnSetting(category, variable, variable, settingsProxy, "boolean", name, false)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.confirmBeforeFill = val
    end)
    Settings.CreateCheckbox(category, setting, tooltip)
  end

  ---------- Bar Settings ----------
  layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Bar Settings"))

  -- Lock bar
  do
    local variable = "BarSmith_Locked"
    local name = "Lock Bar Position"
    local tooltip = "When locked, the bar cannot be dragged. Unlock with /bs lock."
    local setting = Settings.RegisterAddOnSetting(category, variable, variable, settingsProxy, "boolean", name, true)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      local barFrame = BarSmith:GetModule("BarFrame")
      if barFrame then
        barFrame:SetLocked(val)
      end
    end)
    Settings.CreateCheckbox(category, setting, tooltip)
  end

  -- Columns
  do
    local variable = "BarSmith_Columns"
    local name = "Buttons Per Row"
    local tooltip = "Number of buttons per row on the BarSmith bar."
    local setting = Settings.RegisterAddOnSetting(category, variable, variable, settingsProxy, "number", name, 12)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.barColumns = math.max(1, math.min(12, val))
      local barFrame = BarSmith:GetModule("BarFrame")
      if barFrame then
        barFrame:UpdateLayout()
      end
    end)
    local options = Settings.CreateSliderOptions(1, 12, 1)
    Settings.CreateSlider(category, setting, options, tooltip)
  end

  -- Button icon size
  do
    local variable = "BarSmith_IconSize"
    local name = "Button Icon Size"
    local tooltip = "Size of BarSmith buttons/icons in pixels."
    local setting = Settings.RegisterAddOnSetting(category, variable, variable, settingsProxy, "number", name, 37)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.barIconSize = math.max(24, math.min(64, val))
      local barFrame = BarSmith:GetModule("BarFrame")
      if barFrame then
        barFrame:UpdateLayout()
      end
    end)
    local options = Settings.CreateSliderOptions(24, 64, 1)
    Settings.CreateSlider(category, setting, options, tooltip)
  end

  -- Bar alpha
  do
    local variable = "BarSmith_Alpha"
    local name = "Bar Frame Alpha"
    local tooltip = "Adjust the transparency of the BarSmith frame."
    local setting = Settings.RegisterAddOnSetting(category, variable, variable, settingsProxy, "number", name, 1)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.barAlpha = math.max(0.1, math.min(1, val))
      local barFrame = BarSmith:GetModule("BarFrame")
      if barFrame then
        barFrame:UpdateAutoHideState()
      end
    end)
    local options = Settings.CreateSliderOptions(0.1, 1, 0.05)
    Settings.CreateSlider(category, setting, options, tooltip)
  end

  -- Show backdrop
  do
    local variable = "BarSmith_ShowBackdrop"
    local name = "Show Frame Background"
    local tooltip = "Show or hide the bar container background and border."
    local setting = Settings.RegisterAddOnSetting(category, variable, variable, settingsProxy, "boolean", name, true)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.barShowBackdrop = val
      local barFrame = BarSmith:GetModule("BarFrame")
      if barFrame then
        barFrame:UpdateBackdropVisibility()
      end
    end)
    Settings.CreateCheckbox(category, setting, tooltip)
  end

  -- Auto-hide until mouseover
  do
    local variable = "BarSmith_AutoHideMouseover"
    local name = "Auto-Hide Until Mouseover"
    local tooltip = "Fade the bar when not hovered, and show it when your mouse is over it."
    local setting = Settings.RegisterAddOnSetting(category, variable, variable, settingsProxy, "boolean", name, false)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.barAutoHideMouseover = (val == true)
      local barFrame = BarSmith:GetModule("BarFrame")
      if barFrame then
        barFrame:UpdateAutoHideState()
      end
    end)
    Settings.CreateCheckbox(category, setting, tooltip)
  end

  -- Flyout direction
  do
    local variable = "BarSmith_FlyoutDirection"
    local name = "Flyout Direction"
    local tooltip = "Direction flyout buttons expand from the main button."
    local setting = Settings.RegisterAddOnSetting(category, variable, variable, settingsProxy, "string", name, "TOP")
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      local direction = string.upper(tostring(val or "TOP"))
      if direction ~= "TOP" and direction ~= "BOTTOM" and direction ~= "LEFT" and direction ~= "RIGHT" then
        direction = "TOP"
      end
      BarSmith.chardb.flyoutDirection = direction
      settingsProxy[variable] = direction

      local barFrame = BarSmith:GetModule("BarFrame")
      if barFrame then
        barFrame:HideAllFlyouts()
      end
    end)
    Settings.CreateDropdown(category, setting, BuildDirectionDropdownOptions, tooltip)
  end

  ---------- QuickBar ----------
  layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("QuickBar"))

  -- Enable QuickBar
  do
    local variable = "BarSmith_QB_Enabled"
    local name = "Enable QuickBar"
    local tooltip = "Enable the dedicated QuickBar toggle."
    local setting = Settings.RegisterAddOnSetting(category, variable, variable, settingsProxy, "boolean", name, true)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.quickBar.enabled = (val == true)
    end)
    Settings.CreateCheckbox(category, setting, tooltip)
  end

  -- QuickBar columns
  do
    local variable = "BarSmith_QB_Columns"
    local name = "QuickBar Columns"
    local tooltip = "Number of buttons per row on the QuickBar."
    local setting = Settings.RegisterAddOnSetting(category, variable, variable, settingsProxy, "number", name, 6)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.quickBar.columns = math.max(1, math.min(12, val))
      local quickBar = BarSmith:GetModule("QuickBar")
      if quickBar then
        quickBar:UpdateLayout()
      end
    end)
    local options = Settings.CreateSliderOptions(1, 12, 1)
    Settings.CreateSlider(category, setting, options, tooltip)
  end

  -- QuickBar icon size
  do
    local variable = "BarSmith_QB_IconSize"
    local name = "QuickBar Icon Size"
    local tooltip = "Button/icon size in pixels for the QuickBar."
    local setting = Settings.RegisterAddOnSetting(category, variable, variable, settingsProxy, "number", name, 32)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.quickBar.iconSize = math.max(24, math.min(64, val))
      local quickBar = BarSmith:GetModule("QuickBar")
      if quickBar then
        quickBar:UpdateLayout()
      end
    end)
    local options = Settings.CreateSliderOptions(24, 64, 1)
    Settings.CreateSlider(category, setting, options, tooltip)
  end

  -- QuickBar alpha
  do
    local variable = "BarSmith_QB_Alpha"
    local name = "QuickBar Alpha"
    local tooltip = "Adjust the transparency of the QuickBar."
    local setting = Settings.RegisterAddOnSetting(category, variable, variable, settingsProxy, "number", name, 1)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.quickBar.alpha = math.max(0.1, math.min(1, val))
      local quickBar = BarSmith:GetModule("QuickBar")
      if quickBar then
        quickBar:UpdateBackdropVisibility()
      end
    end)
    local options = Settings.CreateSliderOptions(0.1, 1, 0.05)
    Settings.CreateSlider(category, setting, options, tooltip)
  end

  -- QuickBar backdrop
  do
    local variable = "BarSmith_QB_ShowBackdrop"
    local name = "QuickBar Background"
    local tooltip = "Show or hide the QuickBar background and border."
    local setting = Settings.RegisterAddOnSetting(category, variable, variable, settingsProxy, "boolean", name, true)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.quickBar.showBackdrop = (val == true)
      local quickBar = BarSmith:GetModule("QuickBar")
      if quickBar then
        quickBar:UpdateBackdropVisibility()
      end
    end)
    Settings.CreateCheckbox(category, setting, tooltip)
  end

  ---------- Modules ----------
  layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Modules"))

  for key, label in pairs(moduleLabels) do
    local variable = "BarSmith_Mod_" .. key
    local setting = Settings.RegisterAddOnSetting(category, variable, variable, settingsProxy, "boolean", label, true)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.modules[key] = val
      BarSmith:FireCallback("SETTINGS_CHANGED")
    end)
    Settings.CreateCheckbox(category, setting, "Enable or disable the " .. label .. " module.")
  end

  ---------- Consumable Options ----------
  layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Combined Consumables Filters"))

  do
    local variable = "BarSmith_Con_CurrentOnly"
    local name = "Current Expansion Only"
    local tooltip = "Only include consumables from the current expansion."
    local setting = Settings.RegisterAddOnSetting(category, variable, variable, settingsProxy, "boolean", name, false)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.consumables.currentExpansionOnly = val
      BarSmith:FireCallback("SETTINGS_CHANGED")
    end)
    Settings.CreateCheckbox(category, setting, tooltip)
  end

  do
    local variable = "BarSmith_Con_Potions"
    local name = "Potions (All)"
    local tooltip = "Include potions in the combined Consumables flyout."
    local setting = Settings.RegisterAddOnSetting(category, variable, variable, settingsProxy, "boolean", name, true)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.consumables.potions = val
      BarSmith:FireCallback("SETTINGS_CHANGED")
    end)
    Settings.CreateCheckbox(category, setting, tooltip)
  end

  do
    local variable = "BarSmith_Con_Flasks"
    local name = "Flasks / Elixirs"
    local tooltip = "Include flasks and elixirs in the combined Consumables flyout."
    local setting = Settings.RegisterAddOnSetting(category, variable, variable, settingsProxy, "boolean", name, true)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.consumables.flasks = val
      BarSmith:FireCallback("SETTINGS_CHANGED")
    end)
    Settings.CreateCheckbox(category, setting, tooltip)
  end

  do
    local variable = "BarSmith_Con_Food"
    local name = "Food / Drink"
    local tooltip = "Include food and drink in the combined Consumables flyout."
    local setting = Settings.RegisterAddOnSetting(category, variable, variable, settingsProxy, "boolean", name, true)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.consumables.food = val
      BarSmith:FireCallback("SETTINGS_CHANGED")
    end)
    Settings.CreateCheckbox(category, setting, tooltip)
  end

  do
    local variable = "BarSmith_Con_Bandages"
    local name = "Bandages"
    local tooltip = "Include bandages in the combined Consumables flyout."
    local setting = Settings.RegisterAddOnSetting(category, variable, variable, settingsProxy, "boolean", name, true)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.consumables.bandages = val
      BarSmith:FireCallback("SETTINGS_CHANGED")
    end)
    Settings.CreateCheckbox(category, setting, tooltip)
  end

  do
    local variable = "BarSmith_Con_Utilities"
    local name = "Utilities"
    local tooltip = "Include utility consumables (drums, runes, etc.) in the combined Consumables flyout."
    local setting = Settings.RegisterAddOnSetting(category, variable, variable, settingsProxy, "boolean", name, true)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.consumables.utilities = val
      BarSmith:FireCallback("SETTINGS_CHANGED")
    end)
    Settings.CreateCheckbox(category, setting, tooltip)
  end

  ---------- Consumables ----------
  layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Consumables Module Split"))

  do
    local variable = "BarSmith_Con_Split_Potions"
    local name = "Split: Potions (All) Button"
    local tooltip = "Create a dedicated Potions button and remove them from the parent Consumables flyout."
    local setting = Settings.RegisterAddOnSetting(category, variable, variable, settingsProxy, "boolean", name, false)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.consumables.split.potions = val
      BarSmith:FireCallback("SETTINGS_CHANGED")
    end)
    Settings.CreateCheckbox(category, setting, tooltip)
  end

  do
    local variable = "BarSmith_Con_Split_Flasks"
    local name = "Split: Flasks / Elixirs Button"
    local tooltip = "Create a dedicated Flasks/Elixirs button and remove them from the parent Consumables flyout."
    local setting = Settings.RegisterAddOnSetting(category, variable, variable, settingsProxy, "boolean", name, false)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.consumables.split.flasks = val
      BarSmith:FireCallback("SETTINGS_CHANGED")
    end)
    Settings.CreateCheckbox(category, setting, tooltip)
  end

  do
    local variable = "BarSmith_Con_Split_Food"
    local name = "Split: Food / Drink Button"
    local tooltip = "Create a dedicated Food/Drink button and remove them from the parent Consumables flyout."
    local setting = Settings.RegisterAddOnSetting(category, variable, variable, settingsProxy, "boolean", name, false)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.consumables.split.food = val
      BarSmith:FireCallback("SETTINGS_CHANGED")
    end)
    Settings.CreateCheckbox(category, setting, tooltip)
  end

  do
    local variable = "BarSmith_Con_Split_Bandages"
    local name = "Split: Bandages Button"
    local tooltip = "Create a dedicated Bandages button and remove them from the parent Consumables flyout."
    local setting = Settings.RegisterAddOnSetting(category, variable, variable, settingsProxy, "boolean", name, false)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.consumables.split.bandages = val
      BarSmith:FireCallback("SETTINGS_CHANGED")
    end)
    Settings.CreateCheckbox(category, setting, tooltip)
  end

  do
    local variable = "BarSmith_Con_Split_Utilities"
    local name = "Split: Utilities Button"
    local tooltip = "Create a dedicated Utilities button and remove them from the parent Consumables flyout."
    local setting = Settings.RegisterAddOnSetting(category, variable, variable, settingsProxy, "boolean", name, false)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.consumables.split.utilities = val
      BarSmith:FireCallback("SETTINGS_CHANGED")
    end)
    Settings.CreateCheckbox(category, setting, tooltip)
  end

  ---------- Mount Options ----------
  layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Mount Options"))

  do
    local variable = "BarSmith_Mounts_Random"
    local name = "Use Random Favorite Mount"
    local tooltip = "Place the 'Summon Random Favorite Mount' spell instead of individual mounts."
    local setting = Settings.RegisterAddOnSetting(category, variable, variable, settingsProxy, "boolean", name, true)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.mounts.randomMount = val
      BarSmith:FireCallback("SETTINGS_CHANGED")
    end)
    Settings.CreateCheckbox(category, setting, tooltip)
  end

  do
    local variable = "BarSmith_Mounts_TopFavs"
    local name = "Add Top 5 Favorite Mounts"
    local tooltip = "Also include your top 5 favorite mounts as individual buttons."
    local setting = Settings.RegisterAddOnSetting(category, variable, variable, settingsProxy, "boolean", name, false)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.mounts.topFavorites = val
      BarSmith:FireCallback("SETTINGS_CHANGED")
    end)
    Settings.CreateCheckbox(category, setting, tooltip)
  end

  ---------- Advanced ----------
  layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Advanced"))

  do
    local variable = "BarSmith_Debug"
    local name = "Debug Mode"
    local tooltip = "Print debug messages to chat."
    local setting = Settings.RegisterAddOnSetting(category, variable, variable, settingsProxy, "boolean", name, false)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.db.debug = val
    end)
    Settings.CreateCheckbox(category, setting, tooltip)
  end

  Settings.RegisterAddOnCategory(category)
end
