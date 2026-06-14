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

# Point the OS-installed Blender (a package dependency) at our vendored addons.
# NOTE: BLENDER_SYSTEM_SCRIPTS *replaces* the default system scripts dir, so this
# trades the distro Blender's bundled system addons for ours.  If that matters,
# drop this and register /opt/.../scripts as an extra extensions repo instead.
cat > /etc/profile.d/org.v-sekai-blender.sh <<EOF
export BLENDER_SYSTEM_SCRIPTS="/opt/org.v-sekai/blender/${BLENDER_VER}/scripts"
EOF

exit 0
