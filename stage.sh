#!/usr/bin/env bash
# stage.sh — assemble the relocatable /opt/org.v-sekai tree that the native
# packagers wrap.  Build-system-agnostic: it only copies finished artifacts into
# the vendor layout, so the same tree feeds nfpm (deb/rpm) today and pkgbuild/WiX
# later if those channels are ever wanted.  brew (osx+linux) and scoop (windows)
# stay the dev/user channels; this is the system/deploy channel into /opt.
#
# Usage: packaging/stage.sh [STAGE_DIR]   (default: packaging/stage)
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Where the built sinew clusters live.  Defaults to the side-by-side workspace
# (this repo cloned beside driver/, viewer/, ...); override in CI with SINEW_SRC.
root="${SINEW_SRC:-$(cd "$here/.." && pwd)}"
stage="${1:-$here/stage}"
vendor="$stage/opt/org.v-sekai"

SINEW_VER="${SINEW_VER:-0.4}"                   # major.minor channel dir
BLENDER_VER="${BLENDER_VER:-5.1}"

rm -rf "$stage"
mkdir -p "$vendor/sinew/$SINEW_VER/bin" \
         "$vendor/sinew/$SINEW_VER/share/sinew" \
         "$vendor/blender/$BLENDER_VER/scripts/addons" \
         "$vendor/blender/$BLENDER_VER/scripts/startup" \
         "$vendor/blender/$BLENDER_VER/scripts/extensions/system" \
         "$vendor/blender-mcp"

say() { printf '  %-22s %s\n' "$1" "$2"; }

# ── Sinew C++ apps ───────────────────────────────────────────────────────────
# Sourced from each cluster's build/ (configure+build them first if absent).
need_build() { [ -x "$1" ] || { echo "missing $1 — run: cmake -S $2 -B $2/build && cmake --build $2/build"; exit 1; }; }
need_build "$root/driver/build/sinew_tui"    driver
need_build "$root/vr_bridge/build/hmd_reader" vr_bridge
need_build "$root/viewer/build/anny_demo"    viewer

install -m755 "$root/driver/build/sinew_tui"     "$vendor/sinew/$SINEW_VER/bin/"; say sinew_tui ok
install -m755 "$root/vr_bridge/build/hmd_reader" "$vendor/sinew/$SINEW_VER/bin/"; say hmd_reader ok
install -m755 "$root/vr_bridge/build/vr_devices" "$vendor/sinew/$SINEW_VER/bin/"; say vr_devices ok
install -m755 "$root/viewer/build/anny_demo"     "$vendor/sinew/$SINEW_VER/bin/"; say anny_demo ok
install -m644 "$root/viewer/build/lbs.spv"       "$vendor/sinew/$SINEW_VER/share/sinew/"; say lbs.spv ok

# soma_pheno.bin (110 MB) — not in git; reuse a local copy if present else fetch.
soma="$vendor/sinew/$SINEW_VER/share/sinew/soma_pheno.bin"
if [ -f "${SOMA_PHENO:-}" ]; then install -m644 "$SOMA_PHENO" "$soma"
elif [ -f /home/linuxbrew/.linuxbrew/Cellar/sinew-viewer/*/bin/soma_pheno.bin ]; then
  install -m644 $(ls /home/linuxbrew/.linuxbrew/Cellar/sinew-viewer/*/bin/soma_pheno.bin | head -1) "$soma"
else
  tmp="$(mktemp -d)"
  curl -fsSL https://github.com/sinew-mocap/viewer/releases/download/v1/soma_pheno.bin.zst -o "$tmp/s.zst"
  zstd -dq "$tmp/s.zst" -o "$soma"; rm -rf "$tmp"
fi
say soma_pheno.bin ok

# ── osctest — the Lean OSC sender (sinew-mocap/osc-tester) ────────────────────
# Self-contained binary (no Lean shared-lib runtime dep); built with lake.
osc_src="${OSC_TESTER_SRC:-$root/osc-tester}"
if [ -d "$osc_src" ] && command -v lake >/dev/null 2>&1; then
  ( cd "$osc_src" && lake build ) >/dev/null 2>&1
  install -m755 "$osc_src/.lake/build/bin/osctest" "$vendor/sinew/$SINEW_VER/bin/osctest"; say osctest ok
else
  echo "  osctest                SKIPPED (needs lake + $osc_src)"
fi

# ── Blender addons (Blender itself is an OS dependency — see nfpm.yaml) ───────
# Per Blender's "Deploying Blender" guide, bundle via the system env vars (both
# ADD to Blender's defaults — they do not replace user/bundled scripts):
#   NodeOSC  — legacy bl_info addon -> scripts/addons/  (via BLENDER_SYSTEM_SCRIPTS)
#   blender_mcp_addon — an extension (blender_manifest.toml) -> the read-only
#     System repo, which must be a 'system/' subdir of BLENDER_SYSTEM_EXTENSIONS.
#   enable_addons.py — a startup script that auto-enables both for every user.
addons="$vendor/blender/$BLENDER_VER/scripts/addons"
exts="$vendor/blender/$BLENDER_VER/scripts/extensions/system"
startup="$vendor/blender/$BLENDER_VER/scripts/startup"
nodeosc_src="${NODEOSC_SRC:-$HOME/.config/blender/$BLENDER_VER/scripts/addons/NodeOSC}"
[ -d "$nodeosc_src" ] || { git clone --depth 1 https://github.com/maybites/NodeOSC.git "$(mktemp -d)/NodeOSC" && nodeosc_src="$_"; }
cp -a "$nodeosc_src" "$addons/NodeOSC"; rm -rf "$addons/NodeOSC/.git"; say NodeOSC ok
mcp_zip="${MCP_ADDON_ZIP:-/tmp/blender-mcp-dl/blender_mcp_addon-2.0.0-dev.1.zip}"
if [ -f "$mcp_zip" ]; then unzip -q "$mcp_zip" -d "$exts/"
else cp -a "$HOME/.config/blender/$BLENDER_VER/extensions/user_default/blender_mcp_addon" "$exts/"; fi
say blender_mcp_addon ok
install -m644 "$here/blender-setup/enable_addons.py" "$startup/enable_addons.py"; say enable_addons.py ok
install -m644 "$here/blender-setup/enforce_fps.py" "$startup/enforce_fps.py"; say enforce_fps.py ok

# ── blender-mcp server → a relocatable venv on the system python3 ─────────────
# Built --relocatable so it works from /opt after install; the rpm declares
# Requires: python3 (the venv references /usr/bin/python3, it doesn't bundle one).
mcp_wheel="${MCP_WHEEL:-/tmp/blender-mcp-dl/chibifire_blender_mcp-2.0.0-py3-none-any.whl}"
if [ ! -f "$mcp_wheel" ]; then
  mcp_wheel="$(mktemp -d)/mcp.whl"
  curl -fsSL https://github.com/v-sekai-multiplayer-fabric/blender-mcp/releases/download/v2.0.0-dev.1/chibifire_blender_mcp-2.0.0-py3-none-any.whl -o "$mcp_wheel"
fi
venv="$vendor/blender-mcp/venv"
uv venv --relocatable --python /usr/bin/python3 "$venv" >/dev/null 2>&1
uv pip install --quiet --python "$venv/bin/python" "$mcp_wheel"
say blender-mcp ok

echo "staged -> $stage"
find "$vendor" -maxdepth 4 -type d | sed "s|$stage||"
