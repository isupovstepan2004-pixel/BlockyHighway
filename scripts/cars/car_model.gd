class_name CarModel
extends RefCounted
## База воксельных моделей: профильный кузов (пустая оболочка), кабина со стёклами и мелкие помощники.
## Клетка = b.size, x симметрично вокруг 0, перед = -Z, y вверх от низа кузова.

const DARK := Color(0.045, 0.045, 0.05)
const DARK2 := Color(0.08, 0.08, 0.09)
const GLASS := Color(0.10, 0.17, 0.21, 0.55)
const STEEL := Color(0.78, 0.80, 0.82)
const SEAT := Color(0.09, 0.09, 0.10)
const WHITE := Color(0.93, 0.93, 0.92)
const HEADC := Color(1.0, 0.95, 0.8)
const TAILC := Color(0.9, 0.05, 0.04)
const BLUEC := Color(0.1, 0.3, 1.0)
const CARBON := Color(0.03, 0.03, 0.035)

var _vs: float = 0.1
var _z0: int = 0
var _z1: int = 0
var _y0: int = 0
var _cham: bool = true
var _sill: int = 0
var _arch_x: int = 999
var _arches: Array = []
var _arch_y: float = 0.06
var _arch_r: float = 0.4
var _bt: Dictionary = {}
var _hw: Dictionary = {}
var _tm: Dictionary = {}
var _wm: Dictionary = {}
var _cz0: int = 0
var _cz1: int = 0
var _hx: int = 6
var _hxt: int = 5
var _ct: Dictionary = {}


func build(_b: VoxelBuilder, _paint: Color) -> void:
    pass


func curve(keys: Array, z: float) -> float:
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


func top_at(z: int) -> int:
    return int(_bt[z])


func cab_top_at(z: int) -> int:
    return int(_ct[z])


func box(b: VoxelBuilder, x0: int, y0: int, z0: int, x1: int, y1: int, z1: int, layer: String, col: Color) -> void:
    b.fill(Vector3i(x0, y0, z0), Vector3i(x1, y1, z1), layer, col)


## Ящик и его зеркальная копия (x -> -x). x0..x1 обычно положительные.
func sym(b: VoxelBuilder, x0: int, y0: int, z0: int, x1: int, y1: int, z1: int, layer: String, col: Color) -> void:
    b.fill(Vector3i(x0, y0, z0), Vector3i(x1, y1, z1), layer, col)
    b.fill(Vector3i(-x1, y0, z0), Vector3i(-x0, y1, z1), layer, col)


func clear_box(b: VoxelBuilder, x0: int, y0: int, z0: int, x1: int, y1: int, z1: int) -> void:
    for x in range(x0, x1 + 1):
        for y in range(y0, y1 + 1):
            for z in range(z0, z1 + 1):
                b.erase(x, y, z)


func _in_arch(y: int, z: int) -> bool:
    var zc: float = (float(z) + 0.5) * _vs
    var dy: float = (float(y) + 0.5) * _vs - _arch_y
    for wz in _arches:
        var dz: float = zc - float(wz)
        if dz * dz + dy * dy < _arch_r * _arch_r:
            return true
    return false


func _in_body(x: int, y: int, z: int) -> bool:
    if z < _z0 or z > _z1:
        return false
    var t: int = _bt[z]
    if y < _y0 or y > t:
        return false
    var w: int = _hw[z]
    var ax: int = absi(x)
    if ax > w:
        return false
    if _cham and ax == w and y == t and t >= 4:
        return false
    if ax >= _arch_x and _in_arch(y, z):
        return false
    return true


## Пустой профильный кузов. o: z0,z1,top[[z,h]],wid[[z,hw]],y0,arches[z в метрах],arch_y,arch_r,arch_x,cham,sill
func make_body(b: VoxelBuilder, paint: Color, o: Dictionary) -> void:
    _vs = b.size
    _z0 = int(o["z0"])
    _z1 = int(o["z1"])
    _y0 = int(o.get("y0", 0))
    _cham = bool(o.get("cham", true))
    _sill = int(o.get("sill", 0))
    _arches = o.get("arches", [])
    _arch_y = float(o.get("arch_y", 0.06))
    _arch_r = float(o.get("arch_r", 0.4))
    _arch_x = int(o.get("arch_x", 6)) if _arches.size() > 0 else 999
    var top_keys: Array = o["top"]
    var wid_keys: Array = o["wid"]
    _bt.clear()
    _hw.clear()
    _tm.clear()
    _wm.clear()
    for z in range(_z0, _z1 + 1):
        _bt[z] = roundi(curve(top_keys, float(z) + 0.5))
        _hw[z] = roundi(curve(wid_keys, float(z) + 0.5))
    for z in range(_z0, _z1 + 1):
        var tmin: int = _bt[z]
        var wmin: int = _hw[z]
        if z > _z0:
            tmin = mini(tmin, int(_bt[z - 1]))
            wmin = mini(wmin, int(_hw[z - 1]))
        if z < _z1:
            tmin = mini(tmin, int(_bt[z + 1]))
            wmin = mini(wmin, int(_hw[z + 1]))
        _tm[z] = tmin
        _wm[z] = wmin
    for z in range(_z0, _z1 + 1):
        var w: int = _hw[z]
        var t: int = _bt[z]
        for x in range(-w, w + 1):
            var ax: int = absi(x)
            for y in range(_y0, t + 1):
                if z > _z0 and z < _z1 and y > _y0 and y < int(_tm[z]) - 1 and ax < int(_wm[z]) - 1 and ax < _arch_x - 1:
                    continue
                if not _in_body(x, y, z):
                    continue
                var shell: bool = (not _in_body(x + 1, y, z)) or (not _in_body(x - 1, y, z)) or (not _in_body(x, y + 1, z)) or (not _in_body(x, y - 1, z)) or (not _in_body(x, y, z + 1)) or (not _in_body(x, y, z - 1))
                if not shell:
                    continue
                if y == _y0:
                    b.put(x, y, z, "trim", DARK)
                elif y <= _sill and ax >= w - 1:
                    b.put(x, y, z, "trim", DARK)
                else:
                    b.put(x, y, z, "paint", paint)


