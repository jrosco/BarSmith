------------------------------------------------------------------------
-- BarSmith: Modules/MicroMenu.lua
-- Micro menu buttons for the BarSmith bar
------------------------------------------------------------------------

local SystemMenu = BarSmith:NewModule("SystemMenu")

SystemMenu.DEFAULT_ICON = "Interface\\Icons\\INV_Gizmo_Gear_01"

local MENU_ENTRIES = {
  {
    key = "character",
    label = "Character",
    buttonNames = { "CharacterMicroButton" },
    icon = "Interface\\Icons\\INV_Chest_Cloth_17",
    portraitUnit = "player",
  },
  {
    key = "spellbook",
    label = "Spellbook",
    buttonNames = { "SpellbookMicroButton" },
    icon = "Interface\\Icons\\INV_Misc_Book_09",
  },
  {
    key = "talents",
    label = "Talents",
    buttonNames = { "PlayerSpellsMicroButton", "TalentMicroButton" },
    icon = "Interface\\Icons\\Ability_Marksmanship",
  },
  {
    key = "professions",
    label = "Professions",
    buttonNames = { "ProfessionMicroButton", "ProfessionsMicroButton" },
    icon = "Interface\\Icons\\Trade_BlackSmithing",
  },
  {
    key = "achievements",
    label = "Achievements",
    buttonNames = { "AchievementMicroButton" },
    icon = "Interface\\Icons\\Achievement_Zone_Dalaran_01",
  },
  {
    key = "questlog",
    label = "Quest Log",
    buttonNames = { "QuestLogMicroButton" },
    icon = "Interface\\Icons\\INV_Misc_Book_07",
  },
  {
    key = "guild",
    label = "Guild",
    buttonNames = { "GuildMicroButton" },
    icon = "Interface\\Icons\\INV_Banner_03",
  },
  {
    key = "lfg",
    label = "Group Finder",
    buttonNames = { "LFDMicroButton", "LFGMicroButton" },
    icon = "Interface\\Icons\\INV_Misc_GroupLooking",
  },
  {
    key = "collections",
    label = "Collections",
    buttonNames = { "CollectionsMicroButton" },
    icon = "Interface\\Icons\\INV_Misc_Toy_02",
  },
  {
    key = "journal",
    label = "Adventure Guide",
    buttonNames = { "EJMicroButton" },
    icon = "Interface\\Icons\\INV_Misc_Book_11",
  },
  {
    key = "store",
    label = "Shop",
    buttonNames = { "StoreMicroButton" },
    icon = "Interface\\Icons\\INV_Misc_Coin_01",
  },
  {
    key = "help",
    label = "Help",
    buttonNames = { "HelpMicroButton" },
    icon = "Interface\\Icons\\INV_Misc_QuestionMark",
  },
}

local MICRO_BUTTON_NAMES = {
  "CharacterMicroButton",
  "SpellbookMicroButton",
  "PlayerSpellsMicroButton",
  "TalentMicroButton",
  "ProfessionMicroButton",
  "ProfessionsMicroButton",
  "AchievementMicroButton",
  "QuestLogMicroButton",
  "GuildMicroButton",
  "LFDMicroButton",
  "LFGMicroButton",
  "CollectionsMicroButton",
  "EJMicroButton",
  "StoreMicroButton",
  "HelpMicroButton",
}

local function ResolveMicroButton(entry)
  for _, name in ipairs(entry.buttonNames or {}) do
    local btn = _G[name]
    if btn then
      return btn, name
    end
  end
  return nil, nil
end

local function GetButtonIcon(btn, fallbackIcon)
  if btn and btn.GetNormalTexture then
    local tex = btn:GetNormalTexture()
    if tex then
      local atlas = tex.GetAtlas and tex:GetAtlas() or nil
      local texture = tex:GetTexture()
      if atlas then
        return nil, atlas
      end
      if texture then
        return texture, nil
      end
    end
  end
  return fallbackIcon, nil
end

local function CollectMicroMenuContainers()
  local frames = {}
  if MicroButtonAndBagsBar then
    if MicroButtonAndBagsBar.MicroMenu then
      table.insert(frames, MicroButtonAndBagsBar.MicroMenu)
    end
    if MicroButtonAndBagsBar.MicroMenuContainer then
      table.insert(frames, MicroButtonAndBagsBar.MicroMenuContainer)
    end
    if MicroButtonAndBagsBar.MicroButtonContainer then
      table.insert(frames, MicroButtonAndBagsBar.MicroButtonContainer)
    end
  end
  if MainMenuBarMicroButtons then
    table.insert(frames, MainMenuBarMicroButtons)
  end
  if MicroMenu then
    table.insert(frames, MicroMenu)
  end
  return frames
