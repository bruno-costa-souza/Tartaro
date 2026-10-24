"""God portraits for the boon screen (the god shown beside the boon cards).

Run (headless), from the project root:
    blender -b -P tools/blender/gods.py -- art/gods              # every god
    blender -b -P tools/blender/gods.py -- art/gods zeus hermes  # some of them

Output per god: art/gods/<id>.png (cel-shaded half-length portrait on a
transparent background) and art/gods/<id>_glow.png (only the glowing parts,
pulsed additively in-game).
"""

import math
import os
import sys

import bpy
import numpy as np
from mathutils import Euler, Matrix, Vector

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import figure as F  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(ARGS[0] if ARGS else "art/gods")
ONLY = ARGS[1:]
W, H = 600, 840
OUTLINE = 0.0045

M = {}
GLOW = []


# ---------------------------------------------------------------- scene

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.film_transparent = True
    scene.render.resolution_x = W
    scene.render.resolution_y = H
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    try:
        scene.view_settings.view_transform = "Standard"
    except Exception:
        pass
    scene.eevee.taa_render_samples = 48
    world = bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.3, 0.27, 0.4, 1.0)
    bg.inputs["Strength"].default_value = 0.15
    F.OUTLINE = OUTLINE
    F._ink = None
    M.clear()
    GLOW.clear()

    def sun(name, energy, rot):
        ob = bpy.data.objects.new(name, bpy.data.lights.new(name, "SUN"))
        ob.data.energy = energy
        ob.data.angle = math.radians(4)
        ob.rotation_euler = tuple(math.radians(a) for a in rot)
        scene.collection.objects.link(ob)
    sun("Key", 4.4, (48, 0, -58))
    sun("Fill", 0.6, (80, 0, 60))
    sun("Rim", 3.0, (-50, 0, 150))

    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.lens = 85
    cam.data.sensor_fit = "VERTICAL"
    cam.data.sensor_height = 24
    cam.location = (-0.06, -4.2, 1.66)
    cam.rotation_euler = (math.radians(90), 0, 0)
    scene.collection.objects.link(cam)
    scene.camera = cam
    return scene


def mat(key, color, **kw):
    """Toon material cached per god (rim tinted with the god's colour)."""
    if key not in M:
        M[key] = F.toon(key, color, **kw)
    return M[key]


def glow_mat(key, color, strength=1.6):
    if key not in M:
        M[key] = F.toon(key, color, shadow=color, mid=1.0, rim_strength=0.0, emission=color, strength=strength)
        GLOW.append(M[key])
    return M[key]


def ink(ob, subsurf=1, thickness=None):
    return F.outline(ob, thickness=thickness or OUTLINE, subsurf=subsurf)


def parent(ob, to):
    ob.parent = to
    return ob


def empty(name, loc=(0, 0, 0), rot=(0, 0, 0), to=None):
    e = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(e)
    e.location = loc
    e.rotation_euler = rot
    if to is not None:
        e.parent = to
    return e


# ---------------------------------------------------------------- body

class Body:
    """Half-length body posed directly through its joints (no rig needed)."""

    def __init__(self, spec, root):
        self.spec = spec
        self.root = root
        fem = spec.get("sex", "m") == "f"
        bulk = spec.get("bulk", 1.0)
        self.fem = fem
        self.skin = mat("Skin", spec["skin"], shadow=spec.get("skin_shadow"), rim=spec["rim"], rim_strength=0.35)
        sh = 0.175 if fem else 0.215
        self.shoulder = {s: Vector((sh * s, 0.0, 1.47 if fem else 1.48)) for s in (-1, 1)}
        V, E, R = [], [], []

        def v(p, r, par=None):
            V.append(tuple(p))
            R.append(r)
            if par is not None:
                E.append((par, len(V) - 1))
            return len(V) - 1

        k = bulk
        if fem:
            pel = v((0, 0.01, 0.98), (0.15, 0.11))
            wai = v((0, 0.0, 1.13), (0.108, 0.085), pel)
            che = v((0, -0.005, 1.3), (0.135, 0.1), wai)
            upp = v((0, 0.0, 1.42), (0.128, 0.085), che)
            nek = v((0, 0.01, 1.53), (0.05, 0.05), upp)
            v((0, 0.0, 1.68), (0.046, 0.046), nek)
        else:
            pel = v((0, 0.01, 0.98), (0.16 * k, 0.12 * k))
            wai = v((0, 0.0, 1.12), (0.14 * k, 0.105 * k), pel)
            che = v((0, -0.012, 1.3), (0.19 * k, 0.128 * k), wai)
            upp = v((0, 0.0, 1.43), (0.18 * k, 0.11 * k), che)
            nek = v((0, 0.012, 1.55), (0.07 * k, 0.068 * k), upp)
            v((0, 0.0, 1.69), (0.062, 0.062), nek)
        self.arm_joints = {}
        self.hands = {}
        for s in (-1, 1):
            a = spec["arms"][s]
            S = self.shoulder[s]
            Ej = Vector(a["elbow"])
            Wj = Vector(a["wrist"])
            ra = (0.058 if fem else 0.075 * k)
            sj = v(S, (ra, ra), upp)
            mid = v(S.lerp(Ej, 0.45), ((0.048 if fem else 0.066 * k),) * 2, sj)
            ej = v(Ej, ((0.038 if fem else 0.05 * k),) * 2, mid)
            fm = v(Ej.lerp(Wj, 0.4), ((0.04 if fem else 0.055 * k),) * 2, ej)
            wj = v(Wj, ((0.028 if fem else 0.036 * k),) * 2, fm)
            hd = Vector(a.get("hand", (Wj - Ej).normalized()))
            hd.normalize()
            hc = Wj + hd * (0.045 if fem else 0.055)
            hj = v(hc, ((0.036 if fem else 0.047),) * 2, wj)
            v(hc + hd * (0.045 if fem else 0.05), ((0.026 if fem else 0.034),) * 2, hj)
            self.arm_joints[s] = (S, Ej, Wj)
            self.hands[s] = (hc, hd)
        ob = F.skin_body("Body", V, E, R, self.skin, root=pel, subdiv=2)
        parent(ob, root)
        ink(ob, subsurf=1)
        self.ob = ob
        if not fem and spec.get("bare_chest", True):
            self.muscles(k)

    def muscles(self, k):
        """Pecs and abs as soft shapes on the bare chest."""
        for s in (-1, 1):
            pec = F.ellipsoid("Pec", (0.07 * s * k, -0.106 * k, 1.375), (0.085 * k, 0.022, 0.05), self.skin, segs=16,
                              rings=8, rot=(0.1, 0, 0.08 * s),
                              shape=lambda co: (co[0], co[1], co[2] * (1.0 if co[2] < 0 else 0.6)))
            parent(pec, self.root)
            ink(pec, subsurf=1, thickness=OUTLINE * 0.35)

    def hand(self, s, direction=None, closed=True):
        return self.hands[s]

    def bracer(self, s, color, gold):
        S, Ej, Wj = self.arm_joints[s]
        pts = [Ej.lerp(Wj, t) for t in (0.45, 0.7, 0.95)]
        r = 0.05 if self.fem else 0.07
        b = F.tube("Bracer", pts, [r, r * 0.95, r * 0.8], mat("Bracer", color, rim=self.spec["rim"]), sides=12)
        parent(b, self.root)
        ink(b, subsurf=1)
        for t, rr in ((0.45, r * 1.06), (0.95, r * 0.86)):
            ring_band(Ej.lerp(Wj, t), (Wj - Ej).normalized(), rr, 0.01, gold, self.root)

    def armband(self, s, gold, t=0.35):
        S, Ej, Wj = self.arm_joints[s]
        r = 0.058 if self.fem else 0.085 * self.spec.get("bulk", 1.0)
        ring_band(S.lerp(Ej, t), (Ej - S).normalized(), r, 0.012, gold, self.root)


def ring_band(center, axis, r, thick, material, to):
    axis = Vector(axis).normalized()
    u = axis.orthogonal().normalized()
    w = axis.cross(u)
    pts = [tuple(Vector(center) + (u * math.cos(a) + w * math.sin(a)) * r) for a in np.linspace(0, 2 * math.pi, 25)]
    ob = F.tube("Band", pts, thick, material, sides=6, cap=False)
    parent(ob, to)
    ink(ob, subsurf=0, thickness=OUTLINE * 0.6)
    return ob


# ---------------------------------------------------------------- head

class Head:
    def __init__(self, spec, root, body):
        self.spec = spec
        fem = body.fem
        self.fem = fem
        self.skin = body.skin
        self.C = Vector(spec.get("head_at", (0.0, -0.012, 1.775 if not fem else 1.745)))
        self.R = Vector((0.098, 0.115, 0.13)) if fem else Vector((0.106, 0.122, 0.138))
        tilt, turn = spec.get("head_rot", (0.0, 0.0))
        self.e = empty("Head", self.C, (tilt, 0.0, turn), root)
        jaw = 0.22 if fem else 0.3

        def shape(co):
            x, y, z = co
            if z < -0.05:
                k = 1.0 - jaw * ((-z - 0.05) / 0.95) ** 1.3
                x *= k
                if y < 0 and z < -0.5:
                    y -= (0.06 if fem else 0.1) * (-z - 0.5)
            if y < -0.4 and -0.2 < z < 0.4:
                eye = math.exp(-((abs(x) - 0.4) / 0.18) ** 2 - ((z - 0.12) / 0.14) ** 2)
                y += 0.05 * eye
                brow = math.exp(-((z - 0.32) / 0.08) ** 2) * (0.0 if fem else 1.0)
                y -= 0.035 * brow
            if y > 0.0 and z > -0.2:
                y *= 1.07
            if y < 0 and z > 0.45:
                y *= 0.94
            return (x, y, z)

        head = F.ellipsoid("Skull", (0, 0, 0), tuple(self.R), self.skin, segs=40, rings=22, shape=shape)
        parent(head, self.e)
        ink(head, subsurf=1)
        self.face()

    def front(self, x, z, inset=0.0):
        """Local y of the face surface (front is -y) at local (x, z)."""
        k = 1.0 - (x / self.R.x) ** 2 - (z / self.R.z) ** 2
        return -self.R.y * math.sqrt(max(k, 0.0)) * 0.98 + inset

    def face(self):
        s = self.spec
        fem = self.fem
        R = self.R
        ze = 0.012
        # nose
        nb = F.ellipsoid("Nose", (0, self.front(0, -0.012, 0.014), -0.014), (0.015 if not fem else 0.012, 0.024, 0.04),
                         self.skin, segs=14, rings=10, rot=(0.38, 0, 0),
                         shape=lambda co: (co[0] * (0.7 + 0.45 * max(0.0, -co[2])), co[1], co[2]))
        parent(nb, self.e)
        ink(nb, subsurf=1, thickness=OUTLINE * 0.45)
        # eyes: glowing almonds under a dark lid line
        eye_col = s.get("eyes", s["color"])
        em = glow_mat("Eyes", eye_col, 2.4)
        for side in (-1, 1):
            x = 0.04 * side if fem else 0.043 * side
            y = self.front(x, ze, 0.009)
            tilt = (0.12 if fem else -0.05) * side
            eye = F.ellipsoid("Eye", (x, y, ze), (0.021 if fem else 0.022, 0.008, 0.0105 if fem else 0.0085), em, segs=12,
                              rings=6, rot=(0, -0.25 * side, tilt))
            parent(eye, self.e)
            lid = [(x + 0.024 * side * u, self.front(x + 0.024 * side * u, ze + 0.009, 0.003) - 0.003, ze + 0.009 - 0.004 * u * u + (0.003 if fem else 0.0) * u)
                   for u in (-1.0, -0.5, 0.0, 0.5, 1.0)]
            lid_ob = F.tube("Lid", lid, [0.0025, 0.004, 0.0045, 0.004, 0.0028 if not fem else 0.004], F.ink(), sides=5)
            parent(lid_ob, self.e)
            bz = ze + (0.034 if fem else 0.03)
            brow = [(x + side * dx, self.front(x + side * dx, bz + dz, -0.004), bz + dz) for dx, dz in
                    ((-0.03, -0.006 if not fem else 0.0), (-0.01, 0.0), (0.012, 0.004 if fem else 0.002), (0.03, -0.002 if fem else 0.004))]
            bcol = mat("Brow", s.get("brow", s.get("hair", (0.2, 0.15, 0.1))), rim_strength=0.0)
            brow_ob = F.tube("Brow", brow, [0.005, 0.0085 if not fem else 0.005, 0.008 if not fem else 0.0045, 0.004], bcol, sides=6, flat=0.6)
            parent(brow_ob, self.e)
        # mouth
        mz = -0.075 if not fem else -0.07
        mouth = [(dx, self.front(dx, mz, -0.002), mz + 0.004 * (abs(dx) / 0.022) ** 2 * (1 if fem else -0.5)) for dx in (-0.022, -0.01, 0.0, 0.01, 0.022)]
        mo = F.tube("Mouth", mouth, [0.002, 0.0032, 0.0035, 0.0032, 0.002], F.ink(), sides=5)
        parent(mo, self.e)
        lip_col = s.get("lips", tuple(min(1.0, c * 0.85 + (0.12 if i == 0 else 0.0)) for i, c in enumerate(s["skin"])))
        lip = F.ellipsoid("Lip", (0, self.front(0, mz - 0.012, -0.003), mz - 0.011), (0.017, 0.008, 0.007),
                          mat("Lip", lip_col, rim_strength=0.0), segs=10, rings=6)
        parent(lip, self.e)
        # ears
        for side in (-1, 1):
            ear = F.ellipsoid("Ear", (self.R.x * 0.98 * side, 0.01, -0.005), (0.016, 0.028, 0.04), self.skin, segs=10, rings=6)
            parent(ear, self.e)
            ink(ear, subsurf=1, thickness=OUTLINE * 0.7)

    def scalp(self, u, v, lift=0.0, grow=1.04):
        """Point on an ellipsoid slightly bigger than the skull.
        u: azimuth (0 = front, +pi/2 = +x side, pi = back), v: elevation."""
        R = self.R * grow
        d = Vector((math.sin(u) * math.cos(v), -math.cos(u) * math.cos(v), math.sin(v)))
        return Vector((d.x * R.x, d.y * R.y, d.z * R.z)) * (1.0 + lift), d


