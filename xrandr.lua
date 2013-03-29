local gears = require("gears")
local awful = require("awful")
local naughty = require("naughty")
local beautiful = require("beautiful")

local xrandr = {}

local function outputs()
  local outputs = {}
  local xrandr = io.popen("xrandr -q")
  if xrandr then
    for line in xrandr:lines() do
      output = line:match("^([%w-]+) connected ")
      if output then
        outputs[#outputs + 1] = output
      end
    end
    xrandr:close()
  end

  return outputs
end

local function arrange(out)
  local choices  = {}
  local previous = { {} }
  for i = 1, #out do
    local new = {}
    for _, p in pairs(previous) do
      for _, o in pairs(out) do
        if not awful.util.table.hasitem(p, o) then
          new[#new + 1] = awful.util.table.join(p, {o})
        end
      end
    end
    choices = awful.util.table.join(choices, new)
    previous = new
  end

  return choices
end

local function menu()
  local menu = {}
  local out = outputs()
  local choices = arrange(out)

  for _, choice in pairs(choices) do
    local cmd = "xrandr"
    for i, o in pairs(choice) do
      cmd = cmd .. " --output " .. o .. " --auto"
      if i > 1 then
        cmd = cmd .. " --right-of " .. choice[i-1]
      end
    end
    for _, o in pairs(out) do
      if not awful.util.table.hasitem(choice, o) then
        cmd = cmd .. " --output " .. o .. " --off"
      end
    end

    local label = ""
    if #choice == 1 then
      label = 'Only <span weight="bold">' .. choice[1] .. '</span>'
    else
      for i, o in pairs(choice) do
        if i > 1 then label = label .. " + " end
        label = label .. '<span weight="bold">' .. o .. '</span>'
      end
    end

    menu[#menu + 1] = { label, cmd }
  end

  return menu
end

local state = { iterator = nil, timer = nil, cid = nil }
function xrandr.switch(timeout)
  if state.timer then
    state.timer:stop()
    state.timer = nil
  end

  if not state.iterator then
    state.iterator = awful.util.table.iterate(menu(), function()
      return true
    end)
  end

  local next  = state.iterator()
  local label, action
  if not next then
    label = "No change"
    state.iterator = nil
  else
    label, action = unpack(next)
  end
  state.cid = naughty.notify({ text = label,
                               timeout = timeout,
                               screen = mouse.screen,
                               font = font,
                               replaces_id = state.cid
                             }).id

  state.timer = timer { timeout = timeout }
  state.timer:connect_signal("timeout",
  function()
    state.timer:stop()
    state.timer = nil
    state.iterator = nil
    if action then
      awful.util.spawn(action, false)
      gears.wallpaper.maximized(beautiful.wallpaper, s, true)
    end
  end)
  state.timer:start()
end

return xrandr
