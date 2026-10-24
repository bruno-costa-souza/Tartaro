"""Embossed boon emblems (one per god) for the boon cards and the HUD.

Run (headless), from the project root:
    blender -b -P tools/blender/emblems.py -- art/emblems [zeus ...]

Output: art/emblems/<god>.png, 192x192, transparent. The frame around the
emblem (rarity colour) is drawn in-game.
"""

import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import figure as F  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(ARGS[0] if ARGS else "art/emblems")
ONLY = ARGS[1:]
SIZE = 192
DEPTH = 0.12


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.film_transparent = True
    scene.render.resolution_x = SIZE
    scene.render.resolution_y = SIZE
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    try:
        scene.view_settings.view_transform = "Standard"
    except Exception:
        pass
    scene.eevee.taa_render_samples = 32
    world = bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.3, 0.27, 0.4, 1.0)
    bg.inputs["Strength"].default_value = 0.2
    F.OUTLINE = 0.03
    F._ink = None

    def sun(name, energy, rot):
        ob = bpy.data.objects.new(name, bpy.data.lights.new(name, "SUN"))
        ob.data.energy = energy
        ob.data.angle = math.radians(3)
        ob.rotation_euler = tuple(math.radians(a) for a in rot)
        scene.collection.objects.link(ob)
    sun("Key", 4.2, (35, 0, -40))
    sun("Rim", 1.8, (-40, 0, 140))
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 2.3
    cam.location = (0, -5, 0)
    cam.rotation_euler = (math.radians(90), 0, 0)
    scene.collection.objects.link(cam)
    scene.camera = cam


MAT = {}


def gold():
    if "gold" not in MAT:
        MAT["gold"] = F.toon("Gold", (1.0, 0.8, 0.34), shadow=(0.62, 0.32, 0.1), spec=1.3, gloss=0.18,
                             spec_color=(1.0, 0.96, 0.8), rim=(1.0, 0.95, 0.75), rim_strength=0.25)
    return MAT["gold"]


def tint(col, name="Tint", spec=0.8):
    key = name + str(col)
    if key not in MAT:
        MAT[key] = F.toon(key, col, spec=spec, gloss=0.25, rim=(1, 1, 1), rim_strength=0.2)
    return MAT[key]


def glow(col, strength=1.8):
    key = "glow" + str(col)
    if key not in MAT:
        MAT[key] = F.toon(key, col, shadow=col, mid=1.0, rim_strength=0.0, emission=col, strength=strength)
    return MAT[key]


def finish(ob, outline=True):
    if outline:
        F.outline(ob, thickness=0.035, subsurf=0)
    return ob


def slab(points, material, depth=DEPTH, at=(0, 0), rot=0.0, scale=1.0, bevel=0.045, y=0.0, outline=True):
    pts = []
    c, s_ = math.cos(rot), math.sin(rot)
    for x, z in points:
        x, z = x * scale, z * scale
        pts.append(Vector((at[0] + x * c - z * s_, y, at[1] + x * s_ + z * c)))
    n = len(pts)
    verts = [tuple(p + Vector((0, -depth / 2, 0))) for p in pts] + [tuple(p + Vector((0, depth / 2, 0))) for p in pts]
    faces = [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))
    ob = F.mesh_object("Slab", verts, faces, [material], smooth=False)
    F.recalc_normals(ob)
    if bevel:
        bv = ob.modifiers.new("Bevel", "BEVEL")
        bv.width = bevel
        bv.segments = 3
        bv.limit_method = "ANGLE"
    return finish(ob, outline)


def stroke(points, radius, material, y=0.0, outline=True, sides=10):
    pts = [Vector((x, y, z)) for x, z in points]
    radii = radius if hasattr(radius, "__len__") else [radius] * len(pts)
    n = len(pts)
    widths = []
    for i in range(n):
        t = pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]
        widths.append(Vector((0, 1, 0)).cross(t.normalized() if t.length > 1e-9 else Vector((0, 0, 1))))
    ob = F.tube("Stroke", pts, radii, material, sides=sides, flat=0.75, widths=widths)
    return finish(ob, outline)


