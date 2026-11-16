class_name AmericanRoad
extends Node3D
## Американская трасса в духе BeamNG «American Road»: длинная петля с прямой, холмами, виражами,
## мезами и сосновыми склонами, ограждениями, знаками, ЛЭП, билбордами, заправкой и закусочной.
## Лёгкий трафик по обеим полосам.

const HW: float = 5.25            # половина ширины асфальта
const DS: float = 4.0             # шаг сэмплов дороги
const CELL: float = 14.0
const X0: float = -560.0
const X1: float = 1600.0
const Z0: float = -1400.0
const Z1: float = 1000.0
const CX: float = 520.0
const CZ: float = -260.0

var player: Vehicle
var start_hour: float = 9.5
var fog_scale: float = 0.55
var length: float = 0.0
var count: int = 0

var pts: PackedVector3Array = PackedVector3Array()
var tans: PackedVector3Array = PackedVector3Array()
var rights: PackedVector3Array = PackedVector3Array()
var banks: PackedFloat32Array = PackedFloat32Array()
var turns: PackedFloat32Array = PackedFloat32Array()

var gw: int = 0
var gd: int = 0
var hgrid: PackedFloat32Array = PackedFloat32Array()
var dgrid: PackedFloat32Array = PackedFloat32Array()

var dworld: DestructibleWorld
var _rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()
var _mnoise := FastNoiseLite.new()
var _fnoise := FastNoiseLite.new()
var _glow_mat: StandardMaterial3D
var _traffic: Array = []
var _wrecks: Array = []
var _want_cars: int = 8
var _respawn: float = 0.0

const CTRL: Array = [
    Vector3(0, 18, 200), Vector3(0, 22, -300), Vector3(0, 30, -700), Vector3(60, 42, -880),
    Vector3(260, 58, -960), Vector3(480, 70, -900), Vector3(620, 62, -740), Vector3(640, 48, -540),
    Vector3(760, 40, -380), Vector3(900, 44, -300), Vector3(1040, 56, -160), Vector3(1000, 64, 40),
    Vector3(860, 52, 160), Vector3(700, 36, 320), Vector3(600, 28, 520), Vector3(400, 24, 640),
    Vector3(180, 20, 620), Vector3(60, 18, 480),
]


func _ready() -> void:
    _rng.seed = 66
    dworld = DestructibleWorld.new()
    add_child(dworld)
    _noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    _noise.seed = 11
    _noise.fractal_type = FastNoiseLite.FRACTAL_FBM
    _noise.fractal_octaves = 4
    _mnoise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    _mnoise.seed = 29
    _fnoise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    _fnoise.seed = 5
    var q: int = int(Game.settings["quality"])
    _want_cars = [5, 8, 12][clampi(q, 0, 2)]
    _glow_mat = StandardMaterial3D.new()
    _glow_mat.albedo_color = Color(1.0, 0.9, 0.6)
    _glow_mat.emission_enabled = true
    _glow_mat.emission = Color(1.0, 0.85, 0.5)
    _glow_mat.emission_energy_multiplier = 0.0
    _build_centerline()
    _build_terrain()
    _build_road()
    _build_rails_and_signs()
    _build_power_lines()
    _build_roadside()
    _build_scatter()
    _build_far()


func set_night(on: bool) -> void:
    _glow_mat.emission_energy_multiplier = 2.5 if on else 0.0


func get_spawn() -> Transform3D:
    var f: Dictionary = frame_at(0.0, 2.7)
    var t: Vector3 = f["tan"]
    var pos: Vector3 = f["pos"]
    return Transform3D(Basis(Vector3.UP, atan2(-t.x, -t.z)), pos + Vector3(0.0, 0.9, 0.0))


func set_player(v: Vehicle) -> void:
    player = v
    for i in _want_cars:
        _spawn_car()


func _physics_process(delta: float) -> void:
    _traffic = _traffic.filter(func(t: Variant) -> bool: return is_instance_valid(t))
    if _traffic.size() < _want_cars and player != null:
        _respawn -= delta
        if _respawn <= 0.0:
            _respawn = 4.0
            _spawn_car()


func _spawn_car() -> void:
    var ids: Array = ["sedan", "hatchback", "suv", "pickup", "van", "truck", "taxi", "sedan", "offroad", "bus"]
    for attempt in 10:
        var s: float = _rng.randf() * length
        var dist: float = INF
        if player != null:
            dist = Vector2(player.global_position.x - frame_at(s, 0.0)["pos"].x, player.global_position.z - frame_at(s, 0.0)["pos"].z).length()
        if dist < 160.0:
            continue
        var id: String = ids[_rng.randi() % ids.size()]
        var col: Color = CarData.PAINTS[_rng.randi() % CarData.PAINTS.size()]
        var car := RoadCar.new()
        car.setup(self, id, col, s, 1.0 if _rng.randf() < 0.5 else -1.0)
        add_child(car)
        _traffic.append(car)
        return


