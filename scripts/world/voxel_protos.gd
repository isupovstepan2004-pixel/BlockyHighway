class_name VoxelProtos
extends RefCounted
## Воксельные прототипы объектов карты: здания, дома, деревья, фонари, знаки, билборды, камни,
## заправка, закусочная. Строятся лениво — когда объект впервые получает урон.
## Локальные координаты: (0,0,0) — центр основания объекта.

static func make(kind: String, params: Dictionary, mats: Dictionary) -> VoxelBuilder:
    var b: VoxelBuilder
    match kind:
        "building":
            b = building(params)
        "house":
            b = house(params)
        "tree":
            b = tree(params, mats)
        "lamp":
            b = lamp()
        "tl_pole":
            b = tl_pole()
        "sign_post":
            b = sign_post()
        "billboard":
            b = billboard(params)
        "power_pole":
            b = power_pole()
        "rock":
            b = rock(params)
        "station":
            b = station()
        "diner":
            b = diner()
        _:
            b = building(params)
    if kind != "tree":
        b.materials = mats
    return b


static func building_vs(w: float, h: float, d: float) -> float:
    var area: float = 2.0 * (w * h + d * h) + 2.0 * w * d
    return clampf(snappedf(sqrt(area / 9000.0), 0.25), 0.5, 2.0)


static func _fillm(b: VoxelBuilder, a: Vector3, c: Vector3, layer: String, col: Color) -> void:
    var s: float = b.size
    b.fill(Vector3i(floori(a.x / s), floori(a.y / s), floori(a.z / s)), Vector3i(ceili(c.x / s) - 1, ceili(c.y / s) - 1, ceili(c.z / s) - 1), layer, col)


static func _boxc(b: VoxelBuilder, size: Vector3, center: Vector3, layer: String, col: Color, hollow: bool = false) -> void:
    var a: Vector3 = center - size * 0.5
    var c: Vector3 = center + size * 0.5
    if not hollow:
        _fillm(b, a, c, layer, col)
        return
    var s: float = b.size
    var lo := Vector3i(floori(a.x / s), floori(a.y / s), floori(a.z / s))
    var hi := Vector3i(ceili(c.x / s) - 1, ceili(c.y / s) - 1, ceili(c.z / s) - 1)
    for x in range(lo.x, hi.x + 1):
        for y in range(lo.y, hi.y + 1):
            for z in range(lo.z, hi.z + 1):
                if x == lo.x or x == hi.x or y == lo.y or y == hi.y or z == lo.z or z == hi.z:
                    b.put(x, y, z, layer, col)


static func building(p: Dictionary) -> VoxelBuilder:
    var vs: float = float(p["vs"])
    var w: float = float(p["w"])
    var h: float = float(p["h"])
    var d: float = float(p["d"])
    var col: Color = p["color"]
    var nx: int = maxi(3, roundi(w / vs))
    var ny: int = maxi(3, roundi(h / vs))
    var nz: int = maxi(3, roundi(d / vs))
    var b := VoxelBuilder.new()
    b.size = vs
    b.origin = Vector3(-float(nx) * vs * 0.5, 0.0, -float(nz) * vs * 0.5)
    var fh: int = maxi(2, roundi(3.6 / vs))
    var floors: int = ny / fh
    var with_floors: bool = nx * nz * floors <= 9000
    var inner := Color(col.r * 0.8, col.g * 0.8, col.b * 0.8, col.a)
    for x in nx:
        for y in ny:
            for z in nz:
                var shell: bool = x == 0 or x == nx - 1 or z == 0 or z == nz - 1 or y == 0 or y == ny - 1
                if shell:
                    b.put(x, y, z, "paint", col)
                elif with_floors and y % fh == 0:
                    b.put(x, y, z, "trim", inner)
    return b