def lock(head, pts_local, radii, material, flat=0.55, sides=8, sub=1, outline=True):
    ob = F.tube("Lock", pts_local, radii, material, sides=sides, flat=flat)
    parent(ob, head.e)
    if outline:
        ink(ob, subsurf=sub, thickness=OUTLINE * 0.8)
    return ob


def hair_cap(head, material, front_v=0.62, back_drop=0.0):
    """Hair volume: a skull-hugging cap that leaves the face free."""
    R = head.R * 1.05

    def shape(co):
        x, y, z = co
        if y < 0 and z < front_v:
            z = front_v + (z - front_v) * 0.15
            y = y * 0.9
        if y > 0 and z < 0:
            z -= back_drop * y
        return (x, y, z)
    cap = F.ellipsoid("HairCap", (0, 0.008, 0.012), tuple(R), material, segs=32, rings=16, shape=shape)
    parent(cap, head.e)
    ink(cap, subsurf=1)
    return cap


def long_hair(head, material, n=16, length=0.42, wave=0.02, spread=1.0, part=True):
    """Locks from the hairline sweeping back and down to the shoulders."""
    for i in range(n):
        u = math.radians(58 + 244 * i / (n - 1))
        top, _ = head.scalp(math.pi + (u - math.pi) * 0.5, math.radians(62), 0.03)
        side, _ = head.scalp(u, math.radians(12), 0.07)
        pts = [top, side]
        base = Vector(side)
        for k in range(1, 6):
            t = k / 5.0
            out = Vector((math.sin(u) * 0.04 * spread * t, 0.03 * t + abs(math.cos(u)) * 0.02 * t, 0))
            p = base + out + Vector((0, 0.02 * t, -length * t)) + Vector((wave * math.sin(t * 7 + i), 0, 0))
            pts.append(p)
        r = 0.032 * (1.1 if abs(math.sin(u)) > 0.5 else 0.95)
        lock(head, pts, [r * 0.9, r, r * 0.95, r * 0.85, r * 0.7, r * 0.45, r * 0.08], material, flat=0.45)


def curly_top(head, material, n=14, size=0.035):
    """Short curls over the crown (Apolo, Hermes, Dionísio)."""
    rng = np.random.default_rng(len(head.spec["name"]))
    for i in range(n):
        u = rng.uniform(-math.pi * 0.85, math.pi * 0.85)
        v = rng.uniform(math.radians(25), math.radians(80))
        p, d = head.scalp(u, v, 0.08)
        curl = F.ellipsoid("Curl", tuple(p), (size, size, size * 0.85), material, segs=10, rings=6)
        parent(curl, head.e)
        ink(curl, subsurf=1, thickness=OUTLINE * 0.7)


def beard(head, material, length=0.14, width=1.0, curls=True, mustache=True, depth=0.095):
    R = head.R
    mass = F.ellipsoid("Beard", (0, -0.035 - (0.095 - depth) * 0.6, -0.095 - length * 0.25), (R.x * 0.95 * width, depth, 0.06 + length * 0.4),
                       material, segs=24, rings=12,
                       shape=lambda co: (co[0] * (1.0 - 0.25 * max(0.0, -co[2])), co[1] - 0.25 * max(0.0, -co[2]) * 0.3, co[2]))
    parent(mass, head.e)
    ink(mass, subsurf=1)
    if curls:
        for i in range(9):
            x = (i - 4) / 4.0 * R.x * 0.8 * width
            top = Vector((x, head.front(x * 0.9, -0.06, -0.01), -0.07))
            pts = [top]
            for k in range(1, 5):
                t = k / 4.0
                pts.append(top + Vector((0.012 * math.sin(t * 6 + i) - x * 0.15 * t, -0.01 * t, -length * t * (1.0 - abs(x) / 0.25))))
            lock(head, pts, [0.022, 0.024, 0.02, 0.014, 0.003], material, flat=0.6)
    if mustache:
        for side in (-1, 1):
            pts = [Vector((0.004 * side, head.front(0, -0.052, -0.012), -0.052)),
                   Vector((0.025 * side, head.front(0.025, -0.06, -0.014), -0.062)),
                   Vector((0.045 * side, head.front(0.045, -0.08, -0.008), -0.09))]
            lock(head, pts, [0.009, 0.011, 0.004], material, flat=0.6)


# ---------------------------------------------------------------- garments

def torso_front(x, z, fem, bulk=1.0, lift=0.01):
    if fem:
        rx = float(np.interp(z, [0.95, 1.13, 1.3, 1.42, 1.5], [0.15, 0.11, 0.14, 0.13, 0.1]))
        ry = float(np.interp(z, [0.95, 1.13, 1.3, 1.42, 1.5], [0.11, 0.087, 0.11, 0.088, 0.07]))
    else:
        rx = float(np.interp(z, [0.95, 1.12, 1.3, 1.43, 1.52], [0.165, 0.145, 0.195, 0.185, 0.12])) * bulk
        ry = float(np.interp(z, [0.95, 1.12, 1.3, 1.43, 1.52], [0.125, 0.108, 0.135, 0.115, 0.08])) * bulk
    return -ry * math.sqrt(max(0.0, 1.0 - (x / rx) ** 2)) - lift, rx, ry


def himation(body, color, trim, side=-1):
    """Cloth wrapped round the waist and pulled diagonally up over one
    shoulder, leaving the other side of the chest bare (Greek statue style)."""
    fem = body.fem
    k = body.spec.get("bulk", 1.0)
    cloth = mat("Cloth", color, rim=body.spec["rim"], rim_strength=0.35)
    gold = mat("Trim", trim, spec=0.8, rim=body.spec["rim"])
    zs = np.linspace(0.92, 1.5, 12)
    rings_, edge_f = [], []
    n = 28
    for z in zs:
        _, rx, ry = torso_front(0.0, z, fem, k, 0.0)
        rx += 0.03
        ry += 0.03
        t = (z - 0.92) / 0.58
        xe = (0.32 - 0.48 * t) * k
        c = max(-1.0, min(1.0, xe / rx))
        a1 = math.acos(c)
        a2 = 2 * math.pi - a1
        pts = []
        for i in range(n):
            u = i / (n - 1)
            ang = a1 + (a2 - a1) * u
            fold = 0.012 * math.sin(ang * 7 + z * 9) * (0.5 + 0.5 * t)
            x = math.cos(ang) * (rx + fold)
            y = math.sin(ang) * (ry + fold)
            if side > 0:
                x = -x
            pts.append([x, y, z])
        rings_.append(pts)
        edge_f.append(pts[-1])
    ob = F.loft("Himation", rings_, cloth, closed=False)
    ob.modifiers.new("Thick", "SOLIDIFY").thickness = 0.012
    parent(ob, body.root)
    ink(ob, subsurf=1)
    # cloth over the shoulder and hanging down the back
    S = body.shoulder[side]
    cap = F.ellipsoid("ShoulderCloth", tuple(S + Vector((0.01 * side, 0.01, 0.025))), (0.105 * k, 0.12 * k, 0.075), cloth,
                      segs=20, rings=10, rot=(0, -0.45 * side, 0))
    parent(cap, body.root)
    ink(cap, subsurf=1)
    hang = [S + Vector((0.03 * side, 0.07, 0.02)), S + Vector((0.06 * side, 0.11, -0.2)), S + Vector((0.07 * side, 0.13, -0.5))]
    ob = F.tube("Hang", hang, [0.07, 0.09, 0.1], cloth, sides=12, flat=0.35)
    parent(ob, body.root)
    ink(ob, subsurf=1)
    trim_pts = [Vector(p) + Vector((0, -0.006, 0)) for p in edge_f]
    tr = F.tube("Trim", trim_pts, 0.011, gold, sides=6)
    parent(tr, body.root)
    ink(tr, subsurf=0, thickness=OUTLINE * 0.5)
    brooch = F.ellipsoid("Brooch", tuple(S + Vector((-0.04 * side, -0.07, 0.0))), (0.03, 0.014, 0.03), gold, segs=12, rings=6)
    parent(brooch, body.root)
    ink(brooch, subsurf=1, thickness=OUTLINE * 0.6)


def dress(body, color, trim, folds=9, neckline=1.43, sleeves=False):
    """Chiton covering the torso, with fold ridges and a belt under the bust."""
    fem = body.fem
    k = body.spec.get("bulk", 1.0)
    cloth = mat("Dress", color, rim=body.spec["rim"], rim_strength=0.3)
    gold = mat("Trim", trim, spec=0.8, rim=body.spec["rim"])
    rings_ = []
    zs = [0.88, 0.98, 1.1, 1.2, 1.3, 1.38, neckline]
    for z in zs:
        _, rx, ry = torso_front(0.0, z, fem, k, 0.0)
        rx += 0.018
        ry += 0.018

        def fn(a, z=z):
            amp = 0.009 * (1.4 - (z - 0.9))
            return (math.cos(a) * amp * math.cos(a * folds), math.sin(a) * amp * math.cos(a * folds), 0.0)
        rings_.append(F.ring((0, 0.0, z), rx, ry, 48, fn=fn))
    ob = F.loft("Dress", rings_, cloth)
    sol = ob.modifiers.new("Thick", "SOLIDIFY")
    sol.thickness = 0.01
    parent(ob, body.root)
    ink(ob, subsurf=1)
    belt_z = 1.2 if fem else 1.08
    _, rx, ry = torso_front(0, belt_z, fem, k, 0.0)
    belt = [(math.cos(a) * (rx + 0.03), math.sin(a) * (ry + 0.03), belt_z) for a in np.linspace(0, 2 * math.pi, 33)]
    b = F.tube("Belt", belt, 0.012, gold, sides=6, cap=False)
    parent(b, body.root)
    ink(b, subsurf=0, thickness=OUTLINE * 0.6)
    _, rx, ry = torso_front(0, neckline, fem, k, 0.0)
    neck = [(math.cos(a) * (rx + 0.02), math.sin(a) * (ry + 0.02), neckline) for a in np.linspace(0, 2 * math.pi, 33)]
    n = F.tube("Neckline", neck, 0.009, gold, sides=6, cap=False)
    parent(n, body.root)
    for s in (-1, 1):
        strap = [Vector((s * 0.06, -0.075, neckline - 0.01)), Vector((s * 0.1, -0.02, 1.5)), Vector((s * 0.11, 0.05, 1.47))]
        st = F.tube("Strap", strap, 0.022, cloth, sides=8, flat=0.35)
        parent(st, body.root)
        ink(st, subsurf=1)
        br = F.ellipsoid("Brooch", (s * 0.1, -0.03, 1.5), (0.02, 0.012, 0.02), gold, segs=10, rings=6)
        parent(br, body.root)
    if sleeves:
        for s in (-1, 1):
            S, Ej, Wj = body.arm_joints[s]
            pts = [S + Vector((0, 0, 0.02)), S.lerp(Ej, 0.45)]
            sl = F.tube("Sleeve", pts, [0.075, 0.07], cloth, sides=12)
            parent(sl, body.root)
            ink(sl, subsurf=1)


