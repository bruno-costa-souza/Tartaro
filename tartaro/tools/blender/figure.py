"""Character toolkit for Tártaro's hero and god portraits.

Cel-shaded materials with ink outlines, skinned bodies (skin modifier + armature
+ computed weights), loft/tube/ellipsoid shapes and a small position-based cloth
solver for capes and ribbons.
"""

import math

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

INK_COLOR = (0.03, 0.016, 0.028)
OUTLINE = 0.016

_ink = None


# ---------------------------------------------------------------- materials

def _sockets(node, enabled_only=True):
    return [s for s in node.inputs if s.enabled or not enabled_only]


def _mix(nt, blend="MIX"):
    m = nt.nodes.new("ShaderNodeMix")
    m.data_type = "RGBA"
    m.blend_type = blend
    fac, a, b = _sockets(m)
    out = [o for o in m.outputs if o.enabled][0]
    return m, fac, a, b, out


def _ramp(nt, stops, interp="LINEAR"):
    r = nt.nodes.new("ShaderNodeValToRGB")
    r.color_ramp.interpolation = interp
    els = r.color_ramp.elements
    while len(els) > 1:
        els.remove(els[-1])
    els[0].position = stops[0][0]
    els[0].color = (*([stops[0][1]] * 3), 1.0) if not isinstance(stops[0][1], tuple) else (*stops[0][1], 1.0)
    for pos, val in stops[1:]:
        e = els.new(pos)
        e.color = (val, val, val, 1.0) if not isinstance(val, tuple) else (*val, 1.0)
    return r


def lin(c):
    """sRGB colour (as picked by eye) -> linear value for shader nodes."""
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c[:3])


def shade(color, amount=0.5, tint=(0.2, 0.09, 0.3)):
    """Shadow colour: darker and shifted towards violet, like the 2D art."""
    return tuple(c * (1.0 - amount) * 0.8 + t * amount * 0.35 for c, t in zip(color, tint))


def toon(name, color, shadow=None, mid=0.55, spec=0.0, gloss=0.28, spec_color=None,
         rim=(0.62, 0.78, 1.0), rim_strength=0.18, emission=None, strength=0.0,
         lit=0.8, dark=0.42, soft=0.035):
    """Cel shading: diffuse light quantised into shadow / mid / lit bands,
    an optional hard glossy highlight (metals), a Fresnel rim and emission.
    Emission-only output, so the render is fully 'painted'. Colours are sRGB."""
    if shadow is None:
        shadow = shade(color)
    color, shadow, rim = lin(color), lin(shadow), lin(rim)
    spec_color = lin(spec_color) if spec_color else None
    emission = lin(emission) if emission else None
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    N = nt.nodes.new
    L = nt.links.new

    diff = N("ShaderNodeBsdfDiffuse")
    diff.inputs["Color"].default_value = (1, 1, 1, 1)
    s2r = N("ShaderNodeShaderToRGB")
    L(diff.outputs[0], s2r.inputs[0])
    bands = _ramp(nt, [(0.0, 0.0), (dark - soft, 0.0), (dark + soft, mid), (lit - soft, mid), (lit + soft, 1.0), (1.0, 1.0)])
    L(s2r.outputs["Color"], bands.inputs[0])
    _, fac, a, b, base = _mix(nt)
    L(bands.outputs["Color"], fac)
    a.default_value = (*shadow, 1.0)
    b.default_value = (*color, 1.0)
    total = base

    if spec > 0.0:
        gl = N("ShaderNodeBsdfGlossy")
        gl.inputs["Roughness"].default_value = gloss
        gl.inputs["Color"].default_value = (1, 1, 1, 1)
        g2r = N("ShaderNodeShaderToRGB")
        L(gl.outputs[0], g2r.inputs[0])
        hard = _ramp(nt, [(0.0, 0.0), (0.42, 0.0), (0.5, 1.0), (1.0, 1.0)])
        L(g2r.outputs["Color"], hard.inputs[0])
        sc = spec_color or tuple(min(1.0, c * 0.5 + 0.55) for c in color)
        _, f2, a2, b2, o2 = _mix(nt, "MULTIPLY")
        f2.default_value = 1.0
        L(hard.outputs["Color"], a2)
        b2.default_value = (sc[0] * spec, sc[1] * spec, sc[2] * spec, 1.0)
        _, f3, a3, b3, o3 = _mix(nt, "ADD")
        f3.default_value = 1.0
        L(total, a3)
        L(o2, b3)
        total = o3

    if rim_strength > 0.0:
        lw = N("ShaderNodeLayerWeight")
        lw.inputs["Blend"].default_value = 0.4
        rr = _ramp(nt, [(0.0, 0.0), (0.62, 0.0), (0.8, 1.0), (1.0, 1.0)])
        L(lw.outputs["Facing"], rr.inputs[0])
        _, f4, a4, b4, o4 = _mix(nt, "MULTIPLY")
        f4.default_value = 1.0
        L(rr.outputs["Color"], a4)
        b4.default_value = (rim[0] * rim_strength, rim[1] * rim_strength, rim[2] * rim_strength, 1.0)
        _, f5, a5, b5, o5 = _mix(nt, "ADD")
        f5.default_value = 1.0
        L(total, a5)
        L(o4, b5)
        total = o5

    if emission is not None and strength > 0.0:
        _, f6, a6, b6, o6 = _mix(nt, "ADD")
        f6.default_value = 1.0
        L(total, a6)
        b6.default_value = (emission[0] * strength, emission[1] * strength, emission[2] * strength, 1.0)
        total = o6

    em = N("ShaderNodeEmission")
    em.inputs["Strength"].default_value = 1.0
    L(total, em.inputs["Color"])
    out = N("ShaderNodeOutputMaterial")
    L(em.outputs[0], out.inputs["Surface"])
    return m


