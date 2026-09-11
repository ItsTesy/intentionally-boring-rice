#!/usr/bin/env bash
# writes answers to $1
set -uo pipefail

OUT=${1:-/dev/stdout}

# stdin too or it spins
[[ -t 0 && -t 1 ]] || { echo "preview needs a terminal, it is all escape codes" >&2; exit 1; }

UNI=1
case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in *[Uu][Tt][Ff]*8*) ;; *) UNI=0 ;; esac
case "${TERM:-}" in linux|dumb|'') UNI=0 ;; esac

NCOL=$(tput colors 2>/dev/null) || NCOL=8
[[ $NCOL =~ ^[0-9]+$ ]] || NCOL=8
RGB=0
case "${TERM:-}" in
	linux|dumb|'') ;;
	*) (( NCOL >= 8 )) && case "${COLORTERM:-}" in truecolor|24bit) RGB=1 ;; esac ;;
esac
[[ -n ${NO_COLOR:-} ]] && { RGB=0; NCOL=0; }

if (( RGB )); then
	C_FG=$'\033[38;2;184;184;184m'; C_DIM=$'\033[38;2;106;106;106m'
	C_HI=$'\033[38;2;240;240;240m'; C_RULE=$'\033[38;2;70;70;70m'
	C_CRIT=$'\033[38;2;160;64;64m'
elif (( NCOL >= 256 )); then
	C_FG=$'\033[38;5;249m'; C_DIM=$'\033[38;5;242m'; C_HI=$'\033[38;5;255m'
	C_RULE=$'\033[38;5;238m'; C_CRIT=$'\033[38;5;131m'
elif (( NCOL >= 8 )); then
	C_FG=$'\033[0m'; C_DIM=$'\033[2m'; C_HI=$'\033[1m'
	C_RULE=$'\033[2m'; C_CRIT=$'\033[31m'
else
	C_FG=''; C_DIM=''; C_HI=''; C_RULE=''; C_CRIT=''
fi
R=$'\033[0m'

if (( UNI )); then
	G_SEL='›'; G_MORE='↓'; G_ELL='…'; G_RULE='─'
	G_VERT='│'; G_TEE='┬'; G_BOT='┴'; G_MARK='▌'; G_BOX='•'
	G_BAR_ON='█'; G_BAR_OFF='░'
	SPIN=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
	LOGO=('██ ██████  ██████ ' '██ ██   ██ ██   ██' '██ ██████  ██████ ' '██ ██   ██ ██   ██' '██ ██████  ██   ██')
else
	G_SEL='>'; G_MORE='v'; G_ELL='...'; G_RULE='-'
	G_VERT='|'; G_TEE='+'; G_BOT='+'; G_MARK='>'; G_BOX='*'
	G_BAR_ON='#'; G_BAR_OFF='.'
	SPIN=('-' '\' '|' '/')
	LOGO=('## ######  ###### ' '## ##   ## ##   ##' '## ######  ###### ' '## ##   ## ##   ##' '## ######  ##   ##')
fi
LOGO_W=18

STTY_SAVE=$(stty -g 2>/dev/null) || STTY_SAVE=
ALT=1
leave_alt() {
	(( ALT )) || return
	ALT=0
	printf '\033[?2026l\033[?2004l\033[?25h\033[?7h\033[?1049l'
}
drain() { local _d; while IFS= read -rsn64 -t 0.01 _d 2>/dev/null; do :; done; }
restore() { leave_alt; drain; [[ -n $STTY_SAVE ]] && stty "$STTY_SAVE" 2>/dev/null; }
trap restore EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
printf '\033[?1049h\033[?25l\033[?7l\033[?2004h\033[2J'
stty -echo susp undef 2>/dev/null

# read -t is a sleep with no fork
NAPFD=
{ exec {NAPFD}<> <(:); } 2>/dev/null || NAPFD=
nap() {
	if [[ -n $NAPFD ]]; then read -rt "$1" -u "$NAPFD" _ 2>/dev/null
	else sleep "$1"; fi
	return 0
}

COLS=80; ROWSN=24; RESIZED=1
trap 'RESIZED=1' WINCH
measure() {
	local s
	s=$(stty size 2>/dev/null) || s='24 80'
	ROWSN=${s%% *}; COLS=${s##* }
	[[ $ROWSN =~ ^[0-9]+$ ]] && (( ROWSN > 0 )) || ROWSN=24
	[[ $COLS  =~ ^[0-9]+$ ]] && (( COLS  > 0 )) || COLS=80
	RESIZED=0
}

OPTS_os='arch debian fedora opensuse void alpine gentoo chimera artix nixos guix kiss crux freebsd ghostbsd dragonfly hardenedbsd openbsd netbsd'
OPTS_wm='sway niri hyprland swayfx river wayfire dwl mangowm i3 bspwm dwm awesome qtile openbox icewm xmonad'
OPTS_bar='waybar yambar polybar tint2 none'
OPTS_launcher='fuzzel tofi wofi bemenu rofi dmenu none'
OPTS_terminal='foot alacritty kitty st xterm'
OPTS_notifs='dunst mako swaync none'
OPTS_fastfetch='no yes'
OPTS_aur='no yes'
MODULES='workspaces time date volume battery'

ALLFIELDS=(os aur wm bar launcher terminal notifs fastfetch)
FIELDS=()
ZONES=(barleft barmid barright)
declare -A ZLAB=( [barleft]=left [barmid]=center [barright]=right )
declare -A FLABEL=()
declare -A ABBR=( [workspaces]=ws [time]=time [date]=date [volume]=vol [battery]=bat )

declare -A HASMOD=()
if [[ -n ${IBR_MODMAP:-} && -r ${IBR_MODMAP:-} ]]; then
	while IFS=$'\t' read -r _bar _item _wm _name; do
		[[ -z ${_bar:-} ]] && continue
		HASMOD["$_bar:$_item:$_wm"]=$_name
	done < "$IBR_MODMAP"
fi
nocenter() { [[ ${SEL[bar]} == tint2 ]]; }

hasitems() { [[ ${FIELDS[CUR]} == bar && ${SEL[bar]} != none ]]; }
hasaur() { case ${SEL[os]} in arch|artix) return 0 ;; *) return 1 ;; esac; }

