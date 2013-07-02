local gears = require("gears")
local awful = require("awful")
local autofocus = require("awful.autofocus")
local rules = require("awful.rules")
local wibox = require("wibox")
local naughty = require("naughty")
local menubar = require("menubar")
local vicious = require("vicious")
local beautiful = require("beautiful")
local xrandr = require("xrandr")
local error = require("error")

local terminal = "urxvt -e zsh -c 'tmux attach'"
local browser = "chromium"
local editor = "gvim"
local modkey = "Mod4"
local home = os.getenv("HOME")
local confdir = home .. "/.config/awesome"
local themes = confdir .. "/themes"
local wallpapers = confdir .. "/wallpapers"
local icons = confdir .. "/icons"
local active_theme = themes .. "/myzenburn"

-- {{{ Theme initialization
beautiful.init(active_theme .. "/theme.lua")
--beautiful.wallpaper = wallpapers .. "/pacman.jpg"
beautiful.wallpaper = wallpapers .. "/nodejs.png"

if beautiful.wallpaper then
  for s = 1, screen.count() do
    gears.wallpaper.maximized(beautiful.wallpaper, s, true)
  end
end
-- }}}

-- {{{ Layouts
local layouts = {
  awful.layout.suit.tile,
  awful.layout.suit.fair,
  awful.layout.suit.floating,
}
-- }}}}

-- {{{ Tags
tags = {
  names  = { "code", "term", "web", "chat", "other"}
}

for s = 1, screen.count() do
  tags[s] = awful.tag(tags.names, s, layouts[1])
  awful.tag.seticon(beautiful.widget_tag_black, tags[s][1])
  awful.tag.seticon(beautiful.widget_tag_red, tags[s][2])
  awful.tag.seticon(beautiful.widget_tag_magenta, tags[s][3])
  awful.tag.seticon(beautiful.widget_tag_green, tags[s][4])
  awful.tag.seticon(beautiful.widget_tag_yellow, tags[s][5])
end
-- }}}

-- {{{ Contextual menu
mymainmenu = awful.menu({
  items = {
    { "term", terminal },
    { "restart", awesome.restart },
    { "quit", awesome.quit },
  }
})
-- }}}

-- {{{ Separators
space = wibox.widget.textbox()
space:set_text(' ')
-- }}}

-- {{{ Arch icon
archicon = wibox.widget.imagebox()
archicon:set_image(beautiful.widget_arch)
-- }}}

-- {{{ MPD
mpdicon = wibox.widget.imagebox()
mpdicon:set_image(beautiful.widget_mpd)
mpdwidget = wibox.widget.textbox()

vicious.register(mpdwidget, vicious.widgets.mpd, function(mpdwidget, args)
  if args["{state}"] == "Play" then
    return args["{Artist}"]..' - '.. args["{Title}"]
  else
    return " - "
  end
end, 10)
-- }}}

-- {{{ Memory
memwidget = wibox.widget.textbox()
memicon = wibox.widget.imagebox()
memicon:set_image(beautiful.widget_mem)

vicious.register(memwidget, vicious.widgets.mem,
  "<span color='" .. beautiful.fg_magenta .. "'>$1%</span>", 13)
-- }}}

-- {{{ CPU
cpuwidget = wibox.widget.textbox()
cpuicon = wibox.widget.imagebox()
cpuicon:set_image(beautiful.widget_cpu)

vicious.register(cpuwidget, vicious.widgets.cpu,
  "<span color='" .. beautiful.fg_green .. "'>$1%</span>", 13)
-- }}}

-- {{{ Pacman Updates
pacicon = wibox.widget.imagebox()
pacicon:set_image(beautiful.widget_pac)
pacwidget = wibox.widget.textbox()

vicious.register(pacwidget, vicious.widgets.pkg,
    "<span color='" .. beautiful.fg_yellow .. "'>$1</span>", 60, "Arch")
-- }}}

-- {{{ Clock
mytextclock = awful.widget.textclock()
-- }}}

mywibox = {}
mypromptbox = {}
mylayoutbox = {}
mytaglist = {}

