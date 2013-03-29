local gears = require("gears")
local awful = require("awful")
local autofocus = require("awful.autofocus")
local rules = require("awful.rules")
local wibox = require("wibox")
local naughty = require("naughty")
local menubar = require("menubar")
local vicious = require("vicious")
local beautiful = require("beautiful")
local error = require("error")

local terminal = "urxvt -e zsh -c 'tmux attach'"
local modkey = "Mod4"
local home = os.getenv("HOME")
local confdir = home .. "/.config/awesome"
local themes = confdir .. "/themes"
local wallpapers = confdir .. "/wallpapers"
local icons = confdir .. "/icons"
local active_theme = themes .. "/myzenburn"

beautiful.init(active_theme .. "/theme.lua")
beautiful.wallpaper = wallpapers .. "/pacman.jpg"

local layouts = {
    awful.layout.suit.tile,
    awful.layout.suit.fair,
    awful.layout.suit.floating,
}

if beautiful.wallpaper then
    for s = 1, screen.count() do
        gears.wallpaper.maximized(beautiful.wallpaper, s, true)
    end
end

tags = {
    names  = { "code ", "term ", "web ", "chat ", "else "}
}

for s = 1, screen.count() do
    tags[s] = awful.tag(tags.names, s, layouts[1])
    awful.tag.seticon(icons .. "/black/fs_01.png", tags[s][1])
    awful.tag.seticon(icons .. "/red/cat.png", tags[s][2])
    awful.tag.seticon(icons .. "/magenta/dish.png", tags[s][3])
    awful.tag.seticon(icons .. "/yellow/pacman.png", tags[s][4])
    awful.tag.seticon(icons .. "/green/phones.png", tags[s][5])
end

space = wibox.widget.textbox()
space:set_text(' ')
space2 = wibox.widget.textbox()
space2:set_text('  ')

archicon = wibox.widget.imagebox()
archicon:set_image(icons .. "/blue/arch_10x10.png")

-- Initialize widget
mpdicon = wibox.widget.imagebox()
mpdicon:set_image(icons .. "/blue/play.png")
mpdwidget = wibox.widget.textbox()
-- Register widget
vicious.register(mpdwidget, vicious.widgets.mpd,
    function (mpdwidget, args)
        if args["{state}"] == "Stop" then
            return " - "
        else
            return args["{Artist}"]..' - '.. args["{Title}"]
        end
    end, 10)

mymainmenu = awful.menu({ items = {
   { "Terminal", terminal },
   { "restart", awesome.restart },
   { "quit", awesome.quit },
}})

mylauncher = awful.widget.launcher({ menu = mymainmenu })

menubar.utils.terminal = terminal

memwidget = awful.widget.progressbar()
memwidget:set_width(8)
memwidget:set_height(10)
memwidget:set_vertical(true)
memwidget:set_background_color("#494B4F")
memwidget:set_border_color(nil)
memwidget:set_color({ type = "linear",
                      from = { 0, 0 },
                      to = { 10,0 },
                      stops = {
                          {0, "#AECF96"}, {0.5, "#88A175"}, {1, "#FF5656"}
                      }})
-- Register widget
vicious.register(memwidget, vicious.widgets.mem, "$1", 13)

-- {{{ Pacman Updates
pacicon = wibox.widget.imagebox()
pacicon:set_image(beautiful.widget_pac)

pactext = wibox.widget.textbox()
pactext:set_text('updates')

pacwidget = wibox.widget.textbox()
vicious.register(pacwidget, vicious.widgets.pkg,
    "<span color='" .. beautiful.fg_yellow .. "'>$1</span>", 60, "Arch")
-- }}}