func _in_cab(x: int, y: int, z: int) -> bool:
    if z < _cz0 or z > _cz1:
        return false
    var bt: int = _bt[z]
    var ct: int = _ct[z]
    if y <= bt or y > ct:
        return false
    var hx: int = _hx if y < ct - 1 else _hxt
    return absi(x) <= hx


## Кабина: оболочка из стекла и стоек над кузовом (внутри пусто).
## o: z0,z1,cab[[z,h]],hx,hxt,roof0,roof1,pf,pb,bp[z стоек],back_solid,front_solid,glass
func make_cabin(b: VoxelBuilder, paint: Color, o: Dictionary) -> void:
    _cz0 = int(o["z0"])
    _cz1 = int(o["z1"])
    _hx = int(o["hx"])
    _hxt = int(o.get("hxt", _hx - 1))
    var keys: Array = o["cab"]
    var roof0: int = int(o["roof0"])
    var roof1: int = int(o["roof1"])
    var pf: int = int(o["pf"])
    var pb: int = int(o["pb"])
    var bp: Array = o.get("bp", [])
    var back_solid: bool = bool(o.get("back_solid", false))
    var front_solid: bool = bool(o.get("front_solid", false))
    var glass_col: Color = o.get("glass", GLASS)
    _ct.clear()
    for z in range(_cz0, _cz1 + 1):
        _ct[z] = roundi(curve(keys, float(z) + 0.5))
    var hxm: int = mini(_hx, _hxt)
    for z in range(_cz0, _cz1 + 1):
        var bt: int = _bt[z]
        var ct: int = _ct[z]
        if ct <= bt:
            continue
        var bmax: int = bt
        var cmin: int = ct
        if z > _cz0:
            bmax = maxi(bmax, int(_bt[z - 1]))
            cmin = mini(cmin, int(_ct[z - 1]))
        if z < _cz1:
            bmax = maxi(bmax, int(_bt[z + 1]))
            cmin = mini(cmin, int(_ct[z + 1]))
        for y in range(bt + 1, ct + 1):
            var hx: int = _hx if y < ct - 1 else _hxt
            for x in range(-hx, hx + 1):
                var ax: int = absi(x)
                if z > _cz0 and z < _cz1 and y > bmax and y < cmin - 1 and ax < hxm - 1:
                    continue
                var x_edge: bool = (not _in_cab(x + 1, y, z)) or (not _in_cab(x - 1, y, z))
                var top_open: bool = not _in_cab(x, y + 1, z)
                var front_open: bool = not _in_cab(x, y, z - 1)
                var back_open: bool = not _in_cab(x, y, z + 1)
                if not (x_edge or top_open or front_open or back_open):
                    continue
                var is_paint: bool = false
                if top_open and z >= roof0 and z <= roof1:
                    is_paint = true
                elif x_edge:
                    if y >= ct or z <= pf or z >= pb or bp.has(z):
                        is_paint = true
                if not is_paint and back_open and back_solid:
                    is_paint = true
                if not is_paint and front_open and front_solid:
                    is_paint = true
                if is_paint:
                    b.put(x, y, z, "paint", paint)
                else:
                    b.put(x, y, z, "glass", glass_col)


## Ряд сидений: подушка 3 клетки + спинка сзади (z+3).
func seat_row(b: VoxelBuilder, z: int, y: int, xin: int, xout: int, col: Color = SEAT, back_h: int = 3) -> void:
    for sx in [-1, 1]:
        for x in range(xin, xout + 1):
            var xx: int = x * int(sx)
            for dz in range(0, 3):
                b.put(xx, y, z + dz, "trim", col)
            for dy in range(0, back_h):
                b.put(xx, y + dy, z + 3, "trim", col)


## Панель приборов и руль (водитель слева: wheel_x < 0).
func cockpit(b: VoxelBuilder, dash_z: int, y: int, half: int, wheel_x: int) -> void:
    for z in range(dash_z, dash_z + 3):
        for x in range(-half, half + 1):
            b.put(x, y, z, "trim", DARK)
    b.put(wheel_x - 1, y + 2, dash_z + 3, "trim", DARK)
    b.put(wheel_x + 1, y + 2, dash_z + 3, "trim", DARK)
    b.put(wheel_x, y + 3, dash_z + 3, "trim", DARK)
    b.put(wheel_x, y + 1, dash_z + 3, "trim", DARK)