func wreck_traffic(rc: RoadCar, p: Vehicle, closing: float, contact_world: Vector3) -> void:
    var w: WreckCar = TrafficUtil.make_wreck(self, rc.car_id, rc.paint, rc.global_transform, rc.vel, p, closing, contact_world)
    _traffic.erase(rc)
    rc.queue_free()
    _wrecks.append(w)
    _wrecks = _wrecks.filter(func(x: Variant) -> bool: return is_instance_valid(x))
    while _wrecks.size() > 8:
        var old: Node = _wrecks.pop_front()
        old.queue_free()


# ---------------------------------------------------------------- центральная линия

func _cr(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
    var t2: float = t * t
    var t3: float = t2 * t
    return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


func _build_centerline() -> void:
    var n: int = CTRL.size()
    var fine: Array = []
    for i in n:
        var p0: Vector3 = CTRL[(i - 1 + n) % n]
        var p1: Vector3 = CTRL[i]
        var p2: Vector3 = CTRL[(i + 1) % n]
        var p3: Vector3 = CTRL[(i + 2) % n]
        for k in 24:
            fine.append(_cr(p0, p1, p2, p3, float(k) / 24.0))
    fine.append(fine[0])
    var acc: Array = [0.0]
    for i in range(1, fine.size()):
        acc.append(float(acc[i - 1]) + (fine[i] as Vector3).distance_to(fine[i - 1]))
    var total: float = float(acc[acc.size() - 1])
    count = int(total / DS)
    var step: float = total / float(count)
    length = total
    var seg: int = 1
    for i in count:
        var target: float = float(i) * step
        while seg < acc.size() - 1 and float(acc[seg]) < target:
            seg += 1
        var a: float = float(acc[seg - 1])
        var b: float = float(acc[seg])
        var t: float = (target - a) / maxf(b - a, 0.0001)
        pts.append((fine[seg - 1] as Vector3).lerp(fine[seg], t))
    tans.resize(count)
    rights.resize(count)
    for i in count:
        var d: Vector3 = pts[(i + 1) % count] - pts[(i - 1 + count) % count]
        d.y = 0.0
        d = d.normalized()
        tans[i] = d
        rights[i] = Vector3(-d.z, 0.0, d.x)
    var raw := PackedFloat32Array()
    raw.resize(count)
    for i in count:
        var t0: Vector3 = tans[i]
        var t1: Vector3 = tans[(i + 1) % count]
        var cross_y: float = t0.z * t1.x - t0.x * t1.z
        raw[i] = -cross_y / DS
    turns = raw.duplicate()
    for pass_i in 6:
        var tmp := PackedFloat32Array()
        tmp.resize(count)
        for i in count:
            var s: float = 0.0
            for o in range(-2, 3):
                s += turns[(i + o + count) % count]
            tmp[i] = s / 5.0
        turns = tmp
    banks.resize(count)
    for i in count:
        banks[i] = clampf(turns[i] * 140.0, -0.07, 0.07)


## Кадр дороги на расстоянии s по трассе и боковом смещении u (вправо +).
func frame_at(s: float, u: float) -> Dictionary:
    var f: float = fposmod(s, length) / DS
    var i0: int = int(floor(f)) % count
    var i1: int = (i0 + 1) % count
    var t: float = f - floor(f)
    var c: Vector3 = pts[i0].lerp(pts[i1], t)
    var tng: Vector3 = tans[i0].lerp(tans[i1], t).normalized()
    var bank: float = lerpf(banks[i0], banks[i1], t)
    var r := Vector3(-tng.z, 0.0, tng.x)
    var pos: Vector3 = c + r * u
    pos.y -= bank * u
    return {"pos": pos, "tan": tng, "bank": bank}


func turn_at(s: float) -> float:
    var f: float = fposmod(s, length) / DS
    var i0: int = int(floor(f)) % count
    return turns[i0]


# ---------------------------------------------------------------- рельеф

func _natural(x: float, z: float) -> float:
    var n: float = _noise.get_noise_2d(x * 0.0018, z * 0.0018)
    var h: float = 26.0 + 24.0 * n
    var m: float = smoothstep(0.05, 0.3, _mnoise.get_noise_2d(x * 0.001, z * 0.001))
    var f: float = h / 10.0
    var fl: float = floorf(f)
    var terr: float = (fl + smoothstep(0.6, 0.8, f - fl)) * 10.0
    h = lerpf(h, terr + 6.0 * m, m)
    var e := Vector2((x - CX) / 1000.0, (z - CZ) / 1050.0)
    var edge: float = smoothstep(0.7, 1.1, e.length())
    h += edge * (90.0 + 40.0 * _noise.get_noise_2d(x * 0.004, z * 0.004 + 100.0))
    return maxf(h, 3.0)


func ground_h(x: float, z: float) -> float:
    var fx: float = (x - X0) / CELL
    var fz: float = (z - Z0) / CELL
    if fx < 0.0 or fz < 0.0 or fx >= float(gw - 1) or fz >= float(gd - 1):
        return 0.0
    var ix: int = int(fx)
    var iz: int = int(fz)
    var tx: float = fx - float(ix)
    var tz: float = fz - float(iz)
    var a: float = hgrid[iz * gw + ix]
    var b: float = hgrid[iz * gw + ix + 1]
    var c: float = hgrid[(iz + 1) * gw + ix]
    var d: float = hgrid[(iz + 1) * gw + ix + 1]
    return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)


