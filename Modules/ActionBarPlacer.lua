------------------------------------------------------------------------
-- BarSmith: Modules/ActionBarPlacer.lua
-- Gathers items from all modules and assigns them to the dedicated
-- BarSmith bar via BarFrame:SetButton(). No native bar slots touched.
------------------------------------------------------------------------

local Placer = BarSmith:NewModule("ActionBarPlacer")

-- Throttle: prevent rapid re-fills
Placer.lastFillTime = 0
Placer.FILL_COOLDOWN = 2 -- seconds

------------------------------------------------------------------------
-- Main entry point: gather all items and place them
------------------------------------------------------------------------

function Placer:Fill(force)
  -- Guard: never during combat (SetAttribute is protected)
  if InCombatLockdown() then
    BarSmith:Print("Cannot update bar during combat. Will retry after.")
    BarSmith.pendingFill = true
    return
  end

  -- Throttle
  local now = GetTime()
  if not force and (now - self.lastFillTime) < self.FILL_COOLDOWN then
    return
  end
  self.lastFillTime = now

  -- Collect items from all enabled modules in priority order
  local allItems = self:GatherItems()
  local displayItems = self:BuildDisplayItems(allItems)
  self:UpdateModuleButtons(displayItems)

  -- Confirmation dialog
  if BarSmith.chardb.confirmBeforeFill and #displayItems > 0 then
    self:ShowConfirmation(displayItems)
    return
  end

  self:PlaceItems(displayItems)
end

function Placer:UpdateModuleButtons(displayItems)
  local barFrame = BarSmith:GetModule("BarFrame")
  if not barFrame then return end

  local modulePrimary = {}
  for _, item in ipairs(displayItems or {}) do
    local mod = item.module
    if mod then
      if item.isFlyoutGroup and item.primary then
        modulePrimary[mod] = item.primary
      else
        modulePrimary[mod] = item
      end
    end
  end

  barFrame:SetModuleButtons(modulePrimary)
end

------------------------------------------------------------------------
-- Gather items from modules in priority order
------------------------------------------------------------------------

function Placer:GatherItems()
  local allItems = {}
  local seen = {}
  local autoAddedKeys = {}
  local priority = (BarSmith.GetExpandedPriority and BarSmith:GetExpandedPriority()) or BarSmith.chardb.priority

  -- Map of module name -> getter function
  local getters = {
    questItems   = function() return BarSmith:GetModule("QuestItems"):GetItems() end,
    consumables  = function() return BarSmith:GetModule("Consumables"):GetItems() end,
    consumables_potions = function() return BarSmith:GetModule("Consumables"):GetItemsForCategory("potion") end,
    consumables_flask  = function() return BarSmith:GetModule("Consumables"):GetItemsForCategory("flask") end,
    consumables_food   = function() return BarSmith:GetModule("Consumables"):GetItemsForCategory("food") end,
    consumables_bandage= function() return BarSmith:GetModule("Consumables"):GetItemsForCategory("bandage") end,
    consumables_utility= function() return BarSmith:GetModule("Consumables"):GetItemsForCategory("utility") end,
    trinkets     = function() return BarSmith:GetModule("Trinkets"):GetItems() end,
    classSpells  = function() return BarSmith:GetModule("ClassSpells"):GetItems() end,
    professions  = function() return BarSmith:GetModule("Professions"):GetItems() end,
    mounts       = function() return BarSmith:GetModule("Mounts"):GetItems() end,
    toys         = function() return BarSmith:GetModule("Toys"):GetItems() end,
    hearthstones = function() return BarSmith:GetModule("Hearthstones"):GetItems() end,
    macros       = function() return BarSmith:GetModule("Macros"):GetItems() end,
  }

  local function isEnabled(modName)
    if modName:match("^consumables_") then
      return BarSmith.chardb.modules.consumables == true
    end
    return BarSmith.chardb.modules[modName]
  end

  for _, modName in ipairs(priority) do
    if isEnabled(modName) and getters[modName] then
      local ok, items = pcall(getters[modName])
      if ok and items then
        for _, item in ipairs(items) do
          if not BarSmith:IsExcluded(item) then
            local key = BarSmith:GetActionIdentityKey(item)
            local isAuto = not BarSmith:IsManualItem(item)
            item.autoAdded = isAuto
            if key then
              if not seen[key] then
                seen[key] = true
                item.module = modName
                if isAuto then
                  autoAddedKeys[key] = true
                end
                table.insert(allItems, item)
              end
            else
              item.module = modName
              table.insert(allItems, item)
            end
          end
        end
      elseif not ok then
        BarSmith:ReportError("Error gathering from " .. modName .. ": " .. tostring(items))
      end
    end
  end

  BarSmith:SetAutoAddedKeys(autoAddedKeys)
  return allItems