def cuirass(body, color, trim):
    k = body.spec.get("bulk", 1.0)
    metal = mat("Cuirass", color, spec=0.35, gloss=0.45, rim=body.spec["rim"])
    gold = mat("Trim", trim, spec=0.9, rim=body.spec["rim"])
    rings_ = []
    for z in (0.92, 1.0, 1.1, 1.2, 1.3, 1.38, 1.45, 1.51):
        _, rx, ry = torso_front(0, z, body.fem, k, 0.0)

        def fn(a, z=z, rx=rx):
            x = math.cos(a) * rx
            front = -math.sin(a)
            if front <= 0.2:
                return (0, 0, 0)
            pec = math.exp(-((z - 1.36) / 0.05) ** 2) * (math.exp(-((x - 0.085) / 0.055) ** 2) + math.exp(-((x + 0.085) / 0.055) ** 2))
            return (0, -0.016 * pec * front, 0)
        rings_.append(F.ring((0, 0, z), rx + 0.02, ry + 0.02, 40, fn=fn))
    ob = F.loft("Cuirass", rings_, metal)
    ob.modifiers.new("Thick", "SOLIDIFY").thickness = 0.012
    parent(ob, body.root)
    ink(ob, subsurf=1)
    for s in (-1, 1):
        p = F.ellipsoid("Pauldron", tuple(body.shoulder[s] + Vector((0.02 * s, 0, 0.03))), (0.1 * k, 0.11 * k, 0.065), metal,
                        segs=18, rings=9, rot=(0, -0.5 * s, 0))
        parent(p, body.root)
        ink(p, subsurf=1)
    _, rx, ry = torso_front(0, 1.0, body.fem, k, 0.0)
    belt = [(math.cos(a) * (rx + 0.035), math.sin(a) * (ry + 0.035), 1.0) for a in np.linspace(0, 2 * math.pi, 33)]
    b = F.tube("Belt", belt, 0.016, gold, sides=6, cap=False)
    parent(b, body.root)


# ---------------------------------------------------------------- props

def flat_shape(name, outline2d, depth, material, center, rot, scale=1.0, bevel=True):
    """Extrude a 2D polygon (x, z) into a slab facing -y."""
    pts = [Vector((x * scale, 0, z * scale)) for x, z in outline2d]
    n = len(pts)
    verts = [tuple(p + Vector((0, -depth / 2, 0))) for p in pts] + [tuple(p + Vector((0, depth / 2, 0))) for p in pts]
    faces = [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))
    ob = F.mesh_object(name, verts, faces, [material], smooth=False)
    F.recalc_normals(ob)
    if bevel:
        bv = ob.modifiers.new("Bevel", "BEVEL")
        bv.width = depth * 0.45
        bv.segments = 2
    ob.location = center
    ob.rotation_euler = rot
    return ob


BOLT = [(0.05, 0.62), (-0.12, 0.08), (0.02, 0.1), (-0.1, -0.5), (0.13, 0.02), (-0.01, 0.0), (0.12, 0.62)]


ROOT = None


def own(ob, subsurf=0, outline=True, thick=None):
    ob.parent = ROOT
    if outline:
        ink(ob, subsurf=subsurf, thickness=thick)
    return ob


def aim(direction):
    """Euler that turns +Z onto `direction`."""
    return Vector((0, 0, 1)).rotation_difference(Vector(direction).normalized()).to_euler()


def basis(axis):
    """Orthonormal (side, front, axis) frame around an axis, front ~ -y."""
    z = Vector(axis).normalized()
    x = Vector((0, -1, 0)).cross(z)
    if x.length < 1e-4:
        x = Vector((1, 0, 0))
    x.normalize()
    y = z.cross(x)
    return x, y, z


def gold(color=(1.0, 0.8, 0.32)):
    return mat("Gold", color, spec=1.0, gloss=0.2, rim=GOD["rim"], rim_strength=0.3)


def fist(body, s):
    c, d = body.hands[s]
    r = (0.036, 0.042, 0.05) if body.fem else (0.046, 0.054, 0.062)
    rot = aim(d)
    f = F.ellipsoid("Fist", tuple(c), r, body.skin, segs=16, rings=8, rot=(rot.x, rot.y, rot.z))
    own(f, 1)
    return c, d


def shaft(a, b, radius, material, sides=8):
    return own(F.tube("Shaft", [Vector(a), Vector(a).lerp(Vector(b), 0.5), Vector(b)], radius, material, sides=sides))


# ---------------------------------------------------------------- props

def prop_bolt(body, s):
    c, d = fist(body, s)
    gm = glow_mat("BoltGlow", (0.8, 0.94, 1.0), 2.2)
    rot = aim((0.55 * s, -0.2, 1.0))
    at = c + Vector((0.04 * s, -0.04, 0.04))
    own(flat_shape("Bolt", BOLT, 0.04, gm, tuple(at), (rot.x, rot.y, rot.z), scale=0.56), thick=OUTLINE * 0.9)
    flat_shape("BoltCore", [(x * 0.55, z * 0.85) for x, z in BOLT], 0.05, glow_mat("BoltCore", (1, 1, 1), 3.0),
               tuple(at + Vector((0, -0.006, 0))), (rot.x, rot.y, rot.z), scale=0.56).parent = ROOT
    sparks(at + Vector((0, -0.04, 0.12)), (0.75, 0.9, 1.0), 12, 0.2)


def sparks(center, color, n, radius, seed=1, length=0.03):
    gm = glow_mat("Spark", color, 2.6)
    rng = np.random.default_rng(seed)
    for i in range(n):
        d = Vector(rng.normal(size=3)).normalized()
        p = Vector(center) + d * radius * rng.uniform(0.5, 1.0)
        pts = [p]
        for k in range(3):
            p = p + Vector(rng.normal(size=3)).normalized() * length + d * length * 0.8
            pts.append(p)
        F.tube("Spark", pts, [0.005, 0.004, 0.003, 0.001], gm, sides=4).parent = ROOT


def motes(center, color, n, radius, seed=2, size=0.012):
    gm = glow_mat("Mote", color, 2.4)
    rng = np.random.default_rng(seed)
    for i in range(n):
        p = Vector(center) + Vector(rng.normal(size=3)) * radius
        F.ellipsoid("Mote", tuple(p), (size,) * 3, gm, segs=6, rings=4).parent = ROOT


def prop_trident(body, s, metal, glow_col):
    c, d = fist(body, s)
    axis = Vector((0.05 * s, -0.05, 1.0)).normalized()
    top = c + axis * 0.62
    shaft(c - axis * 0.75, top, 0.018, metal)
    x, y, z = basis(axis)
    bar = [top - x * 0.11 + z * 0.02, top, top + x * 0.11 + z * 0.02]
    own(F.tube("Bar", bar, 0.016, metal, sides=8))
    tip_mat = glow_mat("Tine", glow_col, 1.6)
    for k, (off, ln) in enumerate(((-0.11, 0.2), (0.0, 0.26), (0.11, 0.2))):
        base = top + x * off + z * 0.02
        end = base + z * ln + x * off * 0.15
        own(F.tube("Prong", [base, base.lerp(end, 0.6), end], [0.015, 0.014, 0.012], metal, sides=8))
        own(F.tube("Tip", [end, end + z * 0.07], [0.026, 0.001], tip_mat, sides=4), thick=OUTLINE * 0.7)
    motes(top + z * 0.15, glow_col, 10, 0.12, seed=5)


def prop_sword(body, s, blade_col, edge_col, direction=(0.15, -0.2, 1.0), length=0.72):
    c, d = fist(body, s)
    axis = Vector(direction).normalized()
    x, y, z = basis(axis)
    blade = [(0.0, 0.0), (0.045, 0.04), (0.05, 0.5), (0.065, 0.62), (0.0, 1.0), (-0.065, 0.62), (-0.05, 0.5), (-0.045, 0.04)]
    rot = Matrix((x, y, z)).transposed().to_euler()
    metal = mat("Blade", blade_col, spec=1.3, gloss=0.15, rim=GOD["rim"], rim_strength=0.4)
    own(flat_shape("Blade", blade, 0.02, metal, tuple(c + axis * 0.08), (rot.x, rot.y, rot.z), scale=length))
    edge = glow_mat("Edge", edge_col, 1.8)
    p0 = c + axis * 0.14
    own(F.tube("Fuller", [p0, p0 + axis * length * 0.6], [0.006, 0.004], edge, sides=4), outline=False)
    g = gold()
    own(F.tube("Guard", [c + axis * 0.08 - x * 0.1, c + axis * 0.08, c + axis * 0.08 + x * 0.1], [0.012, 0.018, 0.012], g, sides=8))
    own(F.tube("Grip", [c - axis * 0.1, c + axis * 0.07], 0.016, mat("Grip", (0.25, 0.12, 0.08)), sides=8))
    own(F.ellipsoid("Pommel", tuple(c - axis * 0.12), (0.024, 0.024, 0.024), g, segs=10, rings=6))


def prop_lyre(center, gold_m, string_col, size=0.36, tilt=0.15):
    c = Vector(center)
    x = Vector((1, 0, 0))
    z = Vector((0, -math.sin(tilt), math.cos(tilt)))
    box = F.ellipsoid("LyreBox", tuple(c - z * size * 0.32), (size * 0.32, size * 0.12, size * 0.16),
                      mat("Shell", (0.55, 0.32, 0.14), spec=0.5, rim=GOD["rim"]), segs=16, rings=8)
    own(box, 1)
    for side in (-1, 1):
        pts = []
        for k in range(7):
            t = k / 6.0
            pts.append(c - z * size * 0.3 + x * side * (size * 0.18 + size * 0.22 * math.sin(t * 2.4)) + z * size * 0.95 * t)
        own(F.tube("Horn", pts, [0.022, 0.02, 0.018, 0.016, 0.015, 0.016, 0.02], gold_m, sides=8), 1)
    top = c + z * size * 0.62
    own(F.tube("Yoke", [top - x * size * 0.36, top, top + x * size * 0.36], 0.014, gold_m, sides=8))
    sm = glow_mat("Strings", string_col, 1.4)
    for k in range(5):
        xx = (k - 2) * size * 0.07
        F.tube("String", [c - z * size * 0.25 + x * xx * 0.8, top + x * xx], 0.0025, sm, sides=4).parent = ROOT


def prop_caduceus(body, s, metal, snake_col, glow_col):
    c, d = fist(body, s)
    axis = Vector((0.08 * s, -0.08, 1.0)).normalized()
    top = c + axis * 0.48
    shaft(c - axis * 0.35, top, 0.015, metal)
    x, y, z = basis(axis)
    sm = mat("Snake", snake_col, spec=0.5, rim=GOD["rim"])
    for ph in (0.0, math.pi):
        pts = []
        for k in range(22):
            t = k / 21.0
            a = ph + t * 4.5 * math.pi
            r = 0.05 * (1.0 - 0.3 * t)
            pts.append(c + axis * (-0.1 + 0.5 * t) + x * math.cos(a) * r + y * math.sin(a) * r)
        own(F.tube("Snake", pts, [0.012] * 21 + [0.02], sm, sides=6), 1)
    orb = F.ellipsoid("Orb", tuple(top + z * 0.03), (0.035, 0.035, 0.035), glow_mat("CadOrb", glow_col, 2.0), segs=12, rings=6)
    own(orb, thick=OUTLINE * 0.7)
    for side in (-1, 1):
        small_wing(top - z * 0.02, x * side, 0.16, (1.0, 1.0, 1.0))