func _road_dist(x: float, z: float) -> float:
    var ix: int = clampi(int(round((x - X0) / CELL)), 0, gw - 1)
    var iz: int = clampi(int(round((z - Z0) / CELL)), 0, gd - 1)
    return dgrid[iz * gw + ix]


func _build_terrain() -> void:
    gw = int((X1 - X0) / CELL) + 1
    gd = int((Z1 - Z0) / CELL) + 1
    var total: int = gw * gd
    hgrid.resize(total)
    dgrid.resize(total)
    var rh := PackedFloat32Array()
    rh.resize(total)
    for i in total:
        dgrid[i] = 9999.0
    var rc: int = int(ceil(150.0 / CELL))
    for k in range(0, count, 2):
        var c: Vector3 = pts[k]
        var cx: int = int((c.x - X0) / CELL)
        var cz: int = int((c.z - Z0) / CELL)
        for iz in range(cz - rc, cz + rc + 1):
            if iz < 0 or iz >= gd:
                continue
            for ix in range(cx - rc, cx + rc + 1):
                if ix < 0 or ix >= gw:
                    continue
                var d: float = Vector2(X0 + float(ix) * CELL - c.x, Z0 + float(iz) * CELL - c.z).length()
                var idx: int = iz * gw + ix
                if d < dgrid[idx]:
                    dgrid[idx] = d
                    rh[idx] = c.y
    for iz in gd:
        for ix in gw:
            var idx2: int = iz * gw + ix
            var x: float = X0 + float(ix) * CELL
            var z: float = Z0 + float(iz) * CELL
            var nat: float = _natural(x, z)
            var w: float = 1.0 - smoothstep(26.0, 150.0, dgrid[idx2])
            hgrid[idx2] = lerpf(nat, rh[idx2] - 0.85, w)
    var verts := PackedVector3Array()
    var norms := PackedVector3Array()
    var cols := PackedColorArray()
    var idxs := PackedInt32Array()
    verts.resize(total)
    norms.resize(total)
    cols.resize(total)
    var grass := Color(0.27, 0.42, 0.17)
    var dry := Color(0.6, 0.52, 0.31)
    var rock := Color(0.64, 0.36, 0.22)
    var verge := Color(0.5, 0.46, 0.34)
    for iz in gd:
        for ix in gw:
            var i: int = iz * gw + ix
            var h: float = hgrid[i]
            verts[i] = Vector3(X0 + float(ix) * CELL, h, Z0 + float(iz) * CELL)
            var hl: float = hgrid[iz * gw + maxi(ix - 1, 0)]
            var hr: float = hgrid[iz * gw + mini(ix + 1, gw - 1)]
            var hu: float = hgrid[maxi(iz - 1, 0) * gw + ix]
            var hd: float = hgrid[mini(iz + 1, gd - 1) * gw + ix]
            var nrm := Vector3(hl - hr, 2.0 * CELL, hu - hd).normalized()
            norms[i] = nrm
            var slope: float = 1.0 - nrm.y
            var col: Color = grass.lerp(dry, clampf((h - 22.0) / 30.0, 0.0, 1.0))
            var strata: float = 0.85 + 0.15 * sin(h * 0.8)
            var rcol: Color = rock * strata
            rcol.a = 1.0
            col = col.lerp(rcol, clampf((h - 60.0) / 30.0, 0.0, 1.0))
            col = col.lerp(rcol, clampf((slope - 0.12) / 0.2, 0.0, 1.0))
            col = col.lerp(verge, 1.0 - smoothstep(26.0, 44.0, dgrid[i]))
            var j: float = 0.9 + 0.2 * _rng.randf()
            cols[i] = Color(col.r * j, col.g * j, col.b * j)
    for iz in range(gd - 1):
        for ix in range(gw - 1):
            var a: int = iz * gw + ix
            idxs.append(a)
            idxs.append(a + 1)
            idxs.append(a + gw + 1)
            idxs.append(a)
            idxs.append(a + gw + 1)
            idxs.append(a + gw)
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = verts
    arrays[Mesh.ARRAY_NORMAL] = norms
    arrays[Mesh.ARRAY_COLOR] = cols
    arrays[Mesh.ARRAY_INDEX] = idxs
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    var mat: StandardMaterial3D = WorldKit.vc_mat(1.0)
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mesh.surface_set_material(0, mat)
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mi)
    var body := StaticBody3D.new()
    var cs := CollisionShape3D.new()
    cs.shape = mesh.create_trimesh_shape()
    body.add_child(cs)
    add_child(body)


