class_name CityMap
extends Node3D
## Город в духе GTA: сетка улиц, кварталы с высотками и парками, светофоры, трафик, пешеходы.
## Дороги вдоль X и Z на линиях i*P (i = -N..N). Движение правостороннее.

const P: float = 120.0            # шаг сетки
const N: int = 3                  # дороги i = -3..3
const ROAD_HALF: float = 10.0
const BLOCK: float = 100.0        # размер квартала (без дороги)
const SLAB_H: float = 0.18        # высота бордюра/тротуара
const ROAD_Y: float = 0.0
const STOP_DIST: float = 15.0     # стоп-линия от центра перекрёстка
const ENTRY_DIST: float = 10.0    # начало поворота
const SIDE_R: float = 48.25       # кольцо тротуара вокруг квартала
const CYCLE: float = 35.0

var player: Vehicle
var dworld: DestructibleWorld
var start_hour: float = 17.8
var fog_scale: float = 1.0

var _rng := RandomNumberGenerator.new()
var _bld_mat: ShaderMaterial
var _lamp_mat: StandardMaterial3D
var _head_mm: MultiMesh
var _light_t: float = 0.0
var _last_states: Vector2i = Vector2i(-1, -1)
var _traffic: Array = []
var _peds: Array = []
var _wrecks: Array = []
var _respawn_car: float = 0.0
var _respawn_ped: float = 0.0
var _want_cars: int = 18
var _want_peds: int = 30


static func node_pos(i: int, j: int) -> Vector3:
    return Vector3(float(i) * P, 0.0, float(j) * P)


static func lane_off(lane: int) -> float:
    return 2.7 + 4.0 * float(lane)


static func block_center(b: Vector2i) -> Vector3:
    return Vector3((float(b.x) + 0.5) * P, 0.0, (float(b.y) + 0.5) * P)


static func corner_pos(b: Vector2i, k: int) -> Vector3:
    var s: Vector2i = Pedestrian.SIGNS[k]
    return block_center(b) + Vector3(float(s.x) * SIDE_R, 0.0, float(s.y) * SIDE_R)


## Состояние светофора для оси движения машин (0 — вдоль X, 1 — вдоль Z): 0 красный, 1 жёлтый, 2 зелёный.
func light_state(axis: int) -> int:
    var t: float = _light_t
    if axis == 0:
        if t < 14.0:
            return 2
        if t < 16.0:
            return 1
        return 0
    if t < 17.5:
        return 0
    if t < 31.5:
        return 2
    if t < 33.5:
        return 1
    return 0


func set_night(on: bool) -> void:
    _lamp_mat.emission_energy_multiplier = 3.0 if on else 0.0
    _bld_mat.set_shader_parameter("night", 1.0 if on else 0.0)


func get_spawn() -> Transform3D:
    return Transform3D(Basis(), Vector3(lane_off(0) + 0.5, 0.8, 70.0))


func _ready() -> void:
    _rng.seed = 5150
    var q: int = int(Game.settings["quality"])
    _want_cars = [10, 16, 24][clampi(q, 0, 2)]
    _want_peds = [14, 26, 40][clampi(q, 0, 2)]
    _bld_mat = WorldKit.building_material()
    _build_ground()
    _build_roads()
    _build_blocks()
    _build_lights_and_lamps()
    WorldKit.mountain_ring(self, _rng, 1700.0, 260.0, Color(0.2, 0.26, 0.34), Color(0.78, 0.82, 0.9), 3.0)


func set_player(v: Vehicle) -> void:
    player = v
    for i in _want_cars:
        _spawn_traffic(true)
    for i in _want_peds:
        _spawn_ped()


# ---------------------------------------------------------------- построение

