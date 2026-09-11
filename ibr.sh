#!/usr/bin/env bash
# intentionally boring rice
#   bash <(curl -s https://raw.githubusercontent.com/ItsTesy/ibr/main/ibr.sh)
set -uo pipefail

REPO=${IBR_REPO:-https://github.com/ItsTesy/ibr}
BRANCH=${IBR_BRANCH:-main}
SRC=${IBR_SRC:-}
YES=0 DRY=0 PICKED=0 RESTORE=''

while (( $# )); do
	case $1 in
		-y|--yes)  YES=1 ;;
		-n|--dry-run) DRY=1 ;;
		restore)   RESTORE=${2:-}; shift ;;
		-h|--help)
			printf 'usage: ibr [-y] [-n]\n       ibr restore <timestamp>\n'
			exit 0 ;;
		*) printf 'unknown argument: %s\n' "$1" >&2; exit 2 ;;
	esac
	shift
done

die() { printf 'ibr: %s\n' "$1" >&2; exit "${2:-1}"; }
[[ -n ${BASH_VERSION:-} ]] || die "this needs bash, run: bash <(curl -s ...)"
(( ${BASH_VERSINFO[0]} >= 4 )) || die "needs bash 4 or newer, found $BASH_VERSION"
[[ $(id -u) -eq 0 ]] && die "do not run this as root, it writes to your home"

CFG=${XDG_CONFIG_HOME:-$HOME/.config}
STAMP=$(date +%Y%m%d-%H%M%S)
BACKUP="$CFG/ibr-backup-$STAMP"

if [[ -n $RESTORE ]]; then
	d="$CFG/ibr-backup-$RESTORE"
	[[ -d $d ]] || die "no backup at $d"
	( cd "$d" && for p in * .[!.]*; do
		[[ -e $p ]] || continue
		rm -rf "${CFG:?}/$p"
		cp -rf "$p" "$CFG/$p"
	done )
	printf 'restored %s\n' "$d"
	exit 0
fi

detect_os() {
	local id like
	if [[ -r /etc/os-release ]]; then
		id=$(. /etc/os-release 2>/dev/null && printf '%s' "${ID:-}")
		like=$(. /etc/os-release 2>/dev/null && printf '%s' "${ID_LIKE:-}")
	fi
	case $(uname -s) in
		FreeBSD)   OS=freebsd; return ;;
		OpenBSD)   OS=openbsd; return ;;
		NetBSD)    OS=netbsd; return ;;
		DragonFly) OS=dragonfly; return ;;
	esac
	case " $OPTS_os " in *" $id "*) OS=$id; return ;; esac
	for l in $like; do
		case " $OPTS_os " in *" $l "*) OS=$l; return ;; esac
	done
	OS=''
}

backend_of() {
	case $1 in
		arch|artix|manjaro|endeavouros|cachyos|garuda) echo pacman ;;
		debian|ubuntu|linuxmint|pop|zorin|kali|raspbian) echo apt ;;
		fedora|nobara|rhel|almalinux|rocky|centos) echo dnf ;;
		opensuse*|sles) echo zypper ;;
		void) echo xbps ;;
		alpine|postmarketos) echo apk ;;
		chimera) echo apk-chimera ;;
		gentoo|funtoo) echo portage ;;
		nixos) echo nix ;;
		guix) echo guix ;;
		kiss) echo kiss ;;
		crux) echo crux ;;
		freebsd|ghostbsd|dragonfly|hardenedbsd) echo pkg ;;
		openbsd) echo openbsd ;;
		netbsd) echo netbsd ;;
		*) echo '' ;;
	esac
}

install_cmd() {
	case $1 in
		pacman)      echo "sudo pacman -S --needed --noconfirm" ;;
		apt)         echo "sudo apt-get install -y" ;;
		dnf)         echo "sudo dnf install -y" ;;
		zypper)      echo "sudo zypper --non-interactive install" ;;
		xbps)        echo "sudo xbps-install -Sy" ;;
		apk|apk-chimera) echo "sudo apk add" ;;
		portage)     echo "sudo emerge --ask=n" ;;
		nix)         echo "nix-env -iA" ;;
		guix)        echo "guix install" ;;
		pkg)         echo "sudo pkg install -y" ;;
		openbsd)     echo "doas pkg_add" ;;
		netbsd)      echo "sudo pkgin -y install" ;;
		crux)        echo "sudo prt-get depinst" ;;
		kiss)        echo "kiss build" ;;
	esac
}