func _build_far() -> void:
    var body := StaticBody3D.new()
    var cs := CollisionShape3D.new()
    var sh := BoxShape3D.new()
    sh.size = Vector3(8000.0, 2.0, 8000.0)
    cs.shape = sh
    cs.position = Vector3(0.0, -1.5, 0.0)
    body.add_child(cs)
    add_child(body)
    var pm := PlaneMesh.new()
    pm.size = Vector2(8000.0, 8000.0)
    var mi := MeshInstance3D.new()
    mi.mesh = pm
    mi.material_override = WorldKit.flat_mat(Color(0.5, 0.45, 0.32), 1.0)
    mi.position = Vector3(0.0, -0.5, 0.0)
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mi)
    WorldKit.mountain_ring(self, _rng, 2600.0, 420.0, Color(0.42, 0.3, 0.28), Color(0.85, 0.78, 0.72), 4.0, Vector3(CX, 0.0, CZ))


# ---------------------------------------------------------------- дорога

func _asphalt_texture() -> ImageTexture:
    var n: int = 256
    var img := Image.create(n, n, false, Image.FORMAT_RGB8)
    var rng := RandomNumberGenerator.new()
    rng.seed = 4242
    for y in n:
        for x in n:
            var u: float = (float(x) + 0.5) / float(n)
            var k: float = 1.0 + (rng.randf() - 0.5) * 0.3
            var base := Color(0.2, 0.2, 0.21)
            # следы шин
            var wear: float = exp(-pow((u - 0.28) / 0.07, 2.0)) + exp(-pow((u - 0.72) / 0.07, 2.0))
            base = base.darkened(0.12 * wear)
            var c := Color(base.r * k, base.g * k, base.b * k)
            if absf(u - 0.488) < 0.008 or absf(u - 0.512) < 0.008:
                c = Color(0.9, 0.7, 0.08)
            elif absf(u - 0.055) < 0.009 or absf(u - 0.945) < 0.009:
                c = Color(0.88, 0.88, 0.84)
            img.set_pixel(x, y, c)
    img.generate_mipmaps()
    return ImageTexture.create_from_image(img)


func _build_road() -> void:
    var n: int = count
    var av := PackedVector3Array()
    var an := PackedVector3Array()
    var auv := PackedVector2Array()
    var ai := PackedInt32Array()
    for i in n + 1:
        var k: int = i % n
        var c: Vector3 = pts[k]
        var r: Vector3 = rights[k]
        var b: float = banks[k]
        av.append(c - r * HW + Vector3(0.0, b * HW, 0.0))
        av.append(c + r * HW - Vector3(0.0, b * HW, 0.0))
        var nrm: Vector3 = Vector3(b * r.x, 1.0, b * r.z).normalized()
        an.append(nrm)
        an.append(nrm)
        var v: float = float(i) * DS / 12.0
        auv.append(Vector2(0.0, v))
        auv.append(Vector2(1.0, v))
    for i in n:
        var a: int = i * 2
        ai.append(a)
        ai.append(a + 2)
        ai.append(a + 3)
        ai.append(a)
        ai.append(a + 3)
        ai.append(a + 1)
    var arr: Array = []
    arr.resize(Mesh.ARRAY_MAX)
    arr[Mesh.ARRAY_VERTEX] = av
    arr[Mesh.ARRAY_NORMAL] = an
    arr[Mesh.ARRAY_TEX_UV] = auv
    arr[Mesh.ARRAY_INDEX] = ai
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
    var asp := StandardMaterial3D.new()
    asp.albedo_texture = _asphalt_texture()
    asp.roughness = 0.78
    asp.cull_mode = BaseMaterial3D.CULL_DISABLED
    asp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    mesh.surface_set_material(0, asp)
    # обочины
    var sv := PackedVector3Array()
    var sn := PackedVector3Array()
    var sc := PackedColorArray()
    var si := PackedInt32Array()
    var gravel := Color(0.5, 0.45, 0.36)
    for i in n + 1:
        var k2: int = i % n
        var c2: Vector3 = pts[k2]
        var r2: Vector3 = rights[k2]
        var b2: float = banks[k2]
        var el: Vector3 = c2 - r2 * HW + Vector3(0.0, b2 * HW, 0.0)
        var er: Vector3 = c2 + r2 * HW - Vector3(0.0, b2 * HW, 0.0)
        sv.append(el)
        sv.append(el - r2 * 3.4 - Vector3(0.0, 1.15, 0.0))
        sv.append(er)
        sv.append(er + r2 * 3.4 - Vector3(0.0, 1.15, 0.0))
        for q in 4:
            sn.append(Vector3.UP)
            sc.append(gravel)
    for i in n:
        var a2: int = i * 4
        for side in 2:
            var o: int = side * 2
            si.append(a2 + o)
            si.append(a2 + o + 1)
            si.append(a2 + 4 + o)
            si.append(a2 + o + 1)
            si.append(a2 + 5 + o)
            si.append(a2 + 4 + o)
    var arr2: Array = []
    arr2.resize(Mesh.ARRAY_MAX)
    arr2[Mesh.ARRAY_VERTEX] = sv
    arr2[Mesh.ARRAY_NORMAL] = sn
    arr2[Mesh.ARRAY_COLOR] = sc
    arr2[Mesh.ARRAY_INDEX] = si
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr2)
    var sm: StandardMaterial3D = WorldKit.vc_mat(1.0)
    sm.cull_mode = BaseMaterial3D.CULL_DISABLED
    mesh.surface_set_material(1, sm)
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mi)
    var body := StaticBody3D.new()
    var cs := CollisionShape3D.new()
    cs.shape = mesh.create_trimesh_shape()
    body.add_child(cs)
    add_child(body)