# w wayland x x11 b both
declare -A DS=(
	[sway]=w [niri]=w [hyprland]=w [swayfx]=w [river]=w [wayfire]=w [dwl]=w [mangowm]=w
	[i3]=x [bspwm]=x [dwm]=x [awesome]=x [openbox]=x [icewm]=x [xmonad]=x [qtile]=b
	[waybar]=w [yambar]=b [polybar]=x [tint2]=x
	[fuzzel]=w [tofi]=w [wofi]=w [bemenu]=b [dmenu]=x [rofi]=b
	[foot]=w [alacritty]=b [kitty]=b [st]=x [xterm]=x
	[dunst]=b [mako]=w [swaync]=w [none]=b
)

declare -A OSDS=()

AURHAS='swayfx dwl mangowm dwm st yambar tofi'

declare -A GONE=(
	[arch]='swayfx dwl mangowm dwm st yambar tofi'
	[artix]='swayfx dwl mangowm dwm st yambar tofi'
	[debian]='swayfx mangowm hyprland niri tofi swaync'
	[fedora]='swayfx mangowm dwl'
	[opensuse]='swayfx mangowm dwl tofi'
	[void]='swayfx mangowm wayfire'
	[alpine]='swayfx mangowm wayfire yambar swaync tofi'
	[gentoo]='swayfx mangowm'
	[chimera]='swayfx mangowm wayfire yambar swaync hyprland dwm bspwm awesome qtile openbox xmonad polybar tint2 st xterm'
	[nixos]=''
	[guix]=''
	[kiss]='swayfx mangowm wayfire yambar swaync tint2 icewm hyprland niri dwl river i3 bspwm awesome qtile openbox xmonad polybar rofi kitty st'
	[crux]='swayfx mangowm dwl niri hyprland swaync yambar waybar polybar rofi kitty st bspwm awesome qtile icewm xmonad river wayfire dwm fuzzel bemenu'
	[freebsd]='hyprland niri swayfx mangowm dwl swaync mako waybar yambar'
	[ghostbsd]='hyprland niri swayfx mangowm dwl swaync mako waybar yambar'
	[dragonfly]='hyprland niri swayfx mangowm dwl swaync mako waybar yambar wayfire'
	[hardenedbsd]='hyprland niri swayfx mangowm dwl swaync mako waybar yambar'
	[openbsd]='yambar tint2 dwl river hyprland swayfx mangowm mako swaync tofi'
	[netbsd]='yambar tofi dwl river hyprland swayfx mangowm niri wayfire waybar fuzzel wofi mako swaync'
)

declare -A HAVEPKG
if [[ -n ${IBR_PKGMAP:-} && -r ${IBR_PKGMAP:-} ]]; then
	while IFS=$'\t' read -r _b _c _p; do
		[[ $_b == "${IBR_BACKEND:-}" && -n $_p ]] && HAVEPKG[$_c]=1
	done < "$IBR_PKGMAP"
	_gone=''
	for _c in $OPTS_wm $OPTS_bar $OPTS_launcher $OPTS_terminal $OPTS_notifs; do
		[[ $_c == none ]] && continue
		[[ -n ${HAVEPKG[$_c]:-} ]] && continue
		case " dwm dwl mangowm st " in *" $_c "*) continue ;; esac
		_gone+="$_c "
	done
	GONE[${IBR_OS:-arch}]=${_gone% }
fi

