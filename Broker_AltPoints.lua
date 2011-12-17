local ADDON_NAME = "Broker_AltPoints"
local LDB = LibStub:GetLibrary("LibDataBroker-1.1")

function update_currencies()
  local guid = UnitGUID('player')
  local size = GetCurrencyListSize()

  for i = 1, list_size do
    -- local name, isHeader, isExpanded, isUnused, isWatched, count, extraCurrencyType, icon, itemID = GetCurrencyListInfo(i)
    local list_info = GetCurrencyListInfo(i)
    local id = list_info[9] 
    local count = list_info[6]
    local curr_info = GetCurrencyInfo(id)

    db = db or {}
    db[guid] = db[guid] or { name = GetUnitName('player') }
    db[guid][id] = {
      amount          = curr_info[2],
      earnedThisWeek  = curr_info[4],
      weeklyMax       = curr_info[5],
      totalMax        = curr_info[6],
    }
  end
end

function get_currency_row(curr_id, currs) 
  local cap = ''
  local curr_info = GetCurrencyInfo(curr_id)
  local texture = curr_info[2]

  -- check for weekly/total caps
  if currs["weeklyMax"] > 0 then
    cap = string.format(" (%d/%d)", currs["earnedThisWeek"], currs["weeklyMax"])
  elseif currs["totalMax"] > 0 then
    cap = string.format("/%d", info["totalMax"])
  end

  return string.format("|T%s|t %d%s", texture, currs["amount"], cap)
end

local bac = LDB:NewDataObject(ADDON_NAME, {
  type = "data source",
  icon = "Interface\\Icons\\Inv_Misc_Armorkit_18",
})

function bac.OnClick()
  -- show currency frame on click
  ToggleCharacter("TokenFrame")
end

function bac.OnTooltipShow(tooltip)
  tooltip:AddLine("hello!")

  for guid, currs in pairs(db) do
    -- add character name
    tooltip:AddLine(currs["name"])

    -- iterate over currencies
    for curr_id, curr in pairs(currs) do
      if curr_id ~= 'name' then
        tooltip:AddLine(get_currency_row(curr_id, curr))
      end
    end

    -- delimit characters
    tooltip:AddLine("")
  end
end

-- set up a local hidden frame to receive relevant currency events
local frame = CreateFrame("frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
frame:SetScript("OnEvent", function(self, ev, ...) 
  if ev == "PLAYER_ENTERING_WORLD" then
    -- print hello
    local version = GetAddonMetadata(ADDON_NAME, "Version")
    print(ADDON_NAME .. " version " .. version .. " loaded.")
  end

  -- fetch current character's currency state and update it
  update_currency()
end);