def small_wing(base, outward, span, color, up=0.6):
    m = mat("Feather", color, rim=GOD["rim"], rim_strength=0.4)
    out = Vector(outward).normalized()
    upv = Vector((0, 0, 1))
    for k in range(5):
        t = k / 4.0
        d = (out * (1.0 - 0.5 * t) + upv * (up - 0.9 * t)).normalized()
        ln = span * (1.0 - 0.15 * k)
        rot = aim(d)
        f = F.ellipsoid("Feather", tuple(Vector(base) + d * ln * 0.5), (0.018, 0.008, ln * 0.5), m, segs=10, rings=6,
                        rot=(rot.x, rot.y, rot.z))
        own(f, 1, thick=OUTLINE * 0.6)


def prop_bow(body, s, wood, string_col):
    c, d = fist(body, s)
    axis = Vector((0.0, -0.1, 1.0)).normalized()
    x, y, z = basis(axis)
    pts = []
    for k in range(13):
        t = (k / 12.0) * 2 - 1
        bend = 0.12 * (1 - t * t) - 0.03 * abs(t) ** 3
        pts.append(c + z * t * 0.5 + y * (-bend) + x * 0.0)
    own(F.tube("Bow", pts, [0.008, 0.012, 0.016, 0.019, 0.02, 0.021, 0.022, 0.021, 0.02, 0.019, 0.016, 0.012, 0.008], wood, sides=8), 1)
    sm = glow_mat("BowString", string_col, 1.5)
    F.tube("String", [pts[0], pts[-1]], 0.003, sm, sides=4).parent = ROOT
    tip = glow_mat("ArrowTip", string_col, 2.0)
    a0 = c + y * 0.0 - x * 0.02
    own(F.tube("Arrow", [a0 + y * 0.05, a0 - y * 0.45], 0.006, wood, sides=5))
    own(F.tube("Head", [a0 - y * 0.45, a0 - y * 0.53], [0.016, 0.001], tip, sides=4), thick=OUTLINE * 0.6)


def prop_hammer(body, s, metal, hot):
    c, d = fist(body, s)
    axis = Vector((0.35 * s, 0.25, 1.0)).normalized()
    top = c + axis * 0.32
    shaft(c - axis * 0.12, top, 0.02, mat("Handle", (0.35, 0.2, 0.1)))
    x, y, z = basis(axis)
    head_ob = F.ellipsoid("HammerHead", tuple(top + z * 0.04), (0.13, 0.065, 0.07), metal, segs=8, rings=4,
                          rot=tuple(Matrix((x, y, z)).transposed().to_euler()))
    bv = head_ob.modifiers.new("Bevel", "BEVEL")
    bv.width = 0.01
    own(head_ob)
    face = F.ellipsoid("HotFace", tuple(top + z * 0.04 + x * 0.125), (0.012, 0.055, 0.06), glow_mat("Hot", hot, 2.2),
                       segs=10, rings=6, rot=tuple(Matrix((x, y, z)).transposed().to_euler()))
    face.parent = ROOT
    sparks(top + x * 0.15, hot, 9, 0.12, seed=3)


def prop_shield(center, radius, metal, rim_m, emblem_col, facing=(0.1, -1.0, 0.0)):
    c = Vector(center)
    n = Vector(facing).normalized()
    x = Vector((0, 0, 1)).cross(n).normalized()
    up = n.cross(x)
    rings_ = []
    for k, (r, off) in enumerate(((0.001, 0.05), (radius * 0.5, 0.04), (radius * 0.9, 0.015), (radius, 0.0), (radius, -0.02))):
        rings_.append([tuple(c + n * off + (x * math.cos(a) + up * math.sin(a)) * r) for a in np.linspace(0, 2 * math.pi, 40, endpoint=False)])
    own(F.loft("Shield", rings_, metal, cap_bottom=False, cap_top=True), 1)
    rim = [tuple(c + n * 0.005 + (x * math.cos(a) + up * math.sin(a)) * radius) for a in np.linspace(0, 2 * math.pi, 41)]
    own(F.tube("ShieldRim", rim, 0.018, rim_m, sides=6, cap=False))
    em = glow_mat("Emblem", emblem_col, 1.8)
    own(F.ellipsoid("Gorgon", tuple(c + n * 0.055), (radius * 0.28, 0.02, radius * 0.28), em, segs=16, rings=8,
                    rot=tuple(aim(n).to_matrix().to_euler())), thick=OUTLINE * 0.6)
    for k in range(8):
        a = 2 * math.pi * k / 8
        p0 = c + n * 0.05 + (x * math.cos(a) + up * math.sin(a)) * radius * 0.3
        p1 = c + n * 0.03 + (x * math.cos(a + 0.4) + up * math.sin(a + 0.4)) * radius * 0.55
        F.tube("Snakelet", [p0, p0.lerp(p1, 0.5) + n * 0.01, p1], [0.012, 0.01, 0.003], em, sides=5).parent = ROOT


def prop_cup(center, gold_m, wine_col):
    c = Vector(center)
    prof = [(0.03, -0.12), (0.012, -0.11), (0.01, -0.04), (0.02, -0.02), (0.11, 0.02), (0.13, 0.05), (0.125, 0.055)]
    rings_ = [F.ring((c.x, c.y, c.z + z), r, r, 24) for r, z in prof]
    own(F.loft("Kylix", rings_, gold_m, cap_bottom=True), 1)
    wine = F.ellipsoid("Wine", (c.x, c.y, c.z + 0.04), (0.115, 0.115, 0.008), glow_mat("Wine", wine_col, 1.8), segs=20, rings=6)
    wine.parent = ROOT
    motes(c + Vector((0, 0, 0.12)), wine_col, 8, 0.08, seed=9)
    for side in (-1, 1):
        h = [c + Vector((side * 0.12, 0, 0.04)), c + Vector((side * 0.17, 0, 0.06)), c + Vector((side * 0.13, 0, 0.02))]
        own(F.tube("Handle", h, 0.01, gold_m, sides=6))


def prop_wheat(body, s, stalk_col, grain_col, n=9):
    c, d = fist(body, s)
    sm = mat("Stalk", stalk_col, rim=GOD["rim"])
    gm = mat("Grain", grain_col, spec=0.4, emission=grain_col, strength=0.15, rim=GOD["rim"])
    rng = np.random.default_rng(4)
    for k in range(n):
        ang = (k - (n - 1) / 2) * 0.13 + rng.uniform(-0.04, 0.04)
        dirv = Vector((math.sin(ang), -0.15 + rng.uniform(-0.1, 0.1), math.cos(ang))).normalized()
        end = c + dirv * (0.5 + rng.uniform(-0.05, 0.08))
        own(F.tube("Stalk", [c - dirv * 0.15, c, end], 0.006, sm, sides=5))
        for g in range(7):
            t = g / 6.0
            p = end + dirv * (0.02 + 0.13 * t)
            for side in (-1, 1):
                q = p + Vector((side * 0.012, 0, 0))
                rot = aim(dirv + Vector((side * 0.5, 0, 0)))
                F.ellipsoid("Grain", tuple(q), (0.009, 0.007, 0.018), gm, segs=6, rings=4, rot=(rot.x, rot.y, rot.z)).parent = ROOT


def flame(center, height, colors=((1.0, 0.42, 0.08), (1.0, 0.72, 0.2), (1.0, 0.96, 0.75)), seed=7):
    c = Vector(center)
    rng = np.random.default_rng(seed)

    def taper(co):
        k = 1.0 - 0.85 * max(0.0, co[2]) ** 1.1
        return (co[0] * k, co[1] * k, co[2])
    for layer, col in enumerate(colors):
        gm = glow_mat("Flame%d" % layer, col, 2.0 + layer * 0.7)
        scale = 1.0 - layer * 0.3
        tongues = (5, 3, 2)[layer]
        for k in range(tongues):
            off = Vector(((k - (tongues - 1) / 2) * 0.035 * scale + rng.uniform(-0.01, 0.01), -0.012 * layer, 0))
            h = height * scale * rng.uniform(0.7, 1.05) * (1.0 - 0.25 * abs(k - (tongues - 1) / 2) / max(1, tongues))
            lean = Vector((rng.uniform(-0.15, 0.15), 0, 1)).normalized()
            rot = aim(lean)
            f = F.ellipsoid("Flame", tuple(c + off + lean * h * 0.4), (0.045 * scale, 0.035 * scale, h * 0.5), gm, segs=14, rings=10,
                            rot=(rot.x, rot.y, rot.z), shape=taper)
            f.parent = ROOT
    sparks(c + Vector((0, 0, height * 0.8)), colors[1], 10, 0.12, seed=seed, length=0.02)


def prop_ice(center, col):
    c = Vector(center)
    gm = glow_mat("Ice", col, 1.6)
    core = glow_mat("IceCore", (0.95, 1.0, 1.0), 2.2)
    rng = np.random.default_rng(12)
    for k in range(6):
        d = Vector((rng.uniform(-0.6, 0.6), rng.uniform(-0.5, 0.2), rng.uniform(0.3, 1.0))).normalized()
        ln = rng.uniform(0.1, 0.22)
        rot = aim(d)
        sh = F.ellipsoid("Shard", tuple(c + d * ln * 0.5), (0.025, 0.025, ln * 0.55), gm if k % 2 else core, segs=4, rings=3,
                         rot=(rot.x, rot.y, rot.z))
        own(sh, thick=OUTLINE * 0.6)
    for k in range(10):
        p = c + Vector(rng.normal(size=3)) * 0.14 + Vector((0, 0, 0.1))
        for a in range(3):
            d = Vector((math.cos(a * math.pi / 3), 0, math.sin(a * math.pi / 3))) * 0.018
            F.tube("Flake", [p - d, p + d], 0.003, core, sides=4).parent = ROOT


def prop_orb(center, col, radius=0.075, ring_col=None):
    c = Vector(center)
    own(F.ellipsoid("Orb", tuple(c), (radius,) * 3, glow_mat("OrbGlow", col, 1.8), segs=20, rings=12), thick=OUTLINE * 0.7)
    F.ellipsoid("OrbCore", tuple(c + Vector((-0.015, -0.03, 0.015))), (radius * 0.55,) * 3, glow_mat("OrbCore", (1, 1, 1), 2.4),
                segs=12, rings=8).parent = ROOT
    if ring_col:
        pts = [tuple(c + Vector((math.cos(a) * radius * 1.7, math.sin(a) * radius * 0.5, math.sin(a) * radius * 0.6)))
               for a in np.linspace(0, 2 * math.pi, 33)]
        F.tube("OrbRing", pts, 0.005, glow_mat("OrbRing", ring_col, 2.0), sides=4, cap=False).parent = ROOT
    motes(c, col, 10, radius * 2.2, seed=21, size=0.008)


def prop_torch(body, s, flame_cols, axis=(0.06, -0.05, 1.0)):
    c, d = fist(body, s)
    ax = Vector(axis).normalized()
    top = c + ax * 0.42
    shaft(c - ax * 0.3, top, 0.016, mat("Wood", (0.35, 0.2, 0.12)))
    cup = F.ellipsoid("TorchCup", tuple(top), (0.045, 0.045, 0.035), gold(), segs=12, rings=6)
    own(cup, 1)
    flame(top + ax * 0.02, 0.24, flame_cols, seed=s + 10)


