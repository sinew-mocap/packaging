#!/bin/sh
# Undo what postinstall wired up.  The /opt tree itself is removed by the package
# manager (it owns those files); we only clean the symlinks + profile.d we added.
set -e

for app in sinew_tui hmd_reader vr_devices anny_demo; do
  link="/usr/local/bin/${app}"
  [ -L "${link}" ] && rm -f "${link}"
done
rm -f /usr/local/bin/blender-mcp
rm -f /etc/profile.d/org.v-sekai-blender.sh

# The package manager removes the udev rule file itself; reload so the kernel
# drops the rule we no longer ship.
if command -v udevadm >/dev/null 2>&1; then
  udevadm control --reload-rules || true
fi

exit 0