static func house(p: Dictionary) -> VoxelBuilder:
    var vs: float = 0.3
    var w: float = float(p["w"])
    var d: float = float(p["d"])
    var wall_h: float = float(p["wall_h"])
    var wall: Color = p["wall"]
    var roof: Color = p["roof"]
    var nx: int = roundi(w / vs)
    var nz: int = roundi(d / vs)
    var nyw: int = roundi(wall_h / vs)
    var b := VoxelBuilder.new()
    b.size = vs
    b.origin = Vector3(-float(nx) * vs * 0.5, 0.0, -float(nz) * vs * 0.5)
    var slab := Color(0.55, 0.55, 0.56)
    for x in nx:
        for z in nz:
            b.put(x, 0, z, "trim", slab)
    for y in range(1, nyw):
        for x in nx:
            for z in nz:
                if x == 0 or x == nx - 1 or z == 0 or z == nz - 1:
                    b.put(x, y, z, "paint", wall)
    # дверь (z == 0, фасад) и окна
    var dx: int = nx / 2
    for x in range(dx - 2, dx + 2):
        for y in range(1, 8):
            b.erase(x, y, 0)
    var win_cols: Array = [nx / 5, nx * 4 / 5]
    for wx in win_cols:
        for x in range(int(wx) - 2, int(wx) + 3):
            for y in range(5, 10):
                b.put(x, y, 0, "glass", Color(0.45, 0.62, 0.78, 0.55))
                b.put(x, y, nz - 1, "glass", Color(0.45, 0.62, 0.78, 0.55))
    for z in range(nz / 2 - 2, nz / 2 + 3):
        for y in range(5, 10):
            b.put(0, y, z, "glass", Color(0.45, 0.62, 0.78, 0.55))
            b.put(nx - 1, y, z, "glass", Color(0.45, 0.62, 0.78, 0.55))
    # двускатная крыша
    for z in range(-1, nz + 1):
        var zc: int = clampi(z, 0, nz - 1)
        var rh: int = int(float(mini(zc, nz - 1 - zc)) * 0.85) + 1
        for x in range(-1, nx + 1):
            b.put(x, nyw - 1 + rh, z, "trim", roof)
            b.put(x, nyw - 2 + rh, z, "trim", roof)
        if z >= 0 and z < nz:
            pass
    # фронтоны
    for z in nz:
        var rh2: int = int(float(mini(z, nz - 1 - z)) * 0.85) + 1
        for y in range(nyw, nyw - 2 + rh2):
            b.put(0, y, z, "paint", wall)
            b.put(nx - 1, y, z, "paint", wall)
    # труба
    for y in range(nyw, nyw + 12):
        for x in range(int(nx * 0.7), int(nx * 0.7) + 3):
            for z in range(int(nz * 0.3), int(nz * 0.3) + 3):
                b.put(x, y, z, "trim", Color(0.45, 0.25, 0.2))
    return b


static func tree(p: Dictionary, mats: Dictionary) -> VoxelBuilder:
    var rng := RandomNumberGenerator.new()
    rng.seed = int(p.get("seed", 1))
    var b: VoxelBuilder = WorldKit.tree_builder(bool(p["pine"]), rng, float(p["vs"]), mats)
    b.size = float(p["vs"]) * float(p.get("scale", 1.0))
    return b


static func lamp() -> VoxelBuilder:
    var b := VoxelBuilder.new()
    b.size = 0.11
    var gray := Color(0.3, 0.31, 0.33)
    b.fill(Vector3i(-1, 0, -1), Vector3i(0, 72, 0), "trim", gray)
    b.fill(Vector3i(-6, 72, -2), Vector3i(5, 74, 2), "paint", Color(1.0, 0.92, 0.7))
    return b


static func tl_pole() -> VoxelBuilder:
    var b := VoxelBuilder.new()
    b.size = 0.125
    b.fill(Vector3i(-1, 0, -1), Vector3i(0, 48, 0), "trim", Color(0.25, 0.26, 0.28))
    b.fill(Vector3i(-2, 49, -2), Vector3i(1, 56, 1), "paint", Color(0.15, 0.15, 0.17))
    return b


static func sign_post() -> VoxelBuilder:
    var b := VoxelBuilder.new()
    b.size = 0.1
    b.fill(Vector3i(0, 0, 0), Vector3i(0, 20, 0), "trim", Color(0.3, 0.3, 0.32))
    b.fill(Vector3i(-6, 20, -1), Vector3i(6, 30, 0), "paint", Color(0.98, 0.8, 0.05))
    return b