def ball(x, z, r, material, y=0.0, flat=0.7, outline=True):
    ob = F.ellipsoid("Ball", (x, y, z), (r, r * flat, r), material, segs=16, rings=10)
    return finish(ob, outline)


def arc(cx, cz, r, a0, a1, n=24):
    return [(cx + math.cos(a) * r, cz + math.sin(a) * r) for a in np.linspace(a0, a1, n)]


def disc(cx, cz, r, material, depth=DEPTH, y=0.0, n=40):
    return slab(arc(0, 0, r, 0, 2 * math.pi * (1 - 1.0 / n), n), material, depth, at=(cx, cz), y=y)


BOLT = [(0.06, 0.95), (-0.32, 0.08), (0.02, 0.1), (-0.26, -0.95), (0.36, 0.05), (0.0, 0.03), (0.3, 0.95)]


def e_zeus():
    wide = [(x * 1.7, z) for x, z in BOLT]
    slab(wide, gold(), scale=0.95)
    core = [(x * 0.55 + 0.02, z * 0.78) for x, z in wide]
    slab(core, glow((0.8, 0.96, 1.0), 2.4), depth=DEPTH * 1.4, scale=0.95, bevel=0.02, outline=False)


def e_poseidon():
    g = gold()
    stroke([(0, -0.95), (0, 0.3)], 0.07, g)
    stroke(arc(0, 0.55, 0.42, math.pi * 1.05, math.pi * 1.95, 16), 0.065, g)
    for x, h in ((-0.42, 0.85), (0.0, 0.95), (0.42, 0.85)):
        stroke([(x, 0.5), (x, h - 0.2)], 0.06, g)
        slab([(-0.13, 0.0), (0.0, 0.32), (0.13, 0.0), (0.0, 0.08)], glow((0.4, 1.0, 0.95)), at=(x, h - 0.25), bevel=0.02)


def e_ares():
    blade = [(0.0, -0.1), (0.13, 0.05), (0.13, 0.9), (0.0, 1.25), (-0.13, 0.9), (-0.13, 0.05)]
    slab(blade, tint((0.86, 0.88, 0.95), "Steel", 1.4), at=(0.0, -0.35), rot=-0.6, scale=1.0)
    c, s = math.cos(-0.6), math.sin(-0.6)

    def rp(x, z):
        return (x * c - z * s, x * s + z * c - 0.35)
    stroke([rp(0, 0.1), rp(0, 1.0)], 0.03, glow((1.0, 0.3, 0.2)), y=-0.06, outline=False)
    stroke([rp(-0.35, -0.1), rp(0.35, -0.1)], 0.07, gold())
    stroke([rp(0, -0.12), rp(0, -0.5)], 0.06, tint((0.45, 0.2, 0.12), "Grip"))
    ball(*rp(0, -0.58), 0.1, gold())


def e_apolo():
    g = gold()
    for k in range(12):
        a = 2 * math.pi * k / 12 + math.pi / 12
        ln = 0.92 if k % 2 == 0 else 0.75
        p0 = (math.cos(a - 0.14) * 0.5, math.sin(a - 0.14) * 0.5)
        p1 = (math.cos(a) * ln, math.sin(a) * ln)
        p2 = (math.cos(a + 0.14) * 0.5, math.sin(a + 0.14) * 0.5)
        slab([p0, p1, p2], g, bevel=0.02)
    disc(0, 0, 0.5, g)
    disc(0, 0, 0.3, glow((1.0, 0.7, 0.25), 1.6), y=-0.06, depth=DEPTH * 0.6)