end

function SystemMenu:UpdateDefaultMenuVisibility()
  if not BarSmith.chardb or not BarSmith.chardb.modules then
    return
  end

  local hide = BarSmith.chardb.systemMenu
    and BarSmith.chardb.systemMenu.hideDefault == true
    and BarSmith.chardb.modules.systemMenu == true

  if InCombatLockdown() then
    self._pendingVisibility = true
    if not self._eventFrame then
      self._eventFrame = CreateFrame("Frame")
      self._eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
      self._eventFrame:SetScript("OnEvent", function()
        if self._pendingVisibility then
          self._pendingVisibility = nil
          self:UpdateDefaultMenuVisibility()
        end
      end)
    end
    return
  end

  if hide then
    if self._hiddenState then
      return
    end
    self._hiddenState = { containers = {}, buttons = {} }
    for _, frame in ipairs(CollectMicroMenuContainers()) do
      if frame and frame.IsShown then
        self._hiddenState.containers[frame] = frame:IsShown()
        frame:Hide()
      end
    end
    for _, name in ipairs(MICRO_BUTTON_NAMES) do
      local btn = _G[name]
      if btn and btn.IsShown then
        self._hiddenState.buttons[name] = btn:IsShown()
        btn:Hide()
      end
    end
  else
    if not self._hiddenState then
      return
    end
    for frame, wasShown in pairs(self._hiddenState.containers or {}) do
      if wasShown and frame and frame.Show then
        frame:Show()
      end
    end
    for name, wasShown in pairs(self._hiddenState.buttons or {}) do
      if wasShown then
        local btn = _G[name]
        if btn and btn.Show then
          btn:Show()
        end
      end
    end
    self._hiddenState = nil
  end
end

function SystemMenu:Init()
  self:UpdateDefaultMenuVisibility()
  C_Timer.After(1, function()
    SystemMenu:UpdateDefaultMenuVisibility()
  end)

  if not self._eventFrame then
    local f = CreateFrame("Frame")
    f:RegisterEvent("UNIT_PORTRAIT_UPDATE")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", function(_, event, unit)
      if event == "UNIT_PORTRAIT_UPDATE" and unit ~= "player" then
        return
      end
      SystemMenu:RefreshPortraits()
    end)
    self._eventFrame = f
  end
  self:RefreshPortraits()
end

function SystemMenu:GetItems()
  local items = {}

  if not BarSmith.chardb or not BarSmith.chardb.modules or not BarSmith.chardb.modules.systemMenu then
    return items
  end

  for _, entry in ipairs(MENU_ENTRIES) do
    local btn, buttonName = ResolveMicroButton(entry)
    if buttonName then
      local icon, atlas = GetButtonIcon(btn, entry.icon or SystemMenu.DEFAULT_ICON)
      local data = {
        name = entry.label,
        type = "macro",
        macrotext = "/click " .. buttonName,
        icon = icon or SystemMenu.DEFAULT_ICON,
        noPromote = true,
      }
      if entry.portraitUnit then
        data.portraitUnit = entry.portraitUnit
      end
      if atlas then
        data.iconAtlas = atlas
        data.icon = nil
      end
      table.insert(items, data)
    end
  end

  BarSmith:Debug("Micro menu entries: " .. #items)
  return items
end

function SystemMenu:RefreshPortraits()
  if not BarSmith.chardb or not BarSmith.chardb.modules or not BarSmith.chardb.modules.systemMenu then
    return
  end
  local barFrame = BarSmith:GetModule("BarFrame")
  if not barFrame or not barFrame.buttons or not barFrame.ApplyButtonVisuals then
    return
  end

  local function updateButton(btn)
    if btn and btn.itemData and btn.itemData.portraitUnit then
      barFrame:ApplyButtonVisuals(btn, btn.itemData)
    end
  end

  for _, btn in ipairs(barFrame.buttons) do
    updateButton(btn)
    for _, childBtn in ipairs(btn.flyoutButtons or {}) do
      updateButton(childBtn)
    end
  end
end