def prop_wind(center, col):
    c = Vector(center)
    gm = glow_mat("Wind", col, 1.6)
    for k in range(4):
        pts = []
        ph = k * math.pi / 2
        for i in range(30):
            t = i / 29.0
            a = ph + t * 3.2 * math.pi
            r = 0.04 + 0.16 * t
            pts.append(c + Vector((math.cos(a) * r, math.sin(a) * r * 0.5 - 0.02, 0.06 + 0.32 * t)))
        radii = [0.004 + 0.008 * math.sin(math.pi * (i / 29.0)) for i in range(30)]
        own(F.tube("Gust", pts, radii, gm, sides=5), thick=OUTLINE * 0.5)
    motes(c + Vector((0, 0, 0.2)), col, 10, 0.12, seed=31, size=0.008)


def prop_scales(body, s, metal, glow_col):
    c, d = fist(body, s)
    top = c + Vector((0, 0, 0.06))
    own(F.tube("Rod", [c - Vector((0, 0, 0.02)), top + Vector((0, 0, 0.08))], 0.008, metal, sides=6))
    beam = [top + Vector((-0.17, 0, 0.0)), top + Vector((0, 0, 0.03)), top + Vector((0.17, 0, -0.04))]
    own(F.tube("Beam", beam, 0.01, metal, sides=6))
    em = glow_mat("PanGlow", glow_col, 1.6)
    for k, end in enumerate((beam[0], beam[2])):
        pan_c = end - Vector((0, 0, 0.17 + 0.04 * k))
        for a in range(3):
            ang = a * 2 * math.pi / 3
            F.tube("Chain", [end, pan_c + Vector((math.cos(ang) * 0.06, math.sin(ang) * 0.06, 0.01))], 0.002, metal, sides=4).parent = ROOT
        rings_ = [F.ring((pan_c.x, pan_c.y, pan_c.z + z), r, r, 20) for r, z in ((0.01, -0.02), (0.05, -0.01), (0.07, 0.01))]
        own(F.loft("Pan", rings_, metal, cap_bottom=True), 1)
        F.ellipsoid("PanLight", (pan_c.x, pan_c.y, pan_c.z + 0.012), (0.055, 0.055, 0.006), em, segs=14, rings=4).parent = ROOT


RAINBOW = [(1.0, 0.36, 0.36), (1.0, 0.64, 0.28), (1.0, 0.9, 0.35), (0.5, 0.92, 0.45), (0.35, 0.65, 1.0), (0.72, 0.45, 1.0)]


def prop_rainbow(center, radius=0.32):
    c = Vector(center)
    for k, col in enumerate(RAINBOW):
        r = radius - k * 0.022
        pts = [c + Vector((math.cos(a) * r, -0.02 * k, math.sin(a) * r)) for a in np.linspace(0.08, math.pi - 0.08, 30)]
        F.tube("Band", pts, 0.012, glow_mat("Rainbow%d" % k, col, 1.6), sides=5).parent = ROOT
    motes(c + Vector((0, 0, radius * 0.6)), (1.0, 0.85, 0.95), 12, radius * 0.6, seed=41, size=0.008)


def prop_cornucopia(body, s, horn_col, coin_col):
    c, d = fist(body, s)
    hm = mat("Horn", horn_col, spec=0.6, rim=GOD["rim"])
    pts, radii = [], []
    for k in range(14):
        t = k / 13.0
        a = t * 1.9
        pts.append(c + Vector((-0.2 * math.cos(a) * s + 0.2 * s, -0.08 * t, -0.15 + 0.32 * math.sin(a) + 0.1 * t)))
        radii.append(0.008 + 0.075 * t ** 1.4)
    own(F.tube("Cornucopia", pts, radii, hm, sides=14), 1)
    for k in range(8):
        t = k / 7.0
        ring_band(pts[0].lerp(pts[-1], t) if False else pts[min(13, int(t * 13))], (pts[min(13, int(t * 13) + 1)] - pts[max(0, int(t * 13) - 1)]),
                  radii[min(13, int(t * 13))] * 1.02, 0.006, gold(), ROOT)
    mouth = pts[-1]
    cm = mat("Coin", coin_col, spec=1.2, emission=coin_col, strength=0.25, rim=GOD["rim"])
    rng = np.random.default_rng(8)
    for k in range(14):
        p = mouth + Vector((rng.uniform(-0.07, 0.07), rng.uniform(-0.06, 0.03), rng.uniform(-0.02, 0.1)))
        coin = F.ellipsoid("Coin", tuple(p), (0.028, 0.028, 0.006), cm, segs=14, rings=4,
                           rot=(rng.uniform(0, 3), rng.uniform(0, 3), 0))
        own(coin, thick=OUTLINE * 0.5)
    motes(mouth + Vector((0, 0, 0.1)), coin_col, 10, 0.1, seed=17)


# ---------------------------------------------------------------- headgear & wings

def helmet(head, metal, crest_col, crest=True, cheeks=True, up=0.0):
    R = head.R
    e = empty("Helmet", (0, 0, up * 0.06), (-up * 0.35, 0, 0), head.e)

    def shape(co):
        x, y, z = co
        if z < 0.1 and y < -0.2 and abs(x) < 0.75:
            y = y * 0.1 + 0.2
        return (x, y, z)
    dome = F.ellipsoid("Dome", (0, 0.004, 0.035), (R.x * 1.16, R.y * 1.14, R.z * 1.08), metal, segs=28, rings=14, shape=shape)
    dome.parent = e
    ink(dome, 1)
    if cheeks:
        for side in (-1, 1):
            ch = F.ellipsoid("Cheek", (side * R.x * 0.95, -R.y * 0.35, -0.05), (0.03, 0.07, 0.075), metal, segs=12, rings=6,
                             rot=(0.2, 0, side * 0.3))
            ch.parent = e
            ink(ch, 1)
    band = [Vector((math.cos(a) * R.x * 1.17, math.sin(a) * R.y * 1.15, 0.035)) for a in np.linspace(0, 2 * math.pi, 33)]
    b = F.tube("Rim", band, 0.01, gold(), sides=6, cap=False)
    b.parent = e
    if crest:
        cm = mat("Crest", crest_col, rim=GOD["rim"], rim_strength=0.4)
        pts = [Vector((0, -R.y * 0.6, R.z * 1.05)), Vector((0, -0.02, R.z * 1.4)), Vector((0, R.y * 0.8, R.z * 1.3)),
               Vector((0, R.y * 1.45, R.z * 0.6)), Vector((0, R.y * 1.7, -0.05))]
        c = F.tube("Crest", pts, [0.03, 0.05, 0.05, 0.04, 0.012], cm, sides=10, flat=0.35, widths=[Vector((0, 0, 1))] * 5)
        c.parent = e
        ink(c, 1)
        holder = F.tube("CrestHolder", pts[:3], 0.012, gold(), sides=6)
        holder.parent = e


def winged_cap(head, metal):
    R = head.R
    cap = F.ellipsoid("Cap", (0, 0.01, 0.05), (R.x * 1.12, R.y * 1.12, R.z * 0.82), metal, segs=24, rings=12,
                      shape=lambda co: (co[0], co[1], max(co[2], -0.1)))
    parent(cap, head.e)
    ink(cap, 1)
    for side in (-1, 1):
        base = Vector((side * R.x * 1.05, 0.0, 0.07))
        m = mat("Feather", (1.0, 1.0, 1.0), rim=GOD["rim"], rim_strength=0.4)
        for k in range(4):
            d = Vector((side * (0.8 - 0.1 * k), 0.3 + 0.15 * k, 0.6 - 0.25 * k)).normalized()
            ln = 0.12 - 0.015 * k
            rot = aim(d)
            f = F.ellipsoid("CapWing", tuple(base + d * ln * 0.5), (0.016, 0.007, ln * 0.5), m, segs=8, rings=5, rot=(rot.x, rot.y, rot.z))
            parent(f, head.e)
            ink(f, 1, thickness=OUTLINE * 0.5)


def hood(head, color, trim_col, body=None):
    R = head.R
    m = mat("Hood", color, rim=GOD["rim"], rim_strength=0.35)

    def shape(co):
        x, y, z = co
        if y < -0.15 and z < 0.55:
            y = -0.15 + (y + 0.15) * 0.1
            x = x * 1.02
        return (x, y, z)
    h = F.ellipsoid("Hood", (0, 0.03, 0.03), (R.x * 1.32, R.y * 1.25, R.z * 1.25), m, segs=32, rings=16, shape=shape)
    parent(h, head.e)
    ink(h, 1)
    edge = []
    for a in np.linspace(-1.0, 1.0, 15):
        ang = a * 1.35
        edge.append(Vector((math.sin(ang) * R.x * 1.3, -R.y * 0.23, 0.03 + math.cos(ang) * R.z * 1.2)))
    t = F.tube("HoodTrim", edge, 0.012, mat("HoodTrim", trim_col, spec=0.8, rim=GOD["rim"]), sides=6)
    parent(t, head.e)
    cape = [Vector((0, R.y * 0.9, -0.05)), Vector((0, R.y * 1.3, -0.25)), Vector((0, R.y * 1.4, -0.55))]
    c = F.tube("HoodCape", cape, [0.12, 0.2, 0.26], m, sides=14, flat=0.45)
    parent(c, head.e)
    ink(c, 1)


def crown_spikes(head, metal, tip_col, n=7):
    R = head.R
    band = [Vector((math.cos(a) * R.x * 1.08, math.sin(a) * R.y * 1.06, 0.07 + 0.02 * math.sin(a))) for a in np.linspace(0, 2 * math.pi, 33)]
    b = F.tube("CrownBand", band, 0.016, metal, sides=6, cap=False)
    parent(b, head.e)
    ink(b, 0, thickness=OUTLINE * 0.6)
    tm = glow_mat("SpikeTip", tip_col, 1.4)
    for k in range(n):
        a = math.radians(-90 - 70 + 140 * k / (n - 1))
        base = Vector((math.cos(a) * R.x * 1.08, math.sin(a) * R.y * 1.06, 0.08))
        ln = 0.13 if k == n // 2 else 0.09
        sp = F.tube("Spike", [base, base + Vector((math.cos(a) * 0.02, math.sin(a) * 0.02, ln))], [0.022, 0.002], tm if k % 2 == 0 else metal, sides=5)
        parent(sp, head.e)
        ink(sp, 0, thickness=OUTLINE * 0.6)


def wreath(head, leaf_col, berry_col=None, emissive=0.1, n=22, leaf=(0.014, 0.03, 0.004)):
    lm = mat("WreathLeaf", leaf_col, spec=0.4, emission=leaf_col, strength=emissive, rim=GOD["rim"])
    bm = mat("Berry", berry_col, spec=0.8, rim=GOD["rim"]) if berry_col else None
    for i in range(n):
        t = i / (n - 1)
        u = math.radians(-150 + 300 * t) + math.pi
        p, d = head.scalp(u, math.radians(36 if abs(math.cos(u)) < 0.6 else 30), 0.06, grow=1.03)
        for layer in (-1, 1):
            lf = F.ellipsoid("WLeaf", tuple(p + Vector((0, 0, 0.01 * layer))), leaf, lm, segs=8, rings=4,
                             rot=(0.5 * layer, 0.0, u + (math.pi / 2 if u > math.pi else -math.pi / 2)))
            parent(lf, head.e)
            ink(lf, 0, thickness=OUTLINE * 0.45)
        if bm and i % 4 == 2:
            for g in range(5):
                q = p + Vector((0.012 * (g % 2), -0.006, -0.015 * g - 0.02))
                gr = F.ellipsoid("Grape", tuple(q), (0.013, 0.013, 0.013), bm, segs=8, rings=5)
                parent(gr, head.e)
                ink(gr, 0, thickness=OUTLINE * 0.4)