AUR=''
aur_helper() {
	local h
	for h in paru yay; do command -v "$h" >/dev/null && { AUR=$h; return 0; }; done
	return 1
}

declare -A PKG
load_packages() {
	local f=$1 b c p
	while IFS=$'\t' read -r b c p; do
		[[ -z ${b:-} || $b == \#* ]] && continue
		PKG["$b:$c"]=$p
	done < "$f"
}

pkgfor() { printf '%s' "${PKG[$BACKEND:$1]:-}"; }
have()   { [[ -n $(pkgfor "$1") ]]; }

OPTS_os='arch debian fedora opensuse void alpine gentoo chimera artix nixos guix kiss crux freebsd ghostbsd dragonfly hardenedbsd openbsd netbsd'
OPTS_wm='sway niri hyprland swayfx river wayfire dwl mangowm i3 bspwm dwm awesome qtile openbox icewm xmonad'
OPTS_bar='waybar yambar polybar tint2 none'
OPTS_launcher='fuzzel tofi wofi bemenu rofi dmenu none'
OPTS_terminal='foot alacritty kitty st xterm'
OPTS_notifs='dunst mako swaync none'

declare -A DS=(
	[sway]=w [niri]=w [hyprland]=w [swayfx]=w [river]=w [wayfire]=w [dwl]=w [mangowm]=w
	[i3]=x [bspwm]=x [dwm]=x [awesome]=x [openbox]=x [icewm]=x [xmonad]=x [qtile]=b
	[waybar]=w [yambar]=b [polybar]=x [tint2]=x
	[fuzzel]=w [tofi]=w [wofi]=w [bemenu]=b [dmenu]=x [rofi]=b
	[foot]=w [alacritty]=b [kitty]=b [st]=x [xterm]=x
	[dunst]=b [mako]=w [swaync]=w [none]=b
)

BUILD=' dwm dwl mangowm st '

# no headers no build
buildable() {
	local d
	for d in $(builddeps "$1"); do
		[[ -n $(pkgfor "$d") ]] || return 1
	done
	return 0
}

builddeps() {
	case $1 in
		dwm|st)       echo 'cc-toolchain xlib xft xinerama fontconfig' ;;
		dwl)          echo 'cc-toolchain wayland wayland-protocols wlroots libinput pixman' ;;
		mangowm)      echo 'cc-toolchain meson wayland wayland-protocols wlroots libinput pixman scenefx' ;;
	esac
}
buildsrc() {
	case $1 in
		dwm)     echo https://git.suckless.org/dwm ;;
		st)      echo https://git.suckless.org/st ;;
		dwl)     echo https://codeberg.org/dwl/dwl ;;
		mangowm) echo https://github.com/DreamMaoMao/mango ;;
	esac
}

# a c array cannot hold a pipeline
wrappers() {
	local b=$HOME/.local/bin
	mkdir -p "$b"
	{
		printf '#!/bin/sh\n'
		if [[ ${DS[$WM]} == w ]]; then
			printf 'grim -g "$(slurp)" - | wl-copy\n'
		else
			printf 'maim -s | xclip -selection clipboard -t image/png\n'
		fi
	} > "$b/ibr-shot"
	{
		printf '#!/bin/sh\n'
		case $LAUNCHER in
			fuzzel) printf 'exec fuzzel "$@"\n' ;;
			tofi)   printf 'exec tofi-drun "$@"\n' ;;
			wofi)   printf 'exec wofi --show drun "$@"\n' ;;
			bemenu) printf '. "$HOME/.config/bemenu/bemenu.env" 2>/dev/null\nexec bemenu-run "$@"\n' ;;
			rofi)   printf 'exec rofi -show drun "$@"\n' ;;
			dmenu)  printf "exec dmenu_run -fn 'JetBrainsMono Nerd Font-10' -nb '#101010' -nf '#b8b8b8' -sb '#4a4a4a' -sf '#f0f0f0' \"\$@\"\n" ;;
			none)   printf 'exit 0\n' ;;
		esac
	} > "$b/ibr-menu"
	chmod +x "$b/ibr-shot" "$b/ibr-menu"
}

sub() {   # $1 file
	sed -i "s|@TERM@|$TERMINAL|g; s|@MENU@|ibr-menu|g; s|@SHOT@|ibr-shot|g" "$1"
}