end

------------------------------------------------------------------------
-- Build final display list (group each module's items into a flyout)
------------------------------------------------------------------------

-- Display names for flyout group tooltips
Placer.MODULE_LABELS = {
  questItems   = "Quest Items",
  consumables  = "Consumables",
  consumables_potions = "Potions (All)",
  consumables_flask  = "Flasks / Elixirs",
  consumables_food   = "Food / Drink",
  consumables_bandage= "Bandages",
  consumables_utility= "Utilities",
  trinkets     = "Trinkets",
  classSpells  = "Class Spells",
  professions  = "Professions",
  mounts       = "Mounts",
  toys         = "Toys",
  hearthstones = "Hearthstones",
  macros       = "Macros",
}

Placer.MODULE_PLACEHOLDER_ICONS = {
  questItems   = "Interface\\Icons\\INV_Misc_Book_09",
  consumables  = 5931169,
  consumables_potions = "Interface\\Icons\\INV_Potion_54",
  consumables_flask  = "Interface\\Icons\\INV_Potion_71",
  consumables_food   = "Interface\\Icons\\INV_Misc_Food_15",
  consumables_bandage= "Interface\\Icons\\INV_Misc_Bandage_01",
  consumables_utility= "Interface\\Icons\\INV_Misc_Toy_02",
  trinkets     = "Interface\\Icons\\INV_Jewelry_TrinketPVP_01",
  classSpells  = "Interface\\Icons\\Ability_Marksmanship",
  professions  = "Interface\\Icons\\Trade_BlackSmithing",
  mounts       = "Interface\\Icons\\Ability_Mount_RidingHorse",
  toys         = "Interface\\Icons\\INV_Misc_Toy_02",
  hearthstones = "Interface\\Icons\\INV_Misc_Rune_01",
  macros       = "Interface\\Icons\\INV_Misc_QuestionMark",
}

function Placer:PromoteLastUsedChild(moduleName, children)
  if not moduleName or not children or #children <= 1 then
    return
  end

  local wantedKey = BarSmith:GetPinnedForModule(moduleName) or BarSmith:GetLastUsedForModule(moduleName)
  if not wantedKey then
    return
  end

  for i, child in ipairs(children) do
    if BarSmith:GetActionIdentityKey(child) == wantedKey then
      if i > 1 then
        table.remove(children, i)
        table.insert(children, 1, child)
      end
      return
    end
  end
end

function Placer:BuildDisplayItems(items)
  local display = {}
  local ungrouped = {}
  -- Ordered map: module name -> flyout group (preserves priority insertion order)
  local groups = {}

  for _, item in ipairs(items) do
    local mod = item.module
    if not mod then
      -- Ungrouped item (shouldn't happen, but safe fallback)
      table.insert(ungrouped, item)
    else
      if not groups[mod] then
        groups[mod] = {
          name = self.MODULE_LABELS[mod] or mod,
          type = mod .. "_group",
          isFlyoutGroup = true,
          children = {},
          module = mod,
        }
      end
      table.insert(groups[mod].children, item)
    end
  end

  local priority = (BarSmith.GetExpandedPriority and BarSmith:GetExpandedPriority()) or BarSmith.chardb.priority or {}
  local function isEnabled(modName)
    if modName:match("^consumables_") then
      return BarSmith.chardb.modules.consumables == true
    end
    return BarSmith.chardb.modules[modName]
  end

  local function addPlaceholder(modName)
    local label = self.MODULE_LABELS[modName] or modName
    table.insert(display, {
      name = label .. " (Empty)",
      icon = self.MODULE_PLACEHOLDER_ICONS[modName],
      type = "placeholder",
      module = modName,
      isPlaceholder = true,
    })
  end

  -- Build final display: one entry per module group
  for _, mod in ipairs(priority) do
    local group = groups[mod]
    if group then
      local children = group.children

      if #children == 1 then
        -- Single item: no flyout needed, place directly
        table.insert(display, children[1])
      else
        self:PromoteLastUsedChild(mod, children)

        -- Multiple items: flyout group with first item as primary
        local primary = children[1]
        if mod == "macros" and primary and not primary.macrotext then
          for _, child in ipairs(children) do
            if child.macrotext then
              primary = child
              break
            end
          end
        end
        group.primary = primary
        group.icon = primary.icon
        group.itemID = primary.itemID
        group.spellID = primary.spellID
        group.toyID = primary.toyID
        group.count = #children
        group.name = (self.MODULE_LABELS[mod] or mod) .. " (" .. #children .. ")"
        table.insert(display, group)
      end
    elseif isEnabled(mod) and BarSmith.chardb.hideEmptyModules ~= true then
      -- Module enabled but no items: add a placeholder to show the module is active but empty
      addPlaceholder(mod)
    end
  end

  for _, item in ipairs(ungrouped) do
    table.insert(display, item)
  end

  return display
end

------------------------------------------------------------------------
-- Place items onto the BarSmith dedicated bar
------------------------------------------------------------------------

function Placer:PlaceItems(items)
  if InCombatLockdown() then return end

  local barFrame = BarSmith:GetModule("BarFrame")
  if not barFrame then
    BarSmith:ReportError("BarFrame module not found.")
    return
  end

  local maxButtons = barFrame:GetMaxButtons()
  barFrame:EnsureButtonPoolSize(maxButtons)

  -- Clear all existing buttons
  barFrame:ClearAll()

  -- Assign items to buttons (up to current max button count)
  local placed = 0
  for _, item in ipairs(items) do
    if placed >= maxButtons then break end

    local success = barFrame:SetButton(placed + 1, item)
    if success then
      placed = placed + 1
      BarSmith:Debug("Placed: " .. (item.name or "?") .. " -> button " .. placed)
    end
  end

  -- Layout is driven by currently placed module groups, not only enabled modules.
  barFrame:SetLayoutButtonCount(math.max(1, placed))

  -- Update layout to fit the active buttons
  barFrame:UpdateLayout()
  barFrame:Show()

  if placed > 0 then
    BarSmith:Debug("Forged " .. placed .. " item(s) onto your BarSmith bar.")
  else
    BarSmith:Debug("No items to place.")
    barFrame:Hide()
  end

  BarSmith:FireCallback("FILL_COMPLETE", placed)
end

------------------------------------------------------------------------
-- Confirmation popup using StaticPopup
------------------------------------------------------------------------

function Placer:ShowConfirmation(items)
  local barFrame = BarSmith:GetModule("BarFrame")
  local maxButtons = barFrame and barFrame:GetMaxButtons() or 12
  local count = math.min(#items, maxButtons)
  local names = {}
  for i = 1, math.min(count, 5) do
    table.insert(names, "  \124cffffffff" .. (items[i].name or "Unknown") .. "\124r")
  end
  if count > 5 then
    table.insert(names, "  ...and " .. (count - 5) .. " more")
  end

  StaticPopupDialogs["BARSMITH_CONFIRM_FILL"] = {
    text = "BarSmith wants to place " .. count .. " item(s):\n\n" .. table.concat(names, "\n") .. "\n\nProceed?",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function()
      Placer:PlaceItems(items)
    end,
    timeout = 30,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
  }
  StaticPopup_Show("BARSMITH_CONFIRM_FILL")
end