def glow(name, color, strength=1.0):
    """Flat unlit colour (eyes, sparks, lightning)."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*lin(color), 1.0)
    em.inputs["Strength"].default_value = strength
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(em.outputs[0], out.inputs["Surface"])
    return m


def ink():
    global _ink
    if _ink is None or _ink.name not in bpy.data.materials:
        _ink = glow("Ink", INK_COLOR)
        _ink.use_backface_culling = True
        _ink.use_backface_culling_shadow = True
    return _ink


# ---------------------------------------------------------------- meshes

def mesh_object(name, verts, faces, mats=(), smooth=True, parent=None):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(map(float, v)) for v in verts], [], [tuple(int(i) for i in f) for f in faces])
    me.update()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    for m in mats:
        me.materials.append(m)
    if smooth:
        me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
    if parent is not None:
        ob.parent = parent
    return ob


def from_bmesh(name, bm, mats=(), smooth=True):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    for m in mats:
        me.materials.append(m)
    if smooth:
        me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
    return ob


def ellipsoid(name, center, radii, mat, segs=20, rings=12, rot=None, shape=None):
    """UV ellipsoid. `shape(co) -> co` may sculpt the unit sphere first."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=1.0)
    for v in bm.verts:
        co = Vector(v.co)
        if shape:
            co = Vector(shape(co))
        co = Vector((co.x * radii[0], co.y * radii[1], co.z * radii[2]))
        if rot:
            co = Matrix.Rotation(rot[2], 3, "Z") @ Matrix.Rotation(rot[1], 3, "Y") @ Matrix.Rotation(rot[0], 3, "X") @ co
        v.co = co + Vector(center)
    return from_bmesh(name, bm, [mat])


def ring(center, rx, ry, n, start=0.0, fn=None):
    """Ellipse of n points in the XY plane at center.z; fn(angle) -> (dx, dy, dz)."""
    pts = []
    for i in range(n):
        a = start + 2 * math.pi * i / n
        p = [center[0] + math.cos(a) * rx, center[1] + math.sin(a) * ry, center[2]]
        if fn:
            d = fn(a)
            p = [p[0] + d[0], p[1] + d[1], p[2] + d[2]]
        pts.append(p)
    return pts


