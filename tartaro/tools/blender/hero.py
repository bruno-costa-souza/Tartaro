"""Builds the Tártaro hero in 3D, animates it, renders 8 directions and packs
sprite sheets for Godot (Hades-style pre-rendered sprites).

Run (headless):
    blender -b -P tools/blender/hero.py -- <output_dir> [size]

Output: <output_dir>/{idle,walk,attack,dash}.png (rows = 8 directions starting
at "facing camera" and turning clockwise on screen, columns = frames) and
hero.json with frame size, frame counts, fps and the feet anchor.

To use your own model later: replace build_hero() with an import of your
.blend/.glb and map your bones/objects in pose().
"""

import bpy
import json
import math
import os
import sys

import numpy as np
from mathutils import Matrix, Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(ARGS[0] if ARGS else "art/hero")
SIZE = int(ARGS[1]) if len(ARGS) > 1 and ARGS[1].isdigit() else 256
DIRECTIONS = 8
ANIMS = {"idle": 8, "walk": 8, "attack": 6, "dash": 4}
FPS = {"idle": 8, "walk": 12, "attack": 16, "dash": 14}
CAM_PITCH = math.radians(40.0)
ORTHO = 2.7
TARGET_Z = 0.95
INK_THICKNESS = 0.022

P = {}


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    engines = bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items.keys()
    for e in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE", "BLENDER_WORKBENCH"):
        if e in engines:
            scene.render.engine = e
            break
    scene.render.film_transparent = True
    scene.render.resolution_x = SIZE
    scene.render.resolution_y = SIZE
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    try:
        scene.view_settings.view_transform = "Standard"
        scene.view_settings.look = "None"
    except Exception:
        pass
    if hasattr(scene, "eevee"):
        for attr, val in (("taa_render_samples", 24), ("use_shadows", True)):
            if hasattr(scene.eevee, attr):
                setattr(scene.eevee, attr, val)

    world = bpy.data.worlds.new("World")
    scene.world = world
    _nodes_on(world)
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs["Color"].default_value = (0.09, 0.06, 0.14, 1.0)
        bg.inputs["Strength"].default_value = 1.4
    return scene


def _nodes_on(idblock):
    if hasattr(idblock, "use_nodes"):
        try:
            idblock.use_nodes = True
        except Exception:
            pass


def add_lights():
    key = bpy.data.objects.new("Key", bpy.data.lights.new("Key", "SUN"))
    key.data.energy = 5.5
    key.data.color = (1.0, 0.86, 0.68)
    key.data.angle = math.radians(8)
    key.rotation_euler = (math.radians(50), math.radians(-28), math.radians(-35))
    bpy.context.scene.collection.objects.link(key)
    rim = bpy.data.objects.new("Rim", bpy.data.lights.new("Rim", "SUN"))
    rim.data.energy = 4.0
    rim.data.color = (0.55, 0.72, 1.0)
    rim.rotation_euler = (math.radians(-60), math.radians(20), math.radians(160))
    bpy.context.scene.collection.objects.link(rim)
    fill = bpy.data.objects.new("Fill", bpy.data.lights.new("Fill", "SUN"))
    fill.data.energy = 1.6
    fill.data.color = (1.0, 0.45, 0.25)
    fill.rotation_euler = (math.radians(110), 0, math.radians(20))
    bpy.context.scene.collection.objects.link(fill)


def add_camera():
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = ORTHO
    cam = bpy.data.objects.new("Cam", cam_data)
    d = 12.0
    cam.location = (0.0, -d * math.cos(CAM_PITCH), TARGET_Z + d * math.sin(CAM_PITCH))
    cam.rotation_euler = (math.radians(90) - CAM_PITCH, 0.0, 0.0)
    bpy.context.scene.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    return cam


