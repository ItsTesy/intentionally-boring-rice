#!/usr/bin/env bash
# runs every config through its own parser
cd "$(dirname "$0")/.." || exit 1
export XDG_RUNTIME_DIR=/tmp/xdg WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1
mkdir -p "$XDG_RUNTIME_DIR"; chmod 700 "$XDG_RUNTIME_DIR"
setcap -r /usr/bin/sway 2>/dev/null

bad=0
# qtile imports by path so the name must be a legal module
sub() {
	local d=/tmp/ibrsub.$$
	mkdir -p "$d"
	sed -e 's|@TERM@|foot|g' -e 's|@MENU@|ibr-menu|g' -e 's|@SHOT@|ibr-shot|g' \
		"$1" > "$d/$(basename "$1")"
	printf '%s' "$d/$(basename "$1")"
}
r() {
	local name=$1; shift
	if "$@" >/tmp/v.$$ 2>&1; then printf 'ok    %s\n' "$name"
	else printf 'FAIL  %s: %s\n' "$name" "$(grep -iv 'MESSAGE:' /tmp/v.$$ | head -1)"; bad=1; fi
}

r sway      sway --validate -c "$(sub configs/wm/sway/config)"
r i3        i3 -C -c "$(sub configs/wm/i3/config)"
r awesome   awesome -k -c "$(sub configs/wm/awesome/rc.lua)"
r qtile     python lib/qtile-check.py "$(sub configs/wm/qtile/config.py)"
r openbox   xmllint --noout configs/wm/openbox/rc.xml
r dunst     python -c "
import configparser,sys
c=configparser.ConfigParser(strict=False,allow_no_value=True)
c.read(sys.argv[1])
assert 'global' in c, 'no [global] section'
" configs/notifs/dunst/dunstrc
r foot      foot --check-config --config=configs/terminal/foot/foot.ini
r fuzzel    fuzzel --check-config --config="$(sub configs/launcher/fuzzel/fuzzel.ini)"

for f in configs/notifs/swaync/config.json configs/bar/waybar/config.jsonc configs/fastfetch/config.jsonc; do
	r "$(basename "$f")" python -c "
import json,re,sys
json.loads(re.sub(r'^\s*//.*$','',open(sys.argv[1]).read(),flags=re.M))" "$f"
done

r alacritty python -c "import tomllib,sys;tomllib.load(open(sys.argv[1],'rb'))" configs/terminal/alacritty/alacritty.toml
r yambar    python -c "import yaml,sys;yaml.safe_load(open(sys.argv[1]))" configs/bar/yambar/config.yml
for f in configs/bar/yambar/modules/*.yml; do
	r "$(basename "$f")" python -c "
import yaml,sys
d=yaml.safe_load(open(sys.argv[1]))
assert isinstance(d,list) and len(d)==1, 'not a single module'" "$f"
done

for f in configs/wm/river/init configs/wm/bspwm/bspwmrc configs/wm/openbox/autostart \
         configs/lock/*.sh configs/theme/environment \
         configs/launcher/bemenu/bemenu.env configs/wm/icewm/startup; do
	[ -f "$f" ] && r "$(basename "$f")" sh -n "$f"
done

r shellcheck-free bash -n ibr.sh
r picker-syntax  bash -n pick.sh

rm -rf /tmp/ibrsub.$$ /tmp/v.$$
echo
[ $bad -eq 0 ] && echo "all configs parse" || echo "some configs do not parse"
exit $bad