def crescent(center, size, col, rot=(0, 0, 0), strength=1.8, inner=0.8, offset=0.3, n=28):
    """Crescent moon slab in the XZ plane (horns pointing to +x), facing -y."""
    xi = (1 - inner * inner + offset * offset) / (2 * offset)
    yi = math.sqrt(max(0.0, 1 - xi * xi))
    ao0 = math.atan2(yi, xi)
    ai0 = math.atan2(yi, xi - offset)
    verts, faces = [], []
    for k in range(n):
        t = k / (n - 1)
        ao = ao0 + t * (2 * math.pi - 2 * ao0)
        ai = ai0 + t * (2 * math.pi - 2 * ai0)
        verts.append((math.cos(ao) * size, 0.0, math.sin(ao) * size))
        verts.append(((offset + inner * math.cos(ai)) * size, 0.0, inner * math.sin(ai) * size))
    for k in range(n - 1):
        a0, b0, a1, b1 = 2 * k, 2 * k + 1, 2 * k + 2, 2 * k + 3
        faces.append((a0, a1, b1, b0))
    ob = F.mesh_object("Crescent", verts, faces, [glow_mat("Crescent", col, strength)], smooth=False)
    ob.modifiers.new("Thick", "SOLIDIFY").thickness = 0.03
    ob.location = center
    ob.rotation_euler = rot
    ob.parent = ROOT
    ink(ob, 0, thickness=OUTLINE * 0.7)
    return ob


def mural_crown(head, metal):
    R = head.R
    band = [Vector((math.cos(a) * R.x * 1.08, math.sin(a) * R.y * 1.06, 0.07)) for a in np.linspace(0, 2 * math.pi, 33)]
    b = F.tube("Mural", band, 0.014, metal, sides=6, cap=False)
    parent(b, head.e)
    ink(b, 0, thickness=OUTLINE * 0.6)
    for k in range(12):
        a = 2 * math.pi * k / 12
        p = Vector((math.cos(a) * R.x * 1.08, math.sin(a) * R.y * 1.06, 0.105))
        tall = 0.05 if k % 3 == 0 else 0.035
        tw = F.ellipsoid("Tower", tuple(p + Vector((0, 0, tall * 0.3))), (0.022, 0.014, tall), metal, segs=4, rings=2,
                         rot=(0, 0, a + math.pi / 4))
        parent(tw, head.e)
        ink(tw, 0, thickness=OUTLINE * 0.5)


def wings(body, cols, span=0.75, lift=0.35, droop=0.0, glow=False):
    """Big feathered wings from the upper back, spread behind the god."""
    for side in (-1, 1):
        root_p = Vector((side * 0.08, 0.14, 1.42))
        path = []
        for k in range(8):
            t = k / 7.0
            path.append(root_p + Vector((side * span * t, 0.12 * t, lift * math.sin(t * 2.2) - droop * t * t)))
        for row, (ln0, ln1, w, col) in enumerate(((0.12, 0.16, 0.035, cols[0]), (0.22, 0.32, 0.038, cols[min(1, len(cols) - 1)]),
                                                  (0.3, 0.55, 0.042, cols[-1]))):
            count = 9 + row * 3
            for k in range(count):
                t = (k + 0.5) / count
                p = path[0].lerp(path[-1], t)
                idx = t * 7
                i0 = min(int(idx), 6)
                p = path[i0].lerp(path[i0 + 1], idx - i0)
                ln = ln0 + (ln1 - ln0) * t
                d = Vector((side * (0.35 + 0.5 * t), 0.15, -1.0 + 0.25 * t)).normalized()
                c = col if not isinstance(col, list) else col[k % len(col)]
                key = "Wing%d_%d_%d" % (row, k % 6 if isinstance(col, list) else 0, side)
                m = glow_mat(key, c, 1.2) if glow else mat("Wing%s" % str(c), c, rim=GOD["rim"], rim_strength=0.45)
                rot = aim(d)
                f = F.ellipsoid("Feather", tuple(p + d * ln * 0.5 + Vector((0, 0.012 * row, -0.02 * row))), (w * 0.75, 0.008, ln * 0.5), m,
                                segs=10, rings=8, rot=(rot.x, rot.y, rot.z),
                                shape=lambda co: (co[0] * (1.0 - 0.8 * max(0.0, -co[2]) ** 1.5), co[1], co[2]))
                own(f, 1, thick=OUTLINE * 0.6)


def bun(head, material, size=0.07):
    p, d = head.scalp(math.pi, math.radians(20), 0.25)
    b = F.ellipsoid("Bun", tuple(p), (size, size * 0.9, size * 0.85), material, segs=16, rings=8)
    parent(b, head.e)
    ink(b, 1)


def ponytail(head, material, length=0.5):
    p, d = head.scalp(math.pi, math.radians(35), 0.1)
    pts = [p, p + Vector((0, 0.06, -0.05)), p + Vector((0.02, 0.1, -0.2)), p + Vector((0.0, 0.11, -length * 0.7)), p + Vector((-0.02, 0.1, -length))]
    lock(head, pts, [0.04, 0.05, 0.045, 0.035, 0.004], material, flat=0.7, sides=10)


def side_locks(head, material, n=3, length=0.25):
    for side in (-1, 1):
        for k in range(n):
            u = side * math.radians(70 + 20 * k)
            top, _ = head.scalp(u, math.radians(30), 0.05)
            pts = [top]
            for i in range(1, 5):
                t = i / 4.0
                pts.append(top + Vector((side * 0.02 * t, 0.02 * t, -length * t)) + Vector((0.01 * math.sin(t * 6 + k), 0, 0)))
            lock(head, pts, [0.026, 0.028, 0.024, 0.016, 0.003], material, flat=0.5)


def front_sweep(head, material, n=5, lift=0.25):
    """Locks from the forehead swept back over the top."""
    for k in range(n):
        x = (k - (n - 1) / 2) * 0.03
        pts = [Vector((x, head.front(x, head.R.z * 0.55, -0.01), head.R.z * 0.55)), Vector((x * 1.2, -0.05, head.R.z * 1.12)),
               Vector((x * 1.4, 0.06, head.R.z * 1.12 + 0.02)), Vector((x * 1.6, head.R.y * 1.05, head.R.z * 0.8 + lift * 0.1))]
        lock(head, pts, [0.03, 0.036, 0.03, 0.006], material, flat=0.5)


def wild_hair(head, material, n=16, length=0.2, seed=3):
    rng = np.random.default_rng(seed)
    for k in range(n):
        u = rng.uniform(math.pi * 0.25, math.pi * 1.75)
        v = rng.uniform(math.radians(-10), math.radians(70))
        p, d = head.scalp(u, v, 0.02)
        out = (d + Vector((0, 0.6, 0.35))).normalized()
        pts = [p, p + out * length * 0.4 + Vector((0, 0, 0.02)), p + out * length + Vector((rng.uniform(-0.03, 0.03), 0.02, rng.uniform(-0.03, 0.05)))]
        lock(head, pts, [0.034, 0.026, 0.002], material, flat=0.5)


# ---------------------------------------------------------------- gods

def base(spec_skin_rim=True):
    body = Body(GOD, ROOT)
    head = Head(GOD, ROOT, body)
    return body, head


def hair_mat(col, shine=0.35):
    return mat("Hair", col, spec=shine, gloss=0.3, rim=GOD["rim"], rim_strength=0.45)


def zeus():
    body, head = base()
    white = mat("HairW", (0.95, 0.96, 1.0), shadow=(0.56, 0.62, 0.8), spec=0.35, rim=GOD["rim"], rim_strength=0.5)
    hair_cap(head, white, front_v=0.55)
    long_hair(head, white, n=14, length=0.36, wave=0.025)
    beard(head, white, length=0.17, width=1.08)
    wreath(head, (1.0, 0.82, 0.3), emissive=0.3)
    himation(body, (0.97, 0.96, 0.93), (1.0, 0.8, 0.3), side=1)
    body.armband(-1, gold())
    fist(body, 1)
    prop_bolt(body, -1)


def poseidon():
    body, head = base()
    hair = mat("HairSea", (0.2, 0.62, 0.62), shadow=(0.06, 0.25, 0.32), spec=0.5, rim=GOD["rim"], rim_strength=0.5)
    hair_cap(head, hair, front_v=0.5)
    long_hair(head, hair, n=16, length=0.42, wave=0.04, spread=1.3)
    beard(head, hair, length=0.15, width=1.05)
    crown_spikes(head, gold(), (0.5, 1.0, 0.95))
    himation(body, (0.12, 0.52, 0.6), (1.0, 0.8, 0.32), side=1)
    body.armband(-1, gold())
    fist(body, 1)
    prop_trident(body, -1, gold(), (0.45, 1.0, 0.95))


def ares():
    body, head = base()
    hair = hair_mat((0.12, 0.06, 0.05))
    helmet(head, mat("Helm", (0.62, 0.34, 0.14), spec=0.5, gloss=0.4, rim=GOD["rim"]), (0.85, 0.08, 0.08), cheeks=False, up=0.0)
    cuirass(body, (0.42, 0.22, 0.12), (1.0, 0.72, 0.3))
    cape_back(body, (0.75, 0.06, 0.08))
    fist(body, 1)
    prop_sword(body, -1, (0.82, 0.84, 0.9), (1.0, 0.25, 0.15), direction=(0.25, -0.25, 1.0))


def cape_back(body, color):
    cm = mat("Cape", color, rim=GOD["rim"], rim_strength=0.4)
    for side in (-1, 1):
        S = body.shoulder[side]
        pts = [S + Vector((0, 0.06, 0.03)), S + Vector((side * 0.05, 0.14, -0.3)), S + Vector((side * 0.08, 0.18, -0.65))]
        c = F.tube("Cape", pts, [0.09, 0.14, 0.17], cm, sides=14, flat=0.35)
        own(c, 1)


def apolo():
    body, head = base()
    hair = mat("HairGold", (1.0, 0.8, 0.35), shadow=(0.75, 0.42, 0.15), spec=0.6, rim=GOD["rim"], rim_strength=0.5)
    hair_cap(head, hair, front_v=0.6)
    curly_top(head, hair, n=22, size=0.036)
    side_locks(head, hair, n=2, length=0.2)
    wreath(head, (1.0, 0.85, 0.3), emissive=0.35)
    sun_halo(head.C + Vector((0, 0.18, 0.02)), 0.3, (1.0, 0.75, 0.25))
    himation(body, (1.0, 0.94, 0.8), (1.0, 0.7, 0.2), side=1)
    c, d = fist(body, -1)
    fist(body, 1)
    prop_lyre(c + Vector((0.12, -0.1, 0.06)), gold(), (1.0, 0.9, 0.5))


def sun_halo(center, radius, col):
    c = Vector(center)
    gm = glow_mat("Sun", col, 1.4)
    core = glow_mat("SunCore", (1.0, 0.82, 0.4), 1.5)
    rings_ = [[tuple(c + Vector((math.cos(a) * r, 0.0, math.sin(a) * r))) for a in np.linspace(0, 2 * math.pi, 48, endpoint=False)] for r in (radius * 0.98, radius)]
    for k in range(16):
        a = 2 * math.pi * k / 16
        ln = 0.14 if k % 2 == 0 else 0.08
        p0 = c + Vector((math.cos(a), 0, math.sin(a))) * radius * 1.05
        p1 = c + Vector((math.cos(a), 0, math.sin(a))) * (radius * 1.05 + ln)
        F.tube("Ray", [p0, p1], [0.022, 0.002], gm, sides=4).parent = ROOT
    pts = [tuple(c + Vector((math.cos(a) * radius, 0.0, math.sin(a) * radius))) for a in np.linspace(0, 2 * math.pi, 49)]
    F.tube("SunRing", pts, 0.018, core, sides=6, cap=False).parent = ROOT


def hermes():
    body, head = base()
    hair = hair_mat((0.42, 0.24, 0.12))
    hair_cap(head, hair, front_v=0.55)
    side_locks(head, hair, n=2, length=0.1)
    for k in range(9):
        u = math.radians(-120 + 240 * k / 8) + math.pi
        p, d = head.scalp(u, math.radians(8), 0.12)
        curl = F.ellipsoid("Curl", tuple(p), (0.03, 0.03, 0.026), hair, segs=10, rings=6)
        parent(curl, head.e)
        ink(curl, subsurf=1, thickness=OUTLINE * 0.7)
    winged_cap(head, gold((0.95, 0.85, 0.5)))
    chlamys(body, (0.95, 0.55, 0.15))
    fist(body, 1)
    prop_caduceus(body, -1, gold(), (0.3, 0.6, 0.3), (1.0, 1.0, 0.85))


