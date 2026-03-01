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
local defaultsChar = BarSmith.DEFAULTS and BarSmith.DEFAULTS.char or {}
local defaultsGlobal = BarSmith.DEFAULTS and BarSmith.DEFAULTS.global or {}

local MODULE_LABELS = {
  questItems   = "Quest Items",
  consumables  = "Consumables (Potions, Food, Flasks)",
  trinkets     = "Trinkets",
  classSpells  = "Class Special Spells",
  professions  = "Professions",
  mounts       = "Mounts",
  toys         = "Toys",
  hearthstones = "Hearthstones",
  macros       = "Macros",
}

function BarSmith:UpdateSettingsProxy(key, value)
  if not key then return end
  settingsProxy[key] = value
end

function BarSmith:RefreshSettingsProxy()
  if not BarSmith.chardb then return end

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
  settingsProxy["BarSmith_Tooltip_Mod"]       = BarSmith.chardb.tooltipModifier or "NONE"
  settingsProxy["BarSmith_HideEmptyModules"]  = (BarSmith.chardb.hideEmptyModules ~= false)
  settingsProxy["BarSmith_QB_Enabled"]        = (BarSmith.chardb.quickBar.enabled ~= false)
  settingsProxy["BarSmith_QB_IconSize"]       = BarSmith.chardb.quickBar.iconSize or 32
  settingsProxy["BarSmith_QB_Columns"]        = BarSmith.chardb.quickBar.columns or 6
  settingsProxy["BarSmith_QB_Alpha"]          = BarSmith.chardb.quickBar.alpha or 1
  settingsProxy["BarSmith_QB_ShowBackdrop"]   = (BarSmith.chardb.quickBar.showBackdrop ~= false)
  settingsProxy["BarSmith_QB_Tooltip_Mod"]    = BarSmith.chardb.quickBar.tooltipModifier or "NONE"
  settingsProxy["BarSmith_QB_Preview"]        = false
  settingsProxy["BarSmith_Masque"]            = (BarSmith.chardb.masqueEnabled == true)
  settingsProxy["BarSmith_Mounts_Random"]     = BarSmith.chardb.mounts.randomMount
  settingsProxy["BarSmith_Mounts_TopFavs"]    = BarSmith.chardb.mounts.topFavorites
  settingsProxy["BarSmith_Debug"]             = BarSmith.db and BarSmith.db.debug
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
  settingsProxy["BarSmith_Con_SplitCur_Potions"] = BarSmith.chardb.consumables.splitCurrentExpansion.potions
  settingsProxy["BarSmith_Con_SplitCur_Flasks"]  = BarSmith.chardb.consumables.splitCurrentExpansion.flasks
  settingsProxy["BarSmith_Con_SplitCur_Food"]    = BarSmith.chardb.consumables.splitCurrentExpansion.food
  settingsProxy["BarSmith_Con_SplitCur_Bandages"]= BarSmith.chardb.consumables.splitCurrentExpansion.bandages
  settingsProxy["BarSmith_Con_SplitCur_Utilities"]= BarSmith.chardb.consumables.splitCurrentExpansion.utilities
  settingsProxy["BarSmith_Filter_BGOnly"] = BarSmith.chardb.filters and BarSmith.chardb.filters.battleground_only_items ~= false

  for key in pairs(MODULE_LABELS) do
    settingsProxy["BarSmith_Mod_" .. key] = BarSmith.chardb.modules[key]
  end

  BarSmith:Debug("Settings proxy refreshed.")
end

local function BuildDirectionDropdownOptions()
  local container = Settings.CreateControlTextContainer()
  container:Add("TOP", "Top")
  container:Add("BOTTOM", "Bottom")
  container:Add("LEFT", "Left")
  container:Add("RIGHT", "Right")
  return container:GetData()
end