mytaglist.buttons = awful.util.table.join(
  awful.button({ }, 1, awful.tag.viewonly),
  awful.button({ modkey }, 1, awful.client.movetotag)
)

mytasklist = {}
mytasklist.buttons = awful.util.table.join(
  awful.button({ }, 1, function(c)
    if c == client.focus then
      c.minimized = true
    else
      c.minimized = false
      if not c:isvisible() then
        awful.tag.viewonly(c:tags()[1])
      end
      client.focus = c
      c:raise()
    end
  end)
)

for s = 1, screen.count() do
  mypromptbox[s] = awful.widget.prompt()

  mylayoutbox[s] = awful.widget.layoutbox(s)
  mylayoutbox[s]:buttons(awful.util.table.join(
    awful.button({ }, 1, function() awful.layout.inc(layouts, 1) end),
    awful.button({ }, 3, function() awful.layout.inc(layouts, -1) end)
  ))

  mytaglist[s] = awful.widget.taglist(s, awful.widget.taglist.filter.all,
    mytaglist.buttons)

  mytasklist[s] = awful.widget.tasklist(s,
    awful.widget.tasklist.filter.currenttags, mytasklist.buttons)

  mywibox[s] = awful.wibox({ position = "top", screen = s })

  local left_layout = wibox.layout.fixed.horizontal()
  left_layout:add(archicon)
  left_layout:add(mytaglist[s])
  left_layout:add(space)
  left_layout:add(mypromptbox[s])

  local right_layout = wibox.layout.fixed.horizontal()
  if screen.count() == 2 and s == 2 or screen.count() == 1 then
    right_layout:add(mpdicon)
    right_layout:add(mpdwidget)
    right_layout:add(space)
    right_layout:add(wibox.widget.systray())
    right_layout:add(space)
    right_layout:add(pacicon)
    right_layout:add(pacwidget)
    right_layout:add(cpuicon)
    right_layout:add(cpuwidget)
    right_layout:add(memicon)
    right_layout:add(memwidget)
    right_layout:add(mytextclock)
  end
  right_layout:add(mylayoutbox[s])

  local layout = wibox.layout.align.horizontal()
  layout:set_left(left_layout)
  layout:set_middle(mytasklist[s])
  layout:set_right(right_layout)

  mywibox[s]:set_widget(layout)
end

-- {{{ Mouse bindings
root.buttons(awful.util.table.join(
  awful.button({ }, 3, function() mymainmenu:toggle() end)
))
-- }}}

