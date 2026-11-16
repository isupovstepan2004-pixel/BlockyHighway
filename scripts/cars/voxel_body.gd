class_name VoxelBody
extends Node3D
## Разрушаемое воксельное тело в стиле Teardown.
## - Воксели в VoxelBuilder, меш разбит на чанки, перестраиваются только изменённые.
## - hit(): неровная дыра (вытянутая по направлению удара), обугливание, кубики-обломки, пыль, искры.
## - Куски, потерявшие связь с основной массой (или с землёй, если anchor_y задан), отваливаются
##   отдельными телами (VoxelRigid — они тоже ломаются).
## - static_collision: коллизия строится из мешей чанков (для зданий и деревьев).
## - paint(): перекраска вокселей (баллончик).

signal built

const CHUNK: int = 14
const NEIGH: Array = [
    Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
    Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]

var host: RigidBody3D
var vb: VoxelBuilder
var vsize: float = 0.1
var vorigin: Vector3 = Vector3.ZERO
var initial_cells: int = 0
var alive_cells: int = 0
var static_collision: bool = false
var anchor_y: int = -100000
var rigid_fragments: bool = false

var _chunk_cells: Dictionary = {}   # Vector3i -> Dictionary (множество клеток)
var _chunk_mi: Dictionary = {}      # Vector3i -> MeshInstance3D
var _chunk_col: Dictionary = {}     # Vector3i -> CollisionShape3D
var _dirty: Dictionary = {}
var _col_body: StaticBody3D
var _announce: bool = false


func setup(builder: VoxelBuilder, stagger: bool = false) -> void:
    for mi in _chunk_mi.values():
        (mi as Node).queue_free()
    for cs in _chunk_col.values():
        (cs as Node).queue_free()
    _chunk_mi.clear()
    _chunk_col.clear()
    _chunk_cells.clear()
    _dirty.clear()
    vb = builder
    vsize = builder.size
    vorigin = builder.origin
    if static_collision and _col_body == null:
        _col_body = StaticBody3D.new()
        _col_body.set_meta("vbody", self)
        _col_body.add_to_group("structure")
        add_child(_col_body)
    for p in vb.cells.keys():
        var ck: Vector3i = _chunk_of(p)
        if not _chunk_cells.has(ck):
            _chunk_cells[ck] = {}
        (_chunk_cells[ck] as Dictionary)[p] = true
        _dirty[ck] = true
    initial_cells = vb.cells.size()
    alive_cells = initial_cells
    if stagger:
        _announce = true
    else:
        _rebuild(99999)


func damage_ratio() -> float:
    if initial_cells <= 0:
        return 0.0
    return 1.0 - float(alive_cells) / float(initial_cells)


func _chunk_of(p: Vector3i) -> Vector3i:
    return Vector3i(floori(float(p.x) / float(CHUNK)), floori(float(p.y) / float(CHUNK)), floori(float(p.z) / float(CHUNK)))


func _cell_center(p: Vector3i) -> Vector3:
    return (Vector3(p) + Vector3(0.5, 0.5, 0.5)) * vsize + vorigin


func _hash01(p: Vector3i) -> float:
    var h: int = (p.x * 73856093) ^ (p.y * 19349663) ^ (p.z * 83492791)
    return float(h & 1023) / 1023.0


func _mark(p: Vector3i) -> void:
    _dirty[_chunk_of(p)] = true
    for nb in NEIGH:
        _dirty[_chunk_of(p + (nb as Vector3i))] = true


func _process(_delta: float) -> void:
    if not _dirty.is_empty():
        _rebuild(3)
    if _announce and _dirty.is_empty():
        _announce = false
        built.emit()


func _rebuild(max_chunks: int) -> void:
    var done: int = 0
    for ck in _dirty.keys():
        var key: Vector3i = ck
        _dirty.erase(key)
        var cd: Dictionary = _chunk_cells.get(key, {})
        if cd.is_empty():
            if _chunk_mi.has(key):
                (_chunk_mi[key] as Node).queue_free()
                _chunk_mi.erase(key)
            if _chunk_col.has(key):
                (_chunk_col[key] as Node).queue_free()
                _chunk_col.erase(key)
        else:
            var mesh: ArrayMesh = vb.build_cells(cd.keys())
            var mi: MeshInstance3D
            if _chunk_mi.has(key):
                mi = _chunk_mi[key]
            else:
                mi = MeshInstance3D.new()
                add_child(mi)
                _chunk_mi[key] = mi
            mi.mesh = mesh
            if static_collision and mesh.get_surface_count() > 0:
                var cs: CollisionShape3D = _chunk_col.get(key)
                if cs == null:
                    cs = CollisionShape3D.new()
                    _col_body.add_child(cs)
                    _chunk_col[key] = cs
                cs.shape = mesh.create_trimesh_shape()
        done += 1
        if done >= max_chunks:
            break