def material(name, color, metallic=0.0, rough=0.6, emission=None, strength=0.0):
    m = bpy.data.materials.new(name)
    _nodes_on(m)
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*color, 1.0)
        bsdf.inputs["Metallic"].default_value = metallic
        bsdf.inputs["Roughness"].default_value = rough
        if emission is not None:
            for key in ("Emission Color", "Emission"):
                if key in bsdf.inputs:
                    bsdf.inputs[key].default_value = (*emission, 1.0)
                    break
            if "Emission Strength" in bsdf.inputs:
                bsdf.inputs["Emission Strength"].default_value = strength
    return m


def ink_material():
    m = bpy.data.materials.new("Ink")
    _nodes_on(m)
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (0.02, 0.01, 0.02, 1.0)
        bsdf.inputs["Roughness"].default_value = 1.0
        if "Specular IOR Level" in bsdf.inputs:
            bsdf.inputs["Specular IOR Level"].default_value = 0.0
    m.use_backface_culling = True
    return m


def pivot(name, parent, loc):
    e = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(e)
    e.parent = parent
    e.location = loc
    P[name] = e
    return e


def _finish(obj, mat, parent, loc, smooth=True, subsurf=1, outline=True):
    obj.parent = parent
    obj.location = loc
    obj.data.materials.append(mat)
    if smooth:
        for poly in obj.data.polygons:
            poly.use_smooth = True
    if subsurf:
        mod = obj.modifiers.new("Sub", "SUBSURF")
        mod.levels = subsurf
        mod.render_levels = subsurf
    if outline:
        obj.data.materials.append(INK)
        sol = obj.modifiers.new("Ink", "SOLIDIFY")
        sol.thickness = -INK_THICKNESS
        sol.use_flip_normals = True
        sol.material_offset = 1
        sol.offset = 1.0
    P[obj.name] = obj
    return obj


def sphere(name, parent, loc, scale, mat, **kw):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=1.0)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.transform(Matrix.Diagonal((*scale, 1.0)))
    bpy.context.scene.collection.objects.link(obj) if obj.name not in bpy.context.scene.collection.objects else None
    return _finish(obj, mat, parent, loc, **kw)


def limb(name, parent, loc, length, r_top, r_bot, mat, **kw):
    """Tapered cylinder hanging DOWN from its origin (the joint)."""
    bpy.ops.mesh.primitive_cone_add(vertices=16, radius1=r_bot, radius2=r_top, depth=length)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.transform(Matrix.Translation((0, 0, -length / 2)))
    return _finish(obj, mat, parent, loc, **kw)


def cone(name, parent, loc, r1, r2, depth, mat, rot=(0, 0, 0), verts=24, **kw):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=depth)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.transform(Matrix.Translation((0, 0, -depth / 2)))
    obj.rotation_euler = rot
    return _finish(obj, mat, parent, loc, **kw)


def torus(name, parent, loc, major, minor, mat, **kw):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=32, minor_segments=8)
    obj = bpy.context.active_object
    obj.name = name
    return _finish(obj, mat, parent, loc, **kw)


def cape_mesh(name, parent, mat):
    """Curved cloth hanging from the shoulders down the back, flaring at the hem."""
    cols, rows = 8, 10
    verts, faces = [], []
    for r in range(rows + 1):
        t = r / rows
        width = 0.46 + 0.32 * t
        for c in range(cols + 1):
            u = c / cols - 0.5
            x = u * width
            y = 0.08 + 0.10 * (u * 2) ** 2 * (1 - 0.5 * t) + 0.05 * t + 0.035 * math.sin(u * 9.0) * t
            z = -0.92 * t
            verts.append((x, y, z))
    for r in range(rows):
        for c in range(cols):
            a = r * (cols + 1) + c
            faces.append((a, a + 1, a + cols + 2, a + cols + 1))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    sol = obj.modifiers.new("Thick", "SOLIDIFY")
    sol.thickness = 0.02
    return _finish(obj, mat, parent, (0, 0, 0), subsurf=1)


