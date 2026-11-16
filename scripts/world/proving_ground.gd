class_name ProvingGround
extends Node3D
## Площадка: асфальт, трава, горы, деревья, фонари, трамплины, кирпичные стены и ящики (разрушаемые).

const ROAD_HALF: float = 27.0

var dworld: DestructibleWorld
var _bld_mat: ShaderMaterial
var _rng := RandomNumberGenerator.new()
var _asphalt: StandardMaterial3D
var _lamp_mat: StandardMaterial3D
var _brick_mats: Array = []
var _wood_mats: Array = []


func _ready() -> void:
    _rng.seed = 20261115
    _bld_mat = WorldKit.building_material()
    dworld = DestructibleWorld.new()
    dworld.building_material = _bld_mat
    add_child(dworld)
    _asphalt = _make_asphalt()
    _build_ground()
    _build_markings()
    _build_ramps()
    _build_props()
    _build_trees()
    _build_mountains()
    _build_lamps()
    _build_destructibles()


func set_night(on: bool) -> void:
    _lamp_mat.emission_energy_multiplier = 3.5 if on else 0.0
    _bld_mat.set_shader_parameter("night", 1.0 if on else 0.0)


func _flat_mat(c: Color, rough: float) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    m.roughness = rough
    return m


func _noise_tex(n: int, base: Color, var_amt: float, seed_v: int, speck: float) -> ImageTexture:
    var img := Image.create(n, n, false, Image.FORMAT_RGB8)
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_v
    for y in n:
        for x in n:
            var k: float = 1.0 + (rng.randf() - 0.5) * var_amt
            var c := Color(base.r * k, base.g * k, base.b * k)
            if rng.randf() < speck:
                c = c.lightened(0.25)
            img.set_pixel(x, y, c)
    img.generate_mipmaps()
    return ImageTexture.create_from_image(img)


func _make_asphalt() -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_texture = _noise_tex(256, Color(0.2, 0.2, 0.215), 0.4, 1234, 0.02)
    m.uv1_scale = Vector3(ROAD_HALF * 2.0 / 3.0, 600.0 / 3.0, 1.0)
    m.roughness = 0.82
    m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    return m


func _plane(size: Vector2, pos: Vector3, mat: Material) -> void:
    var mi := MeshInstance3D.new()
    var pm := PlaneMesh.new()
    pm.size = size
    mi.mesh = pm
    mi.material_override = mat
    mi.position = pos
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mi)


func _static_box(dims: Vector3, pos: Vector3, rot_deg: Vector3, mat: Material) -> StaticBody3D:
    var body := StaticBody3D.new()
    body.position = pos
    body.rotation_degrees = rot_deg
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = dims
    mi.mesh = bm
    mi.material_override = mat
    var cs := CollisionShape3D.new()
    var sh := BoxShape3D.new()
    sh.size = dims
    cs.shape = sh
    body.add_child(mi)
    body.add_child(cs)
    add_child(body)
    return body


func _build_ground() -> void:
    var body := StaticBody3D.new()
    var cs := CollisionShape3D.new()
    var sh := BoxShape3D.new()
    sh.size = Vector3(4000.0, 2.0, 4000.0)
    cs.shape = sh
    cs.position = Vector3(0.0, -1.0, 0.0)
    body.add_child(cs)
    add_child(body)
    # трава
    var grass := StandardMaterial3D.new()
    grass.albedo_texture = _noise_tex(128, Color(0.2, 0.36, 0.14), 0.5, 77, 0.0)
    grass.uv1_scale = Vector3(1000.0, 1000.0, 1.0)
    grass.roughness = 1.0
    grass.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    _plane(Vector2(4000.0, 4000.0), Vector3(0.0, -0.03, 0.0), grass)
    # асфальт
    _plane(Vector2(ROAD_HALF * 2.0, 600.0), Vector3(0.0, 0.0, 0.0), _asphalt)


func _build_markings() -> void:
    var white: StandardMaterial3D = _flat_mat(Color(0.9, 0.9, 0.85), 0.6)
    var yellow: StandardMaterial3D = _flat_mat(Color(0.95, 0.75, 0.1), 0.6)
    var box := BoxMesh.new()
    box.size = Vector3(0.2, 0.02, 3.0)
    var count: int = 70
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = box
    mm.instance_count = count
    for i in count:
        mm.set_instance_transform(i, Transform3D(Basis(), Vector3(0.0, 0.02, 80.0 - float(i) * 8.0)))
    var mmi := MultiMeshInstance3D.new()
    mmi.multimesh = mm
    mmi.material_override = white
    mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mmi)
    for sx in [-ROAD_HALF + 0.8, ROAD_HALF - 0.8]:
        var edge := MeshInstance3D.new()
        var eb := BoxMesh.new()
        eb.size = Vector3(0.25, 0.02, 600.0)
        edge.mesh = eb
        edge.material_override = yellow
        edge.position = Vector3(float(sx), 0.02, 0.0)
        edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(edge)


