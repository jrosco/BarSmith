------------------------------------------------------------------------
-- BarSmith: Core.lua
-- Global namespace, event bus, and module registration framework
------------------------------------------------------------------------

local ADDON_NAME = ...

-- Create the global addon namespace
BarSmith = BarSmith or {}
BarSmith.name = ADDON_NAME
BarSmith.version = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "dev"
BarSmith.modules = {}
BarSmith.events = {}

-- Logging
local CHAT_PREFIX = "|cff33ccff[BarSmith]|r "

function BarSmith:Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage(CHAT_PREFIX .. tostring(msg))
end

function BarSmith:Debug(msg)
  if self.db and self.db.debug then
    DEFAULT_CHAT_FRAME:AddMessage(CHAT_PREFIX .. "|cff888888" .. tostring(msg) .. "|r")
  end
end

------------------------------------------------------------------------
-- Module System
------------------------------------------------------------------------

function BarSmith:NewModule(name)
  local mod = {
    name = name,
    enabled = true,
  }
  self.modules[name] = mod
  return mod
end

function BarSmith:GetModule(name)
  return self.modules[name]
end

function BarSmith:IterateModules()
  return pairs(self.modules)
end

------------------------------------------------------------------------
-- Event Bus (lightweight pub/sub for inter-module communication)
------------------------------------------------------------------------

function BarSmith:RegisterCallback(event, owner, func)
  if not self.events[event] then
    self.events[event] = {}
  end
  table.insert(self.events[event], { owner = owner, func = func })
end

function BarSmith:FireCallback(event, ...)
  local listeners = self.events[event]
  if not listeners then return end
  for _, entry in ipairs(listeners) do
    local ok, err = pcall(entry.func, entry.owner, ...)
    if not ok then
      self:Debug("Callback error [" .. event .. "]: " .. tostring(err))
    end
  end
end

------------------------------------------------------------------------
-- Blizzard Event Frame
------------------------------------------------------------------------

BarSmith.frame = CreateFrame("Frame", "BarSmithEventFrame", UIParent)
BarSmith.frame.handlers = {}

function BarSmith:RegisterEvent(event, handler)
  self.frame.handlers[event] = handler
  self.frame:RegisterEvent(event)
end

function BarSmith:UnregisterEvent(event)
  self.frame.handlers[event] = nil
  self.frame:UnregisterEvent(event)
end

BarSmith.frame:SetScript("OnEvent", function(self, event, ...)
  local handler = self.handlers[event]
  if handler then
    handler(BarSmith, event, ...)
  end
end)

------------------------------------------------------------------------
-- Utility Helpers
------------------------------------------------------------------------

function BarSmith:IsInCombat()
  return InCombatLockdown()
end

function BarSmith:GetPlayerClass()
  local _, class = UnitClass("player")
  return class
end

function BarSmith:GetPlayerSpec()
  local specIndex = GetSpecialization()
  if specIndex then
    return GetSpecializationInfo(specIndex)
  end
  return nil
end

------------------------------------------------------------------------
-- Priority helpers
------------------------------------------------------------------------

function BarSmith:GetExpandedPriority()
  local priority = self.chardb and self.chardb.priority
  if type(priority) ~= "table" then
    return nil
  end

  local expanded = {}
  local modules = self.chardb and self.chardb.modules or {}
  local con = self.chardb and self.chardb.consumables or {}
  local split = con.split or {}

  for _, modName in ipairs(priority) do
    if modName ~= "consumables" then
      table.insert(expanded, modName)
    else
      if modules.consumables == false then
        -- skip all consumables and split entries when disabled
      else
        local anyParent = false

        local function addSplit(flagKey, suffix, includeFlag)
          if split[flagKey] then
            table.insert(expanded, "consumables_" .. suffix)
            return
          end
          if includeFlag then
            anyParent = true
          end
        end

        addSplit("potions", "potions", con.potions)
        addSplit("flasks", "flask", con.flasks)
        addSplit("food", "food", con.food)
        addSplit("bandages", "bandage", con.bandages)
        addSplit("utilities", "utility", con.utilities)

        if anyParent then
          table.insert(expanded, "consumables")
        end
      end
    end
  end

  return expanded
end

function BarSmith:TableContains(tbl, val)
  for _, v in ipairs(tbl) do
    if v == val then return true end
  end
  return false
end

-- Stable identity key used to remember "last used" entries across sessions.
function BarSmith:GetActionIdentityKey(data)
  if not data then return nil end

  if data.toyID then
    return "toy:" .. tostring(data.toyID)
  end
  if data.itemID then
    return "item:" .. tostring(data.itemID)
  end
  if data.spellID then
    return "spell:" .. tostring(data.spellID)
  end
  if data.macroID then
    return "macro:" .. tostring(data.macroID)
  end
  if data.slotIndex then
    return "macro_slot:" .. tostring(data.slotIndex)
  end
  if data.name then
    return "name:" .. tostring(data.name)
  end

  return nil
end

function BarSmith:IsExcluded(data)
  if not self.chardb or not self.chardb.exclude then
    return false
  end
  local key = self:GetActionIdentityKey(data)
  if not key then return false end
  return self.chardb.exclude[key] == true
end

function BarSmith:AddToExclude(data)
  if not self.chardb then return end
  local key = self:GetActionIdentityKey(data)
  if not key then return end
  self.chardb.exclude = self.chardb.exclude or {}
  self.chardb.exclude[key] = true
end

function BarSmith:RemoveFromExcludeByKey(key)
  if not key or not self.chardb or not self.chardb.exclude then
    return false
  end
  if self.chardb.exclude[key] then
    self.chardb.exclude[key] = nil
    return true
  end
  return false
end

function BarSmith:RemoveFromExcludeForItemID(itemID)
  if not itemID then return false end
  return self:RemoveFromExcludeByKey("item:" .. tostring(itemID))
end

function BarSmith:RemoveFromExcludeForSpellID(spellID)
  if not spellID then return false end
  return self:RemoveFromExcludeByKey("spell:" .. tostring(spellID))
end

-- Backward-compatible wrappers

function BarSmith:ClearInclude()
  if not self.chardb then return end

  if self.chardb.consumables and self.chardb.consumables.include then
    self.chardb.consumables.include = {
      potions = {},
      flasks = {},
      food = {},
      bandages = {},
      utilities = {},
    }
  end

  if self.chardb.mounts then
    self.chardb.mounts.include = {}
  end

  if self.chardb.classSpells then
    self.chardb.classSpells.customSpellIDs = {}
  end
end

-- Backward-compatible wrapper
function BarSmith:ClearExtras()
  self:ClearInclude()
end

function BarSmith:SetLastUsedForModule(moduleName, data)
  if not self.chardb or not moduleName then return end
  local key = self:GetActionIdentityKey(data)
  if not key then return end

  self.chardb.lastUsedByModule = self.chardb.lastUsedByModule or {}
  self.chardb.lastUsedByModule[moduleName] = key
end

function BarSmith:GetLastUsedForModule(moduleName)
  if not self.chardb or not self.chardb.lastUsedByModule then
    return nil
  end
  return self.chardb.lastUsedByModule[moduleName]
end
