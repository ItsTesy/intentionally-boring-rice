import os
import subprocess

from libqtile import hook, layout
from libqtile.config import Group, Key, Screen, Drag
from libqtile.lazy import lazy

mod = "mod4"
term = "@TERM@"
menu = "@MENU@"
shot = '@SHOT@'

background = "#101010"
foreground = "#b8b8b8"
dim = "#6a6a6a"
border = "#2a2a2a"
focus = "#4a4a4a"
critical = "#a04040"

keys = [
    Key([mod], "Return", lazy.spawn(term)),
    Key([mod], "d", lazy.spawn(menu)),
    Key([mod, "shift"], "q", lazy.window.kill()),
    Key([mod], "f", lazy.window.toggle_fullscreen()),
    Key([mod, "shift"], "space", lazy.window.toggle_floating()),
    Key([mod, "shift"], "c", lazy.reload_config()),
    Key([mod, "shift"], "e", lazy.shutdown()),
    Key([mod], "h", lazy.layout.left()),
    Key([mod], "j", lazy.layout.down()),
    Key([mod], "k", lazy.layout.up()),
    Key([mod], "l", lazy.layout.right()),
    Key([mod, "shift"], "h", lazy.layout.shuffle_left()),
    Key([mod, "shift"], "j", lazy.layout.shuffle_down()),
    Key([mod, "shift"], "k", lazy.layout.shuffle_up()),
    Key([mod, "shift"], "l", lazy.layout.shuffle_right()),
    Key([], "Print", lazy.spawn(["sh", "-c", shot])),
]

groups = [Group(str(i)) for i in range(1, 10)]

for g in groups:
    keys.append(Key([mod], g.name, lazy.group[g.name].toscreen()))
    keys.append(Key([mod, "shift"], g.name, lazy.window.togroup(g.name, switch_group=False)))

layouts = [
    layout.Columns(
        border_width=1,
        border_focus=focus,
        border_normal=border,
        border_focus_stack=focus,
        border_normal_stack=border,
        border_on_single=True,
        margin=0,
    ),
    layout.Max(
        border_width=1,
        border_focus=focus,
        border_normal=border,
        margin=0,
    ),
]

floating_layout = layout.Floating(
    border_width=1,
    border_focus=focus,
    border_normal=border,
)

screens = [Screen()]

mouse = [
    Drag([mod], "Button1", lazy.window.set_position_floating(),
         start=lazy.window.get_position()),
    Drag([mod], "Button3", lazy.window.set_size_floating(),
         start=lazy.window.get_size()),
]

widget_defaults = dict(
    font="JetBrainsMono Nerd Font",
    fontsize=10,
    foreground=foreground,
    background=background,
    padding=0,
)
extension_defaults = widget_defaults.copy()

follow_mouse_focus = False
auto_minimize = False

@hook.subscribe.startup_once
def autostart():
    subprocess.Popen([os.path.expanduser("~/.config/ibr/autostart")])