func _build_ramps() -> void:
    var concrete: StandardMaterial3D = _flat_mat(Color(0.5, 0.5, 0.52), 0.9)
    _static_box(Vector3(8.0, 0.6, 14.0), Vector3(-2.5, 1.4, -70.0), Vector3(14.0, 0.0, 0.0), concrete)
    _static_box(Vector3(8.0, 0.6, 14.0), Vector3(14.0, 1.4, -130.0), Vector3(14.0, 0.0, 0.0), concrete)
    # бетонные ограждения по краям
    for sx in [-ROAD_HALF - 0.5, ROAD_HALF + 0.5]:
        _static_box(Vector3(1.0, 1.2, 600.0), Vector3(float(sx), 0.6, 0.0), Vector3.ZERO, concrete)


func _build_props() -> void:
    for c in [Color(0.62, 0.22, 0.16), Color(0.55, 0.2, 0.15), Color(0.68, 0.3, 0.2), Color(0.5, 0.45, 0.42)]:
        _brick_mats.append(_flat_mat(c, 0.95))
    for c in [Color(0.58, 0.4, 0.2), Color(0.5, 0.34, 0.17), Color(0.64, 0.46, 0.25)]:
        _wood_mats.append(_flat_mat(c, 0.9))
    # ящики-пирамиды
    var rows: Array = [4, 3, 2, 1]
    for r in rows.size():
        var n: int = int(rows[r])
        for i in n:
            var x: float = -14.0 + (float(i) - float(n - 1) * 0.5) * 1.05
            _crate(Vector3(x, 0.5 + float(r) * 1.01, -40.0))
    for i in 5:
        for j in 3:
            _crate(Vector3(-14.0 + float(i) * 1.05, 0.5 + float(j) * 1.01, -100.0))
    # кирпичные стены
    _brick_wall(Vector3(2.0, 0.0, -12.0), 15, 6)
    _brick_wall(Vector3(-6.0, 0.0, -160.0), 17, 7)
    _brick_wall(Vector3(12.0, 0.0, -200.0), 11, 5)


func _crate(pos: Vector3) -> void:
    var b := Breakable.new()
    var mat: StandardMaterial3D = _wood_mats[_rng.randi() % _wood_mats.size()]
    b.setup(Vector3.ONE, mat.albedo_color, 25.0, 5.5, 8, mat)
    b.position = pos
    add_child(b)
    b.sleeping = true


func _brick_wall(center: Vector3, cols: int, rows: int) -> void:
    var bw: float = 0.8
    var bh: float = 0.4
    var bd: float = 0.4
    for r in rows:
        var odd: bool = r % 2 == 1
        var n: int = cols - 1 if odd else cols
        var shift: float = bw * 0.5 if odd else 0.0
        for i in n:
            var x: float = center.x + (float(i) - float(cols - 1) * 0.5) * bw + shift
            var y: float = bh * 0.5 + float(r) * (bh + 0.004)
            var mat: StandardMaterial3D = _brick_mats[_rng.randi() % _brick_mats.size()]
            var b := Breakable.new()
            b.setup(Vector3(bw - 0.004, bh, bd), mat.albedo_color, 6.0, 7.5, 5, mat)
            b.position = Vector3(x, y, center.z)
            add_child(b)
            b.sleeping = true


func _tree_mesh(pine: bool) -> ArrayMesh:
    var b := VoxelBuilder.new()
    b.size = 0.3
    b.materials = {"paint": _tree_leaf_mat(), "trim": _tree_leaf_mat()}
    var trunk := Color(0.32, 0.2, 0.1)
    var h: int = 9 if pine else 7
    for y in h:
        b.put(0, y, 0, "trim", trunk)
        b.put(-1, y, 0, "trim", trunk)
    var rr: int = 6
    for x in range(-rr, rr + 1):
        for y in range(0, 16):
            for z in range(-rr, rr + 1):
                var inside: bool = false
                var col := Color(0.16, 0.42, 0.14).lerp(Color(0.3, 0.55, 0.16), _rng.randf())
                if pine:
                    var layer_r: float = float(rr) * (1.0 - float(y) / 16.0) * (0.75 + 0.25 * float(y % 3 == 0))
                    inside = y >= 3 and sqrt(float(x * x + z * z)) <= layer_r
                    col = Color(0.08, 0.3, 0.14).lerp(Color(0.14, 0.42, 0.2), _rng.randf())
                else:
                    var dy: float = float(y) - 10.0
                    inside = y >= 6 and float(x * x + z * z) / 36.0 + dy * dy / 20.0 <= 1.0 and _rng.randf() > 0.06
                if inside:
                    b.put(x, y, z, "paint", col)
    return b.build()


