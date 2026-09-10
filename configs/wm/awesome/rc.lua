local gears = require("gears")
local awful = require("awful")
require("awful.autofocus")
require("awful.rules")
local beautiful = require("beautiful")

local modkey = "Mod4"

beautiful.init({
    font                = "JetBrainsMono Nerd Font 10",
    useless_gap         = 0,
    border_width        = 1,
    border_normal       = "#2a2a2a",
    border_focus        = "#4a4a4a",
    border_marked       = "#a04040",
    border_color_normal = "#2a2a2a",
    border_color_active = "#4a4a4a",
    border_color_urgent = "#a04040",
    bg_normal           = "#101010",
    fg_normal           = "#b8b8b8",
    bg_focus            = "#101010",
    fg_focus            = "#b8b8b8",
    bg_urgent           = "#101010",
    fg_urgent           = "#a04040",
})

awful.layout.layouts = { awful.layout.suit.tile, awful.layout.suit.floating }

awful.screen.connect_for_each_screen(function(s)
    gears.wallpaper.set("#000000")
    awful.tag({ "1", "2", "3", "4", "5", "6", "7", "8", "9" }, s, awful.layout.layouts[1])
end)

local globalkeys = gears.table.join(
    awful.key({ modkey }, "Return", function() awful.spawn("@TERM@") end),
    awful.key({ modkey }, "d", function() awful.spawn("@MENU@") end),
    awful.key({ modkey, "Shift" }, "c", awesome.restart),
    awful.key({ modkey, "Shift" }, "e", awesome.quit),

    awful.key({ modkey }, "h", function() awful.client.focus.global_bydirection("left") end),
    awful.key({ modkey }, "j", function() awful.client.focus.global_bydirection("down") end),
    awful.key({ modkey }, "k", function() awful.client.focus.global_bydirection("up") end),
    awful.key({ modkey }, "l", function() awful.client.focus.global_bydirection("right") end),
    awful.key({ modkey, "Shift" }, "h", function() awful.client.swap.global_bydirection("left") end),
    awful.key({ modkey, "Shift" }, "j", function() awful.client.swap.global_bydirection("down") end),
    awful.key({ modkey, "Shift" }, "k", function() awful.client.swap.global_bydirection("up") end),
    awful.key({ modkey, "Shift" }, "l", function() awful.client.swap.global_bydirection("right") end),

    awful.key({ }, "Print", function() awful.spawn.with_shell("@SHOT@") end)
)

for i = 1, 9 do
    globalkeys = gears.table.join(globalkeys,
        awful.key({ modkey }, "#" .. i + 9, function()
            local t = awful.screen.focused().tags[i]
            if t then t:view_only() end
        end),
        awful.key({ modkey, "Shift" }, "#" .. i + 9, function()
            if client.focus then
                local t = client.focus.screen.tags[i]
                if t then client.focus:move_to_tag(t) end
            end
        end))
end

local clientkeys = gears.table.join(
    awful.key({ modkey, "Shift" }, "q", function(c) c:kill() end),
    awful.key({ modkey }, "f", function(c)
        c.fullscreen = not c.fullscreen
        c:raise()
    end),
    awful.key({ modkey, "Shift" }, "space", awful.client.floating.toggle)
)

local clientbuttons = gears.table.join(
    awful.button({ }, 1, function(c) c:emit_signal("request::activate", "mouse_click", { raise = true }) end),
    awful.button({ modkey }, 1, awful.mouse.client.move),
    awful.button({ modkey }, 3, awful.mouse.client.resize)
)

root.keys(globalkeys)

awful.rules.rules = {
    { rule = { },
      properties = {
          size_hints_honor = false,
          border_width     = beautiful.border_width,
          border_color     = beautiful.border_normal,
          focus            = awful.client.focus.filter,
          raise            = true,
          keys             = clientkeys,
          buttons          = clientbuttons,
          screen           = awful.screen.preferred,
          placement        = awful.placement.no_overlap + awful.placement.no_offscreen,
      }
    },
}

local function border(c)
    if c.urgent then
        c.border_color = "#a04040"
    elseif client.focus == c then
        c.border_color = beautiful.border_focus
    else
        c.border_color = beautiful.border_normal
    end
end

client.connect_signal("focus", border)
client.connect_signal("unfocus", border)
client.connect_signal("property::urgent", border)

awful.spawn.with_shell("~/.config/ibr/autostart")