def build_hero():
    skin = material("Skin", (0.98, 0.6, 0.45), rough=0.5)
    bronze = material("Bronze", (1.0, 0.74, 0.22), metallic=0.85, rough=0.28)
    dark_bronze = material("DarkBronze", (0.5, 0.32, 0.14), metallic=0.5, rough=0.5)
    cloth = material("Cape", (0.72, 0.04, 0.06), rough=0.8)
    linen = material("Linen", (0.97, 0.94, 0.86), rough=0.9)
    leather = material("Leather", (0.32, 0.18, 0.09), rough=0.7)
    hair = material("Hair", (0.08, 0.045, 0.03), rough=0.45)
    leaf = material("Laurel", (0.55, 0.75, 0.22), rough=0.5, emission=(0.35, 0.5, 0.1), strength=0.15)
    wood = material("Wood", (0.42, 0.27, 0.14), rough=0.7)
    blade = material("Blade", (1.0, 0.8, 0.4), metallic=1.0, rough=0.18, emission=(1.0, 0.65, 0.2), strength=0.6)

    root = pivot("root", None, (0, 0, 0))
    hips = pivot("hips", root, (0, 0, 0.92))
    torso = pivot("torso", hips, (0, 0, 0.0))

    cone("tunic", hips, (0, 0, 0.08), 0.24, 0.17, 0.36, linen, verts=20)
    cone("pteruges", hips, (0, 0, 0.04), 0.27, 0.19, 0.24, leather, verts=12, subsurf=0)
    sphere("chest", torso, (0, -0.01, 0.34), (0.215, 0.14, 0.26), bronze)
    sphere("abs", torso, (0, -0.02, 0.17), (0.18, 0.12, 0.13), bronze)
    torus("belt", torso, (0, 0, 0.08), 0.2, 0.035, dark_bronze)
    sphere("pauldron.L", torso, (-0.25, 0, 0.5), (0.1, 0.11, 0.08), bronze)
    sphere("pauldron.R", torso, (0.25, 0, 0.5), (0.1, 0.11, 0.08), bronze)

    neck = pivot("neck", torso, (0, 0, 0.6))
    limb("neckmesh", neck, (0, 0, 0.08), 0.1, 0.055, 0.065, skin, outline=False)
    head = pivot("head", neck, (0, 0, 0.17))
    sphere("skull", head, (0, 0, 0), (0.115, 0.12, 0.135), skin)
    sphere("hair", head, (0, 0.03, 0.05), (0.128, 0.125, 0.112), hair)
    sphere("hairback", head, (0, 0.07, -0.03), (0.11, 0.08, 0.1), hair)
    sphere("nose", head, (0, -0.115, -0.01), (0.018, 0.025, 0.03), skin, outline=False, subsurf=0)
    for x in (-0.042, 0.042):
        sphere("eye%.2f" % x, head, (x, -0.108, 0.012), (0.014, 0.008, 0.012), hair, outline=False, subsurf=0)
    torus("laurel", head, (0, 0.0, 0.055), 0.126, 0.014, leaf, outline=False)
    for i in range(10):
        a = math.pi * (0.1 + 0.8 * i / 9.0) + math.pi
        sphere("leaf%d" % i, head, (math.cos(a) * 0.13, math.sin(a) * 0.13, 0.07),
               (0.03, 0.012, 0.018), leaf, outline=False, subsurf=0)

    cape_root = pivot("cape", torso, (0, 0.05, 0.55))
    cape_mesh("capemesh", cape_root, cloth)

    for side, sx in (("L", -1), ("R", 1)):
        sh = pivot("shoulder." + side, torso, (sx * 0.29, 0, 0.47))
        limb("upperarm." + side, sh, (0, 0, 0), 0.29, 0.062, 0.05, skin)
        el = pivot("elbow." + side, sh, (0, 0, -0.29))
        limb("forearm." + side, el, (0, 0, 0), 0.26, 0.05, 0.042, skin)
        limb("bracer." + side, el, (0, 0, -0.06), 0.16, 0.058, 0.052, leather, outline=False, subsurf=0)
        hand = pivot("hand." + side, el, (0, 0, -0.27))
        sphere("fist." + side, hand, (0, 0, -0.02), (0.05, 0.045, 0.055), skin)

        hip = pivot("hip." + side, hips, (sx * 0.1, 0, -0.02))
        limb("thigh." + side, hip, (0, 0, 0), 0.42, 0.085, 0.065, skin)
        kn = pivot("knee." + side, hip, (0, 0, -0.42))
        limb("shin." + side, kn, (0, 0, 0), 0.42, 0.065, 0.045, skin)
        limb("greave." + side, kn, (0, -0.005, -0.04), 0.3, 0.07, 0.055, bronze, subsurf=0)
        sphere("sandal." + side, kn, (0, -0.05, -0.44), (0.055, 0.11, 0.035), leather)

    spear = pivot("spear", P["hand.R"], (0, 0, -0.03))
    limb("shaft", spear, (0, 0, 0.75), 1.75, 0.018, 0.018, wood, subsurf=0)
    cone("tip", spear, (0, 0, 0.75), 0.0, 0.045, 0.24, blade, rot=(math.pi, 0, 0), verts=8, subsurf=0)
    return root


