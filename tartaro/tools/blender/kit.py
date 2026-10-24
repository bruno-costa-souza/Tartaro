"""Shared Blender helpers for Tártaro's pre-rendered sprites: scene, lights,
ortho camera, simple materials, outlined primitives and sheet packing.

Used by bestiary.py (enemies) and hero.py. Module-level settings (SIZE, ORTHO,
TARGET_Z, OUT, DIRECTIONS) are meant to be overridden by the calling script.
"""

import bpy
import json
import math
import os
import sys

import numpy as np
from mathutils import Matrix, Vector

OUT = os.path.abspath("art")
SIZE = 256
DIRECTIONS = 8
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


INK = None
