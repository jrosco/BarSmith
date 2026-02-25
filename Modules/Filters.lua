------------------------------------------------------------------------
-- BarSmith: Modules/Filters.lua
-- Filter registry and shared item restriction helpers
------------------------------------------------------------------------

local Filters = BarSmith:NewModule("Filters")

function BarSmith:NormalizeFilterSet(values)
  if type(values) ~= "table" then
    return nil
  end
  local set = {}
  for k, v in pairs(values) do
    if type(k) == "number" then
      set[v] = true
    elseif v then
      set[k] = true
    end
  end
  return next(set) and set or nil
end

function BarSmith:RegisterFilter(name, fn, opts)
  if not name or type(fn) ~= "function" then
    return
  end
  opts = opts or {}
  self.filters = self.filters or {}
  self.filters[name] = {
    name = name,
    fn = fn,
    enabled = (opts.enabled ~= false),
    mode = opts.mode,
    settingMode = opts.settingMode or "exclude",
    kinds = self:NormalizeFilterSet(opts.kinds or (opts.kind and { opts.kind }) or nil),
    types = self:NormalizeFilterSet(opts.types),
  }
end

function BarSmith:SyncFiltersFromSettings()
  if not self.filters or not self.chardb or type(self.chardb.filters) ~= "table" then
    return
  end
  for name, filter in pairs(self.filters) do
    local enabled = self.chardb.filters[name]
    if enabled ~= nil then
      if filter.settingMode == "include" then
        filter.enabled = (enabled == false)
      else
        filter.enabled = (enabled == true)
      end
    end
  end
end

function BarSmith:SetFilterEnabled(name, enabled)
  if not self.filters or not self.filters[name] then
    return
  end
  local filter = self.filters[name]
  if filter.settingMode == "include" then
    filter.enabled = (enabled == false)
  else
    filter.enabled = (enabled ~= false)
  end
end

function BarSmith:FilterApplies(filter, data)
  if not filter or not data then
    return false
  end

  if filter.kinds then
    local kindMatch = false
    if filter.kinds.item and data.itemID then
      kindMatch = true
    elseif filter.kinds.spell and data.spellID then
      kindMatch = true
    elseif filter.kinds.toy and data.toyID then
      kindMatch = true
    elseif filter.kinds.mount and data.mountID then
      kindMatch = true
    end
    if not kindMatch then
      return false
    end
  end

  if filter.types then
    local dtype = data.type
    if not dtype or not filter.types[dtype] then
      return false
    end
  end

  return true
end

function BarSmith:ItemPassesFilters(data)
  if not self.filters then
    return true
  end
  local includeMatched = false
  local includeAllowed = false
  for _, filter in pairs(self.filters) do
    if filter.enabled ~= false and self:FilterApplies(filter, data) then
      local ok, keep = pcall(filter.fn, self, data)
      if not ok then
        self:ReportError("Filter error [" .. tostring(filter.name) .. "]: " .. tostring(keep))
      elseif filter.mode == "include" then
        includeMatched = true
        if keep == true then
          includeAllowed = true
        end
      elseif keep == false then
        if self.db and self.db.debug then
          local label = data.name or data.type or "Unknown"
          local id = data.itemID or data.spellID or data.toyID or data.mountID
          local idLabel = id and (" (" .. tostring(id) .. ")") or ""
          self:Debug("Filter excluded: " .. tostring(filter.name) .. " -> " .. label .. idLabel)
        end
        return false
      end
    end
  end
  if includeMatched and not includeAllowed then
    if self.db and self.db.debug then
      local label = data.name or data.type or "Unknown"
      local id = data.itemID or data.spellID or data.toyID or data.mountID
      local idLabel = id and (" (" .. tostring(id) .. ")") or ""
      self:Debug("Filter excluded (include mode): " .. label .. idLabel)
    end
    return false
  end
  return true
end

------------------------------------------------------------------------
-- Item restriction helpers (filters)
------------------------------------------------------------------------

function BarSmith:IsInBattleground()
  local _, instanceType = IsInInstance()
  return instanceType == "pvp"
end

function BarSmith:ItemHasTooltipLine(itemID, bag, slot, needle)
  if not needle or needle == "" then
    return false
  end
  if not C_TooltipInfo then
    return false
  end

  local tip
  if bag and slot and C_TooltipInfo.GetBagItem then
    tip = C_TooltipInfo.GetBagItem(bag, slot)
  elseif itemID and C_TooltipInfo.GetItemByID then
    tip = C_TooltipInfo.GetItemByID(itemID)
  end

  if not tip or not tip.lines then
    return false
  end

  for _, line in ipairs(tip.lines) do
    local text = line.leftText
    if text and text:find(needle, 1, true) then
      return true
    end
  end
  return false
end

------------------------------------------------------------------------
-- Saved filter flag from Settings
------------------------------------------------------------------------
local function GetSavedFilterEnabled(name, defaultSetting, settingMode)
  local cfg = BarSmith.chardb and BarSmith.chardb.filters
  if cfg and cfg[name] ~= nil then
    if settingMode == "include" then
      return cfg[name] == false
    end
    return cfg[name] == true
  end
  if settingMode == "include" then
    return defaultSetting == false
  end
  return defaultSetting == true
end

------------------------------------------------------------------------
-- Add custom filter below
------------------------------------------------------------------------
local BATTLEGROUND_ONLY_TEXT = (rawget(_G, "ITEM_ONLY_USABLE_IN_BATTLEGROUNDS")
  or "Only usable in battlegrounds")


BarSmith:RegisterFilter("battleground_only_items", function(self, data)
  if not data or not data.itemID then
    return true
  end
  if self:IsInBattleground() then
    return true
  end
  if self:ItemHasTooltipLine(data.itemID, data.bag, data.slot, BATTLEGROUND_ONLY_TEXT) then
    return false
  end
  return true
end, {
  kind = "item",
  enabled = GetSavedFilterEnabled("battleground_only_items", true, "include"),
  settingMode = "include",
})