def rot(name, x=0.0, y=0.0, z=0.0):
    P[name].rotation_euler = (x, y, z)


def pose(anim, f, n):
    t = f / n
    ph = 2 * math.pi * t
    for k in list(P):
        if isinstance(P[k], bpy.types.Object) and P[k].type == "EMPTY" and k != "root":
            P[k].rotation_euler = (0, 0, 0)
    P["hips"].location = (0, 0, 0.92)
    P["spear"].rotation_euler = (0, 0, 0)
    rot("shoulder.L", 0.05, -0.18, 0)
    rot("shoulder.R", -0.25, 0.12, 0)
    rot("elbow.R", -1.15, 0, 0)
    rot("elbow.L", -0.25, 0, 0)
    spear_world = 0.12

    if anim == "idle":
        breath = math.sin(ph)
        P["hips"].location = (0, 0, 0.92 + 0.008 * breath)
        rot("torso", 0.03 * breath, 0, 0)
        rot("head", -0.04 * breath, 0, 0)
        rot("cape", 0.08 + 0.05 * math.sin(ph + 0.6), 0, 0)
        rot("hip.L", 0, -0.05, 0)
        rot("hip.R", 0, 0.05, 0)
    elif anim == "walk":
        s = math.sin(ph)
        P["hips"].location = (0, 0, 0.92 + 0.03 * abs(math.cos(ph)))
        rot("hip.L", -0.55 * s, 0, 0)
        rot("hip.R", 0.55 * s, 0, 0)
        rot("knee.L", max(0.0, math.sin(ph + 1.4)) * 0.9, 0, 0)
        rot("knee.R", max(0.0, math.sin(ph + 1.4 + math.pi)) * 0.9, 0, 0)
        rot("shoulder.L", 0.45 * s, -0.18, 0)
        rot("torso", 0.08, 0, 0.08 * s)
        rot("cape", 0.35 + 0.1 * math.sin(ph * 2), 0, 0)
    elif anim == "attack":
        k = [0.0, 0.55, 1.0, -1.0, -0.8, -0.3][f]
        if k >= 0:
            rot("shoulder.R", -1.2 - 1.6 * k, 0.15, 0)
            rot("elbow.R", -0.6 - 0.6 * k, 0, 0)
            rot("torso", -0.08 * k, 0, 0.35 * k)
            spear_world = 0.12 - 0.75 * k
        else:
            a = -k
            rot("shoulder.R", -1.55 * a - 0.2, 0.05, 0)
            rot("elbow.R", -0.1, 0, 0)
            rot("torso", 0.18 * a, 0, -0.3 * a)
            spear_world = math.pi / 2
        rot("hip.L", -0.35, 0, 0)
        rot("hip.R", 0.3, 0, 0)
        rot("knee.R", 0.35, 0, 0)
        rot("cape", 0.2 + 0.25 * abs(k), 0, 0)
    elif anim == "dash":
        rot("torso", 0.45, 0, 0)
        rot("head", -0.3, 0, 0)
        rot("hip.L", -0.7 + 0.15 * f, 0, 0)
        rot("hip.R", 0.9, 0, 0)
        rot("knee.R", 1.1, 0, 0)
        rot("knee.L", 0.4, 0, 0)
        rot("shoulder.L", 0.9, -0.3, 0)
        rot("shoulder.R", 0.6, 0.2, 0)
        rot("cape", 0.8 + 0.1 * math.sin(f * 2.1), 0, 0)
        P["hips"].location = (0, 0, 0.86)
        spear_world = 0.9

    arm = P["shoulder.R"].rotation_euler.x + P["elbow.R"].rotation_euler.x
    P["spear"].rotation_euler = (spear_world - arm, 0, 0)


