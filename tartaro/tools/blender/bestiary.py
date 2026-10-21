"""Enemies and bosses of Tártaro as 3D models -> 8-direction sprite sheets.

Run (headless), from the project root:
    blender -b -P tools/blender/bestiary.py -- all art
    blender -b -P tools/blender/bestiary.py -- brute art          # one character
    BESTIARY_PREVIEW=1 blender -b -P tools/blender/bestiary.py -- all <dir>   # one test frame each

Each character gets art/<id>/move.png, attack.png and meta.json.
Reuses the scene/material/geometry helpers from hero.py.
"""

import bpy
import json
import math
import os
import sys

import bmesh
import numpy as np
from mathutils import Vector

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import hero as H

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
WHICH = ARGS[0] if ARGS else "all"
ROOT_OUT = os.path.abspath(ARGS[1] if len(ARGS) > 1 else "art")
PREVIEW = os.environ.get("BESTIARY_PREVIEW") == "1"
ANIMS = {"move": 8, "attack": 6}
P = H.P


def rot(name, x=0.0, y=0.0, z=0.0):
    P[name].rotation_euler = (x, y, z)


def reset_pose():
    for k, o in P.items():
        if o.type == "EMPTY" and k != "root":
            o.rotation_euler = (0, 0, 0)
            o.scale = (1, 1, 1)
    for k, loc in BASE_LOC.items():
        P[k].location = loc


BASE_LOC = {}


def remember_locations():
    BASE_LOC.clear()
    for k, o in P.items():
        if o.type == "EMPTY":
            BASE_LOC[k] = tuple(o.location)


def wavy_hem(obj, amount, waves):
    """Tatter the bottom rim of a cone (robes, cloth)."""
    zmin = min(v.co.z for v in obj.data.vertices)
    for v in obj.data.vertices:
        if v.co.z < zmin + 0.02:
            a = math.atan2(v.co.y, v.co.x)
            v.co.z += amount * (0.5 + 0.5 * math.sin(a * waves))


def half_torus(name, parent, loc, major, minor, mat, rot_e=(0, 0, 0)):
    obj = H.torus(name, parent, loc, major, minor, mat, outline=True)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.x < -0.01], context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()
    obj.rotation_euler = rot_e
    return obj


def glow(name, color, strength):
    return H.material(name, color, rough=0.4, emission=color, strength=strength)


def build_shade():
    robe = H.material("Robe", (0.09, 0.035, 0.14), rough=0.9)
    hood = H.material("Hood", (0.13, 0.05, 0.2), rough=0.85)
    void = H.material("Void", (0.01, 0.0, 0.02), rough=1.0)
    claw = H.material("Claw", (0.35, 0.3, 0.42), rough=0.6)
    eye = glow("EyeRed", (1.0, 0.12, 0.08), 12.0)
    root = H.pivot("root", None, (0, 0, 0))
    body = H.pivot("body", root, (0, 0, 0.3))
    r = H.cone("robe", body, (0, 0, 1.0), 0.42, 0.18, 1.0, robe, verts=20)
    wavy_hem(r, 0.18, 7)
    H.sphere("hood", body, (0, 0.02, 1.08), (0.25, 0.27, 0.29), hood)
    H.sphere("void", body, (0, -0.12, 1.05), (0.16, 0.08, 0.18), void, outline=False)
    for x in (-0.055, 0.055):
        H.sphere("eye%.2f" % x, body, (x, -0.19, 1.08), (0.03, 0.02, 0.022), eye, outline=False, subsurf=0)
    for side, sx in (("L", -1), ("R", 1)):
        sh = H.pivot("shoulder." + side, body, (sx * 0.24, 0, 0.85))
        H.limb("arm." + side, sh, (0, 0, 0), 0.42, 0.08, 0.055, robe)
        el = H.pivot("elbow." + side, sh, (0, 0, -0.42))
        H.limb("fore." + side, el, (0, 0, 0), 0.36, 0.04, 0.025, claw)
        H.cone("claw." + side, el, (0, 0, -0.34), 0.0, 0.07, 0.2, claw, verts=6, subsurf=0)
    return root


def pose_shade(anim, f, n):
    ph = 2 * math.pi * f / n
    P["body"].location = (0, 0, 0.3 + 0.06 * math.sin(ph))
    if anim == "move":
        rot("body", 0.12 + 0.04 * math.sin(ph * 2), 0, 0)
        rot("shoulder.L", 0.6 + 0.15 * math.sin(ph), -0.2, 0)
        rot("shoulder.R", 0.6 - 0.15 * math.sin(ph), 0.2, 0)
        rot("elbow.L", 0.4)
        rot("elbow.R", 0.4)
    else:
        k = [0.2, 0.6, 1.0, 1.0, 0.7, 0.3][f]
        rot("body", 0.3 * k, 0, 0)
        rot("shoulder.L", -1.4 * k, -0.3 * k, 0)
        rot("shoulder.R", -1.4 * k, 0.3 * k, 0)
        rot("elbow.L", -0.3 * k)
        rot("elbow.R", -0.3 * k)