def feather(x, z, ang, ln, w, material):
    ob = F.ellipsoid("Feather", (x, 0, z), (w, 0.05, ln), material, segs=14, rings=10, rot=(0, ang, 0),
                     shape=lambda co: (co[0] * (1.0 - 0.7 * max(0.0, co[2]) ** 1.4), co[1], co[2]))
    finish(ob)


def e_hermes():
    m = tint((0.97, 0.96, 0.92), "Feather", 0.5)
    base = (-0.6, -0.55)
    for k in range(7):
        a = 0.1 + k * 0.21
        ln = 1.35 - k * 0.12
        cx = base[0] + math.sin(a) * ln * 0.5
        cz = base[1] + math.cos(a) * ln * 0.5
        feather(cx, cz, a, ln * 0.5, 0.15, m)
    stroke(arc(base[0], base[1], 0.3, 0.1, 1.6, 10), 0.07, gold())
    ball(base[0], base[1], 0.13, gold())


def e_artemis():
    wood = tint((0.6, 0.4, 0.2), "Wood", 0.5)
    pts = arc(0.45, 0.0, 0.95, math.pi * 0.62, math.pi * 1.38, 20)
    stroke(pts, [0.035 + 0.04 * math.sin(math.pi * k / 19) for k in range(20)], wood)
    stroke([pts[0], pts[-1]], 0.018, glow((0.75, 1.0, 0.6)), outline=False)
    stroke([(-0.55, 0.0), (0.75, 0.0)], 0.035, wood)
    slab([(0.0, -0.12), (0.28, 0.0), (0.0, 0.12)], glow((0.7, 1.0, 0.55)), at=(0.72, 0.0), bevel=0.02)
    for dz in (-0.08, 0.08):
        slab([(0.0, 0.0), (0.18, dz * 1.5), (0.22, dz * 0.5)], tint((0.95, 0.95, 0.9), "Fletch", 0.3), at=(-0.6, 0.0), bevel=0.01)


def e_hefesto():
    stroke([(-0.6, -0.8), (0.2, 0.25)], 0.08, tint((0.45, 0.25, 0.12), "Handle", 0.3))
    head = [(-0.5, -0.2), (0.5, -0.2), (0.6, -0.1), (0.6, 0.1), (0.5, 0.2), (-0.5, 0.2), (-0.6, 0.1), (-0.6, -0.1)]
    slab(head, tint((0.55, 0.53, 0.58), "Iron", 1.0), at=(0.25, 0.4), rot=0.65, scale=0.9)
    c, s = math.cos(0.65), math.sin(0.65)
    hx, hz = 0.25 + 0.55 * c * 0.9, 0.4 + 0.55 * s * 0.9
    slab([(-0.05, -0.2), (0.05, -0.2), (0.05, 0.2), (-0.05, 0.2)], glow((1.0, 0.5, 0.12), 2.0), at=(hx, hz), rot=0.65, bevel=0.01, y=-0.01)
    for k in range(6):
        a = 0.2 + k * 0.4
        stroke([(hx + math.cos(a) * 0.12, hz + math.sin(a) * 0.12), (hx + math.cos(a) * 0.3, hz + math.sin(a) * 0.3)], 0.022,
               glow((1.0, 0.75, 0.3), 2.2), y=-0.05, outline=False)


def e_atena():
    disc(0, 0, 0.88, tint((0.86, 0.72, 0.42), "Bronze", 1.0))
    stroke(arc(0, 0, 0.84, 0, 2 * math.pi, 48), 0.06, gold(), y=-0.03)
    disc(0, 0, 0.36, glow((0.6, 0.85, 1.0), 1.4), y=-0.08, depth=DEPTH * 0.6)
    for k in range(8):
        a = 2 * math.pi * k / 8
        stroke([(math.cos(a) * 0.4, math.sin(a) * 0.4), (math.cos(a + 0.35) * 0.6, math.sin(a + 0.35) * 0.6),
                (math.cos(a + 0.2) * 0.72, math.sin(a + 0.2) * 0.72)], [0.05, 0.04, 0.015], gold(), y=-0.07)