-- {{{ Key bindings
globalkeys = awful.util.table.join(
  awful.key({ modkey, }, "j", function()
    awful.client.focus.byidx(1)
    if client.focus then client.focus:raise() end
  end),
  awful.key({ modkey, }, "k", function()
    awful.client.focus.byidx(-1)
    if client.focus then client.focus:raise() end
  end),
  awful.key({ modkey, "Mod1" }, "/", function(c)
    local curidx = awful.tag.getidx()
    local dstidx = curidx + 1
    if curidx == 9 then dstidx = 1 end
    awful.client.movetotag(tags[mouse.screen][dstidx], c)
  end),
  awful.key({ modkey, "Mod1"   }, ".", function(c)
    local curidx = awful.tag.getidx()
    local dstidx = curidx - 1
    if curidx == 1 then dstidx = 9 end
    awful.client.movetotag(tags[mouse.screen][dstidx], c)
  end),
  awful.key({ modkey, }, "Return", function() awful.util.spawn(terminal) end),
  awful.key({ modkey, }, "F9", function() awful.util.spawn(editor) end),
  awful.key({ modkey, }, "F10", function() awful.util.spawn(browser) end),
  awful.key({ modkey, "Control" }, "r", awesome.restart),
  awful.key({ modkey, "Control" }, "q", awesome.quit),
  awful.key({ modkey, }, "l", function() awful.tag.incmwfact( 0.05) end),
  awful.key({ modkey, }, "h", function() awful.tag.incmwfact(-0.05) end),
  awful.key({ modkey, }, "space", function() awful.layout.inc(layouts, 1) end),
  awful.key({ modkey, "Control" }, "n", awful.client.restore),
  awful.key({ modkey }, "r", function() mypromptbox[mouse.screen]:run() end),
  awful.key({ modkey, }, "o", awful.client.movetoscreen ),
  awful.key({ modkey, "Mod1" }, "m", function() xrandr.switch(2) end),
  awful.key({ }, "XF86AudioRaiseVolume", function()
    awful.util.spawn("amixer set Master 1%+", false)
  end),
  awful.key({ }, "XF86AudioLowerVolume", function()
    awful.util.spawn("amixer set Master 1%-", false)
  end),
  awful.key({ }, "XF86AudioMute", function()
    awful.util.spawn("amixer set Master toggle", false)
  end),
  awful.key({ "Mod4" }, "F3", function()
    awful.util.spawn("amixer set Master 1%+", false)
  end),
  awful.key({ "Mod4" }, "F2", function()
    awful.util.spawn("amixer set Master 1%-", false)
  end),
  awful.key({ "Mod4" }, "F1", function()
    awful.util.spawn("amixer set Master toggle", false)
  end)
)

clientkeys = awful.util.table.join(
  awful.key({ modkey, "Mod1" }, "c", function(c) c:kill() end),
  awful.key({ modkey, }, "f", function(c) c.fullscreen = not c.fullscreen end),
  awful.key({ modkey, }, "n", function(c) c.minimized = true end),
  awful.key({ modkey, }, "m", function(c)
    c.maximized_horizontal = not c.maximized_horizontal
    c.maximized_vertical = not c.maximized_vertical
  end)
)

clientbuttons = awful.util.table.join(
  awful.button({ }, 1, function (c) client.focus = c; c:raise() end),
  awful.button({ modkey }, 1, awful.mouse.client.move),
  awful.button({ modkey }, 3, awful.mouse.client.resize)
)

keynumber = 0
for s = 1, screen.count() do
  keynumber = math.min(9, math.max(#tags[s], keynumber))
end

for i = 1, keynumber do
  globalkeys = awful.util.table.join(globalkeys,
    awful.key({ modkey }, "#" .. i + 9, function()
      local screen = mouse.screen
      if tags[screen][i] then
        awful.tag.viewonly(tags[screen][i])
      end
    end),
    awful.key({ modkey, "Control" }, "#" .. i + 9, function()
      local screen = mouse.screen
      if tags[screen][i] then
        awful.tag.viewtoggle(tags[screen][i])
      end
    end),
    awful.key({ modkey, "Shift" }, "#" .. i + 9, function()
      if client.focus and tags[client.focus.screen][i] then
        awful.client.movetotag(tags[client.focus.screen][i])
      end
    end),
    awful.key({ modkey, "Control", "Shift" }, "#" .. i + 9, function()
      if client.focus and tags[client.focus.screen][i] then
        awful.client.toggletag(tags[client.focus.screen][i])
      end
    end)
  )
end

root.keys(globalkeys)

-- {{{ Rules
rules.rules = {
    {
      rule = { },
      properties = {
        border_width = beautiful.border_width,
        border_color = beautiful.border_normal,
        focus = awful.client.focus.filter,
        keys = clientkeys,
        buttons = clientbuttons,
        size_hints_honor = false
      }
    },
    { rule = { class = "Exe"}, properties = {floating = true} },
}
-- }}}

-- {{{ Signals
client.connect_signal("manage", function(c, startup)
  c:connect_signal("mouse::enter", function(c)
    if awful.layout.get(c.screen) ~= awful.layout.suit.magnifier
      and awful.client.focus.filter(c) then
      client.focus = c
    end
  end)

  if not startup then
    if not c.size_hints.user_position and not
        c.size_hints.program_position then
      awful.placement.no_overlap(c)
      awful.placement.no_offscreen(c)
    end
  end
end)

client.connect_signal("focus", function(c)
  c.border_color = beautiful.border_focus
end)
client.connect_signal("unfocus", function(c)
  c.border_color = beautiful.border_normal
end)
-- }}}
