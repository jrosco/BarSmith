------------------------------------------------------------------------
-- BarSmith: Modules/Professions.lua
-- Provides Players Professions and Skill for action bar placement
------------------------------------------------------------------------

local Professions = BarSmith:NewModule("Professions")

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------

local function ResolveProfessionSpellID(skillLineID, professionName)
  if C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoBySkillLineID and skillLineID then
    local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID(skillLineID)
    if info and info.spellID then
      return info.spellID
    end
  end

  if C_Spell and C_Spell.GetSpellInfo and professionName then
    local info = C_Spell.GetSpellInfo(professionName)
    if info and info.spellID then
      return info.spellID
    end
  end

  return nil
end

local function BuildJournalMacro(skillLineID)
  if not skillLineID then return nil end
  return "/run if C_TradeSkillUI and C_TradeSkillUI.OpenTradeSkill then C_TradeSkillUI.OpenTradeSkill(" .. tostring(skillLineID) .. ") end"
end

------------------------------------------------------------------------
-- Gather known professions for the action bar
------------------------------------------------------------------------

function Professions:GetItems()
  local items = {}

  if not BarSmith.chardb.modules.professions then
    return items
  end

  local prof1, prof2, archaeology, fishing, cooking = GetProfessions()
  local indices = {
    { index = prof1, category = "primary" },
    { index = prof2, category = "primary" },
    { index = archaeology, category = "secondary" },
    { index = fishing, category = "secondary" },
    { index = cooking, category = "secondary" },
  }

  for _, entry in ipairs(indices) do
    local profIndex = entry.index
    if profIndex then
      local name, icon, skillLevel, maxSkillLevel, _, _, skillLine = GetProfessionInfo(profIndex)
      if name then
        local spellID = ResolveProfessionSpellID(skillLine, name)
        local macrotext = BuildJournalMacro(skillLine)
        table.insert(items, {
          name = name,
          icon = icon,
          spellID = spellID,
          macrotext = macrotext,
          skillLevel = skillLevel,
          maxSkillLevel = maxSkillLevel,
          category = entry.category,
          type = "profession",
        })
      end
    end
  end

  BarSmith:Debug("Professions found: " .. #items)
  return items
end