def e_dionisio():
    grape = tint((0.62, 0.25, 0.75), "Grape", 1.0)
    rows = [(0.0, 0.3, 3), (0.0, 0.05, 3), (0.0, -0.2, 2), (0.0, -0.45, 1)]
    for x0, z, n in rows:
        for k in range(n):
            x = x0 + (k - (n - 1) / 2) * 0.26
            ball(x, z, 0.15, grape, y=-0.02 * k)
    stroke([(0.0, 0.45), (0.05, 0.75), (0.2, 0.9)], 0.04, tint((0.45, 0.3, 0.15), "Stem", 0.3))
    leaf = [(0.0, 0.0), (0.25, 0.12), (0.45, 0.05), (0.35, -0.12), (0.12, -0.12)]
    slab(leaf, tint((0.45, 0.78, 0.3), "Leaf", 0.4), at=(0.05, 0.7), rot=0.2, scale=1.1, bevel=0.02)


def e_demeter():
    g = gold()
    for k, ang in enumerate((-0.35, 0.0, 0.35)):
        c, s = math.cos(ang), math.sin(ang)

        def rp(x, z):
            return (x * c - z * s, x * s + z * c)
        stroke([rp(0, -0.95), rp(0, 0.2)], 0.035, tint((0.75, 0.62, 0.3), "Stalk", 0.3))
        for i in range(5):
            for side in (-1, 1):
                x, z = rp(side * 0.08, 0.25 + i * 0.13)
                ob = F.ellipsoid("Grain", (x, 0, z), (0.07, 0.05, 0.1), g, segs=10, rings=6, rot=(0, -ang - side * 0.4, 0))
                finish(ob)


def flame(cx, cz, h, layers=((1.0, 0.45, 0.1), (1.0, 0.75, 0.25), (1.0, 0.97, 0.8))):
    for k, col in enumerate(layers):
        sc = 1.0 - k * 0.3
        pts = []
        for a in np.linspace(0, 2 * math.pi, 40, endpoint=False):
            x = math.sin(a) * 0.42 * sc
            z = -math.cos(a) * 0.42 * sc
            if z > 0:
                x *= max(0.0, 1.0 - z / (0.42 * sc)) ** 0.6
                z *= h / 0.42
            pts.append((x, z))
        slab(pts, glow(col, 1.8 + k * 0.5), at=(cx, cz - 0.35 + k * 0.1), y=-0.03 * k, bevel=0.03)


def e_hestia():
    flame(0, 0, 1.05)


def e_boreas():
    m = glow((0.7, 0.92, 1.0), 1.4)
    core = tint((0.92, 0.98, 1.0), "Ice", 1.4)
    for k in range(6):
        a = math.pi / 2 + k * math.pi / 3
        d = (math.cos(a), math.sin(a))
        stroke([(0, 0), (d[0] * 0.9, d[1] * 0.9)], 0.06, core)
        for t, ln in ((0.45, 0.22), (0.7, 0.16)):
            p = (d[0] * t, d[1] * t)
            for side in (-1, 1):
                b = a + side * 0.75
                stroke([p, (p[0] + math.cos(b) * ln, p[1] + math.sin(b) * ln)], 0.04, core)
    ball(0, 0, 0.14, m, y=-0.05)