func _build_ground() -> void:
    var body := StaticBody3D.new()
    var cs := CollisionShape3D.new()
    var sh := BoxShape3D.new()
    sh.size = Vector3(5000.0, 2.0, 5000.0)
    cs.shape = sh
    cs.position = Vector3(0.0, -1.0, 0.0)
    body.add_child(cs)
    add_child(body)
    var grass := StandardMaterial3D.new()
    grass.albedo_texture = WorldKit.noise_tex(128, Color(0.2, 0.36, 0.14), 0.5, 77, 0.0)
    grass.uv1_scale = Vector3(1000.0, 1000.0, 1.0)
    grass.roughness = 1.0
    var gm := MeshInstance3D.new()
    var gp := PlaneMesh.new()
    gp.size = Vector2(5000.0, 5000.0)
    gm.mesh = gp
    gm.material_override = grass
    gm.position = Vector3(0.0, -0.04, 0.0)
    gm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(gm)
    var span: float = float(N) * P * 2.0 + ROAD_HALF * 2.0
    var asp := StandardMaterial3D.new()
    asp.albedo_texture = WorldKit.noise_tex(256, Color(0.2, 0.2, 0.215), 0.4, 1234, 0.02)
    asp.uv1_scale = Vector3(span / 3.0, span / 3.0, 1.0)
    asp.roughness = 0.8
    var am := MeshInstance3D.new()
    var ap := PlaneMesh.new()
    ap.size = Vector2(span, span)
    am.mesh = ap
    am.material_override = asp
    am.position = Vector3(0.0, 0.0, 0.0)
    am.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(am)


func _mm(mesh: Mesh, xforms: Array, mat: Material, colors: Array = []) -> MultiMeshInstance3D:
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    if not colors.is_empty():
        mm.use_colors = true
    mm.mesh = mesh
    mm.instance_count = xforms.size()
    for i in xforms.size():
        mm.set_instance_transform(i, xforms[i])
        if not colors.is_empty():
            mm.set_instance_color(i, colors[i])
    var mmi := MultiMeshInstance3D.new()
    mmi.multimesh = mm
    mmi.material_override = mat
    mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mmi)
    return mmi


func _build_roads() -> void:
    var white := WorldKit.flat_mat(Color(0.9, 0.9, 0.85), 0.6)
    var yellow := WorldKit.flat_mat(Color(0.95, 0.75, 0.1), 0.6)
    var dash_box := BoxMesh.new()
    dash_box.size = Vector3(0.18, 0.02, 3.0)
    var dash_box_x := BoxMesh.new()
    dash_box_x.size = Vector3(3.0, 0.02, 0.18)
    var yel_long := BoxMesh.new()
    yel_long.size = Vector3(0.14, 0.02, 1.0)
    var yel_long_x := BoxMesh.new()
    yel_long_x.size = Vector3(1.0, 0.02, 0.14)
    var zebra := BoxMesh.new()
    zebra.size = Vector3(0.6, 0.02, 3.6)
    var zebra_x := BoxMesh.new()
    zebra_x.size = Vector3(3.6, 0.02, 0.6)
    var dashes_z: Array = []
    var dashes_x: Array = []
    var yel_z: Array = []
    var yel_x: Array = []
    var zeb_z: Array = []
    var zeb_x: Array = []
    for r in range(-N, N + 1):
        var rc: float = float(r) * P
        for seg in range(-N, N):
            var a: float = float(seg) * P + ROAD_HALF + 5.0
            var b: float = float(seg + 1) * P - ROAD_HALF - 5.0
            var len_s: float = b - a
            var mid: float = (a + b) * 0.5
            # сплошная двойная жёлтая по центру
            for off in [-0.22, 0.22]:
                yel_z.append(Transform3D(Basis.from_scale(Vector3(1.0, 1.0, len_s)), Vector3(rc + float(off), 0.02, mid)))
                yel_x.append(Transform3D(Basis.from_scale(Vector3(len_s, 1.0, 1.0)), Vector3(mid, 0.02, rc + float(off))))
            # пунктир между полосами
            var z: float = a + 1.5
            while z < b - 1.5:
                for off2 in [-4.7, 4.7]:
                    dashes_z.append(Transform3D(Basis(), Vector3(rc + float(off2), 0.02, z)))
                    dashes_x.append(Transform3D(Basis(), Vector3(z, 0.02, rc + float(off2))))
                z += 8.0
        # зебры на каждом перекрёстке
        for c in range(-N, N + 1):
            var cc: float = float(c) * P
            for s in [-1.0, 1.0]:
                var d: float = 12.5 * float(s)
                var k: float = -ROAD_HALF + 1.2
                while k < ROAD_HALF:
                    zeb_z.append(Transform3D(Basis(), Vector3(rc + k, 0.02, cc + d)))
                    zeb_x.append(Transform3D(Basis(), Vector3(cc + d, 0.02, rc + k)))
                    k += 1.4
    _mm(yel_long, yel_z, yellow)
    _mm(yel_long_x, yel_x, yellow)
    _mm(dash_box, dashes_z, white)
    _mm(dash_box_x, dashes_x, white)
    _mm(zebra, zeb_z, white)
    _mm(zebra_x, zeb_x, white)


