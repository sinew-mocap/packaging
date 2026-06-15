#!/bin/sh
# Undo what postinstall wired up.  The /opt tree itself is removed by the package
# manager (it owns those files); we only clean the symlinks + profile.d we added.
set -e

# Only run on FINAL removal, not during an upgrade.  On rpm upgrade the old
# package's postremove runs AFTER the new postinstall, so unconditional cleanup
# would delete the symlinks/units the new package just created.
#   rpm postun: $1 = remaining instances (0 = final removal)
#   deb postrm: $1 = remove|purge|upgrade|deconfigure|...
case "${1:-}" in
  0|remove|purge) ;;   # final removal — proceed
  *) exit 0 ;;         # upgrade or other — leave everything in place
esac

for app in sinew_tui hmd_reader vr_devices anny_demo osctest; do
  link="/usr/local/bin/${app}"
  [ -L "${link}" ] && rm -f "${link}"
done
rm -f /usr/local/bin/blender-mcp
rm -f /etc/profile.d/org.v-sekai-blender.sh

# Stop and deregister the driver service (its unit file is removed by the
# package manager).
if command -v systemctl >/dev/null 2>&1; then
  systemctl disable --now sinew-driver.service || true
  systemctl daemon-reload || true
fi

# The package manager removes the udev rule file itself; reload so the kernel
# drops the rule we no longer ship.
if command -v udevadm >/dev/null 2>&1; then
  udevadm control --reload-rules || true
fi

exit 0