def build_brute():
    skin = H.material("BruteSkin", (0.3, 0.055, 0.04), rough=0.7)
    dark = H.material("BruteDark", (0.2, 0.05, 0.04), rough=0.8)
    horn = H.material("Horn", (0.92, 0.86, 0.72), rough=0.45)
    leather = H.material("Loin", (0.28, 0.16, 0.08), rough=0.8)
    ring = H.material("Ring", (1.0, 0.75, 0.25), metallic=0.9, rough=0.25)
    eye = glow("EyeGold", (1.0, 0.85, 0.2), 10.0)
    root = H.pivot("root", None, (0, 0, 0))
    hips = H.pivot("hips", root, (0, 0, 0.78))
    for side, sx in (("L", -1), ("R", 1)):
        hp = H.pivot("hip." + side, hips, (sx * 0.2, 0, 0))
        H.limb("thigh." + side, hp, (0, 0, 0), 0.38, 0.15, 0.12, skin)
        kn = H.pivot("knee." + side, hp, (0, 0, -0.38))
        H.limb("shin." + side, kn, (0, 0, 0), 0.36, 0.12, 0.09, skin)
        H.cone("hoof." + side, kn, (0, -0.02, -0.34), 0.1, 0.12, 0.08, dark, verts=10, subsurf=0)
    H.cone("loin", hips, (0, 0, 0.1), 0.34, 0.3, 0.32, leather, verts=12)
    torso = H.pivot("torso", hips, (0, 0, 0.0))
    H.sphere("belly", torso, (0, -0.02, 0.32), (0.38, 0.3, 0.32), skin)
    H.sphere("chest", torso, (0, 0.02, 0.68), (0.52, 0.36, 0.34), skin)
    head = H.pivot("head", torso, (0, -0.12, 1.0))
    H.sphere("skull", head, (0, 0, 0), (0.2, 0.22, 0.19), skin)
    H.sphere("snout", head, (0, -0.18, -0.06), (0.13, 0.1, 0.09), dark)
    H.torus("nosering", head, (0, -0.26, -0.11), 0.045, 0.012, ring, outline=False)
    for x in (-0.08, 0.08):
        H.sphere("eye%.2f" % x, head, (x, -0.17, 0.05), (0.035, 0.02, 0.025), eye, outline=False, subsurf=0)
    for side, sx in (("L", -1), ("R", 1)):
        base = H.pivot("horn." + side, head, (sx * 0.16, 0, 0.1))
        H.cone("hornA." + side, base, (0, 0, 0), 0.05, 0.08, 0.24, horn, rot=(0, sx * -2.09, 0), verts=10, subsurf=0)
        tip = H.pivot("horntip." + side, base, (sx * 0.2, 0, 0.12))
        H.cone("hornB." + side, tip, (0, 0, 0), 0.0, 0.052, 0.24, horn, rot=(0, sx * -2.83, 0), verts=10, subsurf=0)
        sh = H.pivot("shoulder." + side, torso, (sx * 0.55, 0, 0.82))
        H.sphere("delt." + side, sh, (0, 0, 0), (0.18, 0.18, 0.16), skin)
        H.limb("upper." + side, sh, (0, 0, -0.05), 0.42, 0.15, 0.13, skin)
        el = H.pivot("elbow." + side, sh, (0, 0, -0.45))
        H.limb("fore." + side, el, (0, 0, 0), 0.4, 0.14, 0.12, skin)
        H.sphere("fist." + side, el, (0, 0, -0.44), (0.15, 0.14, 0.15), dark)
    return root


def pose_brute(anim, f, n):
    ph = 2 * math.pi * f / n
    s = math.sin(ph)
    if anim == "move":
        P["hips"].location = (0, 0, 0.78 + 0.04 * abs(math.cos(ph)))
        rot("hip.L", -0.45 * s)
        rot("hip.R", 0.45 * s)
        rot("knee.L", max(0.0, math.sin(ph + 1.3)) * 0.7)
        rot("knee.R", max(0.0, math.sin(ph + 1.3 + math.pi)) * 0.7)
        rot("torso", 0.12, 0, 0.12 * s)
        rot("shoulder.L", 0.35 * s, -0.25, 0)
        rot("shoulder.R", -0.35 * s, 0.25, 0)
        rot("elbow.L", -0.4)
        rot("elbow.R", -0.4)
    else:
        rot("torso", 0.65, 0, 0)
        rot("head", 0.45, 0, 0)
        rot("hip.L", -0.8 + 0.3 * math.sin(ph))
        rot("hip.R", 0.6 - 0.3 * math.sin(ph))
        rot("knee.R", 0.8)
        rot("shoulder.L", 0.9, -0.5, 0)
        rot("shoulder.R", 0.9, 0.5, 0)
        rot("elbow.L", -0.6)
        rot("elbow.R", -0.6)
        P["hips"].location = (0, 0, 0.7)


