local ADDON_NAME = "Broker_Cappy"
local LDB = LibStub:GetLibrary("LibDataBroker-1.1")
local LibQTip = LibStub:GetLibrary('LibQTip-1.0')
local tooltip, curr_filter_id, cached_cdo_frame

-- tracked currency ids
local CURRENCY_IDS = {
  395,  -- Justice Points
  396,  -- Valor Points
  392,  -- Honor Points
  390,  -- Conquest Points

  -- source: http://www.wowpedia.org/API_GetCurrencyInfo
  61,   -- Dalaran Jewelcrafter's Token
  81,   -- Dalaran Cooking Award
  241,  -- Champion's Seal
  361,  -- Illustrious Jewelcrafter's Token
  -- 384,  -- Dwarf Archaeology Fragment
  -- 385,  -- Troll Archaeology Fragment
  391,  -- Tol Barad Commendation
  -- 393, -- Fossil Archaeology Fragment
  -- 394, -- Night Elf Archaeology Fragment
  -- 397, -- Orc Archaeology Fragment
  -- 398, -- Draenei Archaeology Fragment
  -- 399, -- Vrykul Archaeology Fragment
  -- 400, -- Nerubian Archaeology Fragment
  -- 401, -- Tol'vir Archaeology Fragment
  402, -- Chef's Award
  416, -- Mark of the World Tree
}

-- list of currencies to exclude from "extra" currencies
local STANDARD_CURRENCY_IDS = {
  395,  -- Justice Points
  396,  -- Valor Points
  392,  -- Honor Points
  390,  -- Conquest Points
}