back_up() {   # $1 path under $CFG
	local p=$CFG/$1
	[[ -e $p ]] || return 0
	mkdir -p "$BACKUP/$(dirname "$1")"
	cp -rf "$p" "$BACKUP/$1"
	rm -rf "$p"
}

place() {   # $1 source under configs/, $2 destination under $CFG
	local s=$SRC/configs/$1 d=$CFG/$2 f
	[[ -e $s ]] || return 0
	back_up "$2"
	mkdir -p "$(dirname "$d")"
	cp -rf "$s" "$d"
	if [[ -d $d ]]; then
		while IFS= read -r f; do sub "$f"; done < <(find "$d" -type f)
	else
		sub "$d"
	fi
}

write_autostart() {
	local f=$CFG/ibr/autostart
	mkdir -p "$CFG/ibr"
	{
		printf '#!/bin/sh\n'
		printf '# written by ibr, edit freely\n\n'
		printf '. "$HOME/.config/ibr/environment"\n\n'
		[[ ${DS[$WM]} == x ]] && printf 'xrdb -merge ~/.Xresources\nxsetroot -solid "#000000"\n'
		[[ ${DS[$WM]} == w ]] && printf 'swaybg -c "#000000" &\n'
		[[ $BAR != none ]] && printf '%s &\n' "$(bar_cmd)"
		[[ $NOTIFS != none ]] && printf '%s &\n' "$NOTIFS"
		[[ $WM == bspwm ]] && printf 'sxhkd &\n'
		if [[ ${DS[$WM]} == w ]]; then
			printf "swayidle -w timeout 600 'swaylock -f'"
			# only these four have dpms
			case $WM in
				sway|swayfx) printf " timeout 900 'swaymsg \"output * dpms off\"' resume 'swaymsg \"output * dpms on\"'" ;;
				hyprland)    printf " timeout 900 'hyprctl dispatch dpms off' resume 'hyprctl dispatch dpms on'" ;;
				niri)        printf " timeout 900 'niri msg action power-off-monitors'" ;;
			esac
			printf ' &\n'
		else
			printf 'xset s 600\nxset +dpms dpms 900 900 900\n'
			printf 'if command -v xss-lock >/dev/null 2>&1; then\n'
			printf '\txss-lock -- ~/.local/bin/ibr-lock &\n'
			printf 'elif command -v xautolock >/dev/null 2>&1; then\n'
			printf '\txautolock -time 10 -detectsleep -locker ~/.local/bin/ibr-lock &\n'
			printf 'fi\n'
		fi
	} > "$f"
	chmod +x "$f"
}

bar_cmd() {
	case $BAR in
		polybar) echo 'polybar ibr' ;;
		tint2)   echo 'tint2' ;;
		*)       echo "$BAR" ;;
	esac
}

fetch_repo() {
	[[ -n $SRC ]] && return 0
	SRC=$(mktemp -d)
	trap 'rm -rf "$SRC"' EXIT
	if command -v git >/dev/null; then
		git clone -q --depth 1 -b "$BRANCH" "$REPO" "$SRC" || die "clone failed"
	else
		command -v curl >/dev/null || die "need git or curl"
		curl -fsSL "$REPO/archive/refs/heads/$BRANCH.tar.gz" \
			| tar -xz -C "$SRC" --strip-components=1 || die "download failed"
	fi
}

wanted() {
	local w=()
	w+=("$WM")
	[[ $BAR != none ]] && w+=("$BAR")
	[[ $LAUNCHER != none ]] && w+=("$LAUNCHER")
	w+=("$TERMINAL")
	[[ $NOTIFS != none ]] && w+=("$NOTIFS")
	if [[ ${DS[$WM]} == w ]]; then
		w+=(swaybg swayidle swaylock grim slurp wl-clipboard)
	else
		w+=(xsetroot i3lock maim xclip xorg-xrandr idle)
	fi
	[[ $WM == bspwm ]] && w+=(sxhkd)
	[[ $WM == river ]] && w+=(rivertile)
	[[ $FASTFETCH == yes ]] && w+=(fastfetch)
	[[ $BAR == waybar ]] && w+=(python)
	printf '%s\n' "${w[@]}"
}