def crescent_strip(size, material, inner=0.78, off=0.38, n=32, at=(0.0, 0.0)):
    xi = (1 - inner * inner + off * off) / (2 * off)
    yi = math.sqrt(1 - xi * xi)
    ao0 = math.atan2(yi, xi)
    ai0 = math.atan2(yi, xi - off)
    verts, faces = [], []
    for k in range(n):
        t = k / (n - 1)
        ao = ao0 + t * (2 * math.pi - 2 * ao0)
        ai = ai0 + t * (2 * math.pi - 2 * ai0)
        verts.append((at[0] + math.cos(ao) * size, 0.0, at[1] + math.sin(ao) * size))
        verts.append((at[0] + (off + inner * math.cos(ai)) * size, 0.0, at[1] + inner * math.sin(ai) * size))
    for k in range(n - 1):
        faces.append((2 * k, 2 * k + 2, 2 * k + 3, 2 * k + 1))
    ob = F.mesh_object("Crescent", verts, faces, [material], smooth=False)
    sol = ob.modifiers.new("Thick", "SOLIDIFY")
    sol.thickness = DEPTH
    sol.offset = 0.0
    return finish(ob)


def e_selene():
    crescent_strip(0.85, glow((0.88, 0.9, 1.0), 1.5), at=(-0.15, 0.0))
    for x, z, r in ((0.45, 0.45, 0.09), (0.62, -0.1, 0.06), (0.3, -0.5, 0.07)):
        star = []
        for k in range(8):
            a = math.pi / 2 + k * math.pi / 4
            rr = r if k % 2 == 0 else r * 0.35
            star.append((math.cos(a) * rr * 2, math.sin(a) * rr * 2))
        slab(star, glow((1.0, 1.0, 0.95), 2.0), at=(x, z), bevel=0.01)


def e_hecate():
    g = gold()
    stroke(arc(0, 0.5, 0.3, 0, 2 * math.pi, 28), 0.075, g)
    stroke([(0, 0.2), (0, -0.9)], 0.07, g)
    for z, w in ((-0.55, 0.25), (-0.8, 0.32)):
        stroke([(0, z), (w, z), (w, z - 0.1)], 0.055, g)
    disc(0, 0.5, 0.17, glow((0.8, 0.5, 1.0), 1.8), y=-0.03, depth=DEPTH * 0.7)


def e_eolo():
    m = glow((0.82, 0.98, 1.0), 1.3)
    for k, (r0, z) in enumerate(((0.75, 0.35), (0.55, -0.15), (0.42, -0.55))):
        pts = []
        for i in range(30):
            t = i / 29
            a = math.pi * 1.0 + t * math.pi * 2.2
            r = r0 * (1 - 0.65 * t)
            pts.append((-0.5 + t * 1.0 + math.cos(a) * r * 0.25 + (r0 - 0.4), z + math.sin(a) * r * 0.45))
        tail = [(-0.95, z + 0.0)] + pts
        stroke(tail, [0.035 + 0.035 * math.sin(math.pi * i / len(tail)) for i in range(len(tail))], m)


def e_nemesis():
    g = gold()
    stroke([(0, -0.9), (0, 0.75)], 0.06, g)
    stroke([(-0.75, 0.5), (0, 0.62), (0.75, 0.5)], 0.055, g)
    for x in (-0.65, 0.65):
        stroke([(x, 0.48), (x - 0.18, 0.0)], 0.02, g, outline=False)
        stroke([(x, 0.48), (x + 0.18, 0.0)], 0.02, g, outline=False)
        slab(arc(0, 0, 0.26, math.pi, 2 * math.pi, 14), g, at=(x, 0.02), bevel=0.02)
        stroke(arc(x, 0.02, 0.26, math.pi, 2 * math.pi, 14), 0.03, glow((1.0, 0.35, 0.3)), y=-0.06, outline=False)
    stroke([(-0.3, -0.9), (0.3, -0.9)], 0.07, g)
    ball(0, 0.78, 0.1, glow((1.0, 0.35, 0.3), 1.8))


RAINBOW = [(1.0, 0.36, 0.36), (1.0, 0.64, 0.28), (1.0, 0.9, 0.35), (0.5, 0.92, 0.45), (0.35, 0.65, 1.0), (0.72, 0.45, 1.0)]