declare -A SEL=(
	[os]=arch [aur]=no [wm]=sway [bar]=waybar [launcher]=fuzzel
	[terminal]=foot [notifs]=dunst [fastfetch]=no
	[barleft]=workspaces [barmid]='' [barright]=time
)

if [[ -n ${IBR_OS:-} ]]; then
	SEL[os]=$IBR_OS
	OPTS_os=$IBR_OS
elif [[ -r /etc/os-release ]]; then
	_id=$(. /etc/os-release 2>/dev/null && printf '%s' "${ID:-}")
	case " $OPTS_os " in *" $_id "*) SEL[os]=$_id ;; esac
fi

WHY=''
why() {   # $1 component, $2 field
	local c=$1 fld=${2:-} d=${SEL[os]} w=${SEL[wm]}
	WHY=''
	case " ${GONE[$d]:-} " in *" $c "*)
		if hasaur && [[ ${SEL[aur]} == yes ]] && [[ " $AURHAS " == *" $c "* ]]; then :
		else WHY='not in your repos'; return; fi
		;;
	esac
	local have=${DS[$c]:-b} osds=${OSDS[$d]:-b}
	if [[ $osds != b && $have != b && $have != "$osds" ]]; then
		[[ $osds == x ]] && WHY='no wayland here' || WHY='no x11 here'
		return
	fi
	if [[ $fld == baritems ]]; then
		if (( ${#HASMOD[@]} )); then
			[[ -n ${HASMOD[${SEL[bar]}:$c:$w]:-} ]] && return
			[[ -n ${HASMOD[${SEL[bar]}:$c:*]:-} ]] && return
			WHY="not in ${SEL[bar]}"
		fi
		return
	fi
	[[ $fld == wm || $fld == os || $fld == fastfetch || $fld == aur ]] && return
	[[ $c == none ]] && return
	local want=${DS[$w]:-b}
	[[ $want == b || $have == b || $want == "$have" ]] && return
	case $have in
		w) WHY='wayland only' ;;
		x) WHY='x11 only' ;;
	esac
}

CUR=0 FOCUS=0 OCUR=0 OTOP=0 FTOP=0

setfields() {
	local f prev=${FIELDS[CUR]:-os}
	FIELDS=()
	for f in "${ALLFIELDS[@]}"; do
		[[ $f == aur ]] && ! hasaur && continue
		FIELDS+=("$f")
	done
	CUR=0
	for f in "${!FIELDS[@]}"; do
		[[ ${FIELDS[f]} == "$prev" ]] && { CUR=$f; break; }
	done
}

inany() {
	local m=$1 f
	for f in "${ZONES[@]}"; do
		[[ " ${SEL[$f]} " == *" $m "* ]] && return 0
	done
	return 1
}

zonetoggle() {
	local m=$1 f x out
	if inany "$m"; then
		for f in "${ZONES[@]}"; do
			out=''
			for x in ${SEL[$f]}; do [[ $x == "$m" ]] || out+="$x "; done
			SEL[$f]=${out% }
		done
	else
		SEL[barright]="${SEL[barright]:+${SEL[barright]} }$m"
	fi
}

ENAME=(); EKIND=(); EWHY=()
INAME=(); IKIND=(); IWHY=()
# 0 unavailable 1 pickable 2 rule 3 heading
LIST_N=0; ILIST_N=0
ICUR=0; ITOP=0