def build_wisp():
    bone = H.material("SkullBone", (0.72, 0.7, 0.62), rough=0.5)
    void = H.material("Socket", (0.02, 0.02, 0.04), rough=1.0)
    flame = glow("Flame", (0.15, 0.75, 1.0), 2.4)
    core = glow("FlameCore", (0.6, 1.0, 1.0), 4.0)
    root = H.pivot("root", None, (0, 0, 0))
    body = H.pivot("body", root, (0, 0, 0.55))
    H.sphere("skull", body, (0, 0, 0), (0.17, 0.19, 0.17), bone)
    H.sphere("brow", body, (0, -0.06, 0.02), (0.15, 0.13, 0.1), bone)
    for x in (-0.06, 0.06):
        H.sphere("sock%.2f" % x, body, (x, -0.15, 0.0), (0.045, 0.03, 0.045), void, outline=False, subsurf=0)
        H.sphere("glint%.2f" % x, body, (x, -0.175, 0.0), (0.018, 0.01, 0.018), core, outline=False, subsurf=0)
    jaw = H.pivot("jaw", body, (0, -0.05, -0.1))
    H.sphere("jawbone", jaw, (0, -0.06, -0.04), (0.12, 0.1, 0.05), bone)
    for i in range(6):
        fl = H.pivot("flame%d" % i, body, (math.cos(i * 1.05) * 0.08, 0.05 + math.sin(i * 1.05) * 0.06, 0.12))
        H.cone("fcone%d" % i, fl, (0, 0, 0), 0.0, 0.07, 0.35, flame, rot=(math.pi, 0, 0), verts=8, subsurf=0, outline=False)
    return root


def pose_wisp(anim, f, n):
    ph = 2 * math.pi * f / n
    P["body"].location = (0, 0, 0.55 + 0.05 * math.sin(ph))
    for i in range(6):
        k = 0.8 + 0.35 * math.sin(ph * 2 + i * 1.7)
        P["flame%d" % i].scale = (1, 1, k)
        rot("flame%d" % i, 0.5 + 0.15 * math.sin(ph + i), 0.2 * math.sin(i * 2.0), 0)
    if anim == "attack":
        rot("jaw", 0.25 + 0.25 * math.sin(ph * 2))
        rot("body", 0.25)


def build_archer():
    bone = H.material("Bone", (0.8, 0.76, 0.64), rough=0.55)
    rag = H.material("Rag", (0.25, 0.22, 0.18), rough=0.95)
    wood = H.material("BowWood", (0.4, 0.26, 0.13), rough=0.6)
    eye = glow("EyeGreen", (0.5, 1.0, 0.35), 10.0)
    root = H.pivot("root", None, (0, 0, 0))
    hips = H.pivot("hips", root, (0, 0, 0.88))
    H.torus("pelvis", hips, (0, 0, 0), 0.12, 0.035, bone)
    rg = H.cone("loincloth", hips, (0, 0, 0.02), 0.2, 0.14, 0.3, rag, verts=12)
    wavy_hem(rg, 0.1, 6)
    torso = H.pivot("torso", hips, (0, 0, 0.0))
    H.limb("spine", torso, (0, 0.03, 0.55), 0.55, 0.025, 0.025, bone, subsurf=0)
    for i in range(4):
        H.torus("rib%d" % i, torso, (0, 0, 0.5 - i * 0.075), 0.15 - i * 0.012, 0.016, bone, outline=False)
    neck = H.pivot("neck", torso, (0, 0, 0.62))
    H.sphere("skull", neck, (0, 0, 0.13), (0.11, 0.13, 0.13), bone)
    H.sphere("jaw", neck, (0, -0.05, 0.04), (0.08, 0.07, 0.04), bone)
    for x in (-0.042, 0.042):
        H.sphere("eye%.2f" % x, neck, (x, -0.11, 0.14), (0.02, 0.012, 0.018), eye, outline=False, subsurf=0)
    for side, sx in (("L", -1), ("R", 1)):
        sh = H.pivot("shoulder." + side, torso, (sx * 0.18, 0, 0.52))
        H.limb("humerus." + side, sh, (0, 0, 0), 0.28, 0.032, 0.028, bone, subsurf=0)
        el = H.pivot("elbow." + side, sh, (0, 0, -0.28))
        H.sphere("ejoint." + side, el, (0, 0, 0), (0.03, 0.03, 0.03), bone, subsurf=0)
        H.limb("radius." + side, el, (0, 0, 0), 0.26, 0.028, 0.024, bone, subsurf=0)
        hp = H.pivot("hip." + side, hips, (sx * 0.09, 0, -0.03))
        H.limb("femur." + side, hp, (0, 0, 0), 0.42, 0.038, 0.032, bone, subsurf=0)
        kn = H.pivot("knee." + side, hp, (0, 0, -0.42))
        H.sphere("kjoint." + side, kn, (0, 0, 0), (0.035, 0.035, 0.035), bone, subsurf=0)
        H.limb("tibia." + side, kn, (0, 0, 0), 0.42, 0.032, 0.026, bone, subsurf=0)
    bow = H.pivot("bow", P["elbow.L"], (0, 0, -0.27))
    half_torus("bowarc", bow, (0, 0, 0), 0.32, 0.022, wood, rot_e=(0, math.pi / 2, 0))
    return root