def loft(name, rings_, mat, closed=True, cap_top=False, cap_bottom=False, mats=None):
    n = len(rings_[0])
    verts = [p for r in rings_ for p in r]
    faces = []
    cols = n if closed else n - 1
    for i in range(len(rings_) - 1):
        for j in range(cols):
            a = i * n + j
            b = i * n + (j + 1) % n
            faces.append((a, b, b + n, a + n))
    if cap_bottom:
        c = len(verts)
        verts.append(list(np.mean(np.array(rings_[0]), axis=0)))
        for j in range(n):
            faces.append((c, (j + 1) % n, j))
    if cap_top:
        c = len(verts)
        k = (len(rings_) - 1) * n
        verts.append(list(np.mean(np.array(rings_[-1]), axis=0)))
        for j in range(n):
            faces.append((c, k + j, k + (j + 1) % n))
    return mesh_object(name, verts, faces, mats or [mat])


def tube(name, points, radii, mat, sides=10, cap=True, flat=1.0, widths=None):
    """Tapered tube along a polyline (hair locks, straps, stems). `flat` < 1
    squashes the cross-section into a ribbon; `widths` (one vector per point)
    sets the ribbon's wide direction."""
    pts = [Vector(p) for p in points]
    n = len(pts)
    tangents = []
    for i in range(n):
        t = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)])
        tangents.append(t.normalized() if t.length > 1e-9 else Vector((0, 0, 1)))
    ref = Vector((0, 0, 1)) if abs(tangents[0].z) < 0.9 else Vector((1, 0, 0))
    normal = tangents[0].cross(ref).normalized()
    rings_ = []
    for i in range(n):
        t = tangents[i]
        if widths is not None:
            normal = Vector(widths[i])
        normal = (normal - t * normal.dot(t))
        normal = normal.normalized() if normal.length > 1e-9 else t.orthogonal().normalized()
        binorm = t.cross(normal)
        r = radii[i] if hasattr(radii, "__len__") else radii
        ring_pts = []
        for k in range(sides):
            a = 2 * math.pi * k / sides
            off = normal * (math.cos(a) * r) + binorm * (math.sin(a) * r * flat)
            ring_pts.append(list(pts[i] + off))
        rings_.append(ring_pts)
    ob = loft(name, rings_, mat, cap_top=cap, cap_bottom=cap)
    return ob


def skin_body(name, verts, edges, radii, mat, root=0, subdiv=2, smoothing=0.6):
    """Organic body from a stick figure: skin modifier + subdivision, applied."""
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [tuple(e) for e in edges], [])
    me.update()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    mod = ob.modifiers.new("Skin", "SKIN")
    mod.branch_smoothing = smoothing
    if len(me.skin_vertices) == 0:
        me.skin_vertices.new()
    layer = me.skin_vertices[0].data
    for i, r in enumerate(radii):
        layer[i].radius = (r[0], r[1]) if hasattr(r, "__len__") else (r, r)
        layer[i].use_root = i == root
    sub = ob.modifiers.new("Sub", "SUBSURF")
    sub.levels = subdiv
    sub.render_levels = subdiv
    apply_modifiers(ob)
    me = ob.data
    me.materials.append(mat)
    me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
    return ob


def recalc_normals(ob):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(ob.data)
    bm.free()
    return ob


def apply_modifiers(ob):
    deps = bpy.context.evaluated_depsgraph_get()
    ev = ob.evaluated_get(deps)
    me = bpy.data.meshes.new_from_object(ev)
    old = ob.data
    ob.modifiers.clear()
    ob.data = me
    bpy.data.meshes.remove(old)


def verts_of(ob):
    me = ob.data
    co = np.empty(len(me.vertices) * 3, dtype=np.float64)
    me.vertices.foreach_get("co", co)
    return co.reshape((-1, 3))


def set_verts(ob, co):
    ob.data.vertices.foreach_set("co", np.asarray(co, dtype=np.float32).ravel())
    ob.data.update()