static func billboard(p: Dictionary) -> VoxelBuilder:
    var b := VoxelBuilder.new()
    b.size = 0.25
    var dark := Color(0.2, 0.2, 0.22)
    for px in [-5.0, 5.0]:
        _boxc(b, Vector3(0.5, 8.0, 0.5), Vector3(float(px), 4.0, 0.0), "trim", dark)
    _boxc(b, Vector3(14.0, 5.5, 0.5), Vector3(0.0, 9.5, 0.0), "paint", p["color"])
    return b


static func power_pole() -> VoxelBuilder:
    var b := VoxelBuilder.new()
    b.size = 0.17
    var wood := Color(0.32, 0.22, 0.14)
    _boxc(b, Vector3(0.35, 11.0, 0.35), Vector3(0.0, 5.5, 0.0), "trim", wood)
    _boxc(b, Vector3(3.4, 0.22, 0.22), Vector3(0.0, 10.4, 0.0), "trim", wood)
    return b


static func rock(p: Dictionary) -> VoxelBuilder:
    var rx: float = float(p["rx"])
    var ry: float = float(p["ry"])
    var rz: float = float(p["rz"])
    var col: Color = p["color"]
    var vs: float = maxf(0.3, maxf(rx, rz) / 9.0)
    var b := VoxelBuilder.new()
    b.size = vs
    var nx: int = ceili(rx / vs)
    var ny: int = ceili(ry / vs)
    var nz: int = ceili(rz / vs)
    for x in range(-nx, nx + 1):
        for y in range(-ny, ny + 1):
            for z in range(-nz, nz + 1):
                var q: float = pow(float(x) / float(nx), 2.0) + pow(float(y) / float(ny), 2.0) + pow(float(z) / float(nz), 2.0)
                if q <= 1.0:
                    b.put(x, y, z, "paint", col)
    return b


static func station() -> VoxelBuilder:
    var b := VoxelBuilder.new()
    b.size = 0.3
    var white := Color(0.92, 0.92, 0.9)
    var red := Color(0.8, 0.1, 0.08)
    _boxc(b, Vector3(11.0, 4.2, 7.0), Vector3(9.0, 2.2, 3.5), "paint", white, true)
    _boxc(b, Vector3(11.8, 0.4, 7.8), Vector3(9.0, 4.5, 3.5), "trim", red)
    _boxc(b, Vector3(13.0, 0.5, 8.0), Vector3(-6.0, 5.6, -2.5), "trim", red)
    for px in [-11.5, -0.5]:
        for pz in [-6.0, 1.0]:
            _boxc(b, Vector3(0.5, 5.4, 0.5), Vector3(float(px), 2.8, float(pz)), "trim", white)
    for px2 in [-8.0, -4.0]:
        _boxc(b, Vector3(0.7, 1.5, 1.0), Vector3(float(px2), 0.9, -2.5), "paint", red)
    _boxc(b, Vector3(0.4, 11.0, 0.4), Vector3(-15.0, 5.5, 6.0), "trim", Color(0.2, 0.2, 0.22))
    _boxc(b, Vector3(4.2, 2.6, 0.4), Vector3(-15.0, 10.8, 6.0), "paint", Color(1.0, 0.85, 0.3))
    return b


static func diner() -> VoxelBuilder:
    var b := VoxelBuilder.new()
    b.size = 0.3
    _boxc(b, Vector3(14.0, 4.0, 8.0), Vector3(6.0, 2.1, 0.0), "paint", Color(0.92, 0.92, 0.9), true)
    _boxc(b, Vector3(14.4, 0.7, 8.4), Vector3(6.0, 4.4, 0.0), "trim", Color(0.8, 0.1, 0.08))
    _boxc(b, Vector3(0.4, 9.0, 0.4), Vector3(-8.0, 4.5, 5.0), "trim", Color(0.2, 0.2, 0.22))
    _boxc(b, Vector3(5.0, 3.0, 0.4), Vector3(-8.0, 8.8, 5.0), "paint", Color(1.0, 0.85, 0.3))
    return b