def pose_archer(anim, f, n):
    ph = 2 * math.pi * f / n
    s = math.sin(ph)
    if anim == "move":
        P["hips"].location = (0, 0, 0.88 + 0.025 * abs(math.cos(ph)))
        rot("hip.L", -0.5 * s)
        rot("hip.R", 0.5 * s)
        rot("knee.L", max(0.0, math.sin(ph + 1.4)) * 0.8)
        rot("knee.R", max(0.0, math.sin(ph + 1.4 + math.pi)) * 0.8)
        rot("shoulder.L", 0.3 * s - 0.2, -0.15, 0)
        rot("shoulder.R", -0.3 * s, 0.15, 0)
        rot("elbow.L", -0.6)
        rot("bow", 0, 0, 0)
    else:
        draw = [0.2, 0.5, 0.8, 1.0, 1.0, 0.3][f]
        rot("torso", 0, 0, -0.5)
        rot("shoulder.L", -1.55, -0.1, 0)
        rot("elbow.L", 0.0)
        rot("shoulder.R", -1.45, 0.1, 0)
        rot("elbow.R", -1.2 - 1.2 * draw)
        rot("hip.L", -0.3)
        rot("hip.R", 0.3)


def build_bomber():
    skin = H.material("ImpSkin", (0.42, 0.16, 0.07), rough=0.55)
    dark = H.material("ImpDark", (0.15, 0.05, 0.04), rough=0.9)
    crack = glow("Crack", (1.0, 0.4, 0.08), 3.0)
    spark = glow("Spark", (1.0, 0.8, 0.3), 5.0)
    eye = glow("ImpEye", (1.0, 0.9, 0.3), 9.0)
    root = H.pivot("root", None, (0, 0, 0))
    body = H.pivot("body", root, (0, 0, 0.48))
    H.sphere("belly", body, (0, 0, 0), (0.38, 0.35, 0.36), skin)
    for i, (rx, ry) in enumerate(((0.4, 0.2), (-0.3, 0.9), (1.1, -0.4))):
        t = H.torus("crack%d" % i, body, (0, 0, 0), 0.33, 0.012, crack, outline=False)
        t.rotation_euler = (rx, ry, i * 0.8)
    head = H.pivot("head", body, (0, -0.05, 0.42))
    H.sphere("headball", head, (0, 0, 0), (0.17, 0.16, 0.15), skin)
    H.sphere("grin", head, (0, -0.13, -0.04), (0.1, 0.04, 0.035), dark, outline=False)
    for x in (-0.06, 0.06):
        H.sphere("eye%.2f" % x, head, (x, -0.13, 0.04), (0.03, 0.02, 0.03), eye, outline=False, subsurf=0)
    fuse = H.pivot("fuse", head, (0.02, 0.02, 0.14))
    H.limb("fusecord", fuse, (0, 0, 0.16), 0.16, 0.015, 0.015, dark, subsurf=0)
    H.sphere("sparkball", fuse, (0, 0, 0.17), (0.035, 0.035, 0.035), spark, outline=False, subsurf=0)
    for side, sx in (("L", -1), ("R", 1)):
        hp = H.pivot("hip." + side, body, (sx * 0.15, 0, -0.28))
        H.limb("leg." + side, hp, (0, 0, 0), 0.22, 0.06, 0.05, skin)
        H.sphere("foot." + side, hp, (0, -0.04, -0.22), (0.07, 0.09, 0.04), dark)
        sh = H.pivot("shoulder." + side, body, (sx * 0.34, 0, 0.1))
        H.limb("arm." + side, sh, (0, 0, 0), 0.22, 0.05, 0.04, skin)
    return root


def pose_bomber(anim, f, n):
    ph = 2 * math.pi * f / n
    s = math.sin(ph)
    if anim == "move":
        P["body"].location = (0, 0, 0.48 + 0.04 * abs(math.cos(ph)))
        rot("body", 0.1, 0.18 * s, 0)
        rot("hip.L", -0.6 * s)
        rot("hip.R", 0.6 * s)
        rot("shoulder.L", 0.5 * s, -0.6, 0)
        rot("shoulder.R", -0.5 * s, 0.6, 0)
        H.bpy.data.materials["Crack"].node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = 3.0
    else:
        k = (f + 1) / n
        sc = 1.0 + 0.22 * k + 0.05 * math.sin(f * 3.0)
        P["body"].scale = (sc, sc, sc)
        rot("shoulder.L", 0, -1.2, 0)
        rot("shoulder.R", 0, 1.2, 0)
        H.bpy.data.materials["Crack"].node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = 3.0 + 9.0 * k