func _build_blocks() -> void:
    dworld = DestructibleWorld.new()
    dworld.building_material = _bld_mat
    add_child(dworld)
    var static_body := StaticBody3D.new()
    add_child(static_body)
    var slab_mesh := BoxMesh.new()
    slab_mesh.size = Vector3.ONE
    var slab_x: Array = []
    var slab_c: Array = []
    var bld: Array = []       # [xform, color, params, aabb, cs]
    var houses: Array = []    # [xform, wall, roof, params, aabb, cs]
    var oak_tf: Array = []
    var street_tf: Array = []
    var pine_tf: Array = []
    for bi in range(-N, N):
        for bj in range(-N, N):
            var c: Vector3 = block_center(Vector2i(bi, bj))
            var dist: float = Vector2(c.x, c.z).length() / P
            var is_park: bool = _rng.randf() < 0.14 and dist > 0.8
            var suburb: bool = dist > 2.6 and not is_park
            var slab_col := Color(0.55, 0.55, 0.56)
            if is_park:
                slab_col = Color(0.22, 0.4, 0.16)
            elif suburb:
                slab_col = Color(0.32, 0.5, 0.26)
            slab_x.append(Transform3D(Basis.from_scale(Vector3(BLOCK, SLAB_H, BLOCK)), Vector3(c.x, SLAB_H * 0.5, c.z)))
            slab_c.append(slab_col)
            _add_box_shape(static_body, Vector3(BLOCK, SLAB_H, BLOCK), Vector3(c.x, SLAB_H * 0.5, c.z))
            if is_park:
                for t in 14:
                    var tp := Vector3(c.x + _rng.randf_range(-42.0, 42.0), SLAB_H, c.z + _rng.randf_range(-42.0, 42.0))
                    var sc: float = _rng.randf_range(0.9, 1.5)
                    var tb := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(sc, sc, sc))
                    if _rng.randf() < 0.5:
                        oak_tf.append(Transform3D(tb, tp))
                    else:
                        pine_tf.append(Transform3D(tb, tp))
                continue
            if suburb:
                var walls: Array = [Color(0.85, 0.8, 0.7), Color(0.75, 0.55, 0.45), Color(0.7, 0.78, 0.85), Color(0.9, 0.9, 0.85), Color(0.8, 0.75, 0.55)]
                var roofs: Array = [Color(0.45, 0.2, 0.15), Color(0.3, 0.3, 0.34), Color(0.4, 0.25, 0.18)]
                for ix in 2:
                    for iz in 2:
                        var hp := Vector3(c.x + (float(ix) - 0.5) * 46.0, SLAB_H, c.z + (float(iz) - 0.5) * 46.0)
                        var q: int = _rng.randi() % 4
                        var xf := Transform3D(Basis(Vector3.UP, float(q) * PI * 0.5), hp)
                        var wc: Color = walls[_rng.randi() % walls.size()]
                        var rcol: Color = roofs[_rng.randi() % roofs.size()]
                        var sz := Vector3(9.0, 7.2, 11.1) if q % 2 == 1 else Vector3(11.1, 7.2, 9.0)
                        var cs: CollisionShape3D = _add_box_shape(static_body, sz, hp + Vector3(0.0, 3.6, 0.0))
                        var aabb: AABB = xf * AABB(Vector3(-5.85, 0.0, -4.8), Vector3(11.7, 7.9, 9.6))
                        houses.append([xf, wc, rcol, {"w": 11.1, "d": 9.0, "wall_h": 4.2, "wall": wc, "roof": rcol}, aabb, cs])
                continue
            # здания: 2x2 участка
            var height_base: float = lerpf(130.0, 14.0, clampf(dist / 2.6, 0.0, 1.0))
            for ix in 2:
                for iz in 2:
                    var pc := Vector3(c.x + (float(ix) - 0.5) * 46.0, 0.0, c.z + (float(iz) - 0.5) * 46.0)
                    var w: float = _rng.randf_range(30.0, 40.0)
                    var d: float = _rng.randf_range(30.0, 40.0)
                    var h: float = clampf(height_base * _rng.randf_range(0.35, 1.0), 9.0, 150.0)
                    var vs: float = VoxelProtos.building_vs(w, h, d)
                    w = maxf(snappedf(w, vs), vs * 3.0)
                    h = maxf(snappedf(h, vs), vs * 3.0)
                    d = maxf(snappedf(d, vs), vs * 3.0)
                    var shade: float = _rng.randf_range(0.0, 1.0)
                    var tint := Color(0.5, 0.52, 0.56).lerp(Color(0.7, 0.62, 0.52), shade)
                    if _rng.randf() < 0.2:
                        tint = Color(0.35, 0.42, 0.5)
                    tint.a = _rng.randf()
                    var origin := Vector3(pc.x, SLAB_H, pc.z)
                    var cs2: CollisionShape3D = _add_box_shape(static_body, Vector3(w, h, d), origin + Vector3(0.0, h * 0.5, 0.0))
                    var aabb2 := AABB(origin + Vector3(-w * 0.5, 0.0, -d * 0.5), Vector3(w, h, d))
                    bld.append([Transform3D(Basis.from_scale(Vector3(w, h, d)), origin + Vector3(0.0, h * 0.5, 0.0)), tint, {"w": w, "h": h, "d": d, "color": tint, "vs": vs}, aabb2, cs2, Transform3D(Basis(), origin)])
            # уличные деревья по периметру
            for side in 4:
                for n in 4:
                    var off: float = -33.0 + float(n) * 22.0
                    var pos := Vector3.ZERO
                    match side:
                        0: pos = Vector3(c.x + off, SLAB_H, c.z - 48.0)
                        1: pos = Vector3(c.x + off, SLAB_H, c.z + 48.0)
                        2: pos = Vector3(c.x - 48.0, SLAB_H, c.z + off)
                        _: pos = Vector3(c.x + 48.0, SLAB_H, c.z + off)
                    street_tf.append(Transform3D(Basis.from_scale(Vector3.ONE * _rng.randf_range(0.8, 1.2)), pos))
    _mm(slab_mesh, slab_x, WorldKit.vc_mat(0.95), slab_c)
    # здания
    var bm := BoxMesh.new()
    bm.size = Vector3.ONE
    var bx: Array = []
    var bc: Array = []
    for e in bld:
        bx.append(e[0])
        bc.append(e[1])
    var bmi: MultiMeshInstance3D = _mm(bm, bx, _bld_mat, bc)
    bmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    for i in bld.size():
        var e: Array = bld[i]
        dworld.register("building", e[2], e[5], e[3], [[bmi, i]], e[4])
    # дома
    if not houses.is_empty():
        var wx: Array = []
        var wcols: Array = []
        var rx: Array = []
        var rcols: Array = []
        for e in houses:
            var xf2: Transform3D = e[0]
            wx.append(Transform3D(xf2.basis * Basis.from_scale(Vector3(11.1, 4.2, 9.0)), xf2.origin + Vector3(0.0, 2.1, 0.0)))
            wcols.append(e[1])
            rx.append(Transform3D(xf2.basis * Basis.from_scale(Vector3(11.7, 3.6, 9.6)), xf2.origin + Vector3(0.0, 4.2, 0.0)))
            rcols.append(e[2])
        var hmat: StandardMaterial3D = WorldKit.vc_mat(0.9)
        var rmat: StandardMaterial3D = WorldKit.vc_mat(0.9)
        rmat.cull_mode = BaseMaterial3D.CULL_DISABLED
        var wmi: MultiMeshInstance3D = _mm(bm, wx, hmat, wcols)
        var rmi: MultiMeshInstance3D = _mm(WorldKit.roof_mesh(), rx, rmat, rcols)
        for i in houses.size():
            var e: Array = houses[i]
            dworld.register("house", e[3], e[0], e[4], [[wmi, i], [rmi, i]], e[5])
    # деревья
    var tmat: StandardMaterial3D = WorldKit.vc_mat()
    var rng_t := RandomNumberGenerator.new()
    rng_t.seed = 77
    if not oak_tf.is_empty():
        var m1: MultiMeshInstance3D = WorldKit.scatter_multimesh(self, WorldKit.tree_mesh(false, rng_t, 0.3), oak_tf, tmat)
        dworld.register_multimesh(m1, oak_tf, "tree", {"pine": false, "vs": 0.3}, AABB(Vector3(-1.9, 0.0, -1.9), Vector3(3.8, 5.6, 3.8)), Vector3(0.6, 3.0, 0.6), Vector3(0.0, 1.5, 0.0))
    if not pine_tf.is_empty():
        var m2: MultiMeshInstance3D = WorldKit.scatter_multimesh(self, WorldKit.tree_mesh(true, rng_t, 0.3), pine_tf, tmat)
        dworld.register_multimesh(m2, pine_tf, "tree", {"pine": true, "vs": 0.3}, AABB(Vector3(-1.9, 0.0, -1.9), Vector3(3.8, 5.6, 3.8)), Vector3(0.6, 3.0, 0.6), Vector3(0.0, 1.5, 0.0))
    var m3: MultiMeshInstance3D = WorldKit.scatter_multimesh(self, WorldKit.tree_mesh(false, rng_t, 0.5), street_tf, tmat)
    dworld.register_multimesh(m3, street_tf, "tree", {"pine": false, "vs": 0.5}, AABB(Vector3(-1.7, 0.0, -1.7), Vector3(3.4, 5.0, 3.4)), Vector3(0.6, 2.5, 0.6), Vector3(0.0, 1.25, 0.0))