def e_iris():
    for k, col in enumerate(RAINBOW):
        r = 0.9 - k * 0.12
        stroke(arc(0, -0.35, r, 0.0, math.pi, 30), 0.055, glow(col, 1.3), y=-0.01 * k)
    for x in (-0.6, 0.6):
        ball(x, -0.45, 0.22, tint((1.0, 1.0, 1.0), "Cloud", 0.2), flat=0.6)
        ball(x - 0.18 * (1 if x > 0 else -1), -0.5, 0.15, tint((1.0, 1.0, 1.0), "Cloud", 0.2), flat=0.6)


def e_tique():
    g = gold()
    disc(0, 0, 0.85, g)
    stroke(arc(0, 0, 0.7, 0, 2 * math.pi, 40), 0.04, tint((0.75, 0.5, 0.18), "Engrave", 0.6), y=-0.07)
    star = []
    for k in range(10):
        a = math.pi / 2 + k * math.pi / 5
        rr = 0.48 if k % 2 == 0 else 0.2
        star.append((math.cos(a) * rr, math.sin(a) * rr))
    slab(star, glow((1.0, 0.92, 0.55), 1.4), y=-0.07, depth=DEPTH * 0.6, bevel=0.02)


def e_olimpo():
    g = gold()
    for side in (-1, 1):
        pts = arc(0, -0.1, 0.72, math.pi * (1.5 + side * 0.08), math.pi * (1.5 + side * 0.85), 16)
        stroke(pts, 0.04, g)
        for k in range(7):
            t = (k + 0.5) / 7
            a = math.pi * (1.5 + side * (0.12 + 0.72 * t))
            p = (math.cos(a) * 0.72, -0.1 + math.sin(a) * 0.72)
            for flip in (-1, 1):
                b = a + side * (math.pi / 2) + flip * 0.55 * side
                ob = F.ellipsoid("Leaf", (p[0] + math.cos(b) * 0.1, 0, p[1] + math.sin(b) * 0.1), (0.05, 0.03, 0.12), g, segs=10, rings=6,
                                 rot=(0, -(b - math.pi / 2), 0))
                finish(ob)
    star = []
    for k in range(8):
        a = math.pi / 2 + k * math.pi / 4
        rr = 0.2 if k % 2 == 0 else 0.07
        star.append((math.cos(a) * rr, math.sin(a) * rr))
    slab(star, glow((1.0, 0.88, 0.45), 2.0), at=(0.0, 0.2), bevel=0.01)


def e_lanca():
    c, s_ = math.cos(-0.75), math.sin(-0.75)

    def rp(x, z):
        return (x * c - z * s_, x * s_ + z * c)
    stroke([rp(0, -1.0), rp(0, 0.45)], 0.055, tint((0.5, 0.3, 0.16), "Shaft", 0.3))
    blade = [(0.0, 0.0), (0.16, 0.18), (0.13, 0.45), (0.0, 0.7), (-0.13, 0.45), (-0.16, 0.18)]
    slab(blade, gold(), at=rp(0, 0.38), rot=-0.75)
    stroke([rp(0, 0.4), rp(0, 0.9)], 0.02, glow((1.0, 0.7, 0.3), 1.8), y=-0.07, outline=False)
    stroke([rp(-0.12, 0.33), rp(0.12, 0.33)], 0.05, gold())
    rib = glow((1.0, 0.25, 0.2), 1.2)
    for k, dx in enumerate((-0.05, 0.06)):
        p0 = rp(dx, 0.3)
        stroke([p0, (p0[0] + 0.12 + 0.05 * k, p0[1] - 0.2), (p0[0] + 0.05 + 0.08 * k, p0[1] - 0.42)], [0.035, 0.03, 0.012], rib)
    ball(*rp(0, -1.0), 0.07, gold())