def outline(ob, thickness=None, subsurf=1):
    """Subdivision + inverted-hull ink outline (keeps modifier order after Armature)."""
    if subsurf:
        sub = ob.modifiers.new("Sub", "SUBSURF")
        sub.levels = subsurf
        sub.render_levels = subsurf
    slot = len(ob.data.materials)
    for _ in range(max(slot, 1)):
        ob.data.materials.append(ink())
    sol = ob.modifiers.new("Ink", "SOLIDIFY")
    sol.thickness = -(thickness or OUTLINE)
    sol.use_flip_normals = True
    sol.material_offset = slot
    sol.material_offset_rim = slot
    sol.offset = 1.0
    return ob


# ---------------------------------------------------------------- rig

def build_armature(name, bones):
    """bones: list of (name, head, tail, parent or None, deform).
    Every bone's X axis points to world +X, so +X rotation pitches it."""
    arm = bpy.data.armatures.new(name)
    ob = bpy.data.objects.new(name, arm)
    bpy.context.scene.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    ebs = {}
    for bname, head, tail, parent, deform in bones:
        eb = arm.edit_bones.new(bname)
        eb.head = head
        eb.tail = tail
        d = (Vector(tail) - Vector(head)).normalized()
        z = Vector((1, 0, 0)).cross(d)
        eb.align_roll(z if z.length > 0.2 else Vector((0, 0, 1)))
        eb.use_deform = deform
        if parent:
            eb.parent = ebs[parent]
        ebs[bname] = eb
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in ob.pose.bones:
        pb.rotation_mode = "XYZ"
    return ob


def seg_dist(X, a, b):
    a = np.asarray(a)
    ab = np.asarray(b) - a
    t = np.clip(((X - a) @ ab) / max(ab @ ab, 1e-12), 0.0, 1.0)
    return np.linalg.norm(X - (a + t[:, None] * ab), axis=1)


def auto_weights(X, arm_ob, allowed=None, power=6.0):
    """Inverse-distance weights to the nearest bone and its parent/children."""
    bones = [b for b in arm_ob.data.bones if b.use_deform and (allowed is None or b.name in allowed)]
    names = [b.name for b in bones]
    D = np.stack([seg_dist(X, b.head_local, b.tail_local) for b in bones], axis=1)
    near = {}
    for i, b in enumerate(bones):
        nb = [i]
        if b.parent and b.parent.name in names:
            nb.append(names.index(b.parent.name))
        for c in b.children:
            if c.name in names:
                nb.append(names.index(c.name))
        near[i] = nb
    first = np.argmin(D, axis=1)
    W = np.zeros_like(D)
    for i in range(len(X)):
        cand = near[first[i]]
        w = 1.0 / np.maximum(D[i, cand], 1e-4) ** power
        W[i, cand] = w / w.sum()
    return {names[k]: W[:, k] for k in range(len(names)) if W[:, k].max() > 1e-4}


def bind(ob, arm_ob, weights):
    """Deform `ob` with the armature. weights: bone name (rigid) or {bone: array}."""
    ob.parent = arm_ob
    n = len(ob.data.vertices)
    if isinstance(weights, str):
        weights = {weights: np.ones(n)}
    for bone, w in weights.items():
        vg = ob.vertex_groups.new(name=bone)
        w = np.asarray(w)
        for value in np.unique(np.round(w, 3)):
            if value <= 0.0:
                continue
            idx = np.nonzero(np.round(w, 3) == value)[0].tolist()
            vg.add(idx, float(value), "REPLACE")
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = arm_ob
    mod.use_vertex_groups = True
    return ob


def blend_weights(X, a_name, b_name, axis, lo, hi):
    """Linear blend from bone a (coord <= lo) to bone b (coord >= hi) along axis."""
    t = np.clip((X[:, axis] - lo) / (hi - lo), 0.0, 1.0)
    t = t * t * (3 - 2 * t)
    return {a_name: 1.0 - t, b_name: t}