def build_cerbero():
    fur = H.material("Fur", (0.16, 0.045, 0.035), rough=0.85)
    dark = H.material("FurDark", (0.12, 0.03, 0.03), rough=0.9)
    fang = H.material("Fang", (0.95, 0.9, 0.8), rough=0.4)
    eye = glow("HellEye", (1.0, 0.55, 0.1), 12.0)
    maw = glow("Maw", (1.0, 0.35, 0.05), 5.0)
    collar = H.material("Collar", (0.85, 0.6, 0.2), metallic=0.9, rough=0.3)
    root = H.pivot("root", None, (0, 0, 0))
    body = H.pivot("body", root, (0, 0.15, 1.0))
    H.sphere("torso", body, (0, 0, 0), (0.55, 0.95, 0.5), fur)
    H.sphere("chest", body, (0, -0.6, 0.1), (0.55, 0.45, 0.55), fur)
    for i in range(9):
        a = (i - 4) * 0.28
        H.cone("spike%d" % i, body, (math.sin(a) * 0.12, -0.5 + i * 0.12, 0.44), 0.0, 0.07, 0.2, dark,
               rot=(math.pi + 0.4, a * 0.6, 0), verts=6, subsurf=0)
    for name, x, y in (("FL", -0.32, -0.6), ("FR", 0.32, -0.6), ("BL", -0.32, 0.6), ("BR", 0.32, 0.6)):
        lg = H.pivot("leg." + name, body, (x, y, -0.15))
        H.limb("thigh." + name, lg, (0, 0, 0), 0.5, 0.24, 0.15, fur)
        kn = H.pivot("knee." + name, lg, (0, 0, -0.5))
        H.limb("shin." + name, kn, (0, 0, 0), 0.4, 0.14, 0.1, fur)
        H.sphere("paw." + name, kn, (0, -0.06, -0.42), (0.12, 0.15, 0.07), dark)
    tail = H.pivot("tail", body, (0, 0.95, 0.15))
    H.cone("tailcone", tail, (0, 0, 0), 0.09, 0.0, 0.7, fur, rot=(-2.2, 0, 0), verts=10)
    for i, x in enumerate((-0.45, 0.0, 0.45)):
        nk = H.pivot("neck%d" % i, body, (x, -0.85, 0.3))
        H.limb("neckmesh%d" % i, nk, (0, 0, 0.42), 0.48, 0.17, 0.21, fur)
        H.torus("collar%d" % i, nk, (0, 0, 0.05), 0.15, 0.03, collar, outline=False)
        hd = H.pivot("head%d" % i, nk, (0, -0.08, 0.52))
        H.sphere("skull%d" % i, hd, (0, 0, 0), (0.33, 0.37, 0.3), fur)
        H.sphere("snout%d" % i, hd, (0, -0.36, -0.08), (0.17, 0.26, 0.14), dark)
        for sx in (-1, 1):
            H.cone("ear%d%d" % (i, sx), hd, (sx * 0.15, 0.05, 0.16), 0.0, 0.08, 0.2, dark, rot=(math.pi + 0.3, sx * 0.4, 0), verts=6, subsurf=0)
            H.sphere("eye%d%d" % (i, sx), hd, (sx * 0.1, -0.2, 0.07), (0.04, 0.025, 0.03), eye, outline=False, subsurf=0)
        jaw = H.pivot("jaw%d" % i, hd, (0, -0.12, -0.12))
        H.sphere("jawmesh%d" % i, jaw, (0, -0.15, -0.02), (0.11, 0.17, 0.05), dark)
        H.sphere("mawglow%d" % i, jaw, (0, -0.16, 0.03), (0.08, 0.13, 0.02), maw, outline=False, subsurf=0)
        for fx in (-0.06, 0.06):
            H.cone("fang%d%.2f" % (i, fx), hd, (fx, -0.4, -0.1), 0.025, 0.0, 0.08, fang, verts=6, subsurf=0, outline=False)
    return root


def pose_cerbero(anim, f, n):
    ph = 2 * math.pi * f / n
    s = math.sin(ph)
    if anim == "move":
        P["body"].location = (0, 0.15, 1.0 + 0.05 * abs(math.cos(ph)))
        rot("leg.FL", -0.5 * s)
        rot("leg.BR", -0.5 * s)
        rot("leg.FR", 0.5 * s)
        rot("leg.BL", 0.5 * s)
        for k in ("FL", "FR", "BL", "BR"):
            rot("knee." + k, max(0.0, s if k in ("FR", "BL") else -s) * 0.6)
        for i in range(3):
            rot("neck%d" % i, -0.5 + 0.1 * math.sin(ph + i), (i - 1) * 0.25, 0)
            rot("jaw%d" % i, 0.1)
        rot("tail", 0, 0, 0.4 * s)
    else:
        k = [0.2, 0.6, 1.0, 1.0, 0.7, 0.3][f]
        rot("body", -0.25 * k, 0, 0)
        for i in range(3):
            rot("neck%d" % i, -0.5 - 0.5 * k, (i - 1) * 0.35, 0)
            rot("head%d" % i, 0.4 * k, 0, 0)
            rot("jaw%d" % i, 0.7 * k)
        rot("leg.FL", -0.6 * k)
        rot("leg.FR", -0.6 * k)