func _remove_cell(p: Vector3i) -> void:
    vb.cells.erase(p)
    vb.colors.erase(p)
    var ck: Vector3i = _chunk_of(p)
    if _chunk_cells.has(ck):
        (_chunk_cells[ck] as Dictionary).erase(p)
    _mark(p)


func _vel_at(world_pos: Vector3) -> Vector3:
    if host == null:
        return Vector3.ZERO
    return host.linear_velocity + host.angular_velocity.cross(world_pos - host.global_position)


func _layer_factor(layer: String) -> float:
    match layer:
        "glass":
            return 0.7
        "trim", "tire", "rim":
            return 1.15
    return 1.0


func _cells_in_sphere(center: Vector3, reach: float) -> Array:
    var rc: int = ceili(reach / vsize) + 1
    var c: Vector3 = (center - vorigin) / vsize
    var cc := Vector3i(floori(c.x), floori(c.y), floori(c.z))
    var lo: Vector3i = _chunk_of(cc - Vector3i(rc, rc, rc))
    var hi: Vector3i = _chunk_of(cc + Vector3i(rc, rc, rc))
    var out: Array = []
    for cx in range(lo.x, hi.x + 1):
        for cy in range(lo.y, hi.y + 1):
            for cz in range(lo.z, hi.z + 1):
                var cd: Dictionary = _chunk_cells.get(Vector3i(cx, cy, cz), {})
                out.append_array(cd.keys())
    return out


## Удар: центр в локальных координатах, радиус в метрах, push_dir — куда лететь обломкам (мир),
## depth_dir — локальное направление «вглубь» (вмятина вытягивается вдоль него).
## Возвращает число выбитых вокселей.
func hit(center: Vector3, radius: float, soot: float, push_dir: Vector3, depth_dir: Vector3 = Vector3.ZERO) -> int:
    var removed: Array = []
    var out: Array = []   # [локальный центр, цвет, слой]
    var has_dir: bool = depth_dir.length() > 0.01
    var dd: Vector3 = depth_dir.normalized() if has_dir else Vector3.ZERO
    for key in _cells_in_sphere(center, radius * 1.8):
        var p: Vector3i = key
        var pc: Vector3 = _cell_center(p)
        var rel: Vector3 = pc - center
        var dist: float = rel.length()
        if has_dir:
            var along: float = rel.dot(dd)
            var perp: Vector3 = rel - dd * along
            var a2: float = along * (0.62 if along > 0.0 else 1.0)
            dist = sqrt(perp.length_squared() + a2 * a2)
        var layer: String = vb.cells[p]
        var lf: float = _layer_factor(layer)
        if dist * lf > radius * 1.6:
            continue
        var e: float = dist * lf + (_hash01(p) - 0.5) * radius * 0.55
        if e < radius:
            out.append([pc, vb.colors[p], layer])
            removed.append(p)
        elif e < radius * 1.5:
            var col: Color = vb.colors[p]
            var k: float = soot * (1.0 - (e - radius) / (radius * 0.5)) * 0.85
            var burnt := Color(0.03, 0.025, 0.02, col.a)
            vb.colors[p] = col.lerp(burnt, clampf(k, 0.0, 0.9))
            _dirty[_chunk_of(p)] = true
    if removed.is_empty():
        return 0
    for p in removed:
        _remove_cell(p)
    alive_cells -= removed.size()
    _spawn_cubes(out, center, radius, push_dir)
    _detach_fragments(removed, push_dir)
    var wc: Vector3 = to_global(center)
    Fx.dust(wc, radius * 1.4, Color(0.62, 0.6, 0.58))
    Fx.sparks(wc, minf(radius, 3.0))
    return removed.size()


## Перекраска вокселей в сфере (баллончик). Возвращает число закрашенных.
func paint(center: Vector3, radius: float, col: Color) -> int:
    var n: int = 0
    for key in _cells_in_sphere(center, radius):
        var p: Vector3i = key
        if vb.cells[p] == "glass":
            continue
        if _cell_center(p).distance_to(center) > radius:
            continue
        var o: Color = vb.colors[p]
        vb.colors[p] = Color(col.r, col.g, col.b, o.a)
        _dirty[_chunk_of(p)] = true
        n += 1
    return n