local function BuildTooltipModifierOptions()
  local container = Settings.CreateControlTextContainer()
  container:Add("NONE", "None")
  container:Add("ALT", "Alt")
  container:Add("SHIFT", "Shift")
  container:Add("CTRL", "Ctrl")
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
  local quickBarCategory, quickBarLayout      = Settings.RegisterVerticalLayoutSubcategory(category, "QuickBar")
  local modulesCategory, modulesLayout        = Settings.RegisterVerticalLayoutSubcategory(category, "Modules")
  local filtersCategory, filtersLayout        = Settings.RegisterVerticalLayoutSubcategory(category, "Filters")
  local mountCategory, mountLayout            = Settings.RegisterVerticalLayoutSubcategory(category, "Mounts")
  local advancedCategory, advancedLayout      = Settings.RegisterVerticalLayoutSubcategory(category, "Advanced")

  if not self._settingsChangedHooked then
    BarSmith:RegisterCallback("SETTINGS_CHANGED", self, self.OnSettingsChanged)
    self._settingsChangedHooked = true
  end

  -- Seed proxy with current values
  BarSmith:RefreshSettingsProxy()

  ---------- General ----------
  layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("General"))

  -- Enable addon
  do
    local variable = "BarSmith_Enabled"
    local name = "Enable BarSmith"
    local tooltip = "Toggle the ActionBar on or off for this character."
    local defaultValue = defaultsChar.enabled ~= false
    local setting = Settings.RegisterAddOnSetting(category, variable, variable, settingsProxy, "boolean", name,
    defaultValue)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.enabled = val
      local barFrame = BarSmith:GetModule("BarFrame")
      if not val then
        if barFrame and barFrame.Hide then
          barFrame:Hide()
        end
      else
        if barFrame and barFrame.Show then
          barFrame:Show()
        end
      end
      BarSmith:FireCallback("SETTINGS_CHANGED")
    end)
    Settings.CreateCheckbox(category, setting, tooltip)
  end

  -- Minimap icon
  do
    local variable = "BarSmith_Minimap_Show"
    local name = "Show Minimap Icon"
    local tooltip = "Show or hide the BarSmith minimap icon."
    local defaultValue = not (defaultsGlobal.minimap and defaultsGlobal.minimap.hide == true)
    local setting = Settings.RegisterProxySetting(category, variable, "boolean", name, defaultValue,
      function()
        return not (BarSmith.db and BarSmith.db.minimap and BarSmith.db.minimap.hide)
      end,
      function(value)
        if not BarSmith.db or not BarSmith.db.minimap then return end
        BarSmith.db.minimap.hide = not value
        local minimapMod = BarSmith:GetModule("Minimap")
        if minimapMod and minimapMod.Init then
          minimapMod:Init()
        end
        if minimapMod and minimapMod.UpdateButton then
          minimapMod:UpdateButton()
        end
      end)
    Settings.CreateCheckbox(category, setting, tooltip)
  end

  -- Hide empty module placeholders
  do
    local variable = "BarSmith_HideEmptyModules"
    local name = "Hide Empty Categories"
    local tooltip = "Hide placeholder buttons for enabled modules that have no items."
    local defaultValue = defaultsChar.hideEmptyModules ~= false
    local setting = Settings.RegisterAddOnSetting(category, variable, variable, settingsProxy, "boolean", name,
    defaultValue)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.hideEmptyModules = (val == true)
      local placer = BarSmith:GetModule("ActionBarPlacer")
      if placer then
        placer:Fill(true)
      end
    end)
    Settings.CreateCheckbox(category, setting, tooltip)
  end

  -- Auto-fill on events
  do
    local variable = "BarSmith_AutoFill"
    local name = "Auto-Fill on Login/Zone Change"
    local tooltip = "Automatically scan and place items when you log in, change zones, or update your bags."
    local defaultValue = defaultsChar.autoFill == true
    local setting = Settings.RegisterAddOnSetting(category, variable, variable, settingsProxy, "boolean", name,
    defaultValue)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.autoFill = val
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
    local defaultValue = defaultsChar.barLocked == true
    local setting = Settings.RegisterAddOnSetting(category, variable, variable, settingsProxy, "boolean", name,
    defaultValue)
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
    local defaultValue = defaultsChar.barColumns or 12
    local setting = Settings.RegisterAddOnSetting(category, variable, variable, settingsProxy, "number", name,
    defaultValue)
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
    local defaultValue = defaultsChar.barIconSize or 36
    local setting = Settings.RegisterAddOnSetting(category, variable, variable, settingsProxy, "number", name,
    defaultValue)
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
    local defaultValue = defaultsChar.barAlpha or 1
    local setting = Settings.RegisterAddOnSetting(category, variable, variable, settingsProxy, "number", name,
    defaultValue)
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
    local defaultValue = defaultsChar.barShowBackdrop ~= false
    local setting = Settings.RegisterAddOnSetting(category, variable, variable, settingsProxy, "boolean", name,
    defaultValue)
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
    local defaultValue = defaultsChar.barAutoHideMouseover == true
    local setting = Settings.RegisterAddOnSetting(category, variable, variable, settingsProxy, "boolean", name,
    defaultValue)
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
    local defaultValue = defaultsChar.flyoutDirection or "TOP"
    local setting = Settings.RegisterAddOnSetting(category, variable, variable, settingsProxy, "string", name,
    defaultValue)
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

  -- Tooltip modifier (main bar)
  do
    local variable = "BarSmith_Tooltip_Mod"
    local name = "Tooltip Modifier"
    local tooltip = "Only show BarSmith tooltips when this modifier is held."
    local defaultValue = defaultsChar.tooltipModifier or "NONE"
    local setting = Settings.RegisterAddOnSetting(category, variable, variable, settingsProxy, "string", name,
    defaultValue)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      local mod = string.upper(tostring(val or "NONE"))
      if mod ~= "ALT" and mod ~= "SHIFT" and mod ~= "CTRL" and mod ~= "NONE" then
        mod = "NONE"
      end
      BarSmith.chardb.tooltipModifier = mod
      settingsProxy[variable] = mod
    end)
    Settings.CreateDropdown(category, setting, BuildTooltipModifierOptions, tooltip)
  end

  ---------- QuickBar ----------
  -- quickBarLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("QuickBar"))

  -- Enable QuickBar
  do
    local variable = "BarSmith_QB_Enabled"
    local name = "Enable QuickBar"
    local tooltip = "Enable a dedicated QuickBar toggle that will show or hide the QuickBar at cursor position.\n\nRequires a keybind: Esc -> Options -> Keybindings -> Others -> BarSmith"
    local defaultValue = defaultsChar.quickBar and defaultsChar.quickBar.enabled ~= false
    local setting = Settings.RegisterAddOnSetting(quickBarCategory, variable, variable, settingsProxy, "boolean",
    name, defaultValue)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.quickBar.enabled = (val == true)
      local quickBar = BarSmith:GetModule("QuickBar")
      if quickBar then
        quickBar:UpdateToggleState()
      end
    end)
    Settings.CreateCheckbox(quickBarCategory, setting, tooltip)
  end

  -- QuickBar columns
  do
    local variable = "BarSmith_QB_Columns"
    local name = "QuickBar Columns"
    local tooltip = "Number of buttons per row on the QuickBar."
    local defaultValue = defaultsChar.quickBar and defaultsChar.quickBar.columns or 6
    local setting = Settings.RegisterAddOnSetting(quickBarCategory, variable, variable, settingsProxy, "number", name,
    defaultValue)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.quickBar.columns = math.max(1, math.min(12, val))
      local quickBar = BarSmith:GetModule("QuickBar")
      if quickBar then
        quickBar:UpdateLayout()
      end
    end)
    local options = Settings.CreateSliderOptions(1, 12, 1)
    Settings.CreateSlider(quickBarCategory, setting, options, tooltip)
  end

  -- QuickBar icon size
  do
    local variable = "BarSmith_QB_IconSize"
    local name = "QuickBar Icon Size"
    local tooltip = "Button/icon size in pixels for the QuickBar."
    local defaultValue = defaultsChar.quickBar and defaultsChar.quickBar.iconSize or 32
    local setting = Settings.RegisterAddOnSetting(quickBarCategory, variable, variable, settingsProxy, "number", name,
    defaultValue)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.quickBar.iconSize = math.max(24, math.min(64, val))
      local quickBar = BarSmith:GetModule("QuickBar")
      if quickBar then
        quickBar:UpdateLayout()
      end
    end)
    local options = Settings.CreateSliderOptions(24, 64, 1)
    Settings.CreateSlider(quickBarCategory, setting, options, tooltip)
  end

  -- QuickBar alpha
  do
    local variable = "BarSmith_QB_Alpha"
    local name = "QuickBar Alpha"
    local tooltip = "Adjust the transparency of the QuickBar."
    local defaultValue = defaultsChar.quickBar and defaultsChar.quickBar.alpha or 1
    local setting = Settings.RegisterAddOnSetting(quickBarCategory, variable, variable, settingsProxy, "number", name,
    defaultValue)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.quickBar.alpha = math.max(0.1, math.min(1, val))
      local quickBar = BarSmith:GetModule("QuickBar")
      if quickBar then
        quickBar:UpdateBackdropVisibility()
      end
    end)
    local options = Settings.CreateSliderOptions(0.1, 1, 0.05)
    Settings.CreateSlider(quickBarCategory, setting, options, tooltip)
  end

  -- QuickBar backdrop
  do
    local variable = "BarSmith_QB_ShowBackdrop"
    local name = "QuickBar Background"
    local tooltip = "Show or hide the QuickBar background and border."
    local defaultValue = defaultsChar.quickBar and defaultsChar.quickBar.showBackdrop ~= false
    local setting = Settings.RegisterAddOnSetting(quickBarCategory, variable, variable, settingsProxy, "boolean", name,
    defaultValue)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.quickBar.showBackdrop = (val == true)
      local quickBar = BarSmith:GetModule("QuickBar")
      if quickBar then
        quickBar:UpdateBackdropVisibility()
      end
    end)
    Settings.CreateCheckbox(quickBarCategory, setting, tooltip)
  end

  -- QuickBar preview
  do
    local variable = "BarSmith_QB_Preview"
    local name = "Preview QuickBar"
    local tooltip = "Show the QuickBar while adjusting layout and appearance."
    local defaultValue = false
    local setting = Settings.RegisterAddOnSetting(quickBarCategory, variable, variable, settingsProxy, "boolean", name,
    defaultValue)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      local quickBar = BarSmith:GetModule("QuickBar")
      if quickBar then
        if val == true then
          quickBar:ShowPreview()
        else
          quickBar:HidePreview()
        end
      end
    end)
    Settings.CreateCheckbox(quickBarCategory, setting, tooltip)
  end

  -- QuickBar tooltip modifier
  do
    local variable = "BarSmith_QB_Tooltip_Mod"
    local name = "Tooltip Modifier (QuickBar)"
    local tooltip = "Only show QuickBar tooltips when this modifier is held."
    local defaultValue = defaultsChar.quickBar and defaultsChar.quickBar.tooltipModifier or "NONE"
    local setting = Settings.RegisterAddOnSetting(quickBarCategory, variable, variable, settingsProxy, "string", name,
      defaultValue)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      local mod = string.upper(tostring(val or "NONE"))
      if mod ~= "ALT" and mod ~= "SHIFT" and mod ~= "CTRL" and mod ~= "NONE" then
        mod = "NONE"
      end
      BarSmith.chardb.quickBar.tooltipModifier = mod
      settingsProxy[variable] = mod
    end)
    Settings.CreateDropdown(quickBarCategory, setting, BuildTooltipModifierOptions, tooltip)
  end

  ---------- Modules ----------

  -- modulesLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Modules"))

  for key, label in pairs(MODULE_LABELS) do
    local variable = "BarSmith_Mod_" .. key
    local defaultValue = true
    if BarSmith.DEFAULTS and BarSmith.DEFAULTS.char and BarSmith.DEFAULTS.char.modules then
      defaultValue = (BarSmith.DEFAULTS.char.modules[key] == true)
    end
    local setting = Settings.RegisterAddOnSetting(modulesCategory, variable, variable, settingsProxy, "boolean", label,
    defaultValue)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.modules[key] = val
      BarSmith:FireCallback("SETTINGS_CHANGED")
      -- Allow toys to load and wait before trying to enable the module
      if key == "toys" and val == true then
        C_Timer.After(1.5, function()
          if not BarSmith.chardb or not BarSmith.chardb.modules
            or BarSmith.chardb.modules.toys ~= true then
            return
          end
          if not InCombatLockdown() then
            BarSmith:RunAutoFill(true)
          end
        end)
      end
    end)
    Settings.CreateCheckbox(modulesCategory, setting, "Enable or disable the " .. label .. " module.")
  end

  ---------- Module Split ----------
  modulesLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Consumables Module Split"))

  do
    local variable = "BarSmith_Con_Split_Potions"
    local name = "Split: Potions (All) Button"
    local tooltip = "Create a dedicated Potions button and remove them from the parent Consumables flyout."
    local defaultValue = defaultsChar.consumables and defaultsChar.consumables.split and
    defaultsChar.consumables.split.potions == true
    local setting = Settings.RegisterAddOnSetting(modulesCategory, variable, variable, settingsProxy, "boolean", name,
      defaultValue)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.consumables.split.potions = val
      BarSmith:FireCallback("SETTINGS_CHANGED")
    end)
    Settings.CreateCheckbox(modulesCategory, setting, tooltip)
  end

  do
    local variable = "BarSmith_Con_Split_Flasks"
    local name = "Split: Flasks / Elixirs Button"
    local tooltip = "Create a dedicated Flasks/Elixirs button and remove them from the parent Consumables flyout."
    local defaultValue = defaultsChar.consumables and defaultsChar.consumables.split and
    defaultsChar.consumables.split.flasks == true
    local setting = Settings.RegisterAddOnSetting(modulesCategory, variable, variable, settingsProxy, "boolean", name,
      defaultValue)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.consumables.split.flasks = val
      BarSmith:FireCallback("SETTINGS_CHANGED")
    end)
    Settings.CreateCheckbox(modulesCategory, setting, tooltip)
  end

  do
    local variable = "BarSmith_Con_Split_Food"
    local name = "Split: Food / Drink Button"
    local tooltip = "Create a dedicated Food/Drink button and remove them from the parent Consumables flyout."
    local defaultValue = defaultsChar.consumables and defaultsChar.consumables.split and
    defaultsChar.consumables.split.food == true
    local setting = Settings.RegisterAddOnSetting(modulesCategory, variable, variable, settingsProxy, "boolean", name,
      defaultValue)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.consumables.split.food = val
      BarSmith:FireCallback("SETTINGS_CHANGED")
    end)
    Settings.CreateCheckbox(modulesCategory, setting, tooltip)
  end

  do
    local variable = "BarSmith_Con_Split_Bandages"
    local name = "Split: Bandages Button"
    local tooltip = "Create a dedicated Bandages button and remove them from the parent Consumables flyout."
    local defaultValue = defaultsChar.consumables and defaultsChar.consumables.split and
    defaultsChar.consumables.split.bandages == true
    local setting = Settings.RegisterAddOnSetting(modulesCategory, variable, variable, settingsProxy, "boolean", name,
      defaultValue)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.consumables.split.bandages = val
      BarSmith:FireCallback("SETTINGS_CHANGED")
    end)
    Settings.CreateCheckbox(modulesCategory, setting, tooltip)
  end

  do
    local variable = "BarSmith_Con_Split_Utilities"
    local name = "Split: Utilities Button"
    local tooltip = "Create a dedicated Utilities button and remove them from the parent Consumables flyout."
    local defaultValue = defaultsChar.consumables and defaultsChar.consumables.split and
    defaultsChar.consumables.split.utilities == true
    local setting = Settings.RegisterAddOnSetting(modulesCategory, variable, variable, settingsProxy, "boolean", name,
      defaultValue)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.consumables.split.utilities = val
      BarSmith:FireCallback("SETTINGS_CHANGED")
    end)
    Settings.CreateCheckbox(modulesCategory, setting, tooltip)
  end

  ---------- Consumable Options ----------
  filtersLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Combined Consumables Module Filters"))

  do
    local variable = "BarSmith_Con_CurrentOnly"
    local name = "Current Expansion Only"
    local tooltip = "Only include consumables from the current expansion."
    local defaultValue = defaultsChar.consumables and defaultsChar.consumables.currentExpansionOnly == true
    local setting = Settings.RegisterAddOnSetting(filtersCategory, variable, variable, settingsProxy, "boolean", name,
    defaultValue)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.consumables.currentExpansionOnly = val
      BarSmith:FireCallback("SETTINGS_CHANGED")
    end)
    Settings.CreateCheckbox(filtersCategory, setting, tooltip)
  end

  do
    local variable = "BarSmith_Con_Potions"
    local name = "Potions (All)"
    local tooltip = "Include potions in the combined Consumables flyout."
    local defaultValue = defaultsChar.consumables and defaultsChar.consumables.potions ~= false
    local setting = Settings.RegisterAddOnSetting(filtersCategory, variable, variable, settingsProxy, "boolean", name,
    defaultValue)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.consumables.potions = val
      BarSmith:FireCallback("SETTINGS_CHANGED")
    end)
    Settings.CreateCheckbox(filtersCategory, setting, tooltip)
  end

  do
    local variable = "BarSmith_Con_Flasks"
    local name = "Flasks / Elixirs"
    local tooltip = "Include flasks and elixirs in the combined Consumables flyout."
    local defaultValue = defaultsChar.consumables and defaultsChar.consumables.flasks ~= false
    local setting = Settings.RegisterAddOnSetting(filtersCategory, variable, variable, settingsProxy, "boolean", name,
    defaultValue)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.consumables.flasks = val
      BarSmith:FireCallback("SETTINGS_CHANGED")
    end)
    Settings.CreateCheckbox(filtersCategory, setting, tooltip)
  end

  do
    local variable = "BarSmith_Con_Food"
    local name = "Food / Drink"
    local tooltip = "Include food and drink in the combined Consumables flyout."
    local defaultValue = defaultsChar.consumables and defaultsChar.consumables.food ~= false
    local setting = Settings.RegisterAddOnSetting(filtersCategory, variable, variable, settingsProxy, "boolean", name,
    defaultValue)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.consumables.food = val
      BarSmith:FireCallback("SETTINGS_CHANGED")
    end)
    Settings.CreateCheckbox(filtersCategory, setting, tooltip)
  end

  do
    local variable = "BarSmith_Con_Bandages"
    local name = "Bandages"
    local tooltip = "Include bandages in the combined Consumables flyout."
    local defaultValue = defaultsChar.consumables and defaultsChar.consumables.bandages ~= false
    local setting = Settings.RegisterAddOnSetting(filtersCategory, variable, variable, settingsProxy, "boolean", name,
    defaultValue)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.consumables.bandages = val
      BarSmith:FireCallback("SETTINGS_CHANGED")
    end)
    Settings.CreateCheckbox(filtersCategory, setting, tooltip)
  end

  do
    local variable = "BarSmith_Con_Utilities"
    local name = "Utilities"
    local tooltip = "Include utility consumables (drums, runes, etc.) in the combined Consumables flyout."
    local defaultValue = defaultsChar.consumables and defaultsChar.consumables.utilities ~= false
    local setting = Settings.RegisterAddOnSetting(filtersCategory, variable, variable, settingsProxy, "boolean", name,
    defaultValue)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.consumables.utilities = val
      BarSmith:FireCallback("SETTINGS_CHANGED")
    end)
    Settings.CreateCheckbox(filtersCategory, setting, tooltip)
  end

  filtersLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Consumables Split Module Filters"))

  do
    local variable = "BarSmith_Con_SplitCur_Potions"
    local name = "Current Expansion Only (Potions)"
    local tooltip = "Limit the Potions split button to current expansion items."
    local defaultValue = defaultsChar.consumables and defaultsChar.consumables.splitCurrentExpansion
      and defaultsChar.consumables.splitCurrentExpansion.potions == true
    local setting = Settings.RegisterAddOnSetting(filtersCategory, variable, variable, settingsProxy, "boolean", name,
    defaultValue)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.consumables.splitCurrentExpansion.potions = val
      BarSmith:FireCallback("SETTINGS_CHANGED")
    end)
    Settings.CreateCheckbox(filtersCategory, setting, tooltip)
  end

  do
    local variable = "BarSmith_Con_SplitCur_Flasks"
    local name = "Current Expansion Only (Flasks)"
    local tooltip = "Limit the Flasks/Elixirs split button to current expansion items."
    local defaultValue = defaultsChar.consumables and defaultsChar.consumables.splitCurrentExpansion
      and defaultsChar.consumables.splitCurrentExpansion.flasks == true
    local setting = Settings.RegisterAddOnSetting(filtersCategory, variable, variable, settingsProxy, "boolean", name,
    defaultValue)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.consumables.splitCurrentExpansion.flasks = val
      BarSmith:FireCallback("SETTINGS_CHANGED")
    end)
    Settings.CreateCheckbox(filtersCategory, setting, tooltip)
  end

  do
    local variable = "BarSmith_Con_SplitCur_Food"
    local name = "Current Expansion Only (Food)"
    local tooltip = "Limit the Food/Drink split button to current expansion items."
    local defaultValue = defaultsChar.consumables and defaultsChar.consumables.splitCurrentExpansion
      and defaultsChar.consumables.splitCurrentExpansion.food == true
    local setting = Settings.RegisterAddOnSetting(filtersCategory, variable, variable, settingsProxy, "boolean", name,
    defaultValue)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.consumables.splitCurrentExpansion.food = val
      BarSmith:FireCallback("SETTINGS_CHANGED")
    end)
    Settings.CreateCheckbox(filtersCategory, setting, tooltip)
  end

  do
    local variable = "BarSmith_Con_SplitCur_Bandages"
    local name = "Current Expansion Only (Bandages)"
    local tooltip = "Limit the Bandages split button to current expansion items."
    local defaultValue = defaultsChar.consumables and defaultsChar.consumables.splitCurrentExpansion
      and defaultsChar.consumables.splitCurrentExpansion.bandages == true
    local setting = Settings.RegisterAddOnSetting(filtersCategory, variable, variable, settingsProxy, "boolean", name,
    defaultValue)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.consumables.splitCurrentExpansion.bandages = val
      BarSmith:FireCallback("SETTINGS_CHANGED")
    end)
    Settings.CreateCheckbox(filtersCategory, setting, tooltip)
  end

  do
    local variable = "BarSmith_Con_SplitCur_Utilities"
    local name = "Current Expansion Only (Utilities)"
    local tooltip = "Limit the Utilities split button to current expansion items."
    local defaultValue = defaultsChar.consumables and defaultsChar.consumables.splitCurrentExpansion
      and defaultsChar.consumables.splitCurrentExpansion.utilities == true
    local setting = Settings.RegisterAddOnSetting(filtersCategory, variable, variable, settingsProxy, "boolean", name,
    defaultValue)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.consumables.splitCurrentExpansion.utilities = val
      BarSmith:FireCallback("SETTINGS_CHANGED")
    end)
    Settings.CreateCheckbox(filtersCategory, setting, tooltip)
  end

  ---------- Item Filters ----------
  filtersLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Item Filters"))

  do
    local variable = "BarSmith_Filter_BGOnly"
    local name = "Include Battleground-Only Items"
    local tooltip = "Include items with \"Only usable in battlegrounds\" even when you are not in a battleground."
    local defaultValue = defaultsChar.filters and defaultsChar.filters.battleground_only_items ~= false
    local setting = Settings.RegisterAddOnSetting(filtersCategory, variable, variable, settingsProxy, "boolean", name,
      defaultValue)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.filters.battleground_only_items = val
      BarSmith:SetFilterEnabled("battleground_only_items", val)
      BarSmith:FireCallback("SETTINGS_CHANGED")
    end)
    Settings.CreateCheckbox(filtersCategory, setting, tooltip)
  end

  ---------- Mount Options ----------

  mountLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Options"))

  do
    local variable = "BarSmith_Mounts_Random"
    local name = "Use Random Favorite Mount"
    local tooltip = "Place the 'Summon Random Favorite Mount' spell instead of individual mounts."
    local defaultValue = defaultsChar.mounts and defaultsChar.mounts.randomMount ~= false
    local setting = Settings.RegisterAddOnSetting(mountCategory, variable, variable, settingsProxy, "boolean", name,
    defaultValue)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.mounts.randomMount = val
      BarSmith:FireCallback("SETTINGS_CHANGED")
    end)
    Settings.CreateCheckbox(mountCategory, setting, tooltip)
  end

  do
    local variable = "BarSmith_Mounts_TopFavs"
    local name = "Add Top 5 Favorite Mounts"
    local tooltip = "Also include your top 5 favorite mounts as individual buttons."
    local defaultValue = defaultsChar.mounts and defaultsChar.mounts.topFavorites == true
    local setting = Settings.RegisterAddOnSetting(mountCategory, variable, variable, settingsProxy, "boolean", name,
    defaultValue)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.mounts.topFavorites = val
      BarSmith:FireCallback("SETTINGS_CHANGED")
    end)
    Settings.CreateCheckbox(mountCategory, setting, tooltip)
  end

  ---------- Advanced ----------

  advancedLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Advanced"))

  do
    local variable = "BarSmith_Masque"
    local name = "Enable Masque Skinning"
    local tooltip = "Allow Masque to skin BarSmith buttons (requires Masque)."
    local defaultValue = defaultsChar.masqueEnabled == true
    local setting = Settings.RegisterAddOnSetting(advancedCategory, variable, variable, settingsProxy, "boolean", name,
      defaultValue)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.masqueEnabled = (val == true)
      BarSmith:MasqueRefreshAll()
    end)
    Settings.CreateCheckbox(advancedCategory, setting, tooltip)
  end

  do
    local variable = "BarSmith_Confirm"
    local name = "Confirm Before Placing"
    local tooltip = "Show a confirmation popup before items are placed on the bar."
    local defaultValue = defaultsChar.confirmBeforeFill == true
    local setting = Settings.RegisterAddOnSetting(advancedCategory, variable, variable, settingsProxy, "boolean", name,
    defaultValue)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.chardb.confirmBeforeFill = val
    end)
    Settings.CreateCheckbox(advancedCategory, setting, tooltip)
  end

  do
    local variable = "BarSmith_Debug"
    local name = "Debug Mode"
    local tooltip = "Print debug messages to chat."
    local defaultValue = defaultsGlobal.debug == true
    local setting = Settings.RegisterAddOnSetting(advancedCategory, variable, variable, settingsProxy, "boolean", name,
      defaultValue)
    Settings.SetOnValueChangedCallback(variable, function(_, _, val)
      BarSmith.db.debug = val
    end)
    Settings.CreateCheckbox(advancedCategory, setting, tooltip)
  end

  advancedLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Actions"))

  do
    local initializer = Settings.CreateElementInitializer("BarSmithSettingsButtonTemplate", {
      text = "Refill Bar Now",
      buttonText = "Refill",
      OnClick = function()
        BarSmith:Print("Refill requested.")
        BarSmith:RunAutoFill(true)
      end,
    })
    advancedLayout:AddInitializer(initializer)
  end

  advancedLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Reset Settings"))

  do
    local initializer = Settings.CreateElementInitializer("BarSmithSettingsButtonTemplate", {
      text = "Reset All (Keep Includes/Excludes)",
      buttonText = "Reset Settings",
      OnClick = function()
        StaticPopupDialogs["BARSMITH_RESET_KEEP_LISTS"] = StaticPopupDialogs["BARSMITH_RESET_KEEP_LISTS"] or {
          text = "Reset all settings to defaults (includes/excludes will be preserved)?",
          button1 = "Yes",
          button2 = "No",
          OnAccept = function()
            BarSmith:ResetCharacterSettingsKeepLists()
          end,
          timeout = 0,
          whileDead = true,
          hideOnEscape = true,
          preferredIndex = 3,
        }
        StaticPopup_Show("BARSMITH_RESET_KEEP_LISTS")
      end,
    })
    advancedLayout:AddInitializer(initializer)
  end

  do
    local initializer = Settings.CreateElementInitializer("BarSmithSettingsButtonTemplate", {
      text = "Reset QuickBar",
      buttonText = "Reset QuickBar",
      OnClick = function()
        StaticPopupDialogs["BARSMITH_RESET_QUICKBAR"] = StaticPopupDialogs["BARSMITH_RESET_QUICKBAR"] or {
          text = "Reset QuickBar to defaults?",
          button1 = "Yes",
          button2 = "No",
          OnAccept = function()
            local quickBar = BarSmith:GetModule("QuickBar")
            if quickBar and quickBar.ResetDefaults then
              quickBar:ResetDefaults()
            else
              BarSmith:Print("QuickBar is not available.")
            end
          end,
          timeout = 0,
          whileDead = true,
          hideOnEscape = true,
          preferredIndex = 3,
        }
        StaticPopup_Show("BARSMITH_RESET_QUICKBAR")
      end,
    })
    advancedLayout:AddInitializer(initializer)
  end

  do
    local initializer = Settings.CreateElementInitializer("BarSmithSettingsButtonTemplate", {
      text = "Reset Includes",
      buttonText = "Clear Includes",
      OnClick = function()
        StaticPopupDialogs["BARSMITH_CLEAR_INCLUDE_FROM_SETTINGS"] = StaticPopupDialogs["BARSMITH_CLEAR_INCLUDE_FROM_SETTINGS"] or {
          text = "Clear all included items/spells?",
          button1 = "Yes",
          button2 = "No",
          OnAccept = function()
            BarSmith:ClearInclude()
            BarSmith:Print("Include list cleared.")
            BarSmith:FireCallback("SETTINGS_CHANGED")
          end,
          timeout = 0,
          whileDead = true,
          hideOnEscape = true,
          preferredIndex = 3,
        }
        StaticPopup_Show("BARSMITH_CLEAR_INCLUDE_FROM_SETTINGS")
      end,
    })
    advancedLayout:AddInitializer(initializer)
  end

  do
    local initializer = Settings.CreateElementInitializer("BarSmithSettingsButtonTemplate", {
      text = "Reset Excludes",
      buttonText = "Clear Excludes",
      OnClick = function()
        StaticPopupDialogs["BARSMITH_CLEAR_EXCLUDE_FROM_SETTINGS"] = StaticPopupDialogs["BARSMITH_CLEAR_EXCLUDE_FROM_SETTINGS"] or {
          text = "Clear all excluded items/spells?",
          button1 = "Yes",
          button2 = "No",
          OnAccept = function()
            if BarSmith.chardb then
              BarSmith.chardb.exclude = {}
            end
            BarSmith:Print("Exclude list cleared.")
            BarSmith:FireCallback("SETTINGS_CHANGED")
          end,
          timeout = 0,
          whileDead = true,
          hideOnEscape = true,
          preferredIndex = 3,
        }
        StaticPopup_Show("BARSMITH_CLEAR_EXCLUDE_FROM_SETTINGS")
      end,
    })
    advancedLayout:AddInitializer(initializer)
  end

  Settings.RegisterAddOnCategory(category)
end

function mod:OnSettingsChanged()
  BarSmith:RefreshSettingsProxy()
end
