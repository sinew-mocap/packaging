#!/bin/sh
# Wire the relocatable /opt tree into the system: PATH symlinks + Blender scripts.
# FHS §3.13: /opt apps own /opt/<vendor>/...; integration via symlinks + profile.d.
set -e

SINEW_VER="0.4"
BLENDER_VER="5.1"
BIN="/opt/org.v-sekai/sinew/${SINEW_VER}/bin"

# Symlink the apps onto PATH.
for app in sinew_tui hmd_reader vr_devices anny_demo; do
  [ -x "${BIN}/${app}" ] && ln -sf "${BIN}/${app}" "/usr/local/bin/${app}"
done

# The blender-mcp server (bundled venv) lives outside the sinew bin dir.
MCP="/opt/org.v-sekai/blender-mcp/venv/bin/blender-mcp"
[ -x "${MCP}" ] && ln -sf "${MCP}" "/usr/local/bin/blender-mcp"

# Point the OS-installed Blender (a package dependency) at our vendored addons,
# per Blender's "Deploying Blender" guide.  Both vars ADD to Blender's defaults
# (scripts/extensions load from user AND system dirs), so nothing is clobbered.
# A startup script (scripts/startup/enable_addons.py) auto-enables them, so no
# per-user preference change is needed.  Applies to new login sessions.
cat > /etc/profile.d/org.v-sekai-blender.sh <<EOF
export BLENDER_SYSTEM_SCRIPTS="/opt/org.v-sekai/blender/${BLENDER_VER}/scripts"
export BLENDER_SYSTEM_EXTENSIONS="/opt/org.v-sekai/blender/${BLENDER_VER}/scripts/extensions"
EOF

# Apply the Rebocap dongle udev rule we just installed so an already-plugged
# dongle picks up the uaccess ACL / dialout group without a replug.
if command -v udevadm >/dev/null 2>&1; then
  udevadm control --reload-rules || true
  udevadm trigger --subsystem-match=tty --attr-match=idVendor=248a || true
fi

exit 0