func _add_box_shape(body: StaticBody3D, size: Vector3, pos: Vector3) -> CollisionShape3D:
    var cs := CollisionShape3D.new()
    var sh := BoxShape3D.new()
    sh.size = size
    cs.shape = sh
    cs.position = pos
    body.add_child(cs)
    return cs


func _build_lights_and_lamps() -> void:
    var pole_mat: StandardMaterial3D = WorldKit.flat_mat(Color(0.25, 0.26, 0.28), 0.6)
    pole_mat.metallic = 0.6
    _lamp_mat = StandardMaterial3D.new()
    _lamp_mat.albedo_color = Color(1.0, 0.92, 0.7)
    _lamp_mat.emission_enabled = true
    _lamp_mat.emission = Color(1.0, 0.85, 0.55)
    _lamp_mat.emission_energy_multiplier = 0.0
    # столбы светофоров + фонари
    var pole := BoxMesh.new()
    pole.size = Vector3(0.25, 6.0, 0.25)
    var lamp_pole := BoxMesh.new()
    lamp_pole.size = Vector3(0.22, 8.0, 0.22)
    var lamp_head := BoxMesh.new()
    lamp_head.size = Vector3(1.2, 0.25, 0.5)
    var tl_poles: Array = []
    var heads: Array = []
    var lamp_poles: Array = []
    var lamp_heads: Array = []
    for i in range(-N, N + 1):
        for j in range(-N, N + 1):
            var c: Vector3 = node_pos(i, j)
            for sx in [-1.0, 1.0]:
                for sz in [-1.0, 1.0]:
                    var p := Vector3(c.x + float(sx) * (ROAD_HALF + 0.9), SLAB_H + 3.0, c.z + float(sz) * (ROAD_HALF + 0.9))
                    tl_poles.append(Transform3D(Basis(), p))
                    heads.append(Transform3D(Basis(), Vector3(p.x - float(sx) * 0.4, SLAB_H + 6.3, p.z - float(sz) * 0.4)))
    for bi in range(-N, N):
        for bj in range(-N, N):
            var c2: Vector3 = block_center(Vector2i(bi, bj))
            for side in 4:
                var lp := Vector3.ZERO
                var inward := Vector3.ZERO
                match side:
                    0:
                        lp = Vector3(c2.x - 15.0, 0.0, c2.z - 49.0)
                        inward = Vector3(0.0, 0.0, 0.7)
                    1:
                        lp = Vector3(c2.x + 15.0, 0.0, c2.z + 49.0)
                        inward = Vector3(0.0, 0.0, -0.7)
                    2:
                        lp = Vector3(c2.x - 49.0, 0.0, c2.z + 15.0)
                        inward = Vector3(0.7, 0.0, 0.0)
                    _:
                        lp = Vector3(c2.x + 49.0, 0.0, c2.z - 15.0)
                        inward = Vector3(-0.7, 0.0, 0.0)
                lamp_poles.append(Transform3D(Basis(), lp + Vector3(0.0, SLAB_H + 4.0, 0.0)))
                lamp_heads.append(Transform3D(Basis(), lp + inward + Vector3(0.0, SLAB_H + 8.1, 0.0)))
    var tl_mmi: MultiMeshInstance3D = _mm(pole, tl_poles, pole_mat)
    var lp_mmi: MultiMeshInstance3D = _mm(lamp_pole, lamp_poles, pole_mat)
    var lh_mmi: MultiMeshInstance3D = _mm(lamp_head, lamp_heads, _lamp_mat)
    # головы светофоров: цвет меняется по состоянию
    var head_mesh := BoxMesh.new()
    head_mesh.size = Vector3(0.5, 0.9, 0.5)
    _head_mm = MultiMesh.new()
    _head_mm.transform_format = MultiMesh.TRANSFORM_3D
    _head_mm.use_colors = true
    _head_mm.mesh = head_mesh
    _head_mm.instance_count = heads.size()
    for k in heads.size():
        _head_mm.set_instance_transform(k, heads[k])
        _head_mm.set_instance_color(k, Color.RED)
    var hmi := MultiMeshInstance3D.new()
    hmi.multimesh = _head_mm
    hmi.material_override = WorldKit.unshaded_vc_mat()
    hmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(hmi)
    for i in tl_poles.size():
        var base: Vector3 = (tl_poles[i] as Transform3D).origin - Vector3(0.0, 3.0, 0.0)
        var xf := Transform3D(Basis(), base)
        var cs: CollisionShape3D = dworld.add_collision(xf, Vector3(0.35, 6.0, 0.35), Vector3(0.0, 3.0, 0.0))
        dworld.register("tl_pole", {}, xf, AABB(base + Vector3(-1.0, 0.0, -1.0), Vector3(2.0, 6.9, 2.0)), [[tl_mmi, i], [hmi, i]], cs)
    for i in lamp_poles.size():
        var base2: Vector3 = (lamp_poles[i] as Transform3D).origin - Vector3(0.0, 4.0, 0.0)
        var xf2 := Transform3D(Basis(), base2)
        var cs2: CollisionShape3D = dworld.add_collision(xf2, Vector3(0.3, 8.0, 0.3), Vector3(0.0, 4.0, 0.0))
        dworld.register("lamp", {}, xf2, AABB(base2 + Vector3(-1.6, 0.0, -1.6), Vector3(3.2, 8.4, 3.2)), [[lp_mmi, i], [lh_mmi, i]], cs2)
    _update_heads()