-- layout for each character
local CURRENCY_VIEWS = {
  ["all"] = {
    -- help description
    desc = "PVE and PVP points, grouped vertically (default)",

    -- header text
    head = '',

    -- summary icons
    icons = {395, 392},

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

  ["all-wide"] = {
    -- help description
    desc = "PVE and PVP points, grouped horizontally",

    -- header text
    head = '',

    -- summary icons
    icons = {395, 392},

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

  ["pve-wide"] = {
    -- help description
    desc = "PVE points, grouped horizontally",

    -- header text
    head = ' (PVE)',

    -- summary icons
    icons = {395, 396},

    init = {
      'LEFT', 'RIGHT', 'RIGHT', 'RIGHT',
      'CENTER',
      'LEFT', 'RIGHT', 'RIGHT', 'RIGHT'
    },

    grid = {
      {395, 396},
    }
  },

  ["pve"] = {
    -- help description
    desc = "PVE points, grouped vertically",

    -- header text
    head = ' (PVE)',

    -- summary icons
    icons = {395, 396},

    init = {
      'LEFT', 'RIGHT', 'RIGHT', 'RIGHT',
    },

    grid = {
      {395},
      {396},
    }
  },

  ["pvp-wide"] = {
    -- help description
    desc = "PVP points, grouped horizontally",

    -- header text
    head = ' (PVP)',

    -- summary icons
    icons = {392, 390},

    init = {
      'LEFT', 'RIGHT', 'RIGHT', 'RIGHT',
      'CENTER',
      'LEFT', 'RIGHT', 'RIGHT', 'RIGHT'
    },

    grid = {
      {392, 390},
    }
  },

  ["pvp"] = {
    -- help description
    desc = "PVP points, grouped vertically",

    -- header text
    head = ' (PVP)',

    -- summary icons
    icons = {392, 390},

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
-- utility functions
--

local function sorted_by_name_or_key(t)
  local ids = {}

  -- build unsorted list of ids
  for k, _ in pairs(t) do
    table.insert(ids, k)
  end

  -- sort ids by name field or by key
  table.sort(ids, function(a, b)
    local av, bv = (t[a].name or a), (t[b].name or b)
    return av < bv
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

local function chat_log(str)
  DEFAULT_CHAT_FRAME:AddMessage(string.format("%s: %s",
    "Cappy",
    str
  ))
end

--
-- config functions
--

local function config_init(force)
  if force or not cappy_config then
    cappy_config = {
      view = 'all'
    }
  end
end

local function config_set(k, v)
  config_init()
  cappy_config[k] = v
  return v
end

local function config_get(k)
  config_init()
  return cappy_config[k]
end

local COMMANDS
COMMANDS = {
  ["^help"] = {
    name = "help",
    desc = "Print list of commands.",

    fn = function(val)
      local LINES = {
        "Cappy lets you quickly view gold and points across characters.",
        "Left-click on the Cappy icon to switch between the six",
        "available views. You can also show one particular",
        "currency across all characters by clicking on the currency.",
        "Right-click on the Cappy icon to remove any filter and",
        "restore the default view.",
      }

      print(table.concat(LINES, ' '))
      print(' ')
      print("Available commands:")
      for _, v in sorted_by_name_or_key(COMMANDS) do
        print(string.format("  /cappy %s - %s", v.name, v.desc))
      end
    end
  },

  ["^reset"] = {
    name = "reset",
    desc = "Restore default Cappy settings.",

    fn = function(val)
      config_init(true)
      curr_filter_id = nil
      -- TODO: reset icons
      print("Cappy: Configuration reset.")
    end
  },

  ["^list"] = {
    name = "list",
    desc = "List available views.",

    fn = function(val)
      print("Available views:")
      for k, v in sorted_by_name_or_key(CURRENCY_VIEWS) do
        print(string.format("  %s - %s", v.name or k, v.desc))
      end
      print("Use '/cappy view <name>' to set a different view")
    end
  },

  ["^filter%s*(.*)"] = {
    name = "filter <name>",
    desc = "Set/clear currency filter.",

    fn = function(val)
      if not val or not val:match('%w') then
        print("Cappy: Cleared currency filter.");

        -- clear currency filter
        curr_filter_id = nil
      else
        -- lower-case search string
        val = val:lower()

        -- look for matching currency by name
        for _, curr_id in pairs(CURRENCY_IDS) do
          -- get currency information
          local curr_name = GetCurrencyInfo(curr_id)

          -- lower case currency name
          local lc_curr_name = curr_name:lower()

          if lc_curr_name:match(val) then
            print("Cappy: Currency filter set to " .. curr_name);

            -- set currency filter
            curr_filter_id = curr_id

            -- exit
            return
          end
        end

        -- ack!
        print("Cappy: no matching currency found.")
      end
    end
  },

  ["^hide%s*(.*)"] = {
    name = "hide <name>",
    desc = "Ignore character.",

    fn = function(val)
      -- get ignore lut
      local ignored = config_get('ignored') or {}

      -- lower-case search string
      val = val:lower()

      -- walk over known characters
      for guid, char in pairs(db) do
        if char.name:lower():match(val) then
          print("Cappy: Hiding " .. char.name)

          -- add character to ignore list
          ignored[guid] = true
        end
      end

      -- save ignore list (in case it wasn't defined)
      config_set('ignored', ignored)
    end
  },

  ["^show%s*(.*)"] = {
    name = "show <name>",
    desc = "Stop ignoring character.",

    fn = function(val)
      -- get ignore lut
      local ignored = config_get('ignored') or {}

      -- lower-case search string
      val = val:lower()

      -- walk over known characters
      for guid, char in pairs(db) do
        if char.name:lower():match(val) and ignored[guid] then
          print("Cappy: Showing " .. char.name)

          -- remove character from ignore list
          ignored[guid] = nil
        end
      end

      -- save ignore list (in case it wasn't defined)
      config_set('ignored', ignored)
    end
  },

  ["^view%s+([%w-]+)"] = {
    name = "view <name>",
    desc = "Set a new view (use '/cappy list' to list available views).",

    fn = function(val)
      if CURRENCY_VIEWS[val] then
        config_set('view', val)
        print('Cappy: View set to ' .. val)
        
        if tooltip then
          -- FIXME
          -- redraw_tooltip()
        end
      else
        print('Cappy: Unknown view: ' .. val)
      end
    end
  },
}

-- src: http://www.wowwiki.com/Creating_a_slash_command
SLASH_CAPPY1 = '/cappy'
SlashCmdList.CAPPY = function(str, _)
  if not str or str == '' then
    str = 'help'
  elseif str == 'ls' or str == 'view list' or str == 'view' then
    str = 'list'
  end

  local matched = false
  for re, cmd in pairs(COMMANDS) do
    local val = string.match(str, re)

    -- print('re: ' .. re)

    if val then
      -- print('starting cmd: ' .. re)
      cmd.fn(val)
      matched = true
      break
    end
  end

  if not matched then
    print("Cappy: Unknown command: " .. str)
  end
end

--
-- db init/update methods
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

  -- save class
  local class, class_fn = UnitClass('player')
  db[guid].class = class_fn

  -- save money and time
  db[guid].money = GetMoney()
  db[guid].time = time()

  -- initialize currency table
  if db[guid].currencies == nil then
    db[guid].currencies = {}
  end
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

local function make_broker_text()
  local currs = CURRENCY_VIEWS[config_get('view')].icons
  local r = ''

  -- walk over visible currencies
  for _, curr_id in ipairs(currs) do
    local _, num, icon, _, _, _, discovered = GetCurrencyInfo(curr_id)

    if not discovered then
      num = 'n/a'
    end

    -- add to result
    r = r .. string.format("\124TInterface/Icons/%s:0\124t %s ", icon, num)
  end

  -- return result
  return r:gsub('%s*$', '')
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
  local money_str = ''

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

  -- append money
  if char.money then
    -- strip silver and copper
    local money = floor(char.money / 10000) * 10000
    money_str = string.format(" (%s)", GetCoinTextureString(money))
  end

  -- TODO: add support for CLASS_ICON_TCOORDS
  return string.format('%s|cff%s%s|r%s',
    icon_str,
    col_str,
    char.name,
    money_str
  )
end

local function get_row(curr_id, curr)
  local cap_str, cap_pct = '  ', ' '
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
    string.format("\124TInterface/Icons/%s:0\124t %s", icon, name),
    curr.amount,
    string.format("%s", cap_str),
    cap_pct
  }
end

--
-- data broker methods
--

function get_tooltip_header(filter_id)
  local name, _, icon = GetCurrencyInfo(filter_id or 396)
  local view_text = CURRENCY_VIEWS[config_get('view')].head

  -- override view text
  if filter_id then
    view_text = string.format(" (%s)", name)
  end

  return string.format("\124TInterface/Icons/%s:0\124t |cFFFFFFFF%s%s|r",
    icon,
    "Cappy",
    view_text
  )
end

function add_tooltip_header(tooltip, filter_id)
  local text = get_tooltip_header(filter_id)

  tooltip:AddLine(' ')
  tooltip:SetCell(tooltip:GetLineCount(), 1, text, nil, nil, 2)
end

function add_cell_link(tooltip, data)
  tooltip:SetCellScript(data.line, data.col, 'OnEnter', function(self, data)
    tooltip:SetCellColor(data.line, data.col, 0, 0, 1.0, 0.5)
  end, data)

  tooltip:SetCellScript(data.line, data.col, 'OnLeave', function(self, data)
    tooltip:SetCellColor(data.line, data.col, 0, 0, 0, 0)
  end, data)

  tooltip:SetCellScript(data.line, data.col, 'OnMouseUp', function(self, data)
    -- local curr_name = GetCurrencyInfo(data.curr_id)
    -- chat_log('clicked ' .. curr_name)
    curr_filter_id = data.curr_id
    redraw_tooltip()
  end, data)
end

function add_char_to_tooltip(tooltip, guid, char, layout, filter_id)
  -- add character name
  tooltip:AddLine(get_char_header(guid, char))

  if char.currencies then
    if filter_id then
      local curr = char.currencies[filter_id]

      if curr then
        tooltip:AddLine(unpack(get_row(filter_id, curr)))
      end
    else
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

        -- add cell filters
        for i, curr_id in ipairs(row_curr_ids) do
          add_cell_link(tooltip, {
            line    = tooltip:GetLineCount(),
            col     = (i - 1) * 5 + 1,
            curr_id = curr_id,
          })
        end
      end
    end
  end

  -- delimit characters
  tooltip:AddLine(' ')
end

function is_standard_currency(curr_id)
  for _, std_curr_id in pairs(STANDARD_CURRENCY_IDS) do
    if curr_id == std_curr_id then
      return true
    end
  end

  return false
end


function add_char_extras_to_tooltip(tooltip, guid, char)
  local ids = CURRENCY_IDS

  -- sort currency ids by name
  table.sort(ids, function(a, b)
    local an = GetCurrencyInfo(a)
    local bn = GetCurrencyInfo(b)

    return (an or '') < (bn or '')
  end)

  if char.currencies then
    for _, curr_id in ipairs(ids) do
      local curr = char.currencies[curr_id]
      if not is_standard_currency(curr_id) and curr then
        tooltip:AddLine(unpack(get_row(curr_id, curr)))

        -- add currency link
        add_cell_link(tooltip, {
          line    = tooltip:GetLineCount(),
          col     = 1,
          curr_id = curr_id,
        })
      end
    end
  end
end

function add_clear_filter_btn(tooltip, filter_id)
  local name, _, icon = GetCurrencyInfo(filter_id)
  local f = "|TInterface/Icons/%s:0|t |cFFFFFF00Remove Filter|r"

  tooltip:AddLine(string.format(f, icon))
  add_cell_link(tooltip, {
    line    = tooltip:GetLineCount(),
    col     = 1,
    curr_id = nil,
  })
end

function add_tooltip_bbar(tooltip)
  tooltip:AddSeparator()
  tooltip:AddLine(' ')
end

-- create cappy data object
local cdo = LDB:NewDataObject(ADDON_NAME, {
  type = "data source",
  -- icon = "Interface/Icons/Inv_Misc_Armorkit_18",
  text = ""
})

function redraw_tooltip()
  -- release existing tooltip, if necessary
  if tooltip then
    LibQTip:Release(tooltip)
    tooltip = nil
  end

  -- redraw tooltip
  cdo.OnEnter(cached_cdo_frame)
end

function cdo.OnClick(self, btn, down)
  local NEXT_VIEW = {
    ["all"]       = "pve",
    ["pve"]       = "pvp",
    ["pvp"]       = "all-wide",
    ["all-wide"]  = "pve-wide",
    ["pve-wide"]  = "pvp-wide",
    ["pvp-wide"]  = "all",
  }

  if not down then
    if btn == 'RightButton' then
      -- reset view, remove filter
      config_set('view', 'all')
      curr_filter_id = nil
    elseif btn == 'LeftButton' then
      if curr_filter_id then
        -- clear filter
        curr_filter_id = nil
      else
        -- switch to next view
        config_set('view', NEXT_VIEW[config_get('view')])
      end
    end

    -- update button text to reflect view
    cdo.text = make_broker_text()

    -- redraw tooltip
    cached_cdo_frame = self
    redraw_tooltip()

    -- show currency frame on click
    -- ToggleCharacter("TokenFrame")
  end
end

function cdo.OnEnter(self)
  local layout = CURRENCY_VIEWS[config_get('view')]
  local cols = layout.init
  local curr_guid = UnitGUID('player')
  local ignored = config_get('ignored') or {}

  -- release existing tooltip, if necessary
  if tooltip then
    LibQTip:Release(tooltip)
    tooltip = nil
  end

  -- create tooltip
  tooltip = LibQTip:Acquire(ADDON_NAME .. 'Tooltip', #cols, unpack(cols))

  -- add header
  add_tooltip_header(tooltip, curr_filter_id)
  tooltip:AddLine(' ')

  -- walk over characters
  for guid, char in sorted_by_name_or_key(db) do
    if guid ~= curr_guid and not ignored[guid] then
      add_char_to_tooltip(tooltip, guid, char, layout, curr_filter_id)
    end
  end

  -- add separator
  tooltip:AddSeparator()
  tooltip:AddLine(' ')

  -- add current character
  add_char_to_tooltip(tooltip, curr_guid, db[curr_guid], layout, curr_filter_id)

  -- add extra currencies for current character to tooltip
  if curr_filter_id then
    add_clear_filter_btn(tooltip, curr_filter_id)
  else
    add_char_extras_to_tooltip(tooltip, curr_guid, db[curr_guid])
  end

  -- anchor, init scrolling, and set autohide delay
  tooltip:SmartAnchorTo(self)
  tooltip:UpdateScrolling()
  tooltip:SetAutoHideDelay(0.25, self)

  -- cache cdo frame
  cached_cdo_frame = self

  -- show tooltip
  tooltip:Show()
end

function cdo.OnLeave(self)
  -- LibQTip:Release(tooltip)
  -- tooltip = nil
end

--
-- wow event methods
--

-- set up a local hidden frame to receive relevant currency events
local frame = CreateFrame("frame")

-- bind to events
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_MONEY")
frame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
frame:RegisterEvent("ADDON_LOADED")

-- add event handler
frame:SetScript("OnEvent", function(self, ev, ...)
  -- print version information on load
  if ev == "PLAYER_ENTERING_WORLD" then
    -- disable this, because it spams the damn chat window
    -- chat_log(string.format("version %s loaded.",
    --   GetAddOnMetadata(ADDON_NAME, "Version")
    -- ))
  end

  -- update currency state
  update()

  -- update data object text
  cdo.text = make_broker_text()
end);