class Pose:
    """Pose helper: rotations in each bone's local frame (X = pitch towards the
    bone's Z axis, Y = twist, Z = swing towards -X)."""

    def __init__(self, arm_ob):
        self.ob = arm_ob

    def reset(self):
        for pb in self.ob.pose.bones:
            pb.rotation_euler = (0, 0, 0)
            pb.location = (0, 0, 0)
            pb.scale = (1, 1, 1)

    def rot(self, name, x=0.0, y=0.0, z=0.0):
        self.ob.pose.bones[name].rotation_euler = (x, y, z)

    def move(self, name, world_offset):
        """Translate a bone by an offset given in armature space."""
        b = self.ob.data.bones[name]
        local = b.matrix_local.to_3x3().inverted() @ Vector(world_offset)
        self.ob.pose.bones[name].location = local

    def update(self):
        bpy.context.view_layer.update()

    def matrix(self, name):
        return self.ob.pose.bones[name].matrix.copy()

    def deform(self, name):
        """Rest -> posed transform of a bone, in armature space."""
        b = self.ob.data.bones[name]
        return self.ob.pose.bones[name].matrix @ b.matrix_local.inverted()

    def aim(self, name, grip, direction, up=(0, 0, 1)):
        """Place a (non-deforming, rigid-child) bone at `grip` pointing along
        `direction` in armature space."""
        y = Vector(direction).normalized()
        upv = Vector(up)
        x = upv.cross(y)
        if x.length < 1e-5:
            x = Vector((1, 0, 0))
        x.normalize()
        z = x.cross(y)
        m = Matrix((x, y, z)).transposed().to_4x4()
        m.translation = Vector(grip)
        self.ob.pose.bones[name].matrix = m


# ---------------------------------------------------------------- cloth