func _state_color(s: int) -> Color:
    if s == 2:
        return Color(0.1, 1.0, 0.25)
    if s == 1:
        return Color(1.0, 0.8, 0.1)
    return Color(1.0, 0.1, 0.05)


func _update_heads() -> void:
    var sx_state: Color = _state_color(light_state(0))
    var sz_state: Color = _state_color(light_state(1))
    var idx: int = 0
    for i in range(-N, N + 1):
        for j in range(-N, N + 1):
            for sx in [-1.0, 1.0]:
                for sz in [-1.0, 1.0]:
                    # угловые столбы по диагонали показывают разные оси
                    _head_mm.set_instance_color(idx, sx_state if float(sx) * float(sz) > 0.0 else sz_state)
                    idx += 1
    _last_states = Vector2i(light_state(0), light_state(1))


# ---------------------------------------------------------------- симуляция

func _physics_process(delta: float) -> void:
    _light_t = fmod(_light_t + delta, CYCLE)
    if Vector2i(light_state(0), light_state(1)) != _last_states:
        _update_heads()
    _traffic = _traffic.filter(func(t: Variant) -> bool: return is_instance_valid(t))
    _peds = _peds.filter(func(p: Variant) -> bool: return is_instance_valid(p))
    if _traffic.size() < _want_cars:
        _respawn_car -= delta
        if _respawn_car <= 0.0:
            _respawn_car = 3.0
            _spawn_traffic(false)
    if _peds.size() < _want_peds:
        _respawn_ped -= delta
        if _respawn_ped <= 0.0:
            _respawn_ped = 2.0
            _spawn_ped()


