#!/usr/bin/env bash
# stage.sh — assemble the relocatable /opt/org.v-sekai/sinew tree that the native
# packagers wrap.  Build-system-agnostic: it only copies finished artifacts into
# the vendor layout, so the same tree feeds nfpm (deb/rpm) today and pkgbuild/WiX
# later if those channels are ever wanted.  brew (osx+linux) and scoop (windows)
# stay the dev/user channels; this is the system/deploy channel into /opt.
#
# Blender addon packaging lives in its own repo now (v-sekai/blender-packaging);
# this repo stages only the Sinew mocap C++ apps.
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

rm -rf "$stage"
mkdir -p "$vendor/sinew/$SINEW_VER/bin" \
         "$vendor/sinew/$SINEW_VER/share/sinew"

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

echo "staged -> $stage"
find "$vendor" -maxdepth 4 -type d | sed "s|$stage||"