resolve() {   # -> REPO_PKGS AUR_PKGS BUILD_PKGS MISSING
	local c p
	REPO_PKGS=() AUR_PKGS=() BUILD_PKGS=() MISSING=()
	while read -r c; do
		[[ -z $c ]] && continue
		p=$(pkgfor "$c")
		if [[ -n $p ]]; then
			REPO_PKGS+=($p)
		elif [[ $USE_AUR == yes && $BACKEND == pacman ]]; then
			AUR_PKGS+=("$c")
		elif [[ " $BUILD " == *" $c "* ]] && buildable "$c"; then
			BUILD_PKGS+=("$c")
		else
			MISSING+=("$c")
		fi
	done < <(wanted)
	local d
	for c in ${BUILD_PKGS[@]+"${BUILD_PKGS[@]}"}; do
		for d in $(builddeps "$c"); do
			p=$(pkgfor "$d"); [[ -n $p ]] && REPO_PKGS+=($p)
		done
	done
	local uniq=()
	while IFS= read -r p; do [[ -n $p ]] && uniq+=("$p"); done < <(
		printf '%s\n' ${REPO_PKGS[@]+"${REPO_PKGS[@]}"} | awk '!seen[$0]++')
	REPO_PKGS=(${uniq[@]+"${uniq[@]}"})

	# bemenu alone cannot draw
	if [[ $LAUNCHER == bemenu ]]; then
		if [[ ${DS[$WM]} == w ]]; then p=$(pkgfor bemenu-wayland); else p=$(pkgfor bemenu-x11); fi
		[[ -n $p ]] && REPO_PKGS+=("$p")
	fi
}

# these binaries are not named after their package
wmbin() {
	case $1 in
		swayfx)  echo sway ;;
		mangowm) echo mango ;;
		xmonad)  echo xmonad ;;
		*)       echo "$1" ;;
	esac
}

run() {
	if (( DRY )); then printf '  %s\n' "$*"; return 0; fi
	"$@"
}