-- {{{ Wibox
-- Create a textclock widget
mytextclock = awful.widget.textclock()

-- {{{ Multiple screen switcher
--
-- Get active outputs
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
   -- We need to enumerate all the way to combinate output. We assume
   -- we want only an horizontal layout.
   local choices  = {}
   local previous = { {} }
   for i = 1, #out do
      -- Find all permutation of length `i`: we take the permutation
      -- of length `i-1` and for each of them, we create new
      -- permutations by adding each output at the end of it if it is
      -- not already present.
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

---- Build available choices
local function menu()
   local menu = {}
   local out = outputs()
   local choices = arrange(out)

   for _, choice in pairs(choices) do
      local cmd = "xrandr"
      -- Enabled outputs
      for i, o in pairs(choice) do
     cmd = cmd .. " --output " .. o .. " --auto"
     if i > 1 then
        cmd = cmd .. " --right-of " .. choice[i-1]
     end
      end
      -- Disabled outputs
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

      menu[#menu + 1] = { label,
              cmd, "/usr/share/icons/oxygen/22x22/devices/video-display.png"}
   end

   return menu
end

---- Display xrandr notifications from choices
local state = { iterator = nil,
        timer = nil,
        cid = nil }
local function xrandr()
   -- Stop any previous timer
   if state.timer then
      state.timer:stop()
      state.timer = nil
   end

   -- Build the list of choices
   if not state.iterator then
      state.iterator = awful.util.table.iterate(menu(),
                    function() return true end)
   end

   -- Select one and display the appropriate notification
   local next  = state.iterator()
   local label, action, icon
   if not next then
      label = "No change"
      icon = "/usr/share/icons/oxygen/22x22/devices/video-display.png"
      state.iterator = nil
   else
      label, action, icon = unpack(next)
   end
   state.cid = naughty.notify({ text = label,
                icon = icon,
                timeout = 4,
                screen = mouse.screen, -- Important, not all screens may be visible
                font = font,
                replaces_id = state.cid }).id

   -- Setup the timer
   state.timer = timer { timeout = 4 }
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
-- }}}

-- Create a wibox for each screen and add it
mywibox = {}
mypromptbox = {}
mylayoutbox = {}
mytaglist = {}
mytaglist.buttons = awful.util.table.join(
                    awful.button({ }, 1, awful.tag.viewonly),
                    awful.button({ modkey }, 1, awful.client.movetotag),
                    awful.button({ }, 3, awful.tag.viewtoggle),
                    awful.button({ modkey }, 3, awful.client.toggletag),
                    awful.button({ }, 4, function(t) awful.tag.viewnext(awful.tag.getscreen(t)) end),
                    awful.button({ }, 5, function(t) awful.tag.viewprev(awful.tag.getscreen(t)) end)
                    )
mytasklist = {}
mytasklist.buttons = awful.util.table.join(
                     awful.button({ }, 1, function (c)
                                              if c == client.focus then
                                                  c.minimized = true
                                              else
                                                  -- Without this, the following
                                                  -- :isvisible() makes no sense
                                                  c.minimized = false
                                                  if not c:isvisible() then
                                                      awful.tag.viewonly(c:tags()[1])
                                                  end
                                                  -- This will also un-minimize
                                                  -- the client, if needed
                                                  client.focus = c
                                                  c:raise()
                                              end
                                          end),
                     awful.button({ }, 3, function ()
                                              if instance then
                                                  instance:hide()
                                                  instance = nil
                                              else
                                                  instance = awful.menu.clients({ width=250 })
                                              end
                                          end),
                     awful.button({ }, 4, function ()
                                              awful.client.focus.byidx(1)
                                              if client.focus then client.focus:raise() end
                                          end),
                     awful.button({ }, 5, function ()
                                              awful.client.focus.byidx(-1)
                                              if client.focus then client.focus:raise() end
                                          end))

for s = 1, screen.count() do
    -- Create a promptbox for each screen
    mypromptbox[s] = awful.widget.prompt()
    -- Create an imagebox widget which will contains an icon indicating which layout we're using.
    -- We need one layoutbox per screen.
    mylayoutbox[s] = awful.widget.layoutbox(s)
    mylayoutbox[s]:buttons(awful.util.table.join(
                           awful.button({ }, 1, function () awful.layout.inc(layouts, 1) end),
                           awful.button({ }, 3, function () awful.layout.inc(layouts, -1) end),
                           awful.button({ }, 4, function () awful.layout.inc(layouts, 1) end),
                           awful.button({ }, 5, function () awful.layout.inc(layouts, -1) end)))
    -- Create a taglist widget
    mytaglist[s] = awful.widget.taglist(s, awful.widget.taglist.filter.all, mytaglist.buttons)

    -- Create a tasklist widget
    mytasklist[s] = awful.widget.tasklist(s, awful.widget.tasklist.filter.currenttags, mytasklist.buttons)

    -- Create the wibox
    mywibox[s] = awful.wibox({ position = "top", screen = s })

    -- Widgets that are aligned to the left
    local left_layout = wibox.layout.fixed.horizontal()
    left_layout:add(mylauncher)
    left_layout:add(archicon)
    left_layout:add(mytaglist[s])
    left_layout:add(space2)
    left_layout:add(mypromptbox[s])

    -- Widgets that are aligned to the right
    local right_layout = wibox.layout.fixed.horizontal()
    if s == 1 then right_layout:add(wibox.widget.systray()) end
    right_layout:add(mpdicon)
    right_layout:add(mpdwidget)
    right_layout:add(space2)
    right_layout:add(pacicon)
    right_layout:add(pacwidget)
    right_layout:add(space)
    right_layout:add(pactext)
    right_layout:add(space2)
    right_layout:add(memwidget)
    right_layout:add(mytextclock)
    right_layout:add(mylayoutbox[s])

    -- Now bring it all together (with the tasklist in the middle)
    local layout = wibox.layout.align.horizontal()
    layout:set_left(left_layout)
    layout:set_middle(mytasklist[s])
    layout:set_right(right_layout)

    mywibox[s]:set_widget(layout)
end
-- }}}