splititems() {
	local o z i bad=() badw=() off=()
	INAME=(); IKIND=(); IWHY=()
	for z in "${ZONES[@]}"; do
		[[ $z == barmid ]] && nocenter && continue
		INAME+=("${ZLAB[$z]}"); IKIND+=(3); IWHY+=('')
		for o in ${SEL[$z]}; do
			why "$o" baritems; [[ -n $WHY ]] && continue
			INAME+=("$o"); IKIND+=(1); IWHY+=("$z")
		done
	done
	for o in $MODULES; do
		inany "$o" && continue
		why "$o" baritems
		if [[ -n $WHY ]]; then bad+=("$o"); badw+=("$WHY"); else off+=("$o"); fi
	done
	INAME+=('off'); IKIND+=(3); IWHY+=('')
	for o in ${off[@]+"${off[@]}"}; do INAME+=("$o"); IKIND+=(1); IWHY+=(''); done
	if (( ${#bad[@]} )); then
		INAME+=(''); IKIND+=(2); IWHY+=('')
		for i in "${!bad[@]}"; do INAME+=("${bad[i]}"); IKIND+=(0); IWHY+=("${badw[i]}"); done
	fi
	ILIST_N=${#INAME[@]}
}

iskip() {
	local d=$1
	while (( ICUR > 0 && ICUR < ILIST_N - 1 && IKIND[ICUR] > 1 )); do (( ICUR += d )); done
	(( ICUR < 0 )) && ICUR=0
	(( ICUR >= ILIST_N )) && ICUR=$(( ILIST_N - 1 ))
	while (( ICUR > 0 && IKIND[ICUR] > 1 )); do (( ICUR-- )); done
	while (( ICUR < ILIST_N - 1 && IKIND[ICUR] > 1 )); do (( ICUR++ )); done
}

ifind() {
	local m=$1 i
	for i in "${!INAME[@]}"; do
		(( IKIND[i] == 1 )) && [[ ${INAME[i]} == "$m" ]] && { ICUR=$i; return; }
	done
}

split() {   # $1 field
	local ref="OPTS_$1" o i
	local bad=() badw=()
	ENAME=(); EKIND=(); EWHY=()
	for o in ${!ref}; do
		why "$o" "$1"
		if [[ -z $WHY ]]; then ENAME+=("$o"); EKIND+=(1); EWHY+=('')
		else bad+=("$o"); badw+=("$WHY"); fi
	done
	if (( ${#bad[@]} )); then
		ENAME+=(''); EKIND+=(2); EWHY+=('')
		for i in "${!bad[@]}"; do ENAME+=("${bad[i]}"); EKIND+=(0); EWHY+=("${badw[i]}"); done
	fi
	LIST_N=${#ENAME[@]}
}

skiprow() {
	local d=$1
	while (( OCUR > 0 && OCUR < LIST_N - 1 && EKIND[OCUR] > 1 )); do (( OCUR += d )); done
	(( OCUR < 0 )) && OCUR=0
	(( OCUR >= LIST_N )) && OCUR=$(( LIST_N - 1 ))
	while (( OCUR > 0 && EKIND[OCUR] > 1 )); do (( OCUR-- )); done
	while (( OCUR < LIST_N - 1 && EKIND[OCUR] > 1 )); do (( OCUR++ )); done
}

zonemove() {
	local d=$1 m=$2 seq=() f x i j t
	for f in "${ZONES[@]}"; do
		[[ $f == barmid ]] && nocenter && continue
		seq+=("h:$f")
		for x in ${SEL[$f]}; do seq+=("i:$x"); done
	done
	i=-1
	for j in "${!seq[@]}"; do [[ ${seq[j]} == "i:$m" ]] && { i=$j; break; }; done
	(( i < 0 )) && return
	j=$(( i + d ))
	(( j < 1 || j >= ${#seq[@]} )) && return
	t=${seq[i]}; seq[i]=${seq[j]}; seq[j]=$t
	for f in "${ZONES[@]}"; do SEL[$f]=''; done
	f=''
	for x in "${seq[@]}"; do
		if [[ ${x%%:*} == h ]]; then f=${x#*:}
		else SEL[$f]="${SEL[$f]:+${SEL[$f]} }${x#*:}"; fi
	done
	splititems
	ifind "$m"
}

repair() {
	local f i z m keep
	for f in wm bar launcher terminal notifs; do
		why "${SEL[$f]}" "$f"
		[[ -z $WHY ]] && continue
		split "$f"
		for i in "${!ENAME[@]}"; do
			(( EKIND[i] == 1 )) && { SEL[$f]=${ENAME[i]}; break; }
		done
	done
	if nocenter && [[ -n ${SEL[barmid]} ]]; then
		SEL[barright]="${SEL[barmid]}${SEL[barright]:+ ${SEL[barright]}}"
		SEL[barmid]=''
	fi
	for z in "${ZONES[@]}"; do
		keep=''
		for m in ${SEL[$z]}; do
			why "$m" baritems
			[[ -z $WHY ]] && keep+="$m "
		done
		SEL[$z]=${keep% }
	done
}

PKGS=0 CFGS=0 BACKUPS=0
counts() {
	local f c cfg=${XDG_CONFIG_HOME:-$HOME/.config}
	CFGS=0; PKGS=0; BACKUPS=0
	for f in wm bar launcher terminal notifs; do
		c=${SEL[$f]}
		[[ $c == none ]] && continue
		why "$c" "$f"
		[[ -n $WHY ]] && continue
		(( CFGS++ ))
		[[ -n ${HAVEPKG[$c]:-} ]] && (( PKGS++ ))
		[[ -e $cfg/$c ]] && (( BACKUPS++ ))
	done
	local h
	if [[ ${DS[${SEL[wm]}]:-w} == w ]]; then
		h='swaybg swayidle swaylock grim slurp wl-clipboard'
	else
		h='xsetroot i3lock maim xclip xorg-xrandr idle'
	fi
	for c in $h; do [[ -n ${HAVEPKG[$c]:-} ]] && (( PKGS++ )); done
	[[ ${SEL[bar]} == waybar ]] && [[ -n ${HAVEPKG[python]:-} ]] && (( PKGS++ ))
	[[ ${SEL[fastfetch]} == yes ]] && (( PKGS++ ))
}

sync_ocur() {
	local f=${FIELDS[CUR]} i
	(( FOCUS > 1 )) && ! hasitems && FOCUS=1
	split "$f"
	OCUR=0; OTOP=0
	for (( i=0; i<LIST_N; i++ )); do
		(( EKIND[i] == 1 )) && [[ ${ENAME[i]} == "${SEL[$f]}" ]] && { OCUR=$i; return; }
	done
}

ENT_NAME='' ENT_KIND=0 ENT_WHY=''
entry() { ENT_NAME=${ENAME[$1]}; ENT_KIND=${EKIND[$1]}; ENT_WHY=${EWHY[$1]}; }

BUF=()
b() { BUF+=("$1"); }

flush() {
	local out=$'\033[?2026h\033[H' i n=${#BUF[@]}
	(( n > ROWSN )) && n=$ROWSN
	for (( i=0; i<n; i++ )); do
		out+="${BUF[i]}"$'\033[K'
		(( i < n - 1 )) && out+=$'\r\n'
	done
	out+=$'\033[J\033[?2026l'
	printf '%s' "$out"
}

TR=''
trunc() {
	local s=$1 n=$2
	if   (( n < 1 ));      then TR=''
	elif (( ${#s} <= n )); then TR=$s
	else TR="${s:0:n-${#G_ELL}}$G_ELL"; fi
}
PD=''
pad() { printf -v PD '%-*s' "$2" "$1"; }
RL=''
rule() { local n=$1; if (( n < 1 )); then RL=''; else printf -v RL '%*s' "$n" ''; RL=${RL// /$G_RULE}; fi; }

LW=20 LABW=10 MW=0 RW=40 PANES=2
geom() {
	LABW=10
	PANES=2
	hasitems && (( COLS >= 68 )) && PANES=3
	if (( PANES == 3 )); then
		LW=$(( COLS / 4 )); (( LW > 24 )) && LW=24; (( LW < 18 )) && LW=18
		MW=16; (( COLS >= 92 )) && MW=20
		RW=$(( COLS - LW - MW - 7 ))
	else
		LW=$(( COLS / 3 )); (( LW > 26 )) && LW=26; (( LW < 20 )) && LW=20
		MW=0
		RW=$(( COLS - LW - 5 ))
	fi
	(( RW < 10 )) && RW=10
}

RULES=0 SUM=0 FOOTBLANK=0 LEAD=0 BODYH=7 RWIN=0 NARROW=0
budget() {
	local nf=${#FIELDS[@]} want
	NARROW=0; (( COLS < 56 )) && NARROW=1
	split "${FIELDS[CUR]}"
	ILIST_N=0
	hasitems && splititems

	want=$(( LIST_N + 2 ))
	(( PANES == 3 || FOCUS == 2 )) && (( ILIST_N + 2 > want )) && want=$(( ILIST_N + 2 ))
	if (( NARROW )); then
		if (( FOCUS )); then BODYH=$want; else BODYH=$nf; fi
	else
		BODYH=$nf; (( want > BODYH )) && BODYH=$want
	fi
	local maxbody=$(( ROWSN - 2 ))
	(( BODYH > maxbody )) && BODYH=$maxbody
	(( BODYH < 1 )) && BODYH=1

	RWIN=$(( BODYH - 2 ))
	(( RWIN < 0 )) && RWIN=0
	(( LIST_N > RWIN )) && (( RWIN-- ))
	(( RWIN < 0 )) && RWIN=0

	local free=$(( ROWSN - 2 - BODYH ))
	RULES=0; SUM=0; FOOTBLANK=0; LEAD=0
	(( free >= 2 )) && { RULES=1; (( free -= 2 )); }
	(( free >= 1 )) && { SUM=1; (( free-- )); }
	(( free >= 1 )) && { FOOTBLANK=1; (( free-- )); }
	(( free >= 1 )) && { LEAD=1; (( free-- )); }

	(( CUR < FTOP )) && FTOP=$CUR
	(( CUR >= FTOP + BODYH )) && FTOP=$(( CUR - BODYH + 1 ))
	(( FTOP > nf - BODYH )) && FTOP=$(( nf - BODYH ))
	(( FTOP < 0 )) && FTOP=0

	(( OCUR >= LIST_N )) && OCUR=$(( LIST_N - 1 ))
	(( OCUR < 0 )) && OCUR=0
	if (( RWIN > 0 )); then
		(( OCUR < OTOP )) && OTOP=$OCUR
		(( OCUR >= OTOP + RWIN )) && OTOP=$(( OCUR - RWIN + 1 ))
		(( OTOP > LIST_N - RWIN )) && OTOP=$(( LIST_N - RWIN ))
		(( OTOP < 0 )) && OTOP=0
	fi

	(( ICUR >= ILIST_N )) && ICUR=$(( ILIST_N - 1 ))
	(( ICUR < 0 )) && ICUR=0
	if (( RWIN > 0 && ILIST_N > 0 )); then
		(( ICUR < ITOP )) && ITOP=$ICUR
		(( ICUR >= ITOP + RWIN )) && ITOP=$(( ICUR - RWIN + 1 ))
		(( ITOP > ILIST_N - RWIN )) && ITOP=$(( ILIST_N - RWIN ))
		(( ITOP < 0 )) && ITOP=0
	fi
}

title() {
	local left='ibr' right=${SEL[os]} gap g
	gap=$(( COLS - 4 - ${#left} - ${#right} ))
	if (( gap < 2 )); then b "  $C_HI$left$R"
	else printf -v g '%*s' "$gap" ''; b "  $C_HI$left$C_DIM$g$right$R"; fi
}

pane_rule() {
	if (( NARROW )); then
		rule $(( COLS - 4 )); b "  $C_RULE$RL$R"
		return
	fi
	local a m
	rule "$LW"; a=$RL
	if (( PANES == 3 )); then
		rule $(( MW + 2 )); m=$RL
		rule "$RW"
		b "  $C_RULE$a$1$m$1$RL$R"
	else
		rule "$RW"
		b "  $C_RULE$a$1$RL$R"
	fi
}

LC=''
leftcell() {
	local i=$(( $1 + FTOP )) f v
	if (( i >= ${#FIELDS[@]} )); then printf -v LC '%*s' "$LW" ''; return; fi
	f=${FIELDS[i]}
	LC='  '; (( i == CUR )) && LC="$G_MARK "
	trunc "${FLABEL[$f]:-$f}" "$LABW"; pad "$TR" "$LABW"; LC+=$PD
	v=${SEL[$f]:-}
	trunc "$v" $(( LW - LABW - 2 )); pad "$TR" $(( LW - LABW - 2 )); LC+=$PD
}

RR='' RRVIS=0
rightrow() {
	local i=$1 w=$2
	RR=''; RRVIS=0
	if (( i == 0 )); then trunc "${FIELDS[CUR]}" "$w"; RR="$C_DIM$TR"; RRVIS=${#TR}; return; fi
	(( i == 1 )) && return
	if (( RWIN > 0 && i - 2 == RWIN && LIST_N > OTOP + RWIN )); then
		RR="$C_DIM$G_ELL $(( LIST_N - OTOP - RWIN )) more $G_MORE"
		RRVIS=$(( ${#G_ELL} + ${#G_MORE} + 8 ))
		return
	fi
	local k=$(( i - 2 + OTOP ))
	(( k >= LIST_N )) && return
	entry "$k"

	if (( ENT_KIND == 2 )); then rule $(( w > 16 ? 16 : w )); RR="$C_RULE$RL"; RRVIS=${#RL}; return; fi
	if (( ENT_KIND == 3 )); then trunc "$ENT_NAME" "$w"; RR="$C_DIM$TR"; RRVIS=${#TR}; return; fi

	local mark='  ' col=$C_FG fld=${FIELDS[CUR]}
	if (( FOCUS == 1 && k == OCUR )); then mark="$G_SEL "; col=$C_HI
	elif (( ! ENT_KIND )); then col=$C_DIM
	elif [[ $ENT_NAME == "${SEL[$fld]:-}" ]]; then col=$C_HI
	fi

	if (( ! ENT_KIND )) && [[ -n $ENT_WHY ]] && (( w >= 22 )); then
		trunc "$ENT_NAME" 11; pad "$TR" 11; RR="$col$mark$PD"
		local wcol=$C_DIM
		[[ $ENT_WHY == 'not in your repos' ]] && wcol=$C_CRIT
		trunc "$ENT_WHY" $(( w - 15 )); RR+="$wcol$TR"; RRVIS=$(( ${#mark} + 11 + ${#TR} ))
	else
		trunc "$ENT_NAME" $(( w - 2 )); RR="$col$mark$TR"; RRVIS=$(( ${#mark} + ${#TR} ))
	fi
}

IR=''
itemrow() {
	local i=$1 w=$2
	IR=''
	if (( i == 0 )); then trunc 'items' "$w"; IR="$C_DIM$TR"; return; fi
	(( i == 1 )) && return
	if (( RWIN > 0 && i - 2 == RWIN && ILIST_N > ITOP + RWIN )); then
		IR="$C_DIM$G_ELL $(( ILIST_N - ITOP - RWIN )) more $G_MORE"
		return
	fi
	local k=$(( i - 2 + ITOP ))
	(( k >= ILIST_N )) && return
	local nm=${INAME[k]} kd=${IKIND[k]} wy=${IWHY[k]}

	if (( kd == 2 )); then rule $(( w > 14 ? 14 : w )); IR="$C_RULE$RL"; return; fi
	if (( kd == 3 )); then trunc "$nm" "$w"; IR="$C_DIM$TR"; return; fi

	local mark='  ' col=$C_FG box='  '
	(( kd == 1 )) && [[ -n $wy ]] && { box="$G_BOX "; col=$C_HI; }
	if (( FOCUS == 2 && k == ICUR )); then mark="$G_SEL "; col=$C_HI
	elif (( ! kd )); then col=$C_DIM
	fi
	mark="$mark$box"
	if (( ! kd )) && [[ -n $wy ]] && (( w >= 22 )); then
		trunc "$nm" 11; pad "$TR" 12; IR="$col$mark$PD"
		trunc "$wy" $(( w - 16 )); IR+="$C_DIM$TR"
	else
		trunc "$nm" $(( w - 4 )); IR="$col$mark$TR"
	fi
}

body() {
	local i lcol gap
	for (( i=0; i<BODYH; i++ )); do
		if (( NARROW )); then
			case $FOCUS in
				0) leftcell "$i"; b "  $C_FG$LC$R" ;;
				1) rightrow "$i" $(( COLS - 4 )); b "  $RR$R" ;;
				*) itemrow "$i" $(( COLS - 4 )); b "  $IR$R" ;;
			esac
			continue
		fi
		leftcell "$i"
		lcol=$C_FG
		(( FTOP + i == CUR && FTOP + i < ${#FIELDS[@]} )) && lcol=$C_HI
		if (( PANES == 3 )); then
			rightrow "$i" "$MW"
			itemrow "$i" "$RW"
			printf -v gap '%*s' $(( MW - RRVIS < 0 ? 0 : MW - RRVIS )) ''
			b "  $lcol$LC$C_RULE$G_VERT $RR$gap $C_RULE$G_VERT $IR$R"
		elif (( FOCUS == 2 )); then
			itemrow "$i" "$RW"
			b "  $lcol$LC$C_RULE$G_VERT $IR$R"
		else
			rightrow "$i" "$RW"
			b "  $lcol$LC$C_RULE$G_VERT $RR$R"
		fi
	done
}

summary() {
	counts
	if (( COLS >= 46 )); then
		b "  $C_DIM$PKGS packages   $CFGS configs   backs up $BACKUPS$R"
	else
		b "  $C_DIM$PKGS pkgs $CFGS cfgs$R"
	fi
}

footer() {
	local t
	if (( FOCUS == 2 )); then
		if   (( COLS >= 66 )); then t='enter adds   shift+up/down moves   esc back   i install'
		elif (( COLS >= 44 )); then t='enter adds  shift+arrows  esc  i install'
		elif (( COLS >= 28 )); then t='enter adds  esc  i install'
		else t='esc  i  q'; fi
	elif (( FOCUS == 1 )); then
		if   (( COLS >= 66 )) && hasitems; then t='enter choose   right for items   esc back   i install'
		elif (( COLS >= 54 )); then t='enter choose   esc back   i install   q quit'
		elif (( COLS >= 44 )); then t='enter choose  esc  i install'
		elif (( COLS >= 28 )); then t='enter choose  esc  i'
		else t='esc  i  q'; fi
	else
		if   (( COLS >= 54 )); then t='up/down move   enter open   i install   q quit'
		elif (( COLS >= 44 )); then t='up/down  enter open  i install  q quit'
		elif (( COLS >= 33 )); then t='enter open  i install  q quit'
		else t='i install  q quit'; fi
	fi
	b "  $C_DIM$t$R"
}

toosmall() {
	BUF=()
	b "$C_CRIT"'terminal too small'"$R"
	b "$C_DIM${COLS}x${ROWSN}, need 30x10$R"
	flush
}

form() {
	geom; budget
	BUF=()
	(( LEAD )) && b ''
	title
	(( RULES )) && pane_rule "$G_TEE"
	body
	(( RULES )) && pane_rule "$G_BOT"
	(( SUM )) && summary
	(( FOOTBLANK )) && b ''
	footer
	flush
}

intro() {
	local pos row ch i d t r line top
	local lut=(100 93 75 50 25 7 0)
	for (( pos=-8; pos<=LOGO_W+8; pos++ )); do
		(( RESIZED )) && measure
		if (( COLS < 30 || ROWSN < 10 )); then toosmall; nap 0.05; continue; fi
		BUF=()
		top=$(( (ROWSN - 7) / 2 ))
		for (( i=0; i<top; i++ )); do b ''; done
		for row in "${LOGO[@]}"; do
			if (( ! RGB )); then b "  $C_FG$row$R"; continue; fi
			line='  '
			for (( i=0; i<${#row}; i++ )); do
				ch=${row:i:1}
				d=$(( i - pos )); (( d < 0 )) && d=$(( -d ))
				if (( d <= 6 )); then
					t=${lut[d]}; r=$(( 184 + 71 * t / 100 ))
					line+=$'\033[38;2;'"$r;$r;${r}m$ch"
				else
					line+="$C_FG$ch"
				fi
			done
			b "$line$R"
		done
		b ''
		trunc 'intentionally boring rice' $(( COLS - 4 )); b "  $C_DIM$TR$R"
		flush
		nap 0.03
	done
	nap 0.25
}

# 0.05 fits an arrow
K=''
readkey() {
	local c rc
	IFS= read -rsn1 -t 0.2 K; rc=$?
	(( rc )) && return $rc
	[[ $K != $'\033' ]] && return 0
	IFS= read -rsn1 -t 0.05 c || return 0
	if [[ $c != '[' && $c != 'O' ]]; then K=$c; return 0; fi
	K+=$c
	while IFS= read -rsn1 -t 0.05 c; do
		K+=$c
		[[ $c == [a-zA-Z~] ]] && break
	done
	return 0
}

eat_paste() {
	local c seen=''
	while IFS= read -rsn1 -t 0.2 c; do
		seen+=$c
		[[ $seen == *$'\033[201~' ]] && return
		(( ${#seen} > 4096 )) && seen=${seen: -8}
	done
}

setfields
measure
repair
intro
sync_ocur

DIRTY=1
while :; do
	if (( RESIZED )); then measure; DIRTY=1; fi
	if (( DIRTY )); then
		if (( COLS < 30 || ROWSN < 10 )); then toosmall; else form; fi
		DIRTY=0
	fi

	readkey; rc=$?
	(( rc == 1 )) && break
	(( rc > 1 )) && continue
	[[ $K == $'\033[200~' ]] && { eat_paste; continue; }
	DIRTY=1

	case $K in
		$'\033[A'|k)
			case $FOCUS in
				2) (( ICUR-- )); (( ICUR < 0 )) && ICUR=0; iskip -1 ;;
				1) (( OCUR-- )); (( OCUR < 0 )) && OCUR=0; skiprow -1 ;;
				*) (( CUR-- )); (( CUR < 0 )) && CUR=0; sync_ocur ;;
			esac ;;
		$'\033[B'|j)
			case $FOCUS in
				2) (( ICUR++ )); (( ICUR >= ILIST_N )) && ICUR=$(( ILIST_N - 1 )); iskip 1 ;;
				1) (( OCUR++ )); (( OCUR >= LIST_N )) && OCUR=$(( LIST_N - 1 )); skiprow 1 ;;
				*) (( CUR++ )); (( CUR >= ${#FIELDS[@]} )) && CUR=$(( ${#FIELDS[@]} - 1 )); sync_ocur ;;
			esac ;;
		$'\033[1;2A')
			(( FOCUS == 2 )) && { zonemove -1 "${INAME[ICUR]}"; } ;;
		$'\033[1;2B')
			(( FOCUS == 2 )) && { zonemove 1 "${INAME[ICUR]}"; } ;;
		$'\033[C'|l|$'\t')
			if (( FOCUS == 0 )); then FOCUS=1; sync_ocur
			elif (( FOCUS == 1 )) && hasitems; then FOCUS=2; splititems; ICUR=0; ITOP=0; iskip 1
			fi ;;
		$'\033[D'|h)  (( FOCUS )) && (( FOCUS-- )) ;;
		'')
			case $FOCUS in
				2)
					if (( IKIND[ICUR] == 1 )); then
						m=${INAME[ICUR]}
						zonetoggle "$m"
						splititems
						ifind "$m"
						iskip 1
					fi ;;
				1)
					entry "$OCUR"
					if (( ENT_KIND == 1 )); then
						SEL[${FIELDS[CUR]}]=$ENT_NAME
						[[ ${FIELDS[CUR]} == os ]] && setfields
						repair
						FOCUS=0
						sync_ocur
					fi ;;
				*) FOCUS=1; sync_ocur ;;
			esac ;;
		$'\033')  (( FOCUS )) && (( FOCUS-- )) ;;
		i)
			leave_alt
			drain
			{
				printf 'WM=%s\n' "${SEL[wm]}"
				printf 'BAR=%s\n' "${SEL[bar]}"
				printf 'LAUNCHER=%s\n' "${SEL[launcher]}"
				printf 'TERMINAL=%s\n' "${SEL[terminal]}"
				printf 'NOTIFS=%s\n' "${SEL[notifs]}"
				printf 'FASTFETCH=%s\n' "${SEL[fastfetch]}"
				printf 'USE_AUR=%s\n' "${SEL[aur]:-no}"
				printf 'ITEMS_LEFT=%q\n' "${SEL[barleft]}"
				printf 'ITEMS_MID=%q\n' "${SEL[barmid]}"
				printf 'ITEMS_RIGHT=%q\n' "${SEL[barright]}"
			} > "$OUT"
			exit 0 ;;
		q)  leave_alt; exit 1 ;;
	esac
done