do_install() {
	local ic; ic=$(install_cmd "$BACKEND")
	[[ -z $ic ]] && die "no installer for $BACKEND"
	if (( ${#REPO_PKGS[@]} )); then
		printf '\n  %s %s\n\n' "$ic" "${REPO_PKGS[*]}"
		(( DRY )) || $ic "${REPO_PKGS[@]}" || die "package install failed"
	fi
	if (( ${#AUR_PKGS[@]} )); then
		aur_helper || die "aur picked but neither paru nor yay is installed"
		printf '\n  %s -S --needed %s\n\n' "$AUR" "${AUR_PKGS[*]}"
		(( DRY )) || $AUR -S --needed --noconfirm "${AUR_PKGS[@]}" || die "aur build failed"
	fi
}

do_builds() {
	local c url d
	(( ${#BUILD_PKGS[@]} )) || return 0
	command -v git >/dev/null || die "building ${BUILD_PKGS[*]} needs git"
	command -v make >/dev/null || die "building ${BUILD_PKGS[*]} needs a compiler"
	mkdir -p "$HOME/.local/src"
	for c in "${BUILD_PKGS[@]}"; do
		url=$(buildsrc "$c"); [[ -n $url ]] || continue
		d=$HOME/.local/src/$c
		printf '  building %s\n' "$c"
		if (( DRY )); then continue; fi
		[[ -d $d ]] || git clone -q --depth 1 "$url" "$d" || die "clone of $c failed"
		if [[ -f $SRC/configs/wm/$c/config.h ]]; then
			cp "$SRC/configs/wm/$c/config.h" "$d/config.h"
		elif [[ -f $SRC/configs/terminal/$c/config.h ]]; then
			cp "$SRC/configs/terminal/$c/config.h" "$d/config.h"
		elif [[ -f $SRC/configs/launcher/$c/config.h ]]; then
			cp "$SRC/configs/launcher/$c/config.h" "$d/config.h"
		fi
		[[ -f $d/config.h ]] && sub "$d/config.h"
		if [[ -f $d/meson.build ]]; then
			( cd "$d" && meson setup --prefix=/usr/local build >/dev/null 2>&1 \
				&& ninja -C build >/dev/null 2>&1 \
				&& sudo ninja -C build install >/dev/null 2>&1 ) \
				|| die "build of $c failed, see $d"
		else
			( cd "$d" && make >/dev/null 2>&1 && sudo make install >/dev/null 2>&1 ) \
				|| die "build of $c failed, see $d"
		fi
	done
}

do_configs() {
	place "wm/$WM"            "$WM"
	[[ $BAR != none ]]      && place "bar/$BAR"           "$BAR"
	[[ $LAUNCHER != none ]] && place "launcher/$LAUNCHER" "$LAUNCHER"
	place "terminal/$TERMINAL" "$TERMINAL"
	[[ $NOTIFS != none ]]   && place "notifs/$NOTIFS"     "$NOTIFS"
	[[ $FASTFETCH == yes ]] && place "fastfetch"          "fastfetch"

	place "theme/gtk-3.0" "gtk-3.0"
	place "theme/gtk-4.0" "gtk-4.0"
	place "theme/qt5ct.conf" "qt5ct/qt5ct.conf"
	place "theme/environment" "ibr/environment"

	if [[ ${DS[$WM]} == w ]]; then
		place "lock/swaylock.conf" "swaylock/config"
	else
		mkdir -p "$HOME/.local/bin"
		cp -f "$SRC/configs/lock/i3lock.sh" "$HOME/.local/bin/ibr-lock"
		chmod +x "$HOME/.local/bin/ibr-lock"
	fi

	if [[ $TERMINAL == xterm ]]; then
		back_up ../.Xresources 2>/dev/null
		cp -f "$SRC/configs/terminal/xterm/Xresources" "$HOME/.Xresources"
		sub "$HOME/.Xresources"
	fi

	if [[ $FASTFETCH == yes ]]; then
		local rc=$HOME/.bashrc
		grep -q 'fastfetch' "$rc" 2>/dev/null || printf '\nfastfetch\n' >> "$rc"
	fi

	wrappers
	write_autostart
	bar_items
}

declare -A MOD
load_modules() {
	local bar item wm name
	while IFS=$'\t' read -r bar item wm name; do
		[[ -z ${bar:-} ]] && continue
		MOD["$bar:$item:$wm"]=$name
	done < "$1"
}

# one lookup so the picker and installer cannot disagree
modfor() {   # $1 bar, $2 item, $3 wm
	local m=${MOD[$1:$2:$3]:-}
	[[ -z $m ]] && m=${MOD[$1:$2:*]:-}
	printf '%s' "$m"
}

zone_items() {   # $1 zone -> the raw item names the user put there
	case $1 in
		left)   printf '%s' "$ITEMS_LEFT" ;;
		center) printf '%s' "$ITEMS_MID" ;;
		*)      printf '%s' "$ITEMS_RIGHT" ;;
	esac
}

polybar_items() {
	local f=$1 zone n out
	for zone in left center right; do
		out=''
		for n in $(zone_items "$zone"); do out+="$(modfor polybar "$n" "$WM") "; done
		if grep -q "^modules-$zone" "$f"; then
			sed -i "s|^modules-$zone.*|modules-$zone = ${out% }|" "$f"
		else
			sed -i "/^\\[bar\\/ibr\\]/a modules-$zone = ${out% }" "$f"
		fi
	done
}

# yambar module bodies are multi line so the zones get assembled
yambar_items() {
	local f=$1 line zone n mod frag tmp body
	tmp=$(mktemp)
	while IFS= read -r line; do
		case $line in
			'  left: []'|'  center: []'|'  right: []')
				zone=${line#  }; zone=${zone%%:*}
				body=$(mktemp)
				for n in $(zone_items "$zone"); do
					mod=$(modfor yambar "$n" "$WM")
					frag=$SRC/configs/bar/yambar/modules/$mod.yml
					[[ -n $mod && -f $frag ]] || continue
					sed 's|^|    |' "$frag" >> "$body"
				done
				if [[ -s $body ]]; then
					printf '  %s:\n' "$zone" >> "$tmp"
					cat "$body" >> "$tmp"
				else
					printf '  %s: []\n' "$zone" >> "$tmp"
				fi
				rm -f "$body"
				;;
			*) printf '%s\n' "$line" >> "$tmp" ;;
		esac
	done < "$f"
	mv "$tmp" "$f"
	rm -rf "$CFG/yambar/modules"
}

waybar_items() {
	local f=$1
	command -v python3 >/dev/null || {
		printf 'ibr: no python3, waybar keeps its default modules\n' >&2
		return 0
	}
	IBR_WM=$WM IBR_L=$ITEMS_LEFT IBR_M=$ITEMS_MID IBR_R=$ITEMS_RIGHT \
		IBR_MODMAP=$SRC/data/modules.tsv python3 "$SRC/lib/waybar-items.py" "$f"
}

bar_items() {
	[[ $BAR == none ]] && return 0
	local f
	case $BAR in
		waybar)  f=$CFG/waybar/config.jsonc; [[ -f $f ]] && waybar_items  "$f" ;;
		yambar)  f=$CFG/yambar/config.yml;   [[ -f $f ]] && yambar_items  "$f" ;;
		polybar) f=$CFG/polybar/config.ini;  [[ -f $f ]] && polybar_items "$f" ;;
	esac
	return 0
}

defaults() {
	if [[ ${DS[${WM:-sway}]:-w} == w ]]; then
		WM=${WM:-sway} BAR=${BAR:-waybar} LAUNCHER=${LAUNCHER:-fuzzel}
		TERMINAL=${TERMINAL:-foot} NOTIFS=${NOTIFS:-dunst}
	else
		WM=${WM:-i3} BAR=${BAR:-polybar} LAUNCHER=${LAUNCHER:-dmenu}
		TERMINAL=${TERMINAL:-xterm} NOTIFS=${NOTIFS:-dunst}
	fi
	FASTFETCH=${FASTFETCH:-no}
	USE_AUR=${USE_AUR:-no}
	ITEMS_LEFT=${ITEMS_LEFT:-workspaces}
	ITEMS_MID=${ITEMS_MID:-}
	ITEMS_RIGHT=${ITEMS_RIGHT:-time}
}

summary() {
	printf '\n'
	printf '  os         %s (%s)\n' "$OS" "$BACKEND"
	printf '  wm         %s\n' "$WM"
	printf '  bar        %s\n' "$BAR"
	printf '  launcher   %s\n' "$LAUNCHER"
	printf '  terminal   %s\n' "$TERMINAL"
	printf '  notifs     %s\n' "$NOTIFS"
	printf '\n'
	(( ${#MISSING[@]} )) && printf '  not in your repos: %s\n\n' "${MISSING[*]}"
	printf '  %d packages, %d built from source\n' \
		"${#REPO_PKGS[@]}" "${#BUILD_PKGS[@]}"
	printf '  existing configs move to %s\n\n' "$BACKUP"
}

confirm() {
	(( YES || PICKED )) && return 0
	[[ -t 0 ]] || return 0
	local a
	printf '  enter to continue, ctrl-c to stop '
	read -r a || true
}

main() {
	OS=${IBR_OS:-}
	[[ -n $OS ]] || detect_os
	[[ -n $OS ]] || die "cannot tell what this system is, set IBR_OS to one of: $OPTS_os"
	BACKEND=$(backend_of "$OS")
	[[ -n $BACKEND ]] || die "no package backend for $OS"

	fetch_repo
	load_packages "$SRC/data/packages.tsv"
	load_modules "$SRC/data/modules.tsv"

	if [[ -t 0 && -t 1 ]] && (( ! YES )) && [[ -f $SRC/pick.sh ]]; then
		local ans; ans=$(mktemp)
		IBR_OS=$OS IBR_BACKEND=$BACKEND IBR_PKGMAP=$SRC/data/packages.tsv \
			IBR_MODMAP=$SRC/data/modules.tsv \
			bash "$SRC/pick.sh" "$ans" || die "cancelled"
		# shellcheck disable=SC1090
		. "$ans"; rm -f "$ans"; PICKED=1
	fi

	defaults
	resolve
	# do not configure a wm we could not install
	(( DRY )) || for c in ${MISSING[@]+"${MISSING[@]}"}; do
		[[ $c == "$WM" ]] && die "$WM is not in this system's repos, \
pick another or turn the aur on" 3
	done
	summary
	confirm

	(( DRY )) || mkdir -p "$BACKUP"
	do_install
	do_builds
	(( DRY )) || do_configs

	printf '\n'
	local n=0
	(( DRY )) || n=$(find "$CFG" -newer "$BACKUP" -type f 2>/dev/null | grep -c .)
	local bin; bin=$(wmbin "$WM")
	if (( ! DRY )) && ! command -v "$bin" >/dev/null && [[ ! -x /usr/local/bin/$bin ]]; then
		die "$WM said it installed but there is no $bin on PATH"
	fi
	printf '  done. %d packages, %d files written.\n\n' "${#REPO_PKGS[@]}" "$n"
	printf '  old configs in %s\n' "$BACKUP"
	printf '  undo with: ibr restore %s\n\n' "$STAMP"
	printf '  log out, pick %s, log back in.\n\n' "$WM"
}

main