func _tree_leaf_mat() -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.vertex_color_use_as_albedo = true
    m.vertex_color_is_srgb = true
    m.roughness = 1.0
    return m


func _build_trees() -> void:
    var mat: StandardMaterial3D = WorldKit.vc_mat()
    for kind in 2:
        var xs: Array = []
        for i in 90:
            var side: float = -1.0 if _rng.randf() < 0.5 else 1.0
            var x: float = side * _rng.randf_range(ROAD_HALF + 6.0, 190.0)
            var z: float = _rng.randf_range(-320.0, 160.0)
            var sc: float = _rng.randf_range(0.85, 1.7)
            var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(sc, sc, sc))
            xs.append(Transform3D(basis, Vector3(x, 0.0, z)))
        var mmi: MultiMeshInstance3D = WorldKit.scatter_multimesh(self, WorldKit.tree_mesh(kind == 1, _rng, 0.3), xs, mat)
        dworld.register_multimesh(mmi, xs, "tree", {"pine": kind == 1, "vs": 0.3}, AABB(Vector3(-1.9, 0.0, -1.9), Vector3(3.8, 5.6, 3.8)), Vector3(0.6, 3.0, 0.6), Vector3(0.0, 1.5, 0.0))


func _build_lamps() -> void:
    var pole_mat: StandardMaterial3D = _flat_mat(Color(0.3, 0.31, 0.33), 0.6)
    pole_mat.metallic = 0.6
    _lamp_mat = StandardMaterial3D.new()
    _lamp_mat.albedo_color = Color(1.0, 0.92, 0.7)
    _lamp_mat.emission_enabled = true
    _lamp_mat.emission = Color(1.0, 0.85, 0.55)
    _lamp_mat.emission_energy_multiplier = 0.0
    var pole := BoxMesh.new()
    pole.size = Vector3(0.25, 7.0, 0.25)
    var lamp := BoxMesh.new()
    lamp.size = Vector3(1.2, 0.25, 0.5)
    var pm := MultiMesh.new()
    pm.transform_format = MultiMesh.TRANSFORM_3D
    pm.mesh = pole
    var lm := MultiMesh.new()
    lm.transform_format = MultiMesh.TRANSFORM_3D
    lm.mesh = lamp
    var n: int = 12
    pm.instance_count = n * 2
    lm.instance_count = n * 2
    var idx: int = 0
    for side in [-1.0, 1.0]:
        for i in n:
            var z: float = 100.0 - float(i) * 36.0
            var x: float = float(side) * (ROAD_HALF - 1.5)
            pm.set_instance_transform(idx, Transform3D(Basis(), Vector3(x, 3.5, z)))
            lm.set_instance_transform(idx, Transform3D(Basis(), Vector3(x - float(side) * 0.7, 7.1, z)))
            idx += 1
    var pmi := MultiMeshInstance3D.new()
    pmi.multimesh = pm
    pmi.material_override = pole_mat
    add_child(pmi)
    var lmi := MultiMeshInstance3D.new()
    lmi.multimesh = lm
    lmi.material_override = _lamp_mat
    lmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(lmi)
    for i in pm.instance_count:
        var t: Transform3D = pm.get_instance_transform(i)
        var base: Vector3 = t.origin - Vector3(0.0, 3.5, 0.0)
        var xf := Transform3D(Basis(), base)
        var cs: CollisionShape3D = dworld.add_collision(xf, Vector3(0.3, 7.0, 0.3), Vector3(0.0, 3.5, 0.0))
        dworld.register("lamp", {}, xf, AABB(base + Vector3(-1.6, 0.0, -1.6), Vector3(3.2, 7.6, 3.2)), [[pmi, i], [lmi, i]], cs)


func _build_mountains() -> void:
    _ring(1100.0, 110.0, Color(0.12, 0.2, 0.17), Color(0.5, 0.55, 0.6), 1.0)
    _ring(1600.0, 260.0, Color(0.2, 0.26, 0.34), Color(0.78, 0.82, 0.9), 2.0)