-- {{{ Mouse bindings
root.buttons(awful.util.table.join(
    awful.button({ }, 3, function () mymainmenu:toggle() end),
    awful.button({ }, 4, awful.tag.viewnext),
    awful.button({ }, 5, awful.tag.viewprev)
))
-- }}}

-- {{{ Key bindings
globalkeys = awful.util.table.join(
    awful.key({ modkey,           }, "Left",   awful.tag.viewprev       ),
    awful.key({ modkey,           }, "Right",  awful.tag.viewnext       ),
    awful.key({ modkey,           }, "Escape", awful.tag.history.restore),

    awful.key({ modkey,           }, "j",
        function ()
            awful.client.focus.byidx( 1)
            if client.focus then client.focus:raise() end
        end),
    awful.key({ modkey,           }, "k",
        function ()
            awful.client.focus.byidx(-1)
            if client.focus then client.focus:raise() end
        end),
    awful.key({ modkey,           }, "w", function () mymainmenu:show() end),

    -- Layout manipulation
    awful.key({ modkey, "Shift"   }, "j", function () awful.client.swap.byidx(  1)    end),
    awful.key({ modkey, "Shift"   }, "k", function () awful.client.swap.byidx( -1)    end),
    awful.key({ modkey, "Control" }, "j", function () awful.screen.focus_relative( 1) end),
    awful.key({ modkey, "Control" }, "k", function () awful.screen.focus_relative(-1) end),
    awful.key({ modkey,           }, "u", awful.client.urgent.jumpto),
    awful.key({ modkey,           }, "Tab",
        function ()
            awful.client.focus.history.previous()
            if client.focus then
                client.focus:raise()
            end
        end),

    -- Standard program
    awful.key({ modkey,           }, "Return", function () awful.util.spawn(terminal) end),
    awful.key({ modkey, "Control" }, "r", awesome.restart),
    awful.key({ modkey, "Shift"   }, "q", awesome.quit),

    awful.key({ modkey,           }, "l",     function () awful.tag.incmwfact( 0.05)    end),
    awful.key({ modkey,           }, "h",     function () awful.tag.incmwfact(-0.05)    end),
    awful.key({ modkey, "Shift"   }, "h",     function () awful.tag.incnmaster( 1)      end),
    awful.key({ modkey, "Shift"   }, "l",     function () awful.tag.incnmaster(-1)      end),
    awful.key({ modkey, "Control" }, "h",     function () awful.tag.incncol( 1)         end),
    awful.key({ modkey, "Control" }, "l",     function () awful.tag.incncol(-1)         end),
    awful.key({ modkey,           }, "space", function () awful.layout.inc(layouts,  1) end),
    awful.key({ modkey, "Shift"   }, "space", function () awful.layout.inc(layouts, -1) end),

    awful.key({ modkey, "Control" }, "n", awful.client.restore),

    -- Prompt
    awful.key({ modkey },            "r",     function () mypromptbox[mouse.screen]:run() end),

    awful.key({ modkey }, "x",
              function ()
                  awful.prompt.run({ prompt = "Run Lua code: " },
                  mypromptbox[mouse.screen].widget,
                  awful.util.eval, nil,
                  awful.util.getdir("cache") .. "/history_eval")
              end),
    -- Menubar
    awful.key({ modkey }, "p", function() menubar.show() end)
)

clientkeys = awful.util.table.join(
    awful.key({ modkey, "Mod1"    }, "m",      xrandr),
    awful.key({ modkey,           }, "f",      function (c) c.fullscreen = not c.fullscreen  end),
    awful.key({ modkey, "Mod1"   }, "c",      function (c) c:kill()                         end),
    awful.key({ modkey, "Control" }, "space",  awful.client.floating.toggle                     ),
    awful.key({ modkey, "Control" }, "Return", function (c) c:swap(awful.client.getmaster()) end),
    awful.key({ modkey,           }, "o",      awful.client.movetoscreen                        ),
    awful.key({ modkey,           }, "t",      function (c) c.ontop = not c.ontop            end),
    awful.key({ modkey,           }, "n",
        function (c)
            -- The client currently has the input focus, so it cannot be
            -- minimized, since minimized clients can't have the focus.
            c.minimized = true
        end),
    awful.key({ modkey,           }, "m",
        function (c)
            c.maximized_horizontal = not c.maximized_horizontal
            c.maximized_vertical   = not c.maximized_vertical
        end)
)

-- Compute the maximum number of digit we need, limited to 9
keynumber = 0
for s = 1, screen.count() do
   keynumber = math.min(9, math.max(#tags[s], keynumber))
end

-- Bind all key numbers to tags.
-- Be careful: we use keycodes to make it works on any keyboard layout.
-- This should map on the top row of your keyboard, usually 1 to 9.
for i = 1, keynumber do
    globalkeys = awful.util.table.join(globalkeys,
        awful.key({ modkey }, "#" .. i + 9,
                  function ()
                        local screen = mouse.screen
                        if tags[screen][i] then
                            awful.tag.viewonly(tags[screen][i])
                        end
                  end),
        awful.key({ modkey, "Control" }, "#" .. i + 9,
                  function ()
                      local screen = mouse.screen
                      if tags[screen][i] then
                          awful.tag.viewtoggle(tags[screen][i])
                      end
                  end),
        awful.key({ modkey, "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus and tags[client.focus.screen][i] then
                          awful.client.movetotag(tags[client.focus.screen][i])
                      end
                  end),
        awful.key({ modkey, "Control", "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus and tags[client.focus.screen][i] then
                          awful.client.toggletag(tags[client.focus.screen][i])
                      end
                  end))
end

-- {{{ Move window to previous/next tag
globalkeys = awful.util.table.join(globalkeys,
    awful.key({ modkey, "Mod1"   }, "/",
        function (c)
            local curidx = awful.tag.getidx()
            local dstidx = curidx + 1
            if curidx == 9 then dstidx = 1 end
            awful.client.movetotag(tags[mouse.screen][dstidx], c)
        end),
    awful.key({ modkey, "Mod1"   }, ".",
      function (c)
            local curidx = awful.tag.getidx()
            local dstidx = curidx - 1
            if curidx == 1 then dstidx = 9 end
            awful.client.movetotag(tags[mouse.screen][dstidx], c)
        end))
-- }}}

-- {{{ Volume configuration
globalkeys = awful.util.table.join(globalkeys,
    awful.key({ }, "XF86AudioRaiseVolume", function () awful.util.spawn("amixer set Master 1%+", false) end),
    awful.key({ }, "XF86AudioLowerVolume", function () awful.util.spawn("amixer set Master 1%-", false) end),
    awful.key({ }, "XF86AudioMute", function () awful.util.spawn("amixer sset Master toggle", false) end)
)
-- }}}

clientbuttons = awful.util.table.join(
    awful.button({ }, 1, function (c) client.focus = c; c:raise() end),
    awful.button({ modkey }, 1, awful.mouse.client.move),
    awful.button({ modkey }, 3, awful.mouse.client.resize))

-- Set keys
root.keys(globalkeys)
-- }}}

-- {{{ Rules
rules.rules = {
    -- All clients will match this rule.
    { rule = { },
      properties = { border_width = beautiful.border_width,
                     border_color = beautiful.border_normal,
                     focus = awful.client.focus.filter,
                     keys = clientkeys,
                     buttons = clientbuttons,
                     size_hints_honor = false } },
}
-- }}}

-- {{{ Signals
-- Signal function to execute when a new client appears.
client.connect_signal("manage", function (c, startup)
    -- Enable sloppy focus
    c:connect_signal("mouse::enter", function(c)
        if awful.layout.get(c.screen) ~= awful.layout.suit.magnifier
            and awful.client.focus.filter(c) then
            client.focus = c
        end
    end)

    if not startup then
        -- Set the windows at the slave,
        -- i.e. put it at the end of others instead of setting it master.
        -- awful.client.setslave(c)

        -- Put windows in a smart way, only if they does not set an initial position.
        if not c.size_hints.user_position and not c.size_hints.program_position then
            awful.placement.no_overlap(c)
            awful.placement.no_offscreen(c)
        end
    end

    local titlebars_enabled = false
    if titlebars_enabled and (c.type == "normal" or c.type == "dialog") then
        -- Widgets that are aligned to the left
        local left_layout = wibox.layout.fixed.horizontal()
        left_layout:add(awful.titlebar.widget.iconwidget(c))

        -- Widgets that are aligned to the right
        local right_layout = wibox.layout.fixed.horizontal()
        right_layout:add(awful.titlebar.widget.floatingbutton(c))
        right_layout:add(awful.titlebar.widget.maximizedbutton(c))
        right_layout:add(awful.titlebar.widget.stickybutton(c))
        right_layout:add(awful.titlebar.widget.ontopbutton(c))
        right_layout:add(awful.titlebar.widget.closebutton(c))

        -- The title goes in the middle
        local title = awful.titlebar.widget.titlewidget(c)
        title:buttons(awful.util.table.join(
                awful.button({ }, 1, function()
                    client.focus = c
                    c:raise()
                    awful.mouse.client.move(c)
                end),
                awful.button({ }, 3, function()
                    client.focus = c
                    c:raise()
                    awful.mouse.client.resize(c)
                end)
                ))

        -- Now bring it all together
        local layout = wibox.layout.align.horizontal()
        layout:set_left(left_layout)
        layout:set_right(right_layout)
        layout:set_middle(title)

        awful.titlebar(c):set_widget(layout)
    end
end)

client.connect_signal("focus", function(c) c.border_color = beautiful.border_focus end)
client.connect_signal("unfocus", function(c) c.border_color = beautiful.border_normal end)
-- }}}
