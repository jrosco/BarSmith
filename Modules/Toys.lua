------------------------------------------------------------------------
-- BarSmith: Modules/Toys.lua
-- Favorite toys and included toys for action bar placement
------------------------------------------------------------------------

local Toys = BarSmith:NewModule("Toys")
Toys.DEFAULT_ICON = "Interface\\Icons\\INV_Misc_Toy_02"

local function GetToyInfo(toyID)
  if not C_ToyBox or not C_ToyBox.GetToyInfo then
    return nil, nil, nil
  end

  local _, toyName, icon, isFavorite = C_ToyBox.GetToyInfo(toyID)
  if icon == 0 then
    icon = nil
  end
  return toyName, icon, isFavorite
end

local function IsToyUsable(toyID)
  if C_ToyBox and C_ToyBox.IsToyUsable then
    return C_ToyBox.IsToyUsable(toyID)
  end
  return true
end

local function GetFavoriteToyIDs()
  if C_ToyBox and C_ToyBox.GetToyFavorites then
    local favorites = C_ToyBox.GetToyFavorites()
    if type(favorites) == "table" then
      return favorites
    end
  end

  local favorites = {}
  if C_ToyBox and C_ToyBox.GetNumFilteredToys and C_ToyBox.GetToyFromIndex then
    local count = C_ToyBox.GetNumFilteredToys()
    for i = 1, count do
      local toyID = C_ToyBox.GetToyFromIndex(i)
      if toyID then
        local _, _, isFavorite = GetToyInfo(toyID)
        if isFavorite then
          table.insert(favorites, toyID)
        end
      end
    end
  end

  return favorites
end

function Toys:AddExtraToy(toyID)
  if not toyID then return false end

  if not (PlayerHasToy and PlayerHasToy(toyID)) then
    BarSmith:Print("That toy isn't collected.")
    return false
  end

  if not IsToyUsable(toyID) then
    BarSmith:Print("That toy isn't usable.")
    return false
  end

  local prefs = BarSmith.chardb.toys
  prefs.include = prefs.include or {}
  prefs.include[toyID] = true
  BarSmith:Print("Included toy.")
  return true
end

function Toys:RemoveExtraToy(toyID)
  if not toyID then return false end
  if not BarSmith.chardb or not BarSmith.chardb.toys then
    return false
  end
  local include = BarSmith.chardb.toys.include
  if include and include[toyID] then
    include[toyID] = nil
    return true
  end
  return false
end

------------------------------------------------------------------------
-- Gather toy entries for the action bar
------------------------------------------------------------------------

function Toys:GetItems()
  local items = {}

  if not BarSmith.chardb.modules.toys then
    return items
  end

  if not C_ToyBox or not C_ToyBox.GetToyInfo then
    return items
  end

  local prefs = BarSmith.chardb.toys
  local includes = prefs.include or {}
  local seen = {}

  local function addToy(toyID)
    if not toyID or seen[toyID] then
      return
    end
    if not (PlayerHasToy and PlayerHasToy(toyID)) then
      return
    end
    if not IsToyUsable(toyID) then
      return
    end

    local name, icon = GetToyInfo(toyID)

    table.insert(items, {
      toyID = toyID,
      name = name or ("Toy " .. tostring(toyID)),
      icon = icon or Toys.DEFAULT_ICON,
      type = "toy",
    })
    seen[toyID] = true
  end

  -- Always include user-included toys first
  for toyID, enabled in pairs(includes) do
    if enabled then
      addToy(toyID)
    end
  end

  -- Then include favorites
  for _, toyID in ipairs(GetFavoriteToyIDs()) do
    addToy(toyID)
  end

  BarSmith:Debug("Toys found: " .. #items)
  return items
end