func _far_from_player(pos: Vector3, min_d: float) -> bool:
    if player == null:
        return true
    return Vector2(pos.x - player.global_position.x, pos.z - player.global_position.z).length() > min_d


func _spawn_traffic(initial: bool) -> void:
    var ids: Array = ["sedan", "hatchback", "suv", "taxi", "police", "van", "pickup", "sedan", "taxi", "bus", "truck", "offroad"]
    for attempt in 12:
        var a := Vector2i(_rng.randi_range(-N, N), _rng.randi_range(-N, N))
        var dirs: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
        var h: Vector2i = dirs[_rng.randi() % 4]
        var b: Vector2i = a + h
        if absi(b.x) > N or absi(b.y) > N:
            continue
        var lane: int = _rng.randi() % 2
        var along: float = _rng.randf_range(STOP_DIST + 8.0, P - STOP_DIST - 8.0)
        var pos: Vector3 = node_pos(a.x, a.y) + Vector3(float(h.x), 0.0, float(h.y)) * along
        if not _far_from_player(pos, 45.0 if initial else 130.0):
            continue
        var id: String = ids[_rng.randi() % ids.size()]
        var col: Color = CarData.PAINTS[_rng.randi() % CarData.PAINTS.size()]
        if id == "taxi" or id == "police":
            col = CarData.default_paint(id)
        var car := TrafficCar.new()
        car.setup(self, id, col, a, h, lane, along)
        add_child(car)
        _traffic.append(car)
        return


