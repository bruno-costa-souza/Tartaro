"""Builds the Tártaro hero in 3D, animates it, renders it in 16 directions and
packs sprite sheets for Godot (Hades-style pre-rendered sprites).

Run (headless), from the project root:
    blender -b -P tools/blender/hero.py -- art/hero
    HERO_PREVIEW=1 blender -b -P tools/blender/hero.py -- <dir>    # a few test frames

Output: <dir>/{idle,walk,attack,dash}.png (rows = directions starting at
"facing camera" and turning clockwise on screen, columns = frames),
<dir>/showcase.png (bigger idle turntable for the menu) and hero.json.

The body is one skinned mesh (skin modifier + armature), armour and props are
bound to bones, and the cape and the spear ribbons are simulated cloth
(figure.Cloth), so they lag, ripple and stream with the motion.
"""

import json
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import figure as F  # noqa: E402
import kit  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(ARGS[0] if ARGS else "art/hero")
PREVIEW = os.environ.get("HERO_PREVIEW") == "1"

SIZE = 192
ORTHO = 2.7
DIRECTIONS = 16
ANIMS = {"idle": 12, "walk": 12, "attack": 8, "dash": 6}
FPS = {"idle": 8, "walk": 18, "attack": 22, "dash": 18}
SHOWCASE = {"size": 320, "ortho": 2.3, "directions": 8}
TARGET_Z = 0.95
CAM_PITCH = math.radians(40.0)

M = {}
OBJ = {}


# ---------------------------------------------------------------- model

def materials():
    rim = (0.6, 0.78, 1.0)
    M["skin"] = F.toon("Skin", (1.0, 0.74, 0.6), shadow=(0.74, 0.4, 0.4), rim=rim, rim_strength=0.1)
    M["bronze"] = F.toon("Bronze", (0.74, 0.4, 0.15), shadow=(0.3, 0.12, 0.09), spec=1.1, gloss=0.2,
                         spec_color=(1.0, 0.88, 0.55), rim=rim, rim_strength=0.22)
    M["gold"] = F.toon("Gold", (1.0, 0.78, 0.3), shadow=(0.6, 0.3, 0.08), spec=1.2, gloss=0.2,
                       emission=(1.0, 0.55, 0.15), strength=0.12, rim=rim)
    M["leather"] = F.toon("Leather", (0.36, 0.18, 0.1), shadow=(0.14, 0.06, 0.07), rim=rim, rim_strength=0.14)
    M["strap"] = F.toon("Strap", (0.24, 0.12, 0.08), shadow=(0.09, 0.04, 0.05), rim_strength=0.1)
    M["linen"] = F.toon("Linen", (0.96, 0.92, 0.83), shadow=(0.55, 0.47, 0.62), rim=rim, rim_strength=0.1)
    M["cape"] = F.toon("Cape", (0.78, 0.06, 0.1), shadow=(0.32, 0.02, 0.1), rim=(1.0, 0.45, 0.4), rim_strength=0.22)
    M["cape_in"] = F.toon("CapeIn", (0.42, 0.04, 0.09), shadow=(0.17, 0.01, 0.06), rim_strength=0.05)
    M["hair"] = F.toon("Hair", (0.11, 0.06, 0.06), shadow=(0.035, 0.015, 0.04), spec=0.45, gloss=0.3,
                       spec_color=(0.55, 0.42, 0.5), rim=rim, rim_strength=0.3)
    M["laurel"] = F.toon("Laurel", (1.0, 0.8, 0.3), shadow=(0.75, 0.4, 0.08), spec=0.8,
                         emission=(1.0, 0.5, 0.1), strength=0.4, rim_strength=0.0)
    M["wood"] = F.toon("Wood", (0.4, 0.23, 0.12), shadow=(0.15, 0.07, 0.05), rim_strength=0.1)
    M["blade"] = F.toon("Blade", (1.0, 0.84, 0.48), shadow=(0.7, 0.4, 0.14), spec=1.4, gloss=0.15,
                        emission=(1.0, 0.55, 0.2), strength=0.3)
    M["ribbon"] = F.toon("Ribbon", (0.95, 0.16, 0.14), shadow=(0.45, 0.04, 0.1), rim_strength=0.15)
    M["eye"] = F.glow("Eye", (0.06, 0.03, 0.03))
    M["eye_shine"] = F.glow("EyeShine", (1.0, 0.86, 0.6))


def bones():
    b = [
        ("hips", (0, 0, 0.94), (0, 0, 1.08), None, True),
        ("spine", (0, 0, 1.08), (0, 0, 1.26), "hips", True),
        ("chest", (0, 0, 1.26), (0, 0, 1.5), "spine", True),
        ("neck", (0, 0.005, 1.5), (0, 0, 1.63), "chest", True),
        ("head", (0, 0, 1.63), (0, 0, 1.9), "neck", True),
    ]
    for side, s in (("L", -1), ("R", 1)):
        b += [
            ("clavicle." + side, (0.03 * s, 0.0, 1.46), (0.19 * s, 0.005, 1.465), "chest", True),
            ("upperarm." + side, (0.2 * s, 0.005, 1.455), (0.27 * s, 0.02, 1.2), "clavicle." + side, True),
            ("forearm." + side, (0.27 * s, 0.02, 1.2), (0.31 * s, -0.005, 0.975), "upperarm." + side, True),
            ("hand." + side, (0.31 * s, -0.005, 0.975), (0.318 * s, -0.012, 0.88), "forearm." + side, True),
            ("thigh." + side, (0.097 * s, 0.0, 0.95), (0.11 * s, -0.015, 0.53), "hips", True),
            ("shin." + side, (0.11 * s, -0.015, 0.53), (0.115 * s, 0.02, 0.095), "thigh." + side, True),
            ("foot." + side, (0.115 * s, 0.02, 0.095), (0.118 * s, -0.11, 0.025), "shin." + side, True),
        ]
    b.append(("spear", (0.318, -0.012, 0.92), (0.318, -0.012, 1.92), "hand.R", True))
    return b