func _ring(radius: float, height: float, low: Color, high: Color, seed_v: float) -> void:
    var seg: int = 128
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var tops: Array = []
    for i in seg + 1:
        var a: float = float(i) / float(seg) * TAU
        var k: float = 0.55 + 0.25 * sin(a * 3.0 + seed_v) + 0.15 * sin(a * 7.0 + seed_v * 2.0) + 0.08 * sin(a * 17.0 + seed_v * 5.0)
        if i == seg:
            k = float(tops[0])
        k = clampf(k + (_rng.randf() - 0.5) * 0.12 if i < seg else k, 0.15, 1.1)
        tops.append(k)
    for i in seg:
        var a0: float = float(i) / float(seg) * TAU
        var a1: float = float(i + 1) / float(seg) * TAU
        var h0: float = height * float(tops[i])
        var h1: float = height * float(tops[i + 1])
        var p0 := Vector3(cos(a0) * radius, -10.0, sin(a0) * radius)
        var p1 := Vector3(cos(a1) * radius, -10.0, sin(a1) * radius)
        var t0 := Vector3(cos(a0) * radius * 0.93, h0, sin(a0) * radius * 0.93)
        var t1 := Vector3(cos(a1) * radius * 0.93, h1, sin(a1) * radius * 0.93)
        var nrm: Vector3 = Vector3(-cos((a0 + a1) * 0.5), 0.5, -sin((a0 + a1) * 0.5)).normalized()
        var verts: Array = [p0, t0, t1, p0, t1, p1]
        var cols: Array = [low, high.lerp(low, 0.25), high.lerp(low, 0.25), low, high.lerp(low, 0.25), low]
        for j in 6:
            st.set_normal(nrm)
            st.set_color(cols[j])
            st.add_vertex(verts[j])
    var mi := MeshInstance3D.new()
    mi.mesh = st.commit()
    var m := StandardMaterial3D.new()
    m.vertex_color_use_as_albedo = true
    m.roughness = 1.0
    m.cull_mode = BaseMaterial3D.CULL_DISABLED
    m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
    mi.material_override = m
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mi)


func _build_destructibles() -> void:
    # дома
    var homes: Array = [
        [Vector3(-18.0, 0.0, -150.0), Color(0.85, 0.8, 0.7), Color(0.45, 0.2, 0.15)],
        [Vector3(16.0, 0.0, -175.0), Color(0.75, 0.55, 0.45), Color(0.3, 0.3, 0.34)],
        [Vector3(-16.0, 0.0, -205.0), Color(0.7, 0.78, 0.85), Color(0.4, 0.25, 0.18)],
    ]
    for hm in homes:
        var n := Node3D.new()
        n.position = hm[0]
        add_child(n)
        WorldKit.house_proxy(n, 11.1, 9.0, 4.2, hm[1], hm[2])
        dworld.register("house", {"w": 11.1, "d": 9.0, "wall_h": 4.2, "wall": hm[1], "roof": hm[2]}, n.transform, n.transform * AABB(Vector3(-5.85, 0.0, -4.8), Vector3(11.7, 7.9, 9.6)), [[n]])
    # башня для сноса
    var w: float = 20.0
    var h: float = 40.0
    var d: float = 20.0
    var vs: float = VoxelProtos.building_vs(w, h, d)
    w = snappedf(w, vs)
    h = snappedf(h, vs)
    d = snappedf(d, vs)
    var origin := Vector3(0.0, 0.0, -240.0)
    var tint := Color(0.55, 0.57, 0.62, 0.37)
    var bm := BoxMesh.new()
    bm.size = Vector3.ONE
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.use_colors = true
    mm.mesh = bm
    mm.instance_count = 1
    mm.set_instance_transform(0, Transform3D(Basis.from_scale(Vector3(w, h, d)), origin + Vector3(0.0, h * 0.5, 0.0)))
    mm.set_instance_color(0, tint)
    var mmi := MultiMeshInstance3D.new()
    mmi.multimesh = mm
    mmi.material_override = _bld_mat
    add_child(mmi)
    var xf := Transform3D(Basis(), origin)
    var cs: CollisionShape3D = dworld.add_collision(xf, Vector3(w, h, d), Vector3(0.0, h * 0.5, 0.0))
    dworld.register("building", {"w": w, "h": h, "d": d, "color": tint, "vs": vs}, xf, AABB(origin + Vector3(-w * 0.5, 0.0, -d * 0.5), Vector3(w, h, d)), [[mmi, 0]], cs)
