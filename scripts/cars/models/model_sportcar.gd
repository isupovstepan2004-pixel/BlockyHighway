extends CarModel
## Sportcar: низкий клиновидный суперкар. Вокселы 0.1 м, ось -Z = перед.
## Сетка: x = -9..9 (1.9 м), z = -22..21 (4.4 м), y = 0..11.

const TOP: Array = [[-22.0, 2.6], [-20.0, 4.0], [-8.0, 5.4], [8.0, 6.4], [18.0, 7.0], [21.0, 5.0]]
const CABIN: Array = [[-9.0, 6.0], [-1.0, 11.0], [4.0, 11.0], [11.0, 8.0], [13.0, 6.5]]
const WHEEL_Z: float = 1.35
const WHEEL_Y: float = 0.06
const ARCH_R: float = 0.43


func _curve(keys: Array, z: float) -> float:
    var first: Array = keys[0]
    if z <= float(first[0]):
        return float(first[1])
    for i in range(keys.size() - 1):
        var a: Array = keys[i]
        var c: Array = keys[i + 1]
        if z <= float(c[0]):
            var t: float = (z - float(a[0])) / (float(c[0]) - float(a[0]))
            return lerpf(float(a[1]), float(c[1]), t)
    var last: Array = keys[keys.size() - 1]
    return float(last[1])


func _top(z: int) -> int:
    return roundi(_curve(TOP, float(z) + 0.5))


func _cabin_top(z: int) -> int:
    return roundi(_curve(CABIN, float(z) + 0.5))


func _in_arch(x: int, y: int, z: int) -> bool:
    if absi(x) < 6:
        return false
    var zc: float = (float(z) + 0.5) * 0.1
    var dy: float = (float(y) + 0.5) * 0.1 - WHEEL_Y
    for wz in [-WHEEL_Z, WHEEL_Z]:
        var dz: float = zc - float(wz)
        if dz * dz + dy * dy < ARCH_R * ARCH_R:
            return true
    return false


func build(b: VoxelBuilder, paint: Color) -> void:
    b.size = 0.1
    b.origin = Vector3(-0.05, 0.0, 0.0)
    var dark := Color(0.045, 0.045, 0.05)
    var glass := Color(0.10, 0.17, 0.21, 0.55)
    var seat := Color(0.09, 0.09, 0.10)
    var steel := Color(0.78, 0.80, 0.82)
    var carbon := Color(0.03, 0.03, 0.035)

    # --- кузов
    for z in range(-22, 22):
        var top: int = _top(z)
        var hw: int = 9
        if z < -20:
            hw = 6
        elif z < -17:
            hw = 7
        elif z < -14:
            hw = 8
        if z > 19:
            hw = 8
        for x in range(-hw, hw + 1):
            for y in range(0, top + 1):
                if _in_arch(x, y, z):
                    continue
                if absi(x) == hw and y == top and top >= 4:
                    continue
                if y == 0:
                    b.put(x, y, z, "trim", dark)
                else:
                    b.put(x, y, z, "paint", paint)

    # пороги, сплиттер, решётка
    for z in range(-9, 10):
        for sx in [-9, 9]:
            b.put(sx, 1, z, "trim", dark)
    for z in range(-22, -18):
        for x in range(-6, 7):
            b.put(x, 1, z, "trim", dark)
    for x in range(-3, 4):
        for y in [1, 2]:
            b.put(x, y, -22, "trim", dark)

    # фары и задние огни
    for x in [-6, -5, -4, 4, 5, 6]:
        for y in [2, 3]:
            for z in [-22, -21]:
                b.put(x, y, z, "head", Color(1.0, 0.95, 0.8))
    for x in range(-7, 8):
        for z in [20, 21]:
            for y in [3, 4]:
                if absi(x) <= 1:
                    b.put(x, y, z, "trim", dark)
                else:
                    b.put(x, y, z, "tail", Color(0.9, 0.05, 0.04))

    # воздухозаборники на капоте, двери, ручки
    for z in range(-14, -8):
        var t: int = _top(z)
        for x in [-3, -2, 2, 3]:
            b.put(x, t, z, "trim", dark)
    for sx in [-9, 9]:
        for y in range(2, 6):
            b.put(sx, y, -3, "trim", dark)
            b.put(sx, y, 7, "trim", dark)
        b.put(sx, 4, 5, "rim", steel)

    # диффузор и выхлоп
    for z in range(19, 22):
        for x in range(-6, 7):
            b.put(x, 1, z, "trim", dark)
    for sx in [-3, 3]:
        b.put(sx, 1, 21, "rim", steel)

    # --- кабина (оболочка из стекла и стоек, внутри пусто)
    var region: Dictionary = {}
    for z in range(-9, 13):
        var bt: int = _top(z)
        var tc: int = _cabin_top(z)
        if tc <= bt:
            continue
        for y in range(bt + 1, tc + 1):
            var hx: int = 6
            if y >= tc - 1:
                hx = 5
            for x in range(-hx, hx + 1):
                region[Vector3i(x, y, z)] = true
    for key in region.keys():
        var p: Vector3i = key
        var x_edge: bool = not region.has(p + Vector3i(1, 0, 0)) or not region.has(p + Vector3i(-1, 0, 0))
        var top_open: bool = not region.has(p + Vector3i(0, 1, 0))
        var front_open: bool = not region.has(p + Vector3i(0, 0, -1))
        var back_open: bool = not region.has(p + Vector3i(0, 0, 1))
        if not (x_edge or top_open or front_open or back_open):
            continue
        var is_paint: bool = false
        if top_open and p.z >= -1 and p.z <= 4:
            is_paint = true
        elif x_edge:
            if p.y >= _cabin_top(p.z):
                is_paint = true
            elif p.z <= -4 or p.z >= 6:
                is_paint = true
        if is_paint:
            b.put(p.x, p.y, p.z, "paint", paint)
        else:
            b.put(p.x, p.y, p.z, "glass", glass)

    # --- салон
    for sx in [-1, 1]:
        for x in range(2, 6):
            var xx: int = x * sx
            for z in range(-1, 3):
                b.put(xx, 7, z, "trim", seat)
            for y in range(7, 10):
                b.put(xx, y, 3, "trim", seat)
        for x in [3, 4]:
            b.put(x * sx, 10, 3, "trim", seat)
    for x in range(-5, 6):
        for y in [7, 8]:
            for z in [-4, -3]:
                b.put(x, y, z, "trim", dark)
    for pos in [Vector3i(-4, 8, -2), Vector3i(-2, 8, -2), Vector3i(-3, 9, -2)]:
        b.put(pos.x, pos.y, pos.z, "trim", dark)

    # зеркала
    for sx in [-1, 1]:
        for x in [6, 7]:
            b.put(x * sx, 7, -6, "trim", dark)

    # антикрыло
    for x in [-6, 6]:
        for y in range(8, 10):
            b.put(x, y, 18, "trim", carbon)
    for x in range(-8, 9):
        for z in range(17, 21):
            b.put(x, 10, z, "trim", carbon)
    for x in [-8, 8]:
        for z in range(17, 21):
            b.put(x, 11, z, "trim", carbon)