BODY_BONES = {"hips", "spine", "chest", "neck", "head", "clavicle.L", "clavicle.R", "upperarm.L", "upperarm.R",
              "forearm.L", "forearm.R", "hand.L", "hand.R", "thigh.L", "thigh.R", "shin.L", "shin.R"}


def build_body(arm):
    V, E, R = [], [], []

    def v(p, r, parent=None):
        V.append(p)
        R.append(r)
        if parent is not None:
            E.append((parent, len(V) - 1))
        return len(V) - 1

    pelvis = v((0, 0.005, 0.98), (0.15, 0.115))
    waist = v((0, 0.0, 1.12), (0.125, 0.095), pelvis)
    chest = v((0, -0.01, 1.3), (0.165, 0.115), waist)
    upper = v((0, 0.0, 1.43), (0.155, 0.1), chest)
    neck = v((0, 0.01, 1.53), (0.066, 0.064), upper)
    v((0, 0.0, 1.68), (0.058, 0.058), neck)
    for s in (-1, 1):
        sh = v((0.2 * s, 0.005, 1.455), (0.084, 0.08), upper)
        bi = v((0.238 * s, 0.01, 1.34), (0.076, 0.07), sh)
        el = v((0.27 * s, 0.02, 1.2), (0.056, 0.055), bi)
        fa = v((0.29 * s, 0.01, 1.1), (0.062, 0.053), el)
        v((0.31 * s, -0.005, 0.975), (0.041, 0.037), fa)
        hp = v((0.095 * s, 0.0, 0.93), (0.102, 0.1), pelvis)
        th = v((0.105 * s, -0.008, 0.74), (0.1, 0.098), hp)
        kn = v((0.11 * s, -0.015, 0.53), (0.066, 0.068), th)
        ca = v((0.112 * s, 0.014, 0.38), (0.08, 0.078), kn)
        v((0.115 * s, 0.02, 0.1), (0.043, 0.045), ca)
    body = F.skin_body("Body", V, E, R, M["skin"], root=pelvis, subdiv=2)
    F.bind(body, arm, F.auto_weights(F.verts_of(body), arm, allowed=BODY_BONES))
    F.outline(body, subsurf=0)
    OBJ["body"] = body


def rigid(ob, arm, bone, subsurf=1, outline=True):
    F.bind(ob, arm, bone)
    if outline:
        F.outline(ob, subsurf=subsurf)
    elif subsurf:
        sub = ob.modifiers.new("Sub", "SUBSURF")
        sub.levels = subsurf
        sub.render_levels = subsurf
    return ob


def torso_weights(X):
    z = X[:, 2]

    def sm(a, b):
        t = np.clip((z - a) / (b - a), 0.0, 1.0)
        return t * t * (3 - 2 * t)

    w_chest = sm(1.2, 1.34)
    w_pelvis = 1.0 - sm(1.0, 1.1)
    w_spine = np.clip(1.0 - w_chest - w_pelvis, 0.0, 1.0)
    return {"hips": w_pelvis, "spine": w_spine, "chest": w_chest}


def skirt_weights(X, top, bottom, reach=0.6):
    """Hips at the waist, following each thigh more towards the hem."""
    down = np.clip((top - X[:, 2]) / (top - bottom), 0.0, 1.0) ** 1.3 * reach
    side = np.clip(X[:, 0] / 0.09, -1.0, 1.0)
    left = down * (0.5 - 0.5 * side)
    right = down * (0.5 + 0.5 * side)
    return {"hips": 1.0 - down, "thigh.L": left, "thigh.R": right}


HEAD_C = Vector((0, -0.004, 1.745))
HEAD_R = (0.118, 0.126, 0.142)


def head_front(x, z, inset=0.0):
    """y of the face surface at (x, z) (front is -y)."""
    k = 1.0 - (x / HEAD_R[0]) ** 2 - ((z - HEAD_C.z) / HEAD_R[2]) ** 2
    return HEAD_C.y - HEAD_R[1] * 0.92 * math.sqrt(max(k, 0.0)) + inset


def build_head(arm):
    def head_shape(co):
        x, y, z = co
        if z < 0.0:
            k = 1.0 - 0.3 * (-z) ** 1.6
            x *= k
            y *= 1.0 - 0.1 * (-z)
            if y < 0.0 and z < -0.55:
                y -= 0.1 * (-z - 0.55)
        if y < 0.0:
            y *= 0.92
        if y > 0.0 and z > -0.3:
            y *= 1.06
        return (x, y, z)

    parts = [F.ellipsoid("Head", tuple(HEAD_C), HEAD_R, M["skin"], segs=28, rings=16, shape=head_shape)]
    parts.append(F.ellipsoid("Nose", (0, head_front(0, 1.722, -0.004), 1.722), (0.018, 0.026, 0.034), M["skin"],
                             segs=10, rings=6, rot=(0.35, 0, 0)))
    for s in (-1, 1):
        parts.append(F.ellipsoid("Ear", (0.116 * s, 0.006, 1.735), (0.017, 0.03, 0.042), M["skin"], segs=10, rings=6))
    for p in parts:
        rigid(p, arm, "head", subsurf=1, outline=p.name.startswith("Head") or p.name.startswith("Ear"))
    for s in (-1, 1):
        ex, ez = 0.045 * s, 1.756
        eye = F.ellipsoid("Eye", (ex, head_front(ex, ez, 0.007), ez), (0.019, 0.011, 0.012), M["eye"], segs=10,
                          rings=6, rot=(0, 0.2 * s, 0.1 * s))
        rigid(eye, arm, "head", subsurf=0, outline=False)
        shine = F.ellipsoid("EyeShine", (ex - 0.005 * s, head_front(ex, ez, -0.003), ez + 0.004),
                            (0.005, 0.004, 0.005), M["eye_shine"], segs=6, rings=4)
        rigid(shine, arm, "head", subsurf=0, outline=False)
        brow = F.tube("Brow", [(x * s, head_front(x, z, -0.004), z) for x, z in ((0.074, 1.781), (0.048, 1.787), (0.02, 1.779))],
                      [0.008, 0.0095, 0.006], M["hair"], sides=6)
        rigid(brow, arm, "head", subsurf=0, outline=False)
    build_hair(arm)