TAIL = 26


def build_medusa():
    scale_m = H.material("Scales", (0.18, 0.45, 0.28), metallic=0.25, rough=0.35)
    belly = H.material("Belly", (0.75, 0.72, 0.45), rough=0.5)
    skin = H.material("GorgonSkin", (0.6, 0.75, 0.55), rough=0.5)
    robe = H.material("GorgonRobe", (0.38, 0.12, 0.42), rough=0.8)
    gold = H.material("GorgonGold", (1.0, 0.75, 0.25), metallic=0.9, rough=0.25)
    snake = H.material("Snake", (0.25, 0.55, 0.3), rough=0.45)
    eye = glow("GazeEye", (1.0, 0.95, 0.3), 14.0)
    root = H.pivot("root", None, (0, 0, 0))
    for i in range(TAIL):
        t = i / (TAIL - 1.0)
        seg = H.pivot("tail%d" % i, root, (0, 0, 0))
        r = 0.34 * (1 - 0.72 * t)
        H.sphere("tailseg%d" % i, seg, (0, 0, 0), (r, r * 1.15, r * 0.85), scale_m, subsurf=0)
        H.sphere("tailbelly%d" % i, seg, (0, -r * 0.55, -r * 0.2), (r * 0.6, r * 0.5, r * 0.55), belly, outline=False, subsurf=0)
    waist = H.pivot("waist", root, (0, 0, 0.9))
    H.cone("skirt", waist, (0, 0, 0.35), 0.36, 0.22, 0.4, robe, verts=16)
    torso = H.pivot("torso", waist, (0, 0, 0.3))
    H.sphere("chest", torso, (0, 0, 0.3), (0.3, 0.2, 0.3), skin)
    H.sphere("top", torso, (0, -0.01, 0.32), (0.27, 0.19, 0.16), robe)
    H.torus("necklace", torso, (0, 0, 0.55), 0.12, 0.025, gold, outline=False)
    head = H.pivot("head", torso, (0, -0.02, 0.75))
    H.sphere("face", head, (0, 0, 0), (0.16, 0.17, 0.19), skin)
    for x in (-0.05, 0.05):
        H.sphere("eye%.2f" % x, head, (x, -0.13, 0.02), (0.03, 0.02, 0.022), eye, outline=False, subsurf=0)
    for k in range(9):
        a = k / 9.0 * math.pi * 2
        sn = H.pivot("snake%d" % k, head, (math.cos(a) * 0.1, math.sin(a) * 0.1 + 0.03, 0.1))
        prev = sn
        for j in range(4):
            seg = H.pivot("sn%d_%d" % (k, j), prev, (0, 0, 0.09))
            H.sphere("snseg%d_%d" % (k, j), seg, (0, 0, 0), (0.048 - j * 0.006,) * 3, snake, subsurf=0)
            prev = seg
        H.sphere("snhead%d" % k, prev, (0, -0.02, 0.07), (0.05, 0.065, 0.035), snake, subsurf=0)
    for side, sx in (("L", -1), ("R", 1)):
        sh = H.pivot("shoulder." + side, torso, (sx * 0.28, 0, 0.45))
        H.limb("arm." + side, sh, (0, 0, 0), 0.32, 0.055, 0.045, skin)
        el = H.pivot("elbow." + side, sh, (0, 0, -0.32))
        H.limb("fore." + side, el, (0, 0, 0), 0.3, 0.045, 0.035, skin)
        H.torus("bracelet." + side, el, (0, 0, -0.2), 0.05, 0.015, gold, outline=False)
    return root


def pose_medusa(anim, f, n):
    ph = 2 * math.pi * f / n
    for i in range(TAIL):
        t = i / (TAIL - 1.0)
        a = t * 7.5 + 0.35 * math.sin(ph - t * 6.0)
        rad = 0.2 + 0.42 * t
        P["tail%d" % i].location = (math.sin(a) * rad, 0.2 + math.cos(a) * rad * 0.85, max(0.18, 0.95 * (1 - t * 1.4)) + 0.04 * math.sin(ph + t * 8))
    for k in range(9):
        a = k / 9.0 * math.pi * 2
        sway = 0.25 * math.sin(ph + k)
        flare = 1.0 if anim == "attack" else 0.0
        rot("snake%d" % k, math.sin(a) * (0.9 + 0.4 * flare) + sway, -math.cos(a) * (0.9 + 0.4 * flare), 0)
        for j in range(4):
            rot("sn%d_%d" % (k, j), 0.25 * math.sin(ph + k + j), 0.15, 0)
    if anim == "move":
        rot("waist", 0, 0.08 * math.sin(ph), 0.1 * math.sin(ph))
        rot("shoulder.L", 0.2, -0.3, 0)
        rot("shoulder.R", 0.2, 0.3, 0)
        rot("elbow.L", -0.5)
        rot("elbow.R", -0.5)
    else:
        k = [0.3, 0.7, 1.0, 1.0, 0.8, 0.4][f]
        rot("torso", -0.15 * k, 0, 0)
        rot("head", 0.15 * k, 0, 0)
        rot("shoulder.L", -1.6 * k, -0.5, 0)
        rot("shoulder.R", -1.6 * k, 0.5, 0)
        rot("elbow.L", -0.3 * k)
        rot("elbow.R", -0.3 * k)
        H.bpy.data.materials["GazeEye"].node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = 14.0 + 20.0 * k
        return
    H.bpy.data.materials["GazeEye"].node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = 14.0


