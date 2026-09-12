FROM archlinux:base

RUN pacman -Syu --noconfirm --needed \
	sway swaybg swayidle swaylock waybar foot dunst fuzzel \
	grim slurp wl-clipboard ttf-jetbrains-mono-nerd libcap dbus fastfetch libfaketime python \
	&& pacman -Scc --noconfirm

# docker cant grant cap_sys_nice
RUN setcap -r /usr/bin/sway && dbus-uuidgen > /etc/machine-id

COPY shot.sh /shot.sh
RUN chmod +x /shot.sh
ENTRYPOINT ["/shot.sh"]