HAIR_C = Vector((0, 0.028, 1.812))
HAIR_R = Vector((0.132, 0.14, 0.118))


def wrap_hair(p, lift=0.0):
    """Project a point onto the hair cap surface, `lift` (fraction) above it."""
    d = Vector(p) - HAIR_C
    d = Vector((d.x / HAIR_R.x, d.y / HAIR_R.y, d.z / HAIR_R.z))
    d.normalize()
    return HAIR_C + Vector((d.x * HAIR_R.x, d.y * HAIR_R.y, d.z * HAIR_R.z)) * (1.0 + lift), d


def hair_lock(arm, path, r0, length_lift=0.35, flat=0.5, tip_drop=0.0):
    """A swept lock that hugs the cap and peels off at the tip."""
    pts, widths = [], []
    n = 9
    for i in range(n):
        t = i / (n - 1)
        q = Vector(path[0]).lerp(Vector(path[1]), min(t * 2, 1.0)) if t <= 0.5 else Vector(path[1]).lerp(Vector(path[2]), (t - 0.5) * 2)
        lift = 0.02 + length_lift * max(0.0, t - 0.55) ** 1.6 / 0.45 ** 1.6
        p, nrm = wrap_hair(q, lift)
        p.z -= tip_drop * t * t
        pts.append(p)
        widths.append(nrm)
    tang = [(pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized() for i in range(n)]
    widths = [w.cross(t) for w, t in zip(widths, tang)]
    radii = [r0 * (1.0 - 0.15 * (i / (n - 1))) if i < n - 3 else r0 * (0.7, 0.4, 0.05)[i - (n - 3)] for i in range(n)]
    lock = F.tube("Lock", pts, radii, M["hair"], sides=8, flat=flat, widths=widths)
    rigid(lock, arm, "head", subsurf=1)


def build_hair(arm):
    cap = F.ellipsoid("HairCap", tuple(HAIR_C), tuple(HAIR_R), M["hair"], segs=24, rings=12)
    rigid(cap, arm, "head", subsurf=1)
    # crown: from the front hairline over the top, flicking out at the back
    for k in range(-3, 4):
        x = 0.032 * k
        hair_lock(arm, [(x, -0.12, 1.86), (x * 1.15, 0.0, 1.95), (x * 1.5, 0.2, 1.84 - 0.012 * abs(k))],
                  0.05 - 0.004 * abs(k), length_lift=0.42, tip_drop=0.02)
    # sides: temples back over the ears
    for s in (-1, 1):
        for j, z in enumerate((1.84, 1.8)):
            hair_lock(arm, [(0.11 * s, -0.07, z + 0.01), (0.14 * s, 0.05, z), (0.12 * s, 0.17, z - 0.06)],
                      0.042, length_lift=0.36, tip_drop=0.02)
    # nape
    for k in range(-2, 3):
        x = 0.045 * k
        hair_lock(arm, [(x, 0.1, 1.9), (x * 1.1, 0.16, 1.78), (x * 1.2, 0.12, 1.66)], 0.045, length_lift=0.3,
                  tip_drop=0.015)
    # fringe flicking up off the forehead
    for s, x in ((-1, 0.05), (1, 0.03), (1, 0.085)):
        pts = [(x * s, -0.105, 1.83), (x * s * 1.2, -0.14, 1.865), (x * s * 1.35, -0.12, 1.91)]
        bang = F.tube("Bang", pts, [0.028, 0.02, 0.003], M["hair"], sides=7, flat=0.6)
        rigid(bang, arm, "head", subsurf=1)
    # laurel wreath, open at the front
    for i in range(22):
        t = i / 21.0
        a = math.radians(-150 + 300 * t) + math.pi / 2
        ring_p = Vector((math.cos(a) * 0.138, math.sin(a) * 0.142 + 0.02, 1.818 + 0.03 * (math.sin(a) + 1) * 0.5))
        for layer in (-1, 1):
            heading = a + math.pi if a < math.pi / 2 else a
            leaf = F.ellipsoid("Leaf", ring_p + Vector((0, 0, 0.012 * layer)), (0.012, 0.03, 0.0045), M["laurel"],
                               segs=8, rings=4, rot=(0.5 * layer, 0.0, heading))
            rigid(leaf, arm, "head", subsurf=0, outline=True)


CUIRASS = []


def cuirass_front(x, z, lift=0.008):
    """Point on the front of the cuirass (for straps lying on it)."""
    zs = [c[0] for c in CUIRASS]
    rx = float(np.interp(z, zs, [c[1] for c in CUIRASS]))
    ry = float(np.interp(z, zs, [c[2] for c in CUIRASS]))
    return -0.008 - ry * math.sqrt(max(0.0, 1.0 - (x / rx) ** 2)) - lift


def build_armour(arm):
    # muscle cuirass
    zs = [1.0, 1.06, 1.13, 1.21, 1.29, 1.37, 1.44, 1.5, 1.538]
    rx = [0.172, 0.158, 0.15, 0.158, 0.18, 0.194, 0.19, 0.165, 0.12]
    ry = [0.134, 0.122, 0.116, 0.121, 0.13, 0.137, 0.128, 0.112, 0.092]
    rings_ = []
    for z, a, b in zip(zs, rx, ry):
        def bumps(ang, z=z, a=a):
            x = math.cos(ang) * a
            front = -math.sin(ang)
            dy = 0.0
            if front > 0.2:
                pec = math.exp(-((z - 1.37) / 0.045) ** 2) * (math.exp(-((x - 0.08) / 0.05) ** 2) + math.exp(-((x + 0.08) / 0.05) ** 2))
                abs_ = math.exp(-((z - 1.19) / 0.07) ** 2) * 0.5 * (math.exp(-((x - 0.04) / 0.035) ** 2) + math.exp(-((x + 0.04) / 0.035) ** 2))
                groove = math.exp(-(x / 0.018) ** 2) * (0.6 if z < 1.42 else 0.0)
                dy = -0.014 * pec - 0.008 * abs_ + 0.007 * groove
            return (0.0, dy * front, 0.0)
        rings_.append(F.ring((0, -0.008, z), a, b, 32, fn=bumps))
    cuirass = F.loft("Cuirass", rings_, M["bronze"])
    F.bind(cuirass, arm, torso_weights(F.verts_of(cuirass)))
    cuirass.modifiers.new("Thick", "SOLIDIFY").thickness = 0.012
    F.outline(cuirass, subsurf=1)
    CUIRASS.extend(zip(zs, rx, ry))

    # harness strap across the chest and a gold boss
    pts = []
    for i in range(9):
        t = i / 8.0
        x = -0.17 + 0.32 * t
        z = 1.47 - 0.36 * t
        pts.append((x, cuirass_front(x, z, 0.012 + 0.014 * math.exp(-((z - 1.37) / 0.05) ** 2)), z))
    strap = F.tube("Harness", pts, 0.012, M["strap"], sides=6, flat=0.45)
    F.bind(strap, arm, torso_weights(F.verts_of(strap)))
    F.outline(strap, subsurf=1)
    boss = F.ellipsoid("Boss", (0.0, -0.152, 1.31), (0.026, 0.012, 0.026), M["gold"], segs=12, rings=6)
    rigid(boss, arm, "chest", subsurf=1)

    # belt + buckle
    belt_pts = [(math.cos(a) * 0.168, math.sin(a) * 0.13 - 0.006, 1.03) for a in np.linspace(0, 2 * math.pi, 25)]
    belt = F.tube("Belt", belt_pts, 0.02, M["strap"], sides=6, flat=0.8, cap=False)
    F.bind(belt, arm, torso_weights(F.verts_of(belt)))
    F.outline(belt, subsurf=1)
    buckle = F.ellipsoid("Buckle", (0, -0.148, 1.03), (0.032, 0.012, 0.024), M["gold"], segs=12, rings=6)
    rigid(buckle, arm, "hips", subsurf=1)

    # linen chiton skirt with folds
    sk = []
    for z, a, b in ((1.0, 0.16, 0.124), (0.9, 0.18, 0.145), (0.8, 0.2, 0.165), (0.7, 0.215, 0.178)):
        def folds(ang, z=z):
            k = (1.0 - z) * 0.6
            return (math.cos(ang) * 0.012 * math.sin(ang * 9) * k * 3, math.sin(ang) * 0.012 * math.sin(ang * 9) * k * 3, 0.0)
        sk.append(F.ring((0, 0.0, z), a, b, 40, fn=folds))
    skirt = F.loft("Chiton", sk, M["linen"])
    F.bind(skirt, arm, skirt_weights(F.verts_of(skirt), 1.0, 0.7))
    F.outline(skirt, subsurf=1)

    # leather pteruges
    n = 16
    for i in range(n):
        a = 2 * math.pi * (i + 0.5) / n
        w = 0.034
        verts = []
        for zt, rx_, ry_ in ((1.02, 0.172, 0.135), (0.93, 0.19, 0.152), (0.84, 0.205, 0.168), (0.76, 0.214, 0.178)):
            for side in (-1, 1):
                aa = a + side * w / ((rx_ + ry_) / 2)
                verts.append((math.cos(aa) * rx_, math.sin(aa) * ry_ - 0.004, zt))
        faces = [(0, 1, 3, 2), (2, 3, 5, 4), (4, 5, 7, 6)]
        strip = F.mesh_object("Pteryx", verts, faces, [M["leather"]])
        F.bind(strip, arm, skirt_weights(F.verts_of(strip), 1.02, 0.76))
        strip.modifiers.new("Thick", "SOLIDIFY").thickness = 0.01
        F.outline(strip, subsurf=1, thickness=0.012)
        stud = F.ellipsoid("Stud", (math.cos(a) * 0.222, math.sin(a) * 0.186 - 0.004, 0.785), (0.012, 0.012, 0.012),
                           M["gold"], segs=8, rings=4)
        F.bind(stud, arm, skirt_weights(F.verts_of(stud), 1.02, 0.76))

    # pauldron on the left shoulder
    for i in range(3):
        plate = F.ellipsoid("Pauldron", (-0.222 - 0.012 * i, 0.005, 1.5 - 0.048 * i), (0.092 - 0.006 * i, 0.105, 0.05),
                            M["bronze"], segs=20, rings=10, rot=(0.0, -0.55 - 0.12 * i, 0.0))
        F.bind(plate, arm, {"clavicle.L": np.full(len(plate.data.vertices), 0.35),
                            "upperarm.L": np.full(len(plate.data.vertices), 0.65)})
        F.outline(plate, subsurf=1)
    stud = F.ellipsoid("PauldronBoss", (-0.26, -0.03, 1.535), (0.018, 0.018, 0.018), M["gold"], segs=10, rings=5)
    F.bind(stud, arm, "clavicle.L")

    # cape brooches
    for s in (-1, 1):
        br = F.ellipsoid("Brooch", (0.17 * s, -0.07, 1.47), (0.026, 0.016, 0.026), M["gold"], segs=12, rings=6,
                         rot=(0.3, 0, 0))
        rigid(br, arm, "chest", subsurf=1)

    for s, side in ((-1, "L"), (1, "R")):
        build_limb_gear(arm, side, s)


def along(arm, bone, t):
    b = arm.data.bones[bone]
    return b.head_local.lerp(b.tail_local, t)


def build_limb_gear(arm, side, s):
    # bracers
    pts = [along(arm, "forearm." + side, t) for t in (0.35, 0.6, 0.97)]
    br = F.tube("Bracer", pts, [0.066, 0.063, 0.05], M["leather"], sides=12)
    rigid(br, arm, "forearm." + side, subsurf=1)
    for t, r in ((0.36, 0.069), (0.96, 0.053)):
        c = along(arm, "forearm." + side, t)
        axis = (arm.data.bones["forearm." + side].tail_local - arm.data.bones["forearm." + side].head_local).normalized()
        u = axis.orthogonal().normalized()
        w = axis.cross(u)
        ring_pts = [tuple(c + (u * math.cos(a) + w * math.sin(a)) * r) for a in np.linspace(0, 2 * math.pi, 17)]
        rim = F.tube("BracerRim", ring_pts, 0.009, M["bronze"], sides=6, cap=False)
        rigid(rim, arm, "forearm." + side, subsurf=1)
    # fists
    hand = F.ellipsoid("Fist", tuple(along(arm, "hand." + side, 0.45)), (0.05, 0.054, 0.062), M["skin"],
                       segs=14, rings=8)
    rigid(hand, arm, "hand." + side, subsurf=1)
    # greaves with knee guard
    pts = [along(arm, "shin." + side, t) for t in (0.08, 0.35, 0.7, 0.9)]
    gr = F.tube("Greave", [p + Vector((0, -0.006, 0)) for p in pts], [0.076, 0.087, 0.07, 0.056], M["bronze"], sides=14)
    rigid(gr, arm, "shin." + side, subsurf=1)
    # feet + sandals
    fb = arm.data.bones["foot." + side]
    mid = fb.head_local.lerp(fb.tail_local, 0.45)
    foot = F.ellipsoid("Foot", tuple(mid + Vector((0, 0, -0.015))), (0.05, 0.11, 0.04), M["skin"], segs=14, rings=8,
                       rot=(0.12, 0, 0))
    rigid(foot, arm, "foot." + side, subsurf=1)
    sole = F.ellipsoid("Sole", tuple(mid + Vector((0, 0.0, -0.05))), (0.058, 0.125, 0.014), M["strap"], segs=14, rings=6)
    rigid(sole, arm, "foot." + side, subsurf=1)
    for k in range(2):
        c = mid + Vector((0, -0.04 + 0.06 * k, -0.01 + 0.02 * k))
        loop = [tuple(c + Vector((math.cos(a) * 0.054, 0, math.sin(a) * 0.045))) for a in np.linspace(0, 2 * math.pi, 15)]
        strap = F.tube("SandalStrap", loop, 0.008, M["strap"], sides=5, cap=False)
        rigid(strap, arm, "foot." + side, subsurf=0, outline=False)


def build_spear(arm):
    b = arm.data.bones["spear"]
    g = b.head_local
    shaft = F.tube("Shaft", [g + Vector((0, 0, z)) for z in (-0.5, 0.0, 0.6, 1.16)], 0.017, M["wood"], sides=8)
    rigid(shaft, arm, "spear", subsurf=0)
    butt = F.tube("Butt", [g + Vector((0, 0, z)) for z in (-0.6, -0.54, -0.48)], [0.004, 0.02, 0.021], M["bronze"], sides=8)
    rigid(butt, arm, "spear", subsurf=0)
    # leaf blade
    prof = [(1.14, 0.022, 0.022), (1.2, 0.026, 0.02), (1.24, 0.05, 0.012), (1.32, 0.058, 0.01), (1.42, 0.044, 0.008),
            (1.52, 0.02, 0.005), (1.58, 0.002, 0.002)]
    rings_ = []
    for z, w, t in prof:
        rings_.append([tuple(g + Vector((x, y, z))) for x, y in ((w, 0), (0, -t), (-w, 0), (0, t))])
    blade = F.loft("Blade", rings_, M["blade"], cap_top=True, cap_bottom=True)
    blade.data.polygons.foreach_set("use_smooth", [False] * len(blade.data.polygons))
    rigid(blade, arm, "spear", subsurf=0)
    wrap = F.tube("Wrap", [g + Vector((0, 0, z)) for z in (1.04, 1.1, 1.14)], 0.022, M["gold"], sides=8)
    rigid(wrap, arm, "spear", subsurf=0)
    grip = F.tube("Grip", [g + Vector((0, 0, z)) for z in (-0.06, 0.0, 0.08)], 0.021, M["strap"], sides=8)
    rigid(grip, arm, "spear", subsurf=0)


# ---------------------------------------------------------------- cloth

CAPE_ROWS, CAPE_COLS = 16, 11
RIB_ROWS = 7


def build_cloth_objects(arm):
    faces = F.grid_faces(CAPE_ROWS, CAPE_COLS)
    verts = [(0, 0, 0)] * (CAPE_ROWS * CAPE_COLS)
    cape = F.mesh_object("Cape", verts, faces, [M["cape"], M["gold"], M["cape_in"], M["gold"]], parent=arm)
    idx = []
    for i, f in enumerate(faces):
        r = i // (CAPE_COLS - 1)
        idx.append(1 if r == CAPE_ROWS - 2 else 0)
    cape.data.polygons.foreach_set("material_index", idx)
    sol = cape.modifiers.new("Thick", "SOLIDIFY")
    sol.thickness = 0.016
    sol.material_offset = 2
    sol.material_offset_rim = 1
    F.outline(cape, subsurf=2, thickness=0.014)
    OBJ["cape"] = cape

    rf = F.grid_faces(RIB_ROWS, 2)
    rfaces = rf + [tuple(i + RIB_ROWS * 2 for i in f) for f in rf]
    rib = F.mesh_object("Ribbon", [(0, 0, 0)] * (RIB_ROWS * 4), rfaces, [M["ribbon"]], parent=arm)
    sol = rib.modifiers.new("Thick", "SOLIDIFY")
    sol.thickness = 0.008
    F.outline(rib, subsurf=1, thickness=0.008)
    OBJ["ribbon"] = rib


def cape_attach_rest():
    u = np.linspace(-1.0, 1.0, CAPE_COLS)
    return np.stack([0.19 * u, 0.12 + 0.035 * (1 - u * u), 1.47 - 0.022 * u * u], axis=1)


CAPSULES = [("hips", 0.06, 0.12), ("hips", -0.06, 0.12), ("spine", 0.065, 0.12), ("spine", -0.065, 0.12),
            ("chest", 0.07, 0.13), ("chest", -0.07, 0.13), ("neck", 0.0, 0.07), ("head", 0.0, 0.15),
            ("thigh.L", 0.0, 0.105), ("thigh.R", 0.0, 0.105), ("shin.L", 0.0, 0.085), ("shin.R", 0.0, 0.085),
            ("upperarm.L", 0.0, 0.1), ("upperarm.R", 0.0, 0.075), ("forearm.L", 0.0, 0.065),
            ("forearm.R", 0.0, 0.065)]


def sample_rig(arm, anim, samples, periodic=True):
    """Evaluate the rig along an animation: cape attach points, ribbon attach
    points and collision capsules, as arrays per sample."""
    R = F.Pose(arm)
    attach_rest = cape_attach_rest()
    cape, rib, caps = [], [], []
    for k in range(samples):
        t = k / samples if periodic else k / (samples - 1)
        pose(R, anim, t)
        D = R.deform("chest")
        cape.append(np.array([tuple(D @ Vector(p)) for p in attach_rest]))
        S = R.matrix("spear")
        rib.append(np.array([tuple(S @ Vector((x, 1.03, 0.0))) for x in (-0.024, -0.004, 0.004, 0.024)]))
        rows = []
        for name, off, r in CAPSULES:
            Dm = R.deform(name)
            bb = arm.data.bones[name]
            a = Dm @ (bb.head_local + Vector((off, 0, 0)))
            b = Dm @ (bb.tail_local + Vector((off, 0, 0)))
            rows.append([*a, *b, r])
        caps.append(np.array(rows))
    return cape, rib, caps


def wind_fn(anim, rows, cols):
    v = np.linspace(0.0, 1.0, rows)[:, None, None]

    def w(t):
        ph = 2 * math.pi * t
        if anim == "idle":
            base = np.array([0.4 * math.sin(ph), 0.7 + 0.35 * math.sin(2 * ph + 1.0), 0.2 * math.sin(3 * ph + 0.5)])
            flutter = 0.35
            k = 2
        elif anim == "walk":
            base = np.array([0.8 * math.sin(2 * ph), 7.0 + 1.2 * math.sin(2 * ph + 0.7), 0.6 + 0.8 * math.sin(4 * ph + 0.3)])
            flutter = 2.6
            k = 4
        elif anim == "dash":
            base = np.array([1.0 * math.sin(2 * ph), 15.0 + 2.0 * math.sin(4 * ph), 1.0 * math.sin(6 * ph)])
            flutter = 4.0
            k = 6
        else:
            base = np.array([0.3 * math.sin(ph), 1.4, 0.3])
            flutter = 0.6
            k = 2
        wave = np.sin(k * ph - v * 7.0) * flutter * v
        out = np.broadcast_to(base, (rows, cols, 3)).copy()
        out[..., 2] += wave[..., 0]
        out[..., 0] += 0.35 * wave[..., 0] * np.sin(np.linspace(-1.5, 1.5, cols))[None, :]
        return out
    return w


def simulate_cloth(arm, anim):
    """Cloth frames for one animation: (cape grids, ribbon vertex arrays)."""
    frames = ANIMS[anim]
    once = anim == "attack"
    period = frames / FPS[anim]
    cycles = 1 if once else 6
    stretch = frames / (frames - 1) if once else 1.0
    cape_s, rib_s, cap_s = sample_rig(arm, anim, frames * 4, not once)

    def at(samples):
        return lambda t: F.lerp_samples(samples, t * stretch, not once)

    idle = None
    if once:
        idle = sample_rig(arm, "idle", ANIMS["idle"] * 4, True)
        idle_period = ANIMS["idle"] / FPS["idle"]

    cape = F.Cloth(CAPE_ROWS, CAPE_COLS, 0.98, 0.5, 0.84, drag=1.9, damping=0.993, iterations=10, bend=0.3,
                   thickness=0.03, pleats=0.03)
    warm = None
    if idle:
        warm = (lambda t: F.lerp_samples(idle[0], t), lambda t: F.capsules(F.lerp_samples(idle[2], t)),
                wind_fn("idle", CAPE_ROWS, CAPE_COLS), idle_period)
    capes = cape.run(at(cape_s), lambda t: F.capsules(at(cap_s)(t)), wind_fn(anim, CAPE_ROWS, CAPE_COLS), period,
                     frames, cycles=cycles, warm=warm)

    halves = []
    for h in (0, 1):
        rb = F.Cloth(RIB_ROWS, 2, 0.24, 0.02, 0.034, drag=2.6, damping=0.99, iterations=6, bend=0.2,
                     thickness=0.01)
        own = [r[2 * h:2 * h + 2] for r in rib_s]
        warm = None
        if idle:
            idle_own = [r[2 * h:2 * h + 2] for r in idle[1]]
            warm = (lambda t, s=idle_own: F.lerp_samples(s, t), lambda t: [], wind_fn("idle", RIB_ROWS, 2), idle_period)
        halves.append(rb.run(at(own), lambda t: [], wind_fn(anim, RIB_ROWS, 2), period, frames, cycles=cycles,
                             warm=warm))
    ribbons = [np.concatenate([a.reshape((-1, 3)), b.reshape((-1, 3))]) for a, b in zip(*halves)]
    return capes, ribbons


# ---------------------------------------------------------------- animation

def smooth_keys(keys, t):
    """Piecewise smooth interpolation of a list of values over t in [0, 1]."""
    x = min(max(t, 0.0), 1.0) * (len(keys) - 1)
    i = min(int(x), len(keys) - 2)
    f = x - i
    f = f * f * (3 - 2 * f)
    return keys[i] + (keys[i + 1] - keys[i]) * f


def pose(R, anim, t):
    R.reset()
    ph = 2 * math.pi * t
    s = math.sin(ph)
    spear_dir = (0.08, -0.12, 1.0)

    if anim == "idle":
        R.move("hips", (0.01 * math.sin(ph), 0, -0.014 + 0.006 * math.cos(2 * ph)))
        R.rot("hips", 0.0, 0.06, 0.0)
        R.rot("spine", 0.02 + 0.012 * s, -0.04, 0.0)
        R.rot("chest", -0.03 - 0.025 * s, -0.03, 0.0)
        R.rot("neck", 0.03, 0.03 * math.sin(ph), 0.0)
        R.rot("head", 0.02 + 0.01 * s, 0.07 * math.sin(ph + 0.4), 0.0)
        R.rot("thigh.L", -0.1, 0.0, 0.1)
        R.rot("shin.L", 0.14)
        R.rot("foot.L", -0.04)
        R.rot("thigh.R", 0.08, 0.0, -0.09)
        R.rot("shin.R", 0.12)
        R.rot("foot.R", -0.08)
        R.rot("clavicle.L", 0.03 * s)
        R.rot("clavicle.R", 0.03 * s)
        R.rot("upperarm.L", 0.06 + 0.025 * s, 0.0, 0.17)
        R.rot("forearm.L", -0.38 - 0.05 * s)
        R.rot("hand.L", -0.1)
        R.rot("upperarm.R", -0.32, 0.0, -0.2)
        R.rot("forearm.R", -1.0 - 0.02 * s)
        spear_dir = (0.08, -0.1, 1.0)

    elif anim == "walk":
        lean = 0.24
        R.move("hips", (0.0, 0.0, -0.05 + 0.04 * math.cos(2 * ph)))
        R.rot("hips", 0.05, 0.17 * s, 0.0)
        R.rot("spine", lean * 0.65, -0.12 * s, 0.0)
        R.rot("chest", lean * 0.35, -0.17 * s, 0.0)
        R.rot("neck", -0.14, 0.1 * s, 0.0)
        R.rot("head", -0.18, 0.08 * s, 0.0)
        for side, k, sz in (("L", 0.0, 1), ("R", math.pi, -1)):
            p = ph + k
            swing = -0.8 * math.sin(p) + 0.08
            knee = 0.28 + 1.4 * max(0.0, math.cos(p - 0.3)) ** 1.4
            R.rot("thigh." + side, swing - 0.05, 0.0, 0.03 * sz)
            R.rot("shin." + side, knee)
            R.rot("foot." + side, 0.1 + 0.45 * max(0.0, math.cos(p - 0.8)))
        R.rot("upperarm.L", 0.72 * s - 0.05, 0.0, 0.16)
        R.rot("forearm.L", -(1.15 - 0.45 * s))
        R.rot("hand.L", -0.2)
        R.rot("clavicle.L", 0.05 * math.cos(ph))
        R.rot("upperarm.R", -0.15 - 0.22 * s, 0.0, -0.16)
        R.rot("forearm.R", -1.25 + 0.1 * s)
        spear_dir = (0.04, -1.0, 0.5)

    elif anim == "attack":
        coil = smooth_keys([0.0, 0.8, 1.0, 0.25, 0.0, 0.0, 0.0, 0.0, 0.0], t)
        strike = smooth_keys([0.0, 0.0, 0.0, 0.85, 1.0, 0.95, 0.6, 0.3, 0.05], t)
        R.move("hips", (0.0, -0.07 * strike, -0.02 - 0.06 * strike - 0.02 * coil))
        R.rot("hips", 0.04 * strike, 0.22 * coil - 0.25 * strike, 0.0)
        R.rot("spine", 0.06 + 0.16 * strike - 0.04 * coil, 0.18 * coil - 0.2 * strike, 0.0)
        R.rot("chest", 0.02 + 0.06 * strike, 0.3 * coil - 0.32 * strike, 0.0)
        R.rot("neck", -0.04 * strike, -0.2 * coil + 0.2 * strike, 0.0)
        R.rot("head", -0.06 * strike, -0.25 * coil + 0.3 * strike, 0.0)
        R.rot("thigh.L", -0.12 - 0.55 * strike, 0.0, 0.1)
        R.rot("shin.L", 0.14 + 0.55 * strike)
        R.rot("foot.L", -0.05 - 0.3 * strike)
        R.rot("thigh.R", 0.08 + 0.45 * strike + 0.08 * coil, 0.0, -0.09)
        R.rot("shin.R", 0.12 + 0.35 * strike)
        R.rot("foot.R", 0.2 * strike)
        R.rot("upperarm.L", -0.9 * coil + 0.6 * strike, 0.0, 0.17 + 0.25 * strike)
        R.rot("forearm.L", -0.4 - 0.4 * coil)
        R.rot("upperarm.R", 0.55 * coil - 1.45 * strike, 0.0, -0.2 - 0.1 * coil)
        R.rot("forearm.R", -1.0 - 0.7 * coil + 0.85 * strike)
        spear_dir = (0.0, -1.0, 0.25 - 0.18 * strike + 0.1 * coil)

    elif anim == "dash":
        R.move("hips", (0.0, 0.0, -0.09))
        R.rot("hips", 0.18, 0.05 * s, 0.0)
        R.rot("spine", 0.36, -0.05 * s, 0.0)
        R.rot("chest", 0.16)
        R.rot("neck", -0.24)
        R.rot("head", -0.32)
        R.rot("thigh.L", -0.95 + 0.06 * s, 0.0, 0.05)
        R.rot("shin.L", 1.0)
        R.rot("foot.L", 0.3)
        R.rot("thigh.R", 0.75 - 0.06 * s, 0.0, -0.05)
        R.rot("shin.R", 0.7)
        R.rot("foot.R", 0.5)
        R.rot("upperarm.L", 1.1 + 0.05 * s, 0.0, 0.32)
        R.rot("forearm.L", -0.3)
        R.rot("upperarm.R", -0.5, 0.0, -0.2)
        R.rot("forearm.R", -0.95)
        spear_dir = (0.0, -1.0, 0.1)

    R.update()
    grip = R.matrix("hand.R") @ Vector((0.0, arm_len("hand.R") * 0.45, 0.0))
    R.aim("spear", grip, spear_dir)
    R.update()


_LEN = {}


def arm_len(name):
    return _LEN[name]


# ---------------------------------------------------------------- render

def setup_render(size, ortho):
    kit.SIZE = size
    kit.ORTHO = ortho
    kit.TARGET_Z = TARGET_Z
    kit.CAM_PITCH = CAM_PITCH
    scene = bpy.context.scene
    scene.render.resolution_x = size
    scene.render.resolution_y = size
    cam = bpy.context.scene.camera
    cam.data.ortho_scale = ortho


def add_lights():
    def sun(name, energy, rot):
        ob = bpy.data.objects.new(name, bpy.data.lights.new(name, "SUN"))
        ob.data.energy = energy
        ob.data.angle = math.radians(3)
        ob.rotation_euler = tuple(math.radians(a) for a in rot)
        bpy.context.scene.collection.objects.link(ob)
        return ob
    sun("Key", 3.2, (48, -22, -38))
    sun("Fill", 0.35, (70, 10, 120))
    sun("Rim", 1.6, (-55, 15, 170))
    bg = bpy.context.scene.world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs["Color"].default_value = (0.3, 0.26, 0.4, 1.0)
        bg.inputs["Strength"].default_value = 0.15


def apply_cloth(cape_co, rib_co):
    F.set_verts(OBJ["cape"], cape_co.reshape((-1, 3)))
    F.set_verts(OBJ["ribbon"], rib_co)


def figure_px(arm, px_per_m):
    deps = bpy.context.evaluated_depsgraph_get()
    top = 0.0
    for ob in bpy.context.scene.objects:
        if ob.type != "MESH" or not (ob.name.startswith("Head") or ob.name.startswith("HairCap") or ob.name.startswith("Body")):
            continue
        ev = ob.evaluated_get(deps)
        mw = ev.matrix_world
        for v in ev.data.vertices:
            w = mw @ v.co
            top = max(top, w.z * math.cos(CAM_PITCH) + w.y * math.sin(CAM_PITCH))
    return top * px_per_m


def main():
    os.makedirs(OUT, exist_ok=True)
    tmp = os.path.join(OUT, "_frames")
    os.makedirs(tmp, exist_ok=True)
    kit.SIZE = SIZE
    kit.ORTHO = ORTHO
    kit.TARGET_Z = TARGET_Z
    kit.OUT = OUT
    kit.reset_scene()
    scene = bpy.context.scene
    scene.eevee.taa_render_samples = 32
    add_lights()
    kit.add_camera()
    materials()
    arm = F.build_armature("Rig", bones())
    for b in arm.data.bones:
        _LEN[b.name] = b.length
    build_body(arm)
    build_head(arm)
    build_armour(arm)
    build_spear(arm)
    build_cloth_objects(arm)
    R = F.Pose(arm)

    sims = {}
    for anim in ANIMS:
        sims[anim] = simulate_cloth(arm, anim)
        print("cloth", anim)

    if PREVIEW:
        setup_render(384, 2.4)
        shots = (("idle", 0, 0), ("idle", 3, 4), ("walk", 2, 2), ("walk", 4, 7), ("walk", 8, 4), ("attack", 2, 3),
                 ("attack", 6, 4), ("dash", 4, 2), ("dash", 12, 1), ("idle", 8, 6), ("walk", 12, 0), ("idle", 14, 2))
        for anim, d, f in shots:
            arm.rotation_euler = (0, 0, math.radians(360.0 / DIRECTIONS * d))
            t = f / ANIMS[anim] if anim != "attack" else f / (ANIMS[anim] - 1)
            pose(R, anim, t)
            apply_cloth(sims[anim][0][f], sims[anim][1][f])
            bpy.context.view_layer.update()
            kit.render_frame(os.path.join(OUT, "preview_%s_%d_%d.png" % (anim, d, f)))
        return

    setup_render(SIZE, ORTHO)
    kit.DIRECTIONS = DIRECTIONS
    kit.SIZE = SIZE
    for anim, frames in ANIMS.items():
        for d in range(DIRECTIONS):
            arm.rotation_euler = (0, 0, math.radians(360.0 / DIRECTIONS * d))
            for f in range(frames):
                t = f / frames if anim != "attack" else f / (frames - 1)
                pose(R, anim, t)
                apply_cloth(sims[anim][0][f], sims[anim][1][f])
                bpy.context.view_layer.update()
                kit.render_frame(os.path.join(tmp, "%s_%d_%d.png" % (anim, d, f)))
        kit.pack(anim, frames, tmp)
        print("packed", anim)

    show = SHOWCASE
    setup_render(show["size"], show["ortho"])
    kit.DIRECTIONS = show["directions"]
    kit.SIZE = show["size"]
    for d in range(show["directions"]):
        arm.rotation_euler = (0, 0, math.radians(360.0 / show["directions"] * d))
        for f in range(ANIMS["idle"]):
            pose(R, "idle", f / ANIMS["idle"])
            apply_cloth(sims["idle"][0][f], sims["idle"][1][f])
            bpy.context.view_layer.update()
            kit.render_frame(os.path.join(tmp, "showcase_%d_%d.png" % (d, f)))
    kit.pack("showcase", ANIMS["idle"], tmp)

    arm.rotation_euler = (0, 0, 0)
    pose(R, "idle", 0.0)
    bpy.context.view_layer.update()
    px_per_m = SIZE / ORTHO
    show_px = show["size"] / show["ortho"]
    meta = {
        "frame_size": SIZE,
        "directions": DIRECTIONS,
        "frames": ANIMS,
        "fps": FPS,
        "feet_y": round(SIZE / 2 + TARGET_Z * math.cos(CAM_PITCH) * px_per_m, 1),
        "figure_px": round(figure_px(arm, px_per_m), 1),
        "px_per_meter": round(px_per_m, 2),
        "showcase": {
            "frame_size": show["size"],
            "directions": show["directions"],
            "frames": ANIMS["idle"],
            "fps": FPS["idle"],
            "feet_y": round(show["size"] / 2 + TARGET_Z * math.cos(CAM_PITCH) * show_px, 1),
            "figure_px": round(figure_px(arm, show_px), 1),
        },
    }
    with open(os.path.join(OUT, "hero.json"), "w") as fh:
        json.dump(meta, fh, indent=2)
    for name in os.listdir(tmp):
        os.remove(os.path.join(tmp, name))
    os.rmdir(tmp)
    print("done", meta)


if __name__ == "__main__":
    main()
