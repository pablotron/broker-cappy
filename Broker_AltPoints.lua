local ADDON_NAME = "Broker_AltPoints"
local LDB = LibStub:GetLibrary("LibDataBroker-1.1")
local LibQTip = LibStub:GetLibrary('LibQTip-1.0')
local tooltip

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
  db[guid].name = GetUnitName('player')

  -- save class (for future color of player text)
  local class, class_fn = UnitClass('player')
  db[guid].class = class_fn

  -- initialize currency table
  if db[guid].currencies == nil then
    db[guid].currencies = {}
  end
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
        db[guid].currencies[curr_id] = {
          ["amount"]          = amount,
          ["earnedThisWeek"]  = earnedThisWeek,
          ["weeklyMax"]       = weeklyMax,
          ["totalMax"]        = totalMax,
        }
      end
    end
  end
end

local function normalize_cap(curr_id, val)
  if curr_id == 390 then
    return val
  else
    return val / 100
  end
end

local function get_char_name(char) 
  local col_str = 'ffffff'

  -- disable this for now
  if false and char.class then
    local c = RAID_CLASS_COLORS[char.class]
    if c then
      col_str = string.format('%02x%02x%02x', 
        floor(255 * c.r),
        floor(255 * c.g),
        floor(255 * c.b)
      )
    end
  end


  -- TODO: add support for CLASS_ICON_TCOORDS
  return string.format('|cff%s%s|r', col_str, char.name)
end

local function get_row(curr_id, curr) 
  local cap_str, cap_pct = 'n/a', 'n/a'
  local name, amount, icon, earnedThisWeek, weeklyMax, totalMax, isDiscovered = GetCurrencyInfo(curr_id)

  -- check for weekly/total caps
  -- note: WoW API returns the caps * 100 for some reason, except for
  -- conquest points...
  if (curr.weeklyMax > 0) or (curr.totalMax > 0) then
    local cap_col, cap_val, cap_max = 'FFFFFF', 0, 0;

    if curr.weeklyMax and curr.weeklyMax > 0 then
      cap_val = curr.earnedThisWeek
      cap_max = normalize_cap(curr_id, curr.weeklyMax)
    elseif curr.totalMax and curr.totalMax > 0 then
      cap_val = amount
      cap_max = normalize_cap(curr_id, curr.totalMax)
    end

    -- calculate percent complete
    cap_pct = 1.0 * cap_val / cap_max

    -- TODO: make this a table?
    if cap_pct > 1.0 then
      cap_col = '00FF00'
    elseif cap_pct > 0.75 then
      cap_col = 'A5FF00'
    elseif cap_pct > 0.5 then
      cap_col = 'FFFF00'
    elseif cap_pct > 0.25 then
      cap_col = 'FFA500'
    else
      cap_col = 'FF0000'
    end

    -- build cap string
    cap_str = string.format("|cFFFFFFFF%d/%d|r", cap_val, cap_max)

    -- convert percent to decimal and round
    cap_pct = string.format('|cFF%s%d%%|r', cap_col, floor(100 * cap_pct + 0.5))
  end

  -- build/return formatted row
  return string.format("\124TInterface/Icons/%s:0\124t |cFFFFFFFF%s|r", icon, name),
         curr.amount,
         string.format("%s", cap_str),
         cap_pct
end

local bac = LDB:NewDataObject(ADDON_NAME, {
  type = "data source",
  icon = "Interface/Icons/Inv_Misc_Armorkit_18",
  text = ""
})

function bac.OnClick()
  -- show currency frame on click
  ToggleCharacter("TokenFrame")
end

function bac.OnEnter(self)
  -- create tooltip
  tooltip = LibQTip:Acquire(
    ADDON_NAME .. 'Tooltip', 4, 
    'LEFT', 'RIGHT', 'RIGHT', 'RIGHT'
  )

  -- add header
  tooltip:AddHeader(ADDON_NAME)
  tooltip:AddLine(' ')

  -- walk over characters
  for guid, char in pairs(db) do
    -- add character name
    tooltip:AddLine(get_char_name(char))

    -- iterate over currencies
    if char.currencies then
      for curr_id, curr in pairs(char.currencies) do
        tooltip:AddLine(get_row(curr_id, curr))
      end
    end

    -- delimit characters
    tooltip:AddLine(' ')
  end

  -- show tooltip
  tooltip:SmartAnchorTo(self)
  tooltip:Show()
end

function bac.OnLeave(self)
  LibQTip:Release(tooltip)
  tooltip = nil
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