class Cloth:
    """Position-based cloth grid (rows x cols) pinned by its first row.

    attach(t)    -> (cols, 3) positions of the pinned row
    colliders(t) -> list of (a, b, radius) capsules
    wind(t)      -> air velocity, (3,) or (rows, cols, 3)
    Everything is driven by periodic functions, so after a few simulated
    cycles the motion settles into a seamless loop."""

    def __init__(self, rows, cols, length, width_top, width_bottom, drag=1.8, damping=0.992,
                 iterations=10, bend=0.35, thickness=0.025, gravity=9.81, pleats=0.0):
        self.rows, self.cols = rows, cols
        self.seg = length / (rows - 1)
        v = np.linspace(0.0, 1.0, rows)
        self.width = width_top + (width_bottom - width_top) * v
        self.cseg = self.width / (cols - 1)
        self.drag = drag
        self.damping = damping
        self.iterations = iterations
        self.bend = bend
        self.thickness = thickness
        self.g = np.array([0.0, 0.0, -gravity])
        self.pleats = pleats
        self.P = None

    def reset(self, top):
        top = np.asarray(top, dtype=np.float64)
        P = np.zeros((self.rows, self.cols, 3))
        for r in range(self.rows):
            P[r] = top + np.array([0.0, 0.0, -self.seg * r])
            mid = top.mean(axis=0)
            P[r, :, 0] = mid[0] + (top[:, 0] - mid[0]) * self.width[r] / max(self.width[0], 1e-6)
            if r > 0:
                P[r, :, 1] += self.pleats * np.cos(np.arange(self.cols) * math.pi)
        self.P = P
        self.Q = P.copy()

    def _dist(self, P, a, b, rest, k=1.0, wa=None, wb=None):
        d = P[b] - P[a]
        ln = np.linalg.norm(d, axis=-1, keepdims=True)
        ln = np.maximum(ln, 1e-9)
        corr = d * ((ln - rest[..., None]) / ln) * 0.5 * k
        P[a] += corr * (1.0 if wa is None else wa)
        P[b] -= corr * (1.0 if wb is None else wb)

    def _constraints(self, P, top):
        R, C = self.rows, self.cols
        pin = np.ones((R - 1, 1, 1))
        pin[0] = 0.0
        free_b = np.ones((R - 1, 1, 1))
        free_b[0] = 2.0
        for _ in range(self.iterations):
            # along the length
            self._dist(P, (slice(0, R - 1),), (slice(1, R),), np.full((R - 1, C), self.seg), 1.0, pin, free_b)
            # across the width
            self._dist(P, (slice(None), slice(0, C - 1)), (slice(None), slice(1, C)),
                       np.repeat(self.cseg[:, None], C - 1, axis=1))
            # shear
            diag = np.sqrt(self.seg ** 2 + ((self.cseg[:-1] + self.cseg[1:]) / 2) ** 2)
            self._dist(P, (slice(0, R - 1), slice(0, C - 1)), (slice(1, R), slice(1, C)),
                       np.repeat(diag[:, None], C - 1, axis=1), 0.6, pin, free_b)
            self._dist(P, (slice(0, R - 1), slice(1, C)), (slice(1, R), slice(0, C - 1)),
                       np.repeat(diag[:, None], C - 1, axis=1), 0.6, pin, free_b)
            # bending (skip one)
            pin2 = np.ones((R - 2, 1, 1))
            pin2[0] = 0.0
            self._dist(P, (slice(0, R - 2),), (slice(2, R),), np.full((R - 2, C), 2 * self.seg),
                       self.bend, pin2, np.where(pin2 == 0.0, 2.0, 1.0))
            P[0] = top
            self._collide(P)
            np.maximum(P[..., 2], 0.012, out=P[..., 2])
            P[0] = top

    def _collide(self, P):
        flat = P.reshape((-1, 3))
        for a, b, r in self.capsules:
            a = np.asarray(a)
            ab = np.asarray(b) - a
            t = np.clip(((flat - a) @ ab) / max(ab @ ab, 1e-12), 0.0, 1.0)
            c = a + t[:, None] * ab
            d = flat - c
            ln = np.linalg.norm(d, axis=1)
            rr = r + self.thickness
            hit = ln < rr
            if np.any(hit):
                n = d[hit] / np.maximum(ln[hit], 1e-9)[:, None]
                flat[hit] = c[hit] + n * rr
        P[:] = flat.reshape(P.shape)

    def run(self, attach, colliders, wind, period, frames, cycles=6, substeps=20, warm=None):
        """Simulate `cycles` periods and return the cloth at `frames` evenly spaced
        times of the last one. If `warm` is given (attach, colliders, wind, period)
        it is simulated first for 3 periods (used for one-shot animations)."""
        out = []
        if self.P is None:
            self.reset(attach(0.0))
        if warm:
            self._simulate(*warm, steps=3 * frames * substeps, frames=frames, substeps=substeps)
        total = cycles * frames * substeps
        self._simulate(attach, colliders, wind, period, steps=total, frames=frames, substeps=substeps,
                       record=out, record_from=(cycles - 1) * frames * substeps)
        return out

    def _simulate(self, attach, colliders, wind, period, steps, frames, substeps, record=None, record_from=0):
        dt = period / (frames * substeps)
        for s in range(steps):
            t = (s * dt) / period
            top = np.asarray(attach(t))
            self.capsules = colliders(t)
            air = np.asarray(wind(t))
            V = (self.P - self.Q) * self.damping
            acc = self.g + self.drag * (air - V / dt)
            Pn = self.P + V + acc * dt * dt
            Pn[0] = top
            self._constraints(Pn, top)
            self.Q, self.P = self.P, Pn
            if record is not None and s >= record_from and (s - record_from) % substeps == 0:
                record.append(self.P.copy())


def grid_faces(rows, cols):
    faces = []
    for r in range(rows - 1):
        for c in range(cols - 1):
            a = r * cols + c
            faces.append((a, a + 1, a + cols + 1, a + cols))
    return faces


def lerp_samples(samples, t, periodic=True):
    """Linear interpolation over evenly spaced numpy samples (t in cycles)."""
    n = len(samples)
    if periodic:
        x = (t % 1.0) * n
        i = int(math.floor(x)) % n
        j = (i + 1) % n
    else:
        x = min(max(t, 0.0), 1.0) * (n - 1)
        i = min(int(math.floor(x)), n - 1)
        j = min(i + 1, n - 1)
    f = x - math.floor(x)
    return samples[i] + (samples[j] - samples[i]) * f


def capsules(arr):
    """(K, 7) array [ax, ay, az, bx, by, bz, r] -> list of (a, b, r)."""
    return [(row[0:3], row[3:6], row[6]) for row in arr]