# ---------------------------------------------------------------- ограждения и знаки

func _build_rails_and_signs() -> void:
    var flag_l: Array = []
    var flag_r: Array = []
    for i in count:
        var t: float = turns[i]
        flag_l.append(t > 0.0035 or t < -0.009)
        flag_r.append(t < -0.0035 or t > 0.009)
    var dil_l: Array = flag_l.duplicate()
    var dil_r: Array = flag_r.duplicate()
    for i in count:
        for o in range(-6, 7):
            var k: int = (i + o + count) % count
            if flag_l[k]:
                dil_l[i] = true
            if flag_r[k]:
                dil_r[i] = true
    var rv := PackedVector3Array()
    var ri := PackedInt32Array()
    var post_tf: Array = []
    var sign_tf: Array = []
    var pole_tf: Array = []
    for side in 2:
        var sgn: float = -1.0 if side == 0 else 1.0
        var flags: Array = dil_l if side == 0 else dil_r
        for i in count:
            if not flags[i]:
                continue
            var j: int = (i + 1) % count
            if not flags[j]:
                continue
            var u: float = sgn * (HW + 0.9)
            var base: int = rv.size()
            for k in [i, j]:
                var c: Vector3 = pts[k] + rights[k] * u
                c.y = pts[k].y - banks[k] * u
                rv.append(c + Vector3(0.0, 0.4, 0.0))
                rv.append(c + Vector3(0.0, 1.1, 0.0))
            ri.append(base)
            ri.append(base + 2)
            ri.append(base + 3)
            ri.append(base)
            ri.append(base + 3)
            ri.append(base + 1)
            if i % 2 == 0:
                var pp: Vector3 = pts[i] + rights[i] * u
                pp.y = pts[i].y - banks[i] * u + 0.55
                post_tf.append(Transform3D(Basis(), pp))
            if i % 5 == 0 and absf(turns[i]) > 0.007:
                var su: float = sgn * (HW + 2.8)
                var sp: Vector3 = pts[i] + rights[i] * su
                sp.y = pts[i].y - 0.2
                var yaw: float = atan2(-tans[i].x, -tans[i].z)
                var bs := Basis(Vector3.UP, yaw)
                pole_tf.append(Transform3D(bs, sp + Vector3(0.0, 1.0, 0.0)))
                sign_tf.append(Transform3D(bs, sp + Vector3(0.0, 2.2, 0.0)))
    if rv.size() > 0:
        var arr: Array = []
        arr.resize(Mesh.ARRAY_MAX)
        arr[Mesh.ARRAY_VERTEX] = rv
        arr[Mesh.ARRAY_INDEX] = ri
        var nrm := PackedVector3Array()
        nrm.resize(rv.size())
        nrm.fill(Vector3.UP)
        arr[Mesh.ARRAY_NORMAL] = nrm
        var mesh := ArrayMesh.new()
        mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
        var rm: StandardMaterial3D = WorldKit.flat_mat(Color(0.7, 0.72, 0.74), 0.4)
        rm.metallic = 0.7
        rm.cull_mode = BaseMaterial3D.CULL_DISABLED
        mesh.surface_set_material(0, rm)
        var mi := MeshInstance3D.new()
        mi.mesh = mesh
        add_child(mi)
        var body := StaticBody3D.new()
        var cs := CollisionShape3D.new()
        cs.shape = mesh.create_trimesh_shape()
        body.add_child(cs)
        add_child(body)
    var post := BoxMesh.new()
    post.size = Vector3(0.14, 1.1, 0.14)
    WorldKit.scatter_multimesh(self, post, post_tf, WorldKit.flat_mat(Color(0.35, 0.33, 0.3), 0.8))
    var pole := BoxMesh.new()
    pole.size = Vector3(0.1, 2.0, 0.1)
    var pole_mmi: MultiMeshInstance3D = WorldKit.scatter_multimesh(self, pole, pole_tf, WorldKit.flat_mat(Color(0.3, 0.3, 0.32), 0.7))
    var panel := BoxMesh.new()
    panel.size = Vector3(1.3, 1.0, 0.06)
    var sign_mmi: MultiMeshInstance3D = WorldKit.scatter_multimesh(self, panel, sign_tf, WorldKit.flat_mat(Color(0.98, 0.8, 0.05), 0.5))
    for i in pole_tf.size():
        var t: Transform3D = pole_tf[i]
        var base: Vector3 = t.origin - Vector3(0.0, 1.0, 0.0)
        var xf := Transform3D(t.basis, base)
        var cs: CollisionShape3D = dworld.add_collision(xf, Vector3(0.3, 2.6, 0.3), Vector3(0.0, 1.3, 0.0))
        dworld.register("sign_post", {}, xf, AABB(base + Vector3(-1.0, 0.0, -1.0), Vector3(2.0, 3.0, 2.0)), [[pole_mmi, i], [sign_mmi, i]], cs)


