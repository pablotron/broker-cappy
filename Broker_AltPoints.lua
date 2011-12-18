local ADDON_NAME = "Broker_Cappy"
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

-- FIXME: make configurable
local CURRENCY_LAYOUT = 'v_all'

-- layout for each character
local CURRENCY_LAYOUTS = {
  h_all = {
    init = {
      'LEFT', 'RIGHT', 'RIGHT', 'RIGHT',
      'CENTER',
      'LEFT', 'RIGHT', 'RIGHT', 'RIGHT'
    },

    grid = {
      {395, 392},
      {396, 390},
    }
  },

  v_all = {
    init = {
      'LEFT', 'RIGHT', 'RIGHT', 'RIGHT',
    },

    grid = {
      {395},
      {396},
      {392},
      {390},
    }
  },

  h_pve = {
    init = {
      'LEFT', 'RIGHT', 'RIGHT', 'RIGHT',
      'CENTER',
      'LEFT', 'RIGHT', 'RIGHT', 'RIGHT'
    },

    grid = {
      {395, 396},
    }
  },

  v_pve = {
    init = {
      'LEFT', 'RIGHT', 'RIGHT', 'RIGHT',
    },

    grid = {
      {395},
      {396},
    }
  },

  h_pvp = {
    init = {
      'LEFT', 'RIGHT', 'RIGHT', 'RIGHT',
      'CENTER',
      'LEFT', 'RIGHT', 'RIGHT', 'RIGHT'
    },

    grid = {
      {392, 390},
    }
  },

  v_pvp = {
    init = {
      'LEFT', 'RIGHT', 'RIGHT', 'RIGHT',
    },

    grid = {
      {392},
      {390},
    }
  },
}

-- class icons (not used atm)
local CLASS_ICONS = {
  DEATHKNIGHT = "Interface/Icons/Spell_Deathknight_ClassIcon",
  DRUID       = "Interface/Icons/INV_Misc_MonsterClaw_04",
  HUNTER      = "Interface/Icons/INV_Weapon_Bow_07",
  MAGE        = "Interface/Icons/INV_Staff_13",
  PALADIN     = "Interface/AddOns/addon/UI-CharacterCreate-Classes_Paladin",
  PRIEST      = "Interface/Icons/INV_Staff_30",
  ROGUE       = "Interface/AddOns/addon/UI-CharacterCreate-Classes_Rogue",
  SHAMAN      = "Interface/Icons/Spell_Nature_BloodLust",
  WARLOCK     = "Interface/Icons/Spell_Nature_FaerieFire",
  WARRIOR     = "Interface/Icons/INV_Sword_27",
}

--
-- init/update methods
--

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
  -- chat_log('guid = ' .. guid)

  -- walk over list of currencies
  for _, curr_id in pairs(CURRENCY_IDS) do
    -- get currency info for this character/currency
    local name, amount, icon, earnedThisWeek, weeklyMax, totalMax, isDiscovered = GetCurrencyInfo(curr_id)

    -- dump currency id
    -- chat_log("curr_id = " .. curr_id)

    if name then
      -- print currency name
      -- chat_log(string.format("name = %s, icon = %s", name, icon))

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

--
-- tooltip methods
--

local function normalize_cap(curr_id, val)
  if curr_id == 390 then
    return val
  else
    return val / 100
  end
end

local function get_char_header(guid, char) 
  local icon_str = ''
  local col_str = 'ffffff'

  if char.class then
    -- add icon for this character
    -- (TODO: disabled for now because it's fugly)
    local icon = CLASS_ICONS[char.class]
    if false and icon then
      icon_str = string.format('|T%s:0|t ', icon)
    end

    -- add class color for character
    -- TODO: make this configurable?
    local c = RAID_CLASS_COLORS[char.class]

    if c then
      col_str = string.format('%02x%02x%02x', 
        floor(255 * c.r),
        floor(255 * c.g),
        floor(255 * c.b)
      )
    end

    -- print color to debug log
    -- chat_log(string.format('class = %s, col_str = %s', char.class, col_str))
  end

  -- TODO: add support for CLASS_ICON_TCOORDS
  return string.format('%s|cff%s%s|r', icon_str, col_str, char.name)
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
      cap_val = curr.amount
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
  return {
    string.format("\124TInterface/Icons/%s:0\124t |cFFFFFFFF%s|r", icon, name),
    curr.amount,
    string.format("%s", cap_str),
    cap_pct
  }
end

--
-- data broker methods
--

local function sorted_accounts(t) 
  local ids = {}

  -- build unsorted list of ids
  for k, _ in pairs(t) do 
    table.insert(ids, k)
  end

  -- sort ids by name
  table.sort(ids, function(a, b)
    return t[a].name < t[b].name
  end)

  -- iterator variable
  local i = 0

  local iter = function()
    -- increment iterator variable
    i = i + 1

    -- yield next value, or stop if we're at the end
    if ids[i] == nil then
      return nil
    else
      return ids[i], t[ids[i]]
    end
  end

  -- return iterator
  return iter
end

function add_char_to_tooltip(tooltip, guid, char, layout)
  -- add character name
  tooltip:AddLine(get_char_header(guid, char))

  if char.currencies then
    -- iterate over currency layout
    for _, row_curr_ids in ipairs(layout.grid) do
      local row = {};

      -- chat_log('adding row')
      -- chat_log('#row_curr_ids = ' .. #row_curr_ids)

      for _, curr_id in ipairs(row_curr_ids) do
        local curr = char.currencies[curr_id]

        -- chat_log('curr_id = ' .. curr_id)

        if curr then
          -- add row
          -- chat_log('add row')
          for _, val in ipairs(get_row(curr_id, curr)) do
            table.insert(row, val)
          end
        else
          -- add empty set
          -- chat_log('empty set')
          for i = 1, 4 do
            table.insert(row, ' ')
          end
        end

        -- add empty cell for padding
        table.insert(row, ' ')
      end

      -- remove trailing padding
      row[#row] = nil

      -- chat_log('adding combined row ')
      -- add combined row
      tooltip:AddLine(unpack(row))
    end
  end

  -- delimit characters
  tooltip:AddLine(' ')
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
  local layout = CURRENCY_LAYOUTS[CURRENCY_LAYOUT]
  local cols = layout.init
  local curr_guid = UnitGUID('player')

  -- create tooltip
  tooltip = LibQTip:Acquire(ADDON_NAME .. 'Tooltip', #cols, unpack(cols))

  -- add header
  tooltip:AddHeader(ADDON_NAME)
  tooltip:AddLine(' ')

  -- walk over characters
  for guid, char in sorted_accounts(db) do
    if guid ~= curr_guid then
      add_char_to_tooltip(tooltip, guid, char, layout)
    end
  end

  -- add separator
  tooltip:AddSeparator()
  tooltip:AddLine(' ')

  -- add current character
  add_char_to_tooltip(tooltip, curr_guid, db[curr_guid], layout)

  -- show tooltip
  tooltip:SmartAnchorTo(self)
  tooltip:Show()
end

function bac.OnLeave(self)
  LibQTip:Release(tooltip)
  tooltip = nil
end

--
-- wow event methods
--

-- set up a local hidden frame to receive relevant currency events
local frame = CreateFrame("frame")

-- bind to events
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
frame:RegisterEvent("ADDON_LOADED")

-- add event handler
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