def build_talos():
    bronze = H.material("TalosBronze", (0.62, 0.36, 0.13), metallic=0.9, rough=0.32)
    patina = H.material("Patina", (0.3, 0.42, 0.36), metallic=0.5, rough=0.6)
    plume = H.material("Plume", (0.75, 0.08, 0.06), rough=0.8)
    core = glow("TalosCore", (1.0, 0.55, 0.15), 10.0)
    slit = glow("TalosEye", (1.0, 0.2, 0.08), 12.0)
    root = H.pivot("root", None, (0, 0, 0))
    hips = H.pivot("hips", root, (0, 0, 1.35))
    for side, sx in (("L", -1), ("R", 1)):
        hp = H.pivot("hip." + side, hips, (sx * 0.32, 0, 0))
        H.limb("thigh." + side, hp, (0, 0, 0), 0.7, 0.26, 0.22, bronze)
        kn = H.pivot("knee." + side, hp, (0, 0, -0.7))
        H.sphere("kneecap." + side, kn, (0, -0.08, 0), (0.17, 0.12, 0.15), bronze)
        H.limb("shin." + side, kn, (0, 0, 0), 0.62, 0.22, 0.24, bronze)
        H.sphere("foot." + side, kn, (0, -0.12, -0.66), (0.24, 0.32, 0.1), bronze)
    H.cone("skirtplates", hips, (0, 0, 0.12), 0.48, 0.4, 0.36, patina, verts=10, subsurf=0)
    torso = H.pivot("torso", hips, (0, 0, 0.0))
    H.sphere("abdomen", torso, (0, 0, 0.35), (0.48, 0.38, 0.3), bronze)
    H.sphere("chest", torso, (0, 0.02, 0.85), (0.85, 0.56, 0.55), bronze)
    H.sphere("coreglow", torso, (0, -0.48, 0.82), (0.15, 0.06, 0.15), core, outline=False, subsurf=0)
    H.torus("corering", torso, (0, -0.46, 0.82), 0.18, 0.035, patina, outline=False)
    head = H.pivot("head", torso, (0, -0.05, 1.42))
    H.sphere("helm", head, (0, 0, 0), (0.28, 0.3, 0.3), bronze)
    H.sphere("visor", head, (0, -0.24, -0.02), (0.2, 0.06, 0.08), H.material("Visor", (0.05, 0.03, 0.02), rough=0.9), outline=False)
    H.sphere("eyeslit", head, (0, -0.29, -0.02), (0.15, 0.02, 0.02), slit, outline=False, subsurf=0)
    H.sphere("crest", head, (0, 0.05, 0.32), (0.06, 0.35, 0.16), plume)
    for side, sx in (("L", -1), ("R", 1)):
        sh = H.pivot("shoulder." + side, torso, (sx * 0.85, 0, 1.0))
        H.sphere("pauldron." + side, sh, (0, 0, 0.05), (0.36, 0.36, 0.3), bronze)
        H.limb("upper." + side, sh, (0, 0, -0.1), 0.65, 0.22, 0.2, bronze)
        el = H.pivot("elbow." + side, sh, (0, 0, -0.75))
        H.limb("fore." + side, el, (0, 0, 0), 0.6, 0.2, 0.24, bronze)
        H.sphere("fist." + side, el, (0, 0, -0.68), (0.28, 0.26, 0.28), bronze)
    return root


def pose_talos(anim, f, n):
    ph = 2 * math.pi * f / n
    s = math.sin(ph)
    if anim == "move":
        P["hips"].location = (0, 0, 1.35 + 0.05 * abs(math.cos(ph)))
        rot("hip.L", -0.35 * s)
        rot("hip.R", 0.35 * s)
        rot("knee.L", max(0.0, math.sin(ph + 1.3)) * 0.5)
        rot("knee.R", max(0.0, math.sin(ph + 1.3 + math.pi)) * 0.5)
        rot("torso", 0.05, 0, 0.1 * s)
        rot("shoulder.L", 0.25 * s, -0.15, 0)
        rot("shoulder.R", -0.25 * s, 0.15, 0)
        rot("elbow.L", -0.35)
        rot("elbow.R", -0.35)
    else:
        k = [0.4, 0.9, 1.0, -1.0, -0.8, -0.3][f]
        if k > 0:
            rot("shoulder.L", -2.6 * k, -0.2, 0)
            rot("shoulder.R", -2.6 * k, 0.2, 0)
            rot("elbow.L", -0.6 * k)
            rot("elbow.R", -0.6 * k)
            rot("torso", -0.15 * k, 0, 0)
        else:
            a = -k
            rot("shoulder.L", -1.0 * a, -0.1, 0)
            rot("shoulder.R", -1.0 * a, 0.1, 0)
            rot("torso", 0.4 * a, 0, 0)
            rot("knee.L", 0.35 * a)
            rot("knee.R", 0.35 * a)
            P["hips"].location = (0, 0, 1.35 - 0.15 * a)