def render_frame(path):
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def pack(anim, frames, tmp):
    sheet = np.zeros((DIRECTIONS * SIZE, frames * SIZE, 4), dtype=np.float32)
    for d in range(DIRECTIONS):
        for f in range(frames):
            img = bpy.data.images.load(os.path.join(tmp, "%s_%d_%d.png" % (anim, d, f)))
            px = np.empty(SIZE * SIZE * 4, dtype=np.float32)
            img.pixels.foreach_get(px)
            px = px.reshape((SIZE, SIZE, 4))
            row = DIRECTIONS - 1 - d
            sheet[row * SIZE:(row + 1) * SIZE, f * SIZE:(f + 1) * SIZE] = px
            bpy.data.images.remove(img)
    out = bpy.data.images.new(anim, width=frames * SIZE, height=DIRECTIONS * SIZE, alpha=True)
    out.pixels.foreach_set(sheet.ravel())
    out.filepath_raw = os.path.join(OUT, anim + ".png")
    out.file_format = "PNG"
    out.save()


PREVIEW = os.environ.get("HERO_PREVIEW") == "1"


def main():
    os.makedirs(OUT, exist_ok=True)
    tmp = os.path.join(OUT, "_frames")
    os.makedirs(tmp, exist_ok=True)
    reset_scene()
    global INK
    INK = ink_material()
    add_lights()
    add_camera()
    root = build_hero()

    if PREVIEW:
        shots = (("idle", 0, 0), ("idle", 2, 0), ("walk", 1, 2), ("attack", 0, 1),
                 ("attack", 3, 3), ("dash", 2, 1), ("idle", 4, 0), ("walk", 6, 5))
        for anim, d, f in shots:
            root.rotation_euler = (0, 0, math.radians(45.0 * d))
            pose(anim, f, ANIMS[anim])
            bpy.context.view_layer.update()
            render_frame(os.path.join(OUT, "preview_%s_%d_%d.png" % (anim, d, f)))
        return

    for anim, frames in ANIMS.items():
        for d in range(DIRECTIONS):
            root.rotation_euler = (0, 0, math.radians(45.0 * d))
            for f in range(frames):
                pose(anim, f, frames)
                bpy.context.view_layer.update()
                render_frame(os.path.join(tmp, "%s_%d_%d.png" % (anim, d, f)))
        pack(anim, frames, tmp)
        print("packed", anim)

    px_per_m = SIZE / ORTHO
    feet_y = SIZE / 2 + TARGET_Z * math.cos(CAM_PITCH) * px_per_m
    meta = {
        "frame_size": SIZE,
        "directions": DIRECTIONS,
        "frames": ANIMS,
        "fps": FPS,
        "feet_y": round(feet_y, 1),
        "px_per_meter": round(px_per_m, 2),
    }
    with open(os.path.join(OUT, "hero.json"), "w") as fh:
        json.dump(meta, fh, indent=2)
    for name in os.listdir(tmp):
        os.remove(os.path.join(tmp, name))
    os.rmdir(tmp)
    print("done", meta)


INK = None
if __name__ == "__main__":
    main()