def e_cetro():
    g = gold()
    stroke([(0.0, -0.95), (0.0, 0.35)], 0.06, g)
    for z in (-0.6, -0.2):
        stroke(arc(0.0, z, 0.075, 0, 2 * math.pi, 16), 0.025, g)
    stroke(arc(0.0, 0.55, 0.3, -0.35, math.pi + 0.35, 20), 0.05, g)
    ball(0.0, 0.58, 0.2, glow((0.55, 0.85, 1.0), 1.8))
    slab([(x * 0.55, z * 0.42) for x, z in BOLT], glow((1.0, 1.0, 1.0), 2.4), at=(0.0, 0.58), bevel=0.01, y=-0.12, outline=False)
    for a in (0.5, 2.6):
        stroke([(math.cos(a) * 0.32, 0.58 + math.sin(a) * 0.32), (math.cos(a) * 0.5, 0.58 + math.sin(a) * 0.48)], 0.02,
               glow((0.7, 0.9, 1.0), 2.0), outline=False)


def e_vida():
    pts = []
    for a in np.linspace(0, 2 * math.pi, 64, endpoint=False):
        x = 16 * math.sin(a) ** 3
        z = 13 * math.cos(a) - 5 * math.cos(2 * a) - 2 * math.cos(3 * a) - math.cos(4 * a)
        pts.append((x / 18.0, z / 18.0 + 0.08))
    slab(pts, tint((0.9, 0.12, 0.2), "Ruby", 1.3), scale=0.95, bevel=0.07)
    stroke([(x * 0.95, z * 0.95) for x, z in pts] + [(pts[0][0] * 0.95, pts[0][1] * 0.95)], 0.035, gold(), y=-0.04)
    ball(-0.3, 0.32, 0.1, glow((1.0, 0.75, 0.8), 1.6), y=-0.1, outline=False)


def e_forca():
    blade = [(0.0, -0.05), (0.11, 0.05), (0.11, 0.95), (0.0, 1.22), (-0.11, 0.95), (-0.11, 0.05)]
    steel = tint((0.86, 0.88, 0.95), "Steel", 1.4)
    aura = glow((1.0, 0.35, 0.15), 1.4)
    disc(0.0, 0.05, 0.42, aura, depth=DEPTH * 0.4, y=0.2)
    for ang in (-0.62, 0.62):
        c, s_ = math.cos(ang), math.sin(ang)

        def rp(x, z):
            return (x * c - z * s_, x * s_ + z * c - 0.45)
        slab(blade, steel, at=rp(0, 0.0), rot=ang)
        stroke([rp(0, 0.1), rp(0, 0.95)], 0.02, glow((1.0, 0.4, 0.2), 1.8), y=-0.07, outline=False)
        stroke([rp(-0.3, 0.0), rp(0.3, 0.0)], 0.065, gold())
        stroke([rp(0, -0.02), rp(0, -0.36)], 0.055, tint((0.5, 0.18, 0.12), "Grip"))
        ball(*rp(0, -0.42), 0.085, gold())


EMBLEMS = {
    "zeus": e_zeus, "poseidon": e_poseidon, "ares": e_ares, "apolo": e_apolo, "hermes": e_hermes, "artemis": e_artemis,
    "hefesto": e_hefesto, "atena": e_atena, "dionisio": e_dionisio, "demeter": e_demeter, "hestia": e_hestia,
    "boreas": e_boreas, "selene": e_selene, "hecate": e_hecate, "eolo": e_eolo, "nemesis": e_nemesis, "iris": e_iris,
    "tique": e_tique, "olimpo": e_olimpo,
    "lanca": e_lanca, "cetro": e_cetro, "vida": e_vida, "forca": e_forca,
}


def main():
    os.makedirs(OUT, exist_ok=True)
    for gid in ONLY or list(EMBLEMS):
        reset()
        MAT.clear()
        EMBLEMS[gid]()
        bpy.context.scene.render.filepath = os.path.join(OUT, gid + ".png")
        bpy.ops.render.render(write_still=True)
        print("emblem", gid)


if __name__ == "__main__":
    main()
