#!/bin/sh
pgrep -x i3lock >/dev/null && exit 0

exec i3lock -n -u -e -c 000000