func _ground_at(i: int, u: float, side: float) -> Vector3:
    var p: Vector3 = pts[i] + rights[i] * u * side
    p.y = pts[i].y - 0.85
    return p


func _build_power_lines() -> void:
    var pole := BoxMesh.new()
    pole.size = Vector3(0.35, 11.0, 0.35)
    var arm := BoxMesh.new()
    arm.size = Vector3(3.4, 0.22, 0.22)
    var pole_tf: Array = []
    var arm_tf: Array = []
    var tops: Array = []
    var i: int = 18
    while i < 215:
        var base: Vector3 = _ground_at(i, HW + 11.0, -1.0)
        var yaw: float = atan2(-tans[i].x, -tans[i].z)
        var bs := Basis(Vector3.UP, yaw)
        pole_tf.append(Transform3D(bs, base + Vector3(0.0, 5.5, 0.0)))
        arm_tf.append(Transform3D(bs, base + Vector3(0.0, 10.4, 0.0)))
        tops.append([base + Vector3(0.0, 10.4, 0.0), bs])
        i += 11
    var wood: StandardMaterial3D = WorldKit.flat_mat(Color(0.32, 0.22, 0.14), 0.9)
    var pp_mmi: MultiMeshInstance3D = WorldKit.scatter_multimesh(self, pole, pole_tf, wood, true)
    var arm_mmi: MultiMeshInstance3D = WorldKit.scatter_multimesh(self, arm, arm_tf, wood)
    for j in pole_tf.size():
        var pt: Transform3D = pole_tf[j]
        var pbase: Vector3 = pt.origin - Vector3(0.0, 5.5, 0.0)
        var pxf := Transform3D(pt.basis, pbase)
        var pcs: CollisionShape3D = dworld.add_collision(pxf, Vector3(0.45, 11.0, 0.45), Vector3(0.0, 5.5, 0.0))
        dworld.register("power_pole", {}, pxf, AABB(pbase + Vector3(-2.2, 0.0, -2.2), Vector3(4.4, 11.3, 4.4)), [[pp_mmi, j], [arm_mmi, j]], pcs)
    var wv := PackedVector3Array()
    for k in range(tops.size() - 1):
        var a: Vector3 = (tops[k] as Array)[0]
        var b: Vector3 = (tops[k + 1] as Array)[0]
        var bs2: Basis = (tops[k] as Array)[1]
        for off in [-1.4, 0.0, 1.4]:
            var o: Vector3 = bs2.x * float(off)
            var prev: Vector3 = a + o
            for s in range(1, 9):
                var t: float = float(s) / 8.0
                var pp: Vector3 = (a + o).lerp(b + o, t)
                pp.y -= 1.3 * 4.0 * t * (1.0 - t)
                wv.append(prev)
                wv.append(pp)
                prev = pp
    if wv.size() > 0:
        var arr: Array = []
        arr.resize(Mesh.ARRAY_MAX)
        arr[Mesh.ARRAY_VERTEX] = wv
        var mesh := ArrayMesh.new()
        mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
        var wm := StandardMaterial3D.new()
        wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        wm.albedo_color = Color(0.1, 0.1, 0.1)
        mesh.surface_set_material(0, wm)
        var mi := MeshInstance3D.new()
        mi.mesh = mesh
        mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(mi)


# ---------------------------------------------------------------- придорожные постройки

func _roadside_node(i: int, u_abs: float, side: float) -> Node3D:
    var n := Node3D.new()
    var base: Vector3 = _ground_at(i, u_abs, side)
    var yaw: float = atan2(-tans[i].x, -tans[i].z) + (0.0 if side > 0.0 else PI)
    n.transform = Transform3D(Basis(Vector3.UP, yaw), base)
    add_child(n)
    return n


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, collide: bool = true) -> void:
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    mi.mesh = bm
    mi.material_override = mat
    mi.position = pos
    parent.add_child(mi)
    if collide:
        var body := StaticBody3D.new()
        body.position = pos
        var cs := CollisionShape3D.new()
        var sh := BoxShape3D.new()
        sh.size = size
        cs.shape = sh
        body.add_child(cs)
        parent.add_child(body)


