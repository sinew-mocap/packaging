# System startup script: enforce 30 fps on every scene, for every file that loads.
# Bundled at $BLENDER_SYSTEM_SCRIPTS/startup so it applies for all users.
# Deferred via load_post + a one-shot timer because bpy.data is restricted during
# startup-script register() (accessing bpy.data.scenes then raises).
import bpy
from bpy.app.handlers import persistent

FPS = 30


def _set_fps():
    for sc in bpy.data.scenes:
        sc.render.fps = FPS
        sc.render.fps_base = 1.0
    return None  # one-shot timer


@persistent
def _on_load(_dummy):  # fires on file open and File > New
    _set_fps()


def register():
    if _on_load not in bpy.app.handlers.load_post:
        bpy.app.handlers.load_post.append(_on_load)
    try:
        bpy.app.timers.register(_set_fps, first_interval=0.0)  # the initial startup scene
    except Exception:
        pass


def unregister():
    if _on_load in bpy.app.handlers.load_post:
        bpy.app.handlers.load_post.remove(_on_load)