def chlamys(body, color):
    cm = mat("Chlamys", color, rim=GOD["rim"], rim_strength=0.35)
    for side in (-1, 1):
        S = body.shoulder[side]
        pts = [S + Vector((-side * 0.03, 0.02, 0.05)), S + Vector((side * 0.03, 0.12, -0.2)), S + Vector((side * 0.06, 0.16, -0.55))]
        own(F.tube("Chlamys", pts, [0.08, 0.13, 0.15], cm, sides=14, flat=0.35), 1)
    pin = F.ellipsoid("Pin", tuple(body.shoulder[1] + Vector((-0.05, -0.08, 0.0))), (0.03, 0.014, 0.03), gold(), segs=10, rings=6)
    own(pin, 1)
    _, rx, ry = torso_front(0, 1.47, False, 1.0, 0.0)
    drape = [Vector((math.cos(a) * (rx + 0.06), math.sin(a) * (ry + 0.06), 1.47 - 0.03 * math.sin(a))) for a in np.linspace(0.3, math.pi - 0.3, 12)]
    own(F.tube("Collar", drape, 0.035, cm, sides=10, flat=0.5), 1)


def artemis():
    body, head = base()
    hair = hair_mat((0.55, 0.26, 0.12))
    hair_cap(head, hair, front_v=0.6)
    front_sweep(head, hair, n=4)
    ponytail(head, hair, length=0.55)
    side_locks(head, hair, n=1, length=0.16)
    crescent(head.C + Vector((0, -0.125, 0.13)), 0.045, (0.85, 0.95, 1.0), rot=(0, 0, -0.5))
    dress(body, (0.3, 0.55, 0.3), (0.95, 0.9, 0.7), folds=8)
    strap = [Vector((0.16, -0.06, 1.47)), Vector((0.0, -0.12, 1.3)), Vector((-0.16, -0.08, 1.08))]
    own(F.tube("Quiver", strap, 0.016, mat("Leather", (0.42, 0.24, 0.12)), sides=6, flat=0.4))
    fist(body, 1)
    prop_bow(body, -1, mat("BowWood", (0.55, 0.38, 0.2), spec=0.4, rim=GOD["rim"]), (0.75, 1.0, 0.7))


def hefesto():
    body, head = base()
    hair = hair_mat((0.14, 0.08, 0.06))
    hair_cap(head, hair, front_v=0.65)
    wild_hair(head, hair, n=10, length=0.12, seed=4)
    beard(head, hair, length=0.11, width=1.12)
    apron = mat("Apron", (0.36, 0.2, 0.12), rim=GOD["rim"], rim_strength=0.25)
    rings_ = []
    for z in (0.9, 1.0, 1.12, 1.24, 1.34):
        _, rx, ry = torso_front(0, z, False, GOD["bulk"], 0.0)
        rings_.append([[math.cos(a) * (rx + 0.025), math.sin(a) * (ry + 0.025), z] for a in np.linspace(math.pi * 1.15, math.pi * 1.85, 16)])
    own(F.loft("Apron", rings_, apron, closed=False), 1)
    for side in (-1, 1):
        st = [Vector((side * 0.11, -0.12, 1.34)), Vector((side * 0.13, -0.05, 1.5)), Vector((side * 0.1, 0.08, 1.5))]
        own(F.tube("ApronStrap", st, 0.014, apron, sides=6, flat=0.4))
    body.bracer(-1, (0.3, 0.17, 0.1), gold((0.75, 0.5, 0.25)))
    fist(body, 1)
    prop_hammer(body, -1, mat("Iron", (0.35, 0.33, 0.36), spec=0.9, rim=GOD["rim"]), (1.0, 0.45, 0.1))
    sparks(Vector((-0.1, -0.3, 1.25)), (1.0, 0.6, 0.2), 8, 0.2, seed=6)


def atena():
    body, head = base()
    hair = hair_mat((0.3, 0.2, 0.14))
    hair_cap(head, hair, front_v=0.6)
    side_locks(head, hair, n=2, length=0.24)
    long_hair(head, hair, n=10, length=0.35, wave=0.02)
    helmet(head, mat("Helm", (0.85, 0.85, 0.9), spec=1.2, gloss=0.18, rim=GOD["rim"]), (0.25, 0.45, 0.9), cheeks=False, up=1.0)
    dress(body, (0.9, 0.9, 0.95), (1.0, 0.8, 0.3), folds=9)
    aegis(body)
    fist(body, -1)
    c, d = body.hands[-1]
    shaft(c - Vector((0, 0, 0.6)), c + Vector((0.03, -0.03, 0.62)), 0.015, mat("SpearWood", (0.45, 0.3, 0.18)))
    tip = c + Vector((0.03, -0.03, 0.62))
    own(F.tube("SpearTip", [tip, tip + Vector((0.006, -0.006, 0.16))], [0.035, 0.001], mat("SpearHead", (0.9, 0.9, 0.95), spec=1.2), sides=4))
    fist(body, 1)
    prop_shield(body.hands[1][0] + Vector((0.06, -0.1, -0.05)), 0.27, mat("ShieldMetal", (0.82, 0.7, 0.4), spec=1.0, rim=GOD["rim"]),
                gold(), (0.6, 0.85, 1.0), facing=(0.5, -1.0, 0.1))


def aegis(body):
    m = mat("Aegis", (0.9, 0.78, 0.4), spec=1.0, rim=GOD["rim"])
    for row in range(3):
        z = 1.44 - row * 0.05
        n = 9 - row
        for k in range(n):
            x = (k - (n - 1) / 2) * 0.04
            y, rx, ry = torso_front(x, z, True, 1.0, 0.02)
            sc = F.ellipsoid("Scale", (x, y, z), (0.022, 0.008, 0.026), m, segs=8, rings=4)
            own(sc, 0, thick=OUTLINE * 0.4)


def dionisio():
    body, head = base()
    hair = hair_mat((0.25, 0.12, 0.25))
    hair_cap(head, hair, front_v=0.58)
    curly_top(head, hair, n=18, size=0.034)
    side_locks(head, hair, n=2, length=0.22)
    wreath(head, (0.45, 0.75, 0.25), berry_col=(0.55, 0.18, 0.6), emissive=0.05, leaf=(0.02, 0.034, 0.005))
    himation(body, (0.55, 0.2, 0.6), (1.0, 0.8, 0.32), side=1)
    fist(body, 1)
    c, d = fist(body, -1)
    prop_cup(c + Vector((0.02, -0.04, 0.12)), gold(), (0.8, 0.3, 1.0))


def demeter():
    body, head = base()
    hair = mat("HairBlond", (0.98, 0.78, 0.4), shadow=(0.7, 0.42, 0.18), spec=0.5, rim=GOD["rim"], rim_strength=0.45)
    hair_cap(head, hair, front_v=0.6)
    long_hair(head, hair, n=12, length=0.4, wave=0.03)
    side_locks(head, hair, n=2, length=0.3)
    wreath(head, (1.0, 0.82, 0.35), emissive=0.2, leaf=(0.008, 0.035, 0.006))
    dress(body, (0.55, 0.72, 0.3), (1.0, 0.82, 0.35), folds=10)
    fist(body, 1)
    prop_wheat(body, -1, (0.72, 0.62, 0.3), (1.0, 0.84, 0.4))


def hestia():
    body, head = base()
    hair = hair_mat((0.32, 0.17, 0.1))
    hair_cap(head, hair, front_v=0.62)
    hood(head, (0.62, 0.22, 0.12), (1.0, 0.75, 0.3))
    dress(body, (0.85, 0.45, 0.2), (1.0, 0.8, 0.35), folds=10, sleeves=True)
    c1, _ = fist(body, -1)
    c2, _ = fist(body, 1)
    flame(c1.lerp(c2, 0.5) + Vector((0, -0.05, 0.04)), 0.32)


def boreas():
    body, head = base()
    ice_hair = mat("HairIce", (0.86, 0.95, 1.0), shadow=(0.45, 0.62, 0.85), spec=0.6, rim=GOD["rim"], rim_strength=0.6)
    hair_cap(head, ice_hair, front_v=0.5)
    wild_hair(head, ice_hair, n=16, length=0.16, seed=7)
    long_hair(head, ice_hair, n=10, length=0.3, wave=0.03)
    beard(head, ice_hair, length=0.18, width=1.1)
    wings(body, [(0.75, 0.9, 1.0), (0.6, 0.82, 1.0), (0.85, 0.95, 1.0)], span=0.7, lift=0.4)
    himation(body, (0.55, 0.75, 0.95), (0.85, 0.95, 1.0), side=1)
    fist(body, 1)
    c, d = fist(body, -1)
    prop_ice(c + Vector((0.0, -0.04, 0.03)), (0.6, 0.9, 1.0))


def selene():
    body, head = base()
    hair = mat("HairSilver", (0.85, 0.85, 0.98), shadow=(0.45, 0.45, 0.68), spec=0.6, rim=GOD["rim"], rim_strength=0.5)
    hair_cap(head, hair, front_v=0.6)
    long_hair(head, hair, n=14, length=0.48, wave=0.03, spread=1.2)
    side_locks(head, hair, n=2, length=0.32)
    crescent(head.C + Vector((0.0, 0.2, 0.08)), 0.27, (0.85, 0.88, 1.0), rot=(0, 0, 0.5), strength=1.4)
    dress(body, (0.62, 0.6, 0.85), (0.9, 0.92, 1.0), folds=9)
    fist(body, 1)
    c, d = fist(body, -1)
    prop_orb(c + Vector((0.02, -0.06, 0.1)), (0.85, 0.9, 1.0), 0.07, ring_col=(0.7, 0.75, 1.0))


def hecate():
    body, head = base()
    hair = hair_mat((0.12, 0.06, 0.14))
    hair_cap(head, hair, front_v=0.62)
    side_locks(head, hair, n=2, length=0.3)
    hood(head, (0.3, 0.12, 0.4), (0.75, 0.5, 1.0))
    crescent(head.C + Vector((0, -0.14, 0.13)), 0.04, (0.85, 0.6, 1.0), rot=(0, 0, -0.5))
    dress(body, (0.25, 0.1, 0.32), (0.75, 0.5, 1.0), folds=8, sleeves=True)
    fist(body, 1)
    prop_torch(body, -1, ((0.55, 0.15, 0.85), (0.8, 0.45, 1.0), (1.0, 0.9, 1.0)))
    motes(Vector((0.0, -0.25, 1.3)), (0.75, 0.45, 1.0), 14, 0.25, seed=13)


def eolo():
    body, head = base()
    hair = mat("HairWind", (0.88, 0.92, 0.95), shadow=(0.5, 0.58, 0.68), spec=0.4, rim=GOD["rim"], rim_strength=0.5)
    hair_cap(head, hair, front_v=0.55)
    for k in range(12):
        u = math.radians(40 + 280 * k / 11)
        p, d = head.scalp(u, math.radians(35), 0.03)
        pts = [p, p + Vector((0.12, 0.05, 0.03)), p + Vector((0.26, 0.08, 0.06 + 0.02 * math.sin(k)))]
        lock(head, pts, [0.03, 0.022, 0.002], hair, flat=0.5)
    beard(head, hair, length=0.08, width=1.0, curls=False)
    himation(body, (0.75, 0.9, 0.92), (0.9, 0.95, 1.0), side=1)
    fist(body, 1)
    c, d = fist(body, -1)
    prop_wind(c + Vector((0.02, -0.04, 0.0)), (0.82, 0.98, 1.0))


def nemesis():
    body, head = base()
    hair = hair_mat((0.1, 0.05, 0.06))
    hair_cap(head, hair, front_v=0.6)
    long_hair(head, hair, n=12, length=0.42, wave=0.02)
    side_locks(head, hair, n=2, length=0.3)
    wings(body, [(0.25, 0.12, 0.16), (0.32, 0.12, 0.18), (0.4, 0.1, 0.14)], span=0.72, lift=0.45, droop=0.1)
    dress(body, (0.55, 0.1, 0.12), (0.95, 0.75, 0.35), folds=8)
    crown_spikes(head, gold((0.8, 0.6, 0.3)), (1.0, 0.3, 0.25), n=5)
    prop_sword(body, 1, (0.75, 0.75, 0.8), (1.0, 0.25, 0.2), direction=(-0.15, -0.3, -1.0), length=0.6)
    prop_scales(body, -1, gold(), (1.0, 0.45, 0.35))