func _build_roadside() -> void:
    var concrete: StandardMaterial3D = WorldKit.flat_mat(Color(0.55, 0.55, 0.56), 0.9)
    var white: StandardMaterial3D = WorldKit.flat_mat(Color(0.92, 0.92, 0.9), 0.8)
    var red: StandardMaterial3D = WorldKit.flat_mat(Color(0.8, 0.1, 0.08), 0.6)
    var dark: StandardMaterial3D = WorldKit.flat_mat(Color(0.2, 0.2, 0.22), 0.7)
    # заправка
    var apron1: Node3D = _roadside_node(95, 18.5, 1.0)
    _box(apron1, Vector3(34.0, 0.14, 16.0), Vector3(0.0, 0.07, 0.0), concrete)
    var st: Node3D = _roadside_node(95, 18.5, 1.0)
    _box(st, Vector3(11.0, 4.2, 7.0), Vector3(9.0, 2.2, 3.5), white)
    _box(st, Vector3(11.8, 0.4, 7.8), Vector3(9.0, 4.5, 3.5), red)
    _box(st, Vector3(13.0, 0.5, 8.0), Vector3(-6.0, 5.6, -2.5), red)
    _box(st, Vector3(13.0, 0.12, 8.0), Vector3(-6.0, 5.3, -2.5), _glow_mat, false)
    for px in [-11.5, -0.5]:
        for pz in [-6.0, 1.0]:
            _box(st, Vector3(0.5, 5.4, 0.5), Vector3(float(px), 2.8, float(pz)), white)
    for px2 in [-8.0, -4.0]:
        _box(st, Vector3(0.7, 1.5, 1.0), Vector3(float(px2), 0.9, -2.5), red)
    _box(st, Vector3(0.4, 11.0, 0.4), Vector3(-15.0, 5.5, 6.0), dark)
    _box(st, Vector3(4.2, 2.6, 0.4), Vector3(-15.0, 10.8, 6.0), _glow_mat, false)
    dworld.register("station", {}, st.transform, st.transform * AABB(Vector3(-16.0, 0.0, -8.5), Vector3(32.0, 12.5, 17.0)), [[st]])
    # закусочная
    var apron2: Node3D = _roadside_node(190, 18.0, -1.0)
    _box(apron2, Vector3(30.0, 0.14, 15.0), Vector3(0.0, 0.07, 0.0), concrete)
    var dn: Node3D = _roadside_node(190, 18.0, -1.0)
    _box(dn, Vector3(14.0, 4.0, 8.0), Vector3(6.0, 2.1, 0.0), white)
    _box(dn, Vector3(14.4, 0.7, 8.4), Vector3(6.0, 4.4, 0.0), red)
    _box(dn, Vector3(14.1, 1.4, 0.2), Vector3(6.0, 2.6, -4.05), WorldKit.flat_mat(Color(0.3, 0.5, 0.65), 0.1), false)
    _box(dn, Vector3(0.4, 9.0, 0.4), Vector3(-8.0, 4.5, 5.0), dark)
    _box(dn, Vector3(5.0, 3.0, 0.4), Vector3(-8.0, 8.8, 5.0), _glow_mat, false)
    dworld.register("diner", {}, dn.transform, dn.transform * AABB(Vector3(-10.5, 0.0, -4.5), Vector3(24.0, 10.5, 10.0)), [[dn]])
    # билборды
    for bb in [[60, Color(0.85, 0.2, 0.15)], [150, Color(0.15, 0.4, 0.85)], [235, Color(0.95, 0.75, 0.1)]]:
        var n: Node3D = _roadside_node(int(bb[0]), 22.0, 1.0)
        _box(n, Vector3(0.5, 8.0, 0.5), Vector3(-5.0, 4.0, 0.0), dark)
        _box(n, Vector3(0.5, 8.0, 0.5), Vector3(5.0, 4.0, 0.0), dark)
        _box(n, Vector3(14.0, 5.5, 0.4), Vector3(0.0, 9.5, 0.0), WorldKit.flat_mat(bb[1], 0.6), false)
        _box(n, Vector3(12.0, 0.4, 0.45), Vector3(0.0, 10.4, 0.0), _glow_mat, false)
        dworld.register("billboard", {"color": bb[1]}, n.transform, n.transform * AABB(Vector3(-7.5, 0.0, -1.0), Vector3(15.0, 12.6, 2.0)), [[n]])
    # фермерские дома и сарай
    var farm: Array = [[40, 24.0, 1.0, Color(0.85, 0.8, 0.7), Color(0.45, 0.2, 0.15)], [120, 26.0, -1.0, Color(0.8, 0.25, 0.2), Color(0.3, 0.3, 0.34)], [215, 24.0, 1.0, Color(0.9, 0.9, 0.85), Color(0.4, 0.25, 0.18)], [260, 25.0, -1.0, Color(0.7, 0.78, 0.85), Color(0.3, 0.3, 0.34)]]
    for f in farm:
        var hn: Node3D = _roadside_node(int(f[0]), float(f[1]), float(f[2]))
        hn.rotate_y(PI * 0.5 * (1.0 if float(f[2]) > 0.0 else -1.0))
        WorldKit.house_proxy(hn, 11.1, 9.0, 4.2, f[3], f[4])
        dworld.register("house", {"w": 11.1, "d": 9.0, "wall_h": 4.2, "wall": f[3], "roof": f[4]}, hn.transform, hn.transform * AABB(Vector3(-5.85, 0.0, -4.8), Vector3(11.7, 7.9, 9.6)), [[hn]])