func _spawn_cubes(out: Array, center: Vector3, radius: float, push_dir: Vector3) -> void:
    var cube: float = minf(vsize * 1.5, 0.7)
    var boost: float = clampf(vsize / 0.3, 1.0, 3.0)
    var want: int = clampi(int(float(out.size()) * 0.3 * boost), 4, 60)
    var stride: float = maxf(1.0, float(out.size()) / float(want))
    var wc: Vector3 = to_global(center)
    var i: float = 0.0
    while int(i) < out.size():
        var e: Array = out[int(i)]
        i += stride
        var lp: Vector3 = e[0]
        var col: Color = e[1]
        var wp: Vector3 = to_global(lp)
        var dir: Vector3 = (wp - wc).normalized()
        var v: Vector3 = _vel_at(wp) + dir * randf_range(1.5, 4.5) * (0.6 + minf(radius, 2.5)) + push_dir * randf_range(0.5, 3.0) + Vector3(0.0, randf_range(0.5, 3.0), 0.0)
        Debris.spawn_cube(wp, col, cube * randf_range(0.8, 1.2), v, host)


## Находит куски, потерявшие связь с основным телом/землёй, и отправляет их в свободный полёт.
func _detach_fragments(removed: Array, push_dir: Vector3) -> void:
    var anchored: bool = anchor_y > -1000
    var cap: int = (1 << 30) if anchored else maxi(150, int(float(vb.cells.size()) * 0.3))
    var seen: Dictionary = {}
    var main: Dictionary = {}
    var comps: Array = []
    for rp in removed:
        for nb in NEIGH:
            var q: Vector3i = (rp as Vector3i) + (nb as Vector3i)
            if not vb.cells.has(q) or seen.has(q) or main.has(q):
                continue
            var comp: Array = []
            var queue: Array = [q]
            seen[q] = true
            var head: int = 0
            var is_main: bool = false
            while head < queue.size():
                var cur: Vector3i = queue[head]
                head += 1
                comp.append(cur)
                if comp.size() > cap or (anchored and cur.y <= anchor_y):
                    is_main = true
                    break
                for nb2 in NEIGH:
                    var r: Vector3i = cur + (nb2 as Vector3i)
                    if not vb.cells.has(r):
                        continue
                    if main.has(r):
                        is_main = true
                    elif not seen.has(r):
                        seen[r] = true
                        queue.append(r)
                if is_main:
                    break
            if is_main:
                for cell in queue:
                    main[cell] = true
            else:
                comps.append(comp)
    if comps.is_empty():
        return
    if main.is_empty() and not anchored:
        var big: int = 0
        for i in comps.size():
            if (comps[i] as Array).size() > (comps[big] as Array).size():
                big = i
        comps.remove_at(big)
    for comp in comps:
        _release(comp as Array, push_dir)


func _release(cells: Array, push_dir: Vector3) -> void:
    var count: int = cells.size()
    if count <= 10:
        for p in cells:
            var cp: Vector3i = p
            var wp: Vector3 = to_global(_cell_center(cp))
            var col: Color = vb.colors[cp]
            Debris.spawn_cube(wp, col, minf(vsize * 1.4, 0.8), _vel_at(wp) + push_dir * randf_range(0.5, 2.0), host)
            _remove_cell(cp)
        alive_cells -= count
        return
    var minp: Vector3i = cells[0]
    var maxp: Vector3i = cells[0]
    for p in cells:
        var cp: Vector3i = p
        minp = Vector3i(mini(minp.x, cp.x), mini(minp.y, cp.y), mini(minp.z, cp.z))
        maxp = Vector3i(maxi(maxp.x, cp.x), maxi(maxp.y, cp.y), maxi(maxp.z, cp.z))
    var fb := VoxelBuilder.new()
    fb.size = vsize
    fb.origin = Vector3.ZERO
    fb.materials = vb.materials
    for p in cells:
        var cp: Vector3i = p
        fb.put(cp.x - minp.x, cp.y - minp.y, cp.z - minp.z, vb.cells[cp], vb.colors[cp])
    for p in cells:
        _remove_cell(p as Vector3i)
    alive_cells -= count
    var dims: Vector3 = Vector3(maxp - minp + Vector3i.ONE) * vsize
    var corner: Vector3 = Vector3(minp) * vsize + vorigin
    var xf: Transform3D = global_transform * Transform3D(Basis(), corner)
    var center_w: Vector3 = xf * (dims * 0.5)
    var vel: Vector3 = _vel_at(center_w) + push_dir * randf_range(1.0, 3.5) + Vector3(0.0, randf_range(0.5, 2.0), 0.0)
    var ang := Vector3(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5), randf_range(-1.5, 1.5))
    if rigid_fragments and count > 60:
        var m: float = clampf(float(count) * vsize * vsize * vsize * 900.0, 30.0, 25000.0)
        VoxelRigid.spawn(fb, xf, dims, m, vel * 0.5, ang * 0.5)
    else:
        Debris.spawn_fragment(xf, fb.build(), dims, clampf(float(count) * 0.35, 1.0, 300.0), vel, ang * 2.0, host)
    Fx.dust(center_w, minf(0.8 + float(count) * 0.002, 3.0))
