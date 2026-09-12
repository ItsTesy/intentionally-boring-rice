#!/bin/bash
# headless render to /out
set -eu

export HOME=/root
export XDG_RUNTIME_DIR=/tmp/xdg
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"

mkdir -p "$HOME/.config"/{sway,waybar,foot,dunst,ibr,fastfetch}
cp /repo/configs/wm/sway/config          "$HOME/.config/sway/config"
cp /repo/configs/bar/waybar/config.jsonc "$HOME/.config/waybar/config.jsonc"
IBR_WM=sway IBR_L=workspaces IBR_M= IBR_R=time IBR_MODMAP=/repo/data/modules.tsv \
	python3 /repo/lib/waybar-items.py "$HOME/.config/waybar/config.jsonc"
cp /repo/configs/bar/waybar/style.css    "$HOME/.config/waybar/style.css"
cp /repo/configs/terminal/foot/foot.ini  "$HOME/.config/foot/foot.ini"
cp /repo/configs/notifs/dunst/dunstrc    "$HOME/.config/dunst/dunstrc"
cp /repo/configs/fastfetch/config.jsonc  "$HOME/.config/fastfetch/config.jsonc"
cat > "$HOME/.config/ibr/autostart" <<'AS'
#!/bin/sh
swaybg -c "#000000" &
waybar &
dunst &
AS
chmod +x "$HOME/.config/ibr/autostart"

cat > /tmp/render.conf <<CONF
include $HOME/.config/sway/config
output HEADLESS-1 resolution ${RES:-1920x1080}
exec /inner.sh
CONF

cat > /inner.sh <<'INNER'
#!/bin/bash
sleep 3
foot -e bash -c 'cd ~; fastfetch; exec bash' &
sleep 2
swaymsg exec foot &
sleep 4
grim /out/rice.png || true
sleep 1
swaymsg exit
INNER
chmod +x /inner.sh

WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1 \
	faketime "$(date +%Y-%m-%d) 09:00:00" dbus-run-session -- sway -c /tmp/render.conf 2>/tmp/sway.log || true

echo "--- waybar ---"; tail -15 /tmp/waybar.log 2>/dev/null; echo "--- sway log tail ---"
tail -25 /tmp/sway.log || true
ls -la /out