func _spawn_ped() -> void:
    for attempt in 10:
        var b := Vector2i(_rng.randi_range(-N, N - 1), _rng.randi_range(-N, N - 1))
        var k: int = _rng.randi() % 4
        var dir: int = 1 if _rng.randf() < 0.5 else -1
        if not _far_from_player(corner_pos(b, k), 12.0):
            continue
        var ped := Pedestrian.new()
        ped.setup(self, b, k, dir)
        add_child(ped)
        _peds.append(ped)
        return


## Расстояние до ближайшего пешехода на пути (для торможения машин).
func ped_gap(front: Vector3, dirv: Vector3, reach: float) -> float:
    var best: float = reach
    var right := Vector3(-dirv.z, 0.0, dirv.x)
    for p in _peds:
        if not is_instance_valid(p):
            continue
        var rel: Vector3 = (p as Node3D).global_position - front
        rel.y = 0.0
        var fwd: float = rel.dot(dirv)
        if fwd < -0.5 or fwd > best:
            continue
        if absf(rel.dot(right)) < 2.0:
            best = maxf(fwd, 0.0)
    return best


func wreck_traffic(tc: TrafficCar, p: Vehicle, closing: float, contact_world: Vector3) -> void:
    var w: WreckCar = TrafficUtil.make_wreck(self, tc.car_id, tc.paint, tc.global_transform, tc.vel, p, closing, contact_world)
    _traffic.erase(tc)
    tc.queue_free()
    _wrecks.append(w)
    _wrecks = _wrecks.filter(func(x: Variant) -> bool: return is_instance_valid(x))
    while _wrecks.size() > 8:
        var old: Node = _wrecks.pop_front()
        old.queue_free()


func knock_ped(ped: Pedestrian, p: Vehicle) -> void:
    var rb: RigidBody3D = ped.make_ragdoll()
    rb.transform = Transform3D(ped.global_transform.basis, ped.global_position)
    add_child(rb)
    rb.linear_velocity = p.linear_velocity * 0.9 + Vector3(0.0, 3.5, 0.0)
    rb.angular_velocity = Vector3(randf_range(-6.0, 6.0), randf_range(-3.0, 3.0), randf_range(-6.0, 6.0))
    _peds.erase(ped)
    ped.queue_free()
    get_tree().create_timer(8.0).timeout.connect(func() -> void:
        if is_instance_valid(rb):
            rb.queue_free())


func blast_ped(ped: Pedestrian, origin: Vector3, power: float) -> void:
    var rb: RigidBody3D = ped.make_ragdoll()
    rb.transform = Transform3D(ped.global_transform.basis, ped.global_position)
    add_child(rb)
    var dir: Vector3 = (ped.global_position - origin)
    dir = dir.normalized() if dir.length() > 0.01 else Vector3.UP
    rb.linear_velocity = (dir + Vector3.UP * 0.8) * 12.0 * power
    rb.angular_velocity = Vector3(randf_range(-8.0, 8.0), randf_range(-4.0, 4.0), randf_range(-8.0, 8.0))
    _peds.erase(ped)
    ped.queue_free()
    get_tree().create_timer(8.0).timeout.connect(func() -> void:
        if is_instance_valid(rb):
            rb.queue_free())


func blast_car(tc: TrafficCar, origin: Vector3, power: float) -> void:
    var w: WreckCar = TrafficUtil.make_blast_wreck(self, tc.car_id, tc.paint, tc.global_transform, tc.vel, origin, power)
    _traffic.erase(tc)
    tc.queue_free()
    _wrecks.append(w)