# ---------------------------------------------------------------- деревья и камни

func _slope_at(x: float, z: float) -> float:
    var d: float = 6.0
    var dx: float = ground_h(x + d, z) - ground_h(x - d, z)
    var dz: float = ground_h(x, z + d) - ground_h(x, z - d)
    return Vector2(dx, dz).length() / (2.0 * d)


func _scatter_chunked(mesh: Mesh, xforms: Array, mat: Material, pine: bool) -> void:
    var buckets: Dictionary = {}
    for t in xforms:
        var o: Vector3 = (t as Transform3D).origin
        var key := Vector2i(int(floor(o.x / 600.0)), int(floor(o.z / 600.0)))
        if not buckets.has(key):
            buckets[key] = []
        (buckets[key] as Array).append(t)
    for key in buckets.keys():
        var mmi: MultiMeshInstance3D = WorldKit.scatter_multimesh(self, mesh, buckets[key], mat)
        dworld.register_multimesh(mmi, buckets[key], "tree", {"pine": pine, "vs": 0.5}, AABB(Vector3(-1.7, 0.0, -1.7), Vector3(3.4, 5.0, 3.4)), Vector3(0.6, 2.5, 0.6), Vector3(0.0, 1.25, 0.0))


func _build_scatter() -> void:
    var oak_tf: Array = []
    var pine_tf: Array = []
    var rocks: Array = []     # [xform, color]
    var tries: int = 2400
    for n in tries:
        var x: float = _rng.randf_range(X0 + 40.0, X1 - 40.0)
        var z: float = _rng.randf_range(Z0 + 40.0, Z1 - 40.0)
        var d: float = _road_dist(x, z)
        if d < 36.0:
            continue
        var h: float = ground_h(x, z)
        if h > 85.0 or _slope_at(x, z) > 0.5:
            continue
        var forest: float = _fnoise.get_noise_2d(x * 0.004, z * 0.004)
        var s: float = _rng.randf_range(0.8, 1.5)
        var bs := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s, s))
        var tf := Transform3D(bs, Vector3(x, h - 0.1, z))
        if forest > -0.05 and oak_tf.size() + pine_tf.size() < 420:
            if h > 38.0:
                pine_tf.append(tf)
            else:
                oak_tf.append(tf)
        elif _rng.randf() < 0.35 and rocks.size() < 260:
            var rs: float = _rng.randf_range(1.0, 4.5)
            var rb := Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3.RIGHT, _rng.randf_range(-0.3, 0.3))
            rb = rb.scaled(Vector3(rs * 1.2, rs * 0.7, rs))
            var g: float = _rng.randf_range(0.7, 1.1)
            var rcol: Color = Color(0.58 * g, 0.4 * g, 0.3 * g) if h > 35.0 else Color(0.5 * g, 0.5 * g, 0.5 * g)
            rocks.append([Transform3D(rb, Vector3(x, h + rs * 0.15, z)), rcol])
    var tmat: StandardMaterial3D = WorldKit.vc_mat()
    if not oak_tf.is_empty():
        _scatter_chunked(WorldKit.tree_mesh(false, _rng, 0.5), oak_tf, tmat, false)
    if not pine_tf.is_empty():
        _scatter_chunked(WorldKit.tree_mesh(true, _rng, 0.5), pine_tf, tmat, true)
    if not rocks.is_empty():
        var sm := SphereMesh.new()
        sm.radius = 0.5
        sm.height = 1.0
        sm.radial_segments = 8
        sm.rings = 4
        var mm := MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.use_colors = true
        mm.mesh = sm
        mm.instance_count = rocks.size()
        for i in rocks.size():
            var e: Array = rocks[i]
            mm.set_instance_transform(i, e[0])
            mm.set_instance_color(i, e[1])
        var mmi := MultiMeshInstance3D.new()
        mmi.multimesh = mm
        mmi.material_override = WorldKit.vc_mat(1.0)
        add_child(mmi)
        for i in rocks.size():
            var e2: Array = rocks[i]
            var rt: Transform3D = e2[0]
            var sc: Vector3 = rt.basis.get_scale()
            var xf := rt.orthonormalized()
            var cs: CollisionShape3D = dworld.add_collision(xf, sc * 0.85, Vector3.ZERO)
            dworld.register("rock", {"rx": sc.x * 0.5, "ry": sc.y * 0.5, "rz": sc.z * 0.5, "color": e2[1]}, xf, rt * AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE), [[mmi, i]], cs)


func blast_car(rc: RoadCar, origin: Vector3, power: float) -> void:
    var w: WreckCar = TrafficUtil.make_blast_wreck(self, rc.car_id, rc.paint, rc.global_transform, rc.vel, origin, power)
    _traffic.erase(rc)
    rc.queue_free()
    _wrecks.append(w)