def iris():
    body, head = base()
    hair = mat("HairRose", (0.98, 0.55, 0.75), shadow=(0.65, 0.25, 0.5), spec=0.5, rim=GOD["rim"], rim_strength=0.5)
    hair_cap(head, hair, front_v=0.6)
    long_hair(head, hair, n=12, length=0.4, wave=0.03)
    side_locks(head, hair, n=2, length=0.26)
    wings(body, [RAINBOW, RAINBOW, RAINBOW], span=0.68, lift=0.45, glow=False)
    dress(body, (0.98, 0.88, 0.95), (1.0, 0.8, 0.5), folds=9)
    fist(body, 1)
    c, d = fist(body, -1)
    prop_rainbow(c + Vector((0.08, -0.05, 0.05)), 0.28)


def tique():
    body, head = base()
    hair = hair_mat((0.42, 0.22, 0.1))
    hair_cap(head, hair, front_v=0.6)
    bun(head, hair)
    side_locks(head, hair, n=2, length=0.22)
    mural_crown(head, gold())
    dress(body, (0.95, 0.75, 0.3), (1.0, 0.92, 0.6), folds=9)
    fist(body, 1)
    prop_cornucopia(body, -1, (0.75, 0.55, 0.25), (1.0, 0.82, 0.3))


RAISE = {"elbow": (-0.34, -0.03, 1.56), "wrist": (-0.3, -0.08, 1.79), "hand": (0.05, -0.15, 1.0)}
RAISE_F = {"elbow": (-0.29, -0.03, 1.53), "wrist": (-0.26, -0.08, 1.74), "hand": (0.05, -0.15, 1.0)}
STAFF = {"elbow": (-0.33, -0.05, 1.24), "wrist": (-0.29, -0.17, 1.36), "hand": (0.0, -0.3, 1.0)}
STAFF_F = {"elbow": (-0.28, -0.05, 1.23), "wrist": (-0.24, -0.16, 1.34), "hand": (0.0, -0.3, 1.0)}
FRONT = {"elbow": (-0.3, -0.1, 1.2), "wrist": (-0.14, -0.28, 1.28), "hand": (0.5, -0.4, 0.4)}
FRONT_F = {"elbow": (-0.25, -0.1, 1.2), "wrist": (-0.11, -0.26, 1.27), "hand": (0.5, -0.4, 0.4)}
REST = {"elbow": (0.3, 0.02, 1.22), "wrist": (0.2, -0.14, 1.06), "hand": (-0.6, -0.5, -0.2)}
REST_F = {"elbow": (0.25, 0.02, 1.2), "wrist": (0.17, -0.12, 1.05), "hand": (-0.6, -0.5, -0.2)}
CUP_F = {"elbow": (0.26, -0.08, 1.2), "wrist": (0.1, -0.26, 1.27), "hand": (-0.5, -0.4, 0.4)}

GODS = {
    "zeus": dict(build=zeus, sex="m", color=(0.55, 0.85, 1.0), rim=(0.6, 0.85, 1.0), skin=(0.96, 0.74, 0.6),
                 skin_shadow=(0.62, 0.38, 0.44), brow=(0.95, 0.96, 1.0), eyes=(0.6, 0.92, 1.0), head_rot=(0.06, -0.12),
                 arms={-1: RAISE, 1: REST}),
    "poseidon": dict(build=poseidon, sex="m", color=(0.25, 0.75, 0.9), rim=(0.3, 0.95, 0.9), skin=(0.82, 0.6, 0.48),
                     skin_shadow=(0.45, 0.3, 0.36), brow=(0.2, 0.6, 0.6), eyes=(0.4, 1.0, 0.95), head_rot=(0.02, -0.15),
                     arms={-1: STAFF, 1: REST}),
    "ares": dict(build=ares, sex="m", color=(1.0, 0.35, 0.3), rim=(1.0, 0.35, 0.25), skin=(0.88, 0.6, 0.47),
                 skin_shadow=(0.5, 0.26, 0.28), brow=(0.15, 0.07, 0.05), eyes=(1.0, 0.4, 0.25), head_rot=(0.0, -0.1),
                 bare_chest=False, arms={-1: RAISE, 1: REST}),
    "apolo": dict(build=apolo, sex="m", color=(1.0, 0.7, 0.26), rim=(1.0, 0.75, 0.3), skin=(1.0, 0.8, 0.64),
                  skin_shadow=(0.7, 0.45, 0.4), brow=(0.85, 0.6, 0.25), eyes=(1.0, 0.85, 0.4), head_rot=(0.05, -0.18),
                  bulk=0.92, arms={-1: FRONT, 1: CUP_F}),
    "hermes": dict(build=hermes, sex="m", color=(0.96, 0.94, 0.86), rim=(1.0, 0.95, 0.75), skin=(0.95, 0.74, 0.58),
                   skin_shadow=(0.6, 0.38, 0.38), brow=(0.35, 0.2, 0.1), eyes=(1.0, 0.95, 0.7), head_rot=(0.05, -0.2),
                   bulk=0.9, arms={-1: STAFF, 1: REST}),
    "artemis": dict(build=artemis, sex="f", color=(0.6, 0.9, 0.42), rim=(0.65, 1.0, 0.55), skin=(0.98, 0.8, 0.68),
                    skin_shadow=(0.68, 0.45, 0.45), brow=(0.45, 0.2, 0.1), eyes=(0.65, 1.0, 0.55), head_rot=(0.03, -0.15),
                    arms={-1: STAFF_F, 1: REST_F}),
    "hefesto": dict(build=hefesto, sex="m", color=(0.8, 0.38, 0.2), rim=(1.0, 0.5, 0.2), skin=(0.72, 0.46, 0.36),
                    skin_shadow=(0.38, 0.2, 0.2), brow=(0.12, 0.06, 0.04), eyes=(1.0, 0.6, 0.2), head_rot=(0.08, -0.1),
                    bulk=1.12, arms={-1: RAISE, 1: REST}),
    "atena": dict(build=atena, sex="f", color=(0.82, 0.8, 0.75), rim=(0.65, 0.85, 1.0), skin=(0.98, 0.82, 0.72),
                  skin_shadow=(0.66, 0.48, 0.48), brow=(0.28, 0.18, 0.12), eyes=(0.6, 0.85, 1.0), head_rot=(0.02, -0.12),
                  arms={-1: STAFF_F, 1: FRONT_F}),
    "dionisio": dict(build=dionisio, sex="m", color=(0.69, 0.42, 1.0), rim=(0.8, 0.5, 1.0), skin=(0.93, 0.72, 0.62),
                     skin_shadow=(0.58, 0.36, 0.42), brow=(0.25, 0.12, 0.25), eyes=(0.85, 0.55, 1.0), head_rot=(0.0, -0.18),
                     bulk=0.92, arms={-1: FRONT, 1: REST}),
    "demeter": dict(build=demeter, sex="f", color=(0.88, 0.69, 0.17), rim=(1.0, 0.85, 0.35), skin=(0.96, 0.78, 0.62),
                    skin_shadow=(0.66, 0.44, 0.4), brow=(0.7, 0.5, 0.25), eyes=(1.0, 0.85, 0.4), head_rot=(0.03, -0.15),
                    arms={-1: STAFF_F, 1: REST_F}),
    "hestia": dict(build=hestia, sex="f", color=(1.0, 0.55, 0.23), rim=(1.0, 0.6, 0.25), skin=(0.92, 0.66, 0.52),
                   skin_shadow=(0.6, 0.36, 0.34), brow=(0.3, 0.16, 0.1), eyes=(1.0, 0.7, 0.3), head_rot=(0.12, -0.08),
                   arms={-1: FRONT_F, 1: CUP_F}),
    "boreas": dict(build=boreas, sex="m", color=(0.66, 0.9, 1.0), rim=(0.6, 0.9, 1.0), skin=(0.82, 0.88, 0.95),
                   skin_shadow=(0.45, 0.52, 0.7), brow=(0.9, 0.95, 1.0), eyes=(0.6, 0.95, 1.0), head_rot=(0.02, -0.12),
                   arms={-1: FRONT, 1: REST}),
    "selene": dict(build=selene, sex="f", color=(0.88, 0.9, 1.0), rim=(0.75, 0.8, 1.0), skin=(0.93, 0.9, 0.98),
                   skin_shadow=(0.58, 0.55, 0.75), brow=(0.7, 0.7, 0.85), eyes=(0.8, 0.85, 1.0), head_rot=(0.03, -0.15),
                   arms={-1: FRONT_F, 1: REST_F}),
    "hecate": dict(build=hecate, sex="f", color=(0.56, 0.27, 0.68), rim=(0.75, 0.45, 1.0), skin=(0.82, 0.74, 0.84),
                   skin_shadow=(0.45, 0.36, 0.55), brow=(0.2, 0.1, 0.22), eyes=(0.85, 0.5, 1.0), head_rot=(0.05, -0.12),
                   arms={-1: STAFF_F, 1: REST_F}),
    "eolo": dict(build=eolo, sex="m", color=(0.78, 0.93, 0.93), rim=(0.75, 1.0, 1.0), skin=(0.96, 0.84, 0.74),
                 skin_shadow=(0.6, 0.48, 0.48), brow=(0.85, 0.9, 0.95), eyes=(0.75, 1.0, 1.0), head_rot=(0.0, -0.15),
                 bulk=0.94, arms={-1: FRONT, 1: REST}),
    "nemesis": dict(build=nemesis, sex="f", color=(0.75, 0.22, 0.17), rim=(1.0, 0.3, 0.25), skin=(0.82, 0.6, 0.54),
                    skin_shadow=(0.48, 0.3, 0.32), brow=(0.1, 0.05, 0.06), eyes=(1.0, 0.35, 0.3), head_rot=(0.02, -0.12),
                    arms={-1: FRONT_F, 1: REST_F}),
    "iris": dict(build=iris, sex="f", color=(1.0, 0.62, 0.95), rim=(1.0, 0.7, 0.95), skin=(1.0, 0.85, 0.8),
                 skin_shadow=(0.72, 0.5, 0.55), brow=(0.75, 0.35, 0.55), eyes=(1.0, 0.75, 1.0), head_rot=(0.04, -0.15),
                 arms={-1: FRONT_F, 1: REST_F}),
    "tique": dict(build=tique, sex="f", color=(1.0, 0.85, 0.29), rim=(1.0, 0.85, 0.4), skin=(0.95, 0.76, 0.56),
                  skin_shadow=(0.62, 0.42, 0.36), brow=(0.4, 0.2, 0.1), eyes=(1.0, 0.85, 0.4), head_rot=(0.03, -0.15),
                  arms={-1: FRONT_F, 1: REST_F}),
}
for _k, _v in GODS.items():
    _v["name"] = _k
    _v.setdefault("turn", 0.5)
GOD = {}


def render_god(gid):
    global GOD
    reset()
    global ROOT
    GOD = GODS[gid]
    root = empty("Root")
    ROOT = root
    GOD["build"]()
    root.rotation_euler = (0, 0, GOD.get("turn", 0.5))
    scene = bpy.context.scene
    os.makedirs(OUT, exist_ok=True)
    scene.render.filepath = os.path.join(OUT, gid + ".png")
    bpy.ops.render.render(write_still=True)
    # glow pass: everything that is not glowing becomes a black holdout
    hold = bpy.data.materials.new("Hold")
    hold.use_nodes = True
    nt = hold.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(nt.nodes.new("ShaderNodeHoldout").outputs[0], out.inputs["Surface"])
    for ob in scene.objects:
        if ob.type != "MESH":
            continue
        for i, slot in enumerate(ob.material_slots):
            if slot.material not in GLOW:
                slot.material = hold
    scene.render.filepath = os.path.join(OUT, gid + "_glow.png")
    bpy.ops.render.render(write_still=True)
    print("god", gid)


def main():
    ids = ONLY or list(GODS)
    for gid in ids:
        render_god(gid)


if __name__ == "__main__":
    main()
