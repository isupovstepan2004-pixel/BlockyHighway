class_name CarFactory
extends RefCounted
## Создаёт материалы, меши кузова/колёс и визуальную копию машины для витрины.

static var _mats: Dictionary = {}
static var _cache: Dictionary = {}


static func _mat(metallic: float, rough: float) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.vertex_color_use_as_albedo = true
    m.vertex_color_is_srgb = true
    m.metallic = metallic
    m.roughness = rough
    return m


static func _emissive(c: Color, energy: float) -> StandardMaterial3D:
    var m: StandardMaterial3D = _mat(0.0, 0.3)
    m.emission_enabled = true
    m.emission = c
    m.emission_energy_multiplier = energy
    return m


static func materials() -> Dictionary:
    if not _mats.is_empty():
        return _mats
    var paint: StandardMaterial3D = _mat(0.4, 0.3)
    paint.clearcoat_enabled = true
    paint.clearcoat = 0.8
    paint.clearcoat_roughness = 0.08
    _mats["paint"] = paint
    _mats["trim"] = _mat(0.1, 0.8)
    _mats["head"] = _emissive(Color(1.0, 0.93, 0.75), 1.6)
    _mats["tail"] = _emissive(Color(1.0, 0.05, 0.03), 1.2)
    _mats["blue"] = _emissive(Color(0.1, 0.3, 1.0), 1.8)
    var glass: StandardMaterial3D = _mat(0.3, 0.05)
    glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _mats["glass"] = glass
    _mats["tire"] = _mat(0.0, 0.95)
    _mats["rim"] = _mat(0.9, 0.3)
    return _mats


static func build_body_mesh(id: String, paint: Color) -> ArrayMesh:
    var key: String = "body_%s_%s" % [id, paint.to_html()]
    if _cache.has(key):
        return _cache[key]
    var b := VoxelBuilder.new()
    b.materials = materials()
    var model: CarModel = (CarData.MODELS[id] as GDScript).new()
    model.build(b, paint)
    var mesh: ArrayMesh = b.build()
    _cache[key] = mesh
    return mesh


## Свежий (не кэшированный) билдер кузова — для разрушаемой машины.
static func make_builder(id: String, paint: Color) -> VoxelBuilder:
    var b := VoxelBuilder.new()
    b.materials = materials()
    var model: CarModel = (CarData.MODELS[id] as GDScript).new()
    model.build(b, paint)
    return b


static func build_wheel_mesh(stats: Dictionary) -> ArrayMesh:
    var key: String = "wheel_%s_%s_%s" % [str(stats["wheel_radius"]), str(stats["wheel_width"]), str(stats["tread"])]
    if _cache.has(key):
        return _cache[key]
    var b := VoxelBuilder.new()
    var wr: float = float(stats["wheel_radius"])
    b.size = clampf(wr / 5.5, 0.05, 0.11)
    b.materials = materials()
    var radius: float = wr / b.size
    var half_w: int = maxi(1, roundi(float(stats["wheel_width"]) / b.size / 2.0))
    var n: int = ceili(radius)
    var tread: bool = bool(stats["tread"])
    var tire_col := Color(0.05, 0.05, 0.055)
    var rim_col := Color(0.75, 0.77, 0.8)
    var dark := Color(0.08, 0.08, 0.09)
    for y in range(-n, n):
        for z in range(-n, n):
            var fy: float = float(y) + 0.5
            var fz: float = float(z) + 0.5
            var r: float = sqrt(fy * fy + fz * fz)
            if r > radius:
                continue
            var ang: float = atan2(fz, fy) + PI
            var sector: int = int(floor(ang / (TAU / 10.0)))
            var knob: int = int(floor(ang / (TAU / 18.0)))
            for x in range(-half_w, half_w):
                if r > radius * 0.66:
                    if tread and r > radius - 1.0 and knob % 2 == 0:
                        continue
                    b.put(x, y, z, "tire", tire_col)
                elif r <= 1.6:
                    b.put(x, y, z, "trim", dark)
                elif sector % 2 == 0 and r < radius * 0.62:
                    b.put(x, y, z, "trim", dark)
                else:
                    b.put(x, y, z, "rim", rim_col)
    var mesh: ArrayMesh = b.build()
    _cache[key] = mesh
    return mesh


## Визуальная копия (без физики) — для главного меню и гаража.
static func make_showroom_car(id: String, paint: Color) -> Node3D:
    var stats: Dictionary = CarData.get_stats(id)
    var root := Node3D.new()
    var body := MeshInstance3D.new()
    body.mesh = build_body_mesh(id, paint)
    root.add_child(body)
    var wmesh: ArrayMesh = build_wheel_mesh(stats)
    var wx: float = float(stats["wheel_x"])
    var wc: float = float(stats["wheel_c"])
    for ax in stats["axles"]:
        var a: Array = ax
        for sx in [-1.0, 1.0]:
            var w := MeshInstance3D.new()
            w.mesh = wmesh
            w.position = Vector3(float(sx) * wx, wc, float(a[0]))
            root.add_child(w)
    return root
