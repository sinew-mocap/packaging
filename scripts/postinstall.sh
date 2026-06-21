#!/bin/sh
# Wire the relocatable /opt tree into the system: PATH symlinks + driver service.
# FHS §3.13: /opt apps own /opt/<vendor>/...; integration via symlinks.
set -e

SINEW_VER="0.4"
BIN="/opt/org.v-sekai/sinew/${SINEW_VER}/bin"

# Symlink the apps onto PATH.
for app in sinew_tui hmd_reader vr_devices anny_demo osctest; do
  [ -x "${BIN}/${app}" ] && ln -sf "${BIN}/${app}" "/usr/local/bin/${app}"
done

# Create the unprivileged 'sinew' service account (in dialout) from sysusers.d.
if command -v systemd-sysusers >/dev/null 2>&1; then
  systemd-sysusers /usr/lib/sysusers.d/sinew-driver.conf || true
fi

# Register the driver service, then apply the Rebocap udev rule so an
# already-plugged dongle picks up the uaccess ACL / dialout access and pulls in
# sinew-driver.service without a replug.
if command -v systemctl >/dev/null 2>&1; then
  systemctl daemon-reload || true
  systemctl enable sinew-driver.service || true
fi
if command -v udevadm >/dev/null 2>&1; then
  udevadm control --reload-rules || true
  # Re-add the tty by path (idVendor lives on the parent, so an attr filter on
  # the tty matches nothing) to fire uaccess + SYSTEMD_WANTS on what's plugged.
  for d in /sys/class/tty/ttyACM*; do
    [ -e "$d" ] && udevadm trigger --action=add "$d" || true
  done
fi

exit 0
