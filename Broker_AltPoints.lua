local ADDON_NAME = "Broker_AltPoints"
local LDB = LibStub:GetLibrary("LibDataBroker-1.1")

-- tracked currency ids
local CURRENCY_IDS = {
  395,  -- Justice Points
  396,  -- Valor Points
  392,  -- Honor Points
  390,  -- Conquest Points
}

local function db_init(guid)
  -- lazily initialize database
  if db == nil then
    db = {}
  end

  -- lazily initialize store for this player
  if db[guid] == nil then
    db[guid] = {}
  end

  -- handle first time load, name changes, faction changes, etc
  db[guid]["name"] = GetUnitName('player')
end

local function chat_log(str)
  DEFAULT_CHAT_FRAME:AddMessage(string.format("%s: %s",
    ADDON_NAME, 
    str
  ))
end

local function update()
  local guid = UnitGUID('player')

  -- init database
  db_init(guid)

  -- print guid (debug)
  chat_log('guid = ' .. guid)

  -- walk over list of currencies
  for _, curr_id in pairs(CURRENCY_IDS) do
    -- get currency info for this character/currency
    local name, amount, icon, earnedThisWeek, weeklyMax, totalMax, isDiscovered = GetCurrencyInfo(curr_id)

    -- dump currency id
    -- chat_log("curr_id = " .. curr_id)

    if name then
      -- print currency name
      chat_log(string.format("name = %s, icon = %s", name, icon))

      -- if the character has ever discovered this currency,
      -- then save the info
      if isDiscovered then
        -- save currency stats for this character/currency
        db[guid][curr_id] = {
          ["amount"]          = amount,
          ["earnedThisWeek"]  = earnedThisWeek,
          ["weeklyMax"]       = weeklyMax,
          ["totalMax"]        = totalMax,
        }
      end
    end
  end
end

local function old_update()
  local guid = UnitGUID('player')
  local list_size = GetCurrencyListSize()

  -- init database
  db_init(guid)

  -- print currency count (debug)
  chat_log(string.format('guid = %s, list_size = %d', 
    guid,
    list_size
  ))

  -- walk over list of currencies
  for i = 1, list_size do
    local curr_name, is_header, is_expanded, is_unused, is_watched, count, extra_currency_type, icon, curr_id = GetCurrencyListInfo(i)

    -- print currency name
    chat_log(string.format("currency name = %s, is_header = %d",
      curr_name,
      is_header
    ))

    -- if this currency has a name and is not a header, 
    -- then try and get info about it
    if curr_name and not is_header then
      -- get currency info for this character/currency
      local name, amount, texture, earnedThisWeek, weeklyMax, totalMax, isDiscovered = GetCurrencyInfo(i)

      -- dump currency id
      -- chat_log("curr_id = " .. curr_id)

      if name then
        -- print currency name
        chat_log("currency = " .. name)

        -- if the character has ever discovered this currency,
        -- then save the info
        if isDiscovered then
          -- save currency stats for this character/currency
          db[guid][curr_id] = {
            ["amount"]          = amount,
            ["earnedThisWeek"]  = earnedThisWeek,
            ["weeklyMax"]       = weeklyMax,
            ["totalMax"]        = totalMax,
          }
        end
      end
    end
  end
end

local function get_row(curr_id, curr) 
  local cap = ''
  local name, amount, texture, earnedThisWeek, weeklyMax, totalMax, isDiscovered = GetCurrencyInfo(curr_id)

  -- check for weekly/total caps
  -- note: WoW API returns the caps * 100 for some reason...
  if curr.weeklyMax and curr.weeklyMax > 0 then
    cap = string.format(" (%d/%d)", curr.earnedThisWeek, curr.weeklyMax / 100)
  elseif curr.totalMax and curr.totalMax > 0 then
    cap = string.format("/%d", curr.totalMax / 100)
  end

  -- build/return formatted row
  return string.format("\124TInterface/Icons/%s:0\124t |cFFFFFFFF%s|r %d%s", 
    texture,
    name,
    curr.amount,
    cap
  )
end

local bac = LDB:NewDataObject(ADDON_NAME, {
  type = "data source",
  icon = "Interface\\Icons\\Inv_Misc_Armorkit_18",
  text = ""
})

function bac.OnClick()
  -- show currency frame on click
  ToggleCharacter("TokenFrame")
end

function bac.OnTooltipShow(tooltip)
  -- add tooltip header
  tooltip:AddLine(ADDON_NAME)
  tooltip:AddLine(' ')

  -- walk over characters
  for guid, currs in pairs(db) do
    -- add character name
    tooltip:AddLine(currs.name)

    -- iterate over currencies
    for curr_id, curr in pairs(currs) do
      if curr_id ~= 'name' then
        tooltip:AddLine(get_row(curr_id, curr))
      end
    end

    -- delimit characters
    tooltip:AddLine(' ')
  end
end

-- set up a local hidden frame to receive relevant currency events
local frame = CreateFrame("frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, ev, ...) 
  -- print version information on load
  if ev == "PLAYER_ENTERING_WORLD" then
    chat_log(string.format("version %s loaded.",
      GetAddOnMetadata(ADDON_NAME, "Version")
    ))
  end

  -- update currency state
  update()
end);