CHARACTERS = {
    "shade": {"build": build_shade, "pose": pose_shade, "ortho": 2.6, "target_z": 0.85, "size": 160},
    "brute": {"build": build_brute, "pose": pose_brute, "ortho": 3.4, "target_z": 1.0, "size": 160},
    "wisp": {"build": build_wisp, "pose": pose_wisp, "ortho": 1.5, "target_z": 0.6, "size": 128},
    "archer": {"build": build_archer, "pose": pose_archer, "ortho": 2.6, "target_z": 0.9, "size": 160},
    "bomber": {"build": build_bomber, "pose": pose_bomber, "ortho": 2.0, "target_z": 0.6, "size": 144},
    "cerbero": {"build": build_cerbero, "pose": pose_cerbero, "ortho": 5.0, "target_z": 1.2, "size": 256},
    "medusa": {"build": build_medusa, "pose": pose_medusa, "ortho": 4.0, "target_z": 1.25, "size": 256},
    "talos": {"build": build_talos, "pose": pose_talos, "ortho": 6.0, "target_z": 1.7, "size": 256},
}
FPS = {"move": 10, "attack": 12}


def figure_height_px(px_per_m):
    """Tallest projected point of the figure above its feet, in pixels."""
    deps = bpy.context.evaluated_depsgraph_get()
    top = 0.0
    p = H.CAM_PITCH
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        ev = obj.evaluated_get(deps)
        mw = ev.matrix_world
        for v in ev.data.vertices:
            w = mw @ v.co
            top = max(top, w.z * math.cos(p) + w.y * math.sin(p))
    return top * px_per_m


def run_character(cid, spec, out_dir):
    P.clear()
    H.SIZE = spec["size"]
    H.ORTHO = spec["ortho"]
    H.TARGET_Z = spec["target_z"]
    H.OUT = out_dir
    H.reset_scene()
    H.INK = H.ink_material()
    H.add_lights()
    bpy.data.objects["Key"].data.energy = 2.4
    bpy.data.objects["Fill"].data.energy = 0.6
    bpy.data.objects["Rim"].data.energy = 3.2
    bg = bpy.context.scene.world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs["Strength"].default_value = 0.45
    H.add_camera()
    root = spec["build"]()
    remember_locations()

    if PREVIEW:
        root.rotation_euler = (0, 0, math.radians(45.0))
        reset_pose()
        spec["pose"]("move", 2, ANIMS["move"])
        bpy.context.view_layer.update()
        H.render_frame(os.path.join(out_dir, "preview_%s.png" % cid))
        return

    tmp = os.path.join(out_dir, "_frames")
    os.makedirs(tmp, exist_ok=True)
    for anim, frames in ANIMS.items():
        for d in range(H.DIRECTIONS):
            root.rotation_euler = (0, 0, math.radians(45.0 * d))
            for f in range(frames):
                reset_pose()
                spec["pose"](anim, f, frames)
                bpy.context.view_layer.update()
                H.render_frame(os.path.join(tmp, "%s_%d_%d.png" % (anim, d, f)))
        H.pack(anim, frames, tmp)

    root.rotation_euler = (0, 0, 0)
    reset_pose()
    spec["pose"]("move", 0, ANIMS["move"])
    bpy.context.view_layer.update()
    px_per_m = spec["size"] / spec["ortho"]
    meta = {
        "frame_size": spec["size"],
        "frames": ANIMS,
        "fps": FPS,
        "feet_y": round(spec["size"] / 2 + spec["target_z"] * math.cos(H.CAM_PITCH) * px_per_m, 1),
        "figure_px": round(figure_height_px(px_per_m), 1),
    }
    with open(os.path.join(out_dir, "meta.json"), "w") as fh:
        json.dump(meta, fh, indent=2)
    for name in os.listdir(tmp):
        os.remove(os.path.join(tmp, name))
    os.rmdir(tmp)
    print("done", cid, meta)


def main():
    ids = list(CHARACTERS) if WHICH == "all" else [WHICH]
    for cid in ids:
        out_dir = ROOT_OUT if PREVIEW else os.path.join(ROOT_OUT, cid)
        os.makedirs(out_dir, exist_ok=True)
        run_character(cid, CHARACTERS[cid], out_dir)


main()
