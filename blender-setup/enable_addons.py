# System startup script (bundled at $BLENDER_SYSTEM_SCRIPTS/startup): auto-enable
# the v-sekai addons for every user, per Blender's "Deploying Blender" guide.
# Pairs with BLENDER_SYSTEM_SCRIPTS (legacy addons) + BLENDER_SYSTEM_EXTENSIONS
# (the read-only System extension repo) — no per-user preference change needed.
#
# Enabling is DEFERRED (load_post handler + a one-shot timer) because at startup-
# script register() time the system script dir is not yet on sys.path and the
# extension repos are not loaded, so a direct enable fails ("No module named
# 'NodeOSC'" / the extension silently not enabling).
import os
import sys
import bpy
from bpy.app.handlers import persistent

ADDONS = ("NodeOSC", "bl_ext.system.blender_mcp_addon")


def _enable():
    import addon_utils
    scripts = os.environ.get("BLENDER_SYSTEM_SCRIPTS", "")
    addons_dir = os.path.join(scripts, "addons")
    if addons_dir and os.path.isdir(addons_dir) and addons_dir not in sys.path:
        sys.path.append(addons_dir)
    for mod in ADDONS:
        try:
            addon_utils.enable(mod, default_set=True, persistent=True)
        except Exception as e:  # never break Blender
            print("v-sekai enable_addons:", mod, e)
    return None  # one-shot timer


@persistent
def _on_load(_dummy):
    _enable()


def register():
    if _on_load not in bpy.app.handlers.load_post:
        bpy.app.handlers.load_post.append(_on_load)
    try:
        bpy.app.timers.register(_enable, first_interval=0.0)  # after the initial startup file
    except Exception:
        pass


def unregister():
    if _on_load in bpy.app.handlers.load_post:
        bpy.app.handlers.load_post.remove(_on_load)
