class_name TrafficCar
extends AnimatableBody3D
## Машина городского трафика: едет по полосам, стоит на красный, пропускает пешеходов,
## сворачивает на перекрёстках. При сильном ударе игрока превращается в WreckCar.

var city: CityMap
var car_id: String = "sedan"
var paint: Color = Color.WHITE
var stats: Dictionary = {}
var heading: Vector2i = Vector2i(1, 0)   # (x, z) единичное направление
var lane: int = 0
var tgt: Vector2i = Vector2i.ZERO        # перекрёсток, к которому едем
var speed: float = 0.0
var cruise: float = 13.0
var vel: Vector3 = Vector3.ZERO

var _mode: int = 0                        # 0 — прямо, 1 — поворот по кривой Безье
var _t: float = 0.0
var _p0: Vector3 = Vector3.ZERO
var _p1: Vector3 = Vector3.ZERO
var _p2: Vector3 = Vector3.ZERO
var _blen: float = 10.0
var _next_heading: Vector2i = Vector2i.ZERO
var _next_lane: int = 0
var _half_len: float = 2.4
var _wheels: Array = []
var _wheel_r: float = 0.35
var _gy: float = 0.0


static func right_of(h: Vector2i) -> Vector3:
    return Vector3(-float(h.y), 0.0, float(h.x))


static func yaw_of(d: Vector3) -> float:
    return atan2(-d.x, -d.z)


func setup(c: CityMap, id: String, col: Color, node_a: Vector2i, h: Vector2i, ln: int, along: float) -> void:
    city = c
    car_id = id
    paint = col
    heading = h
    lane = ln
    tgt = node_a + h
    stats = CarData.get_stats(id)
    _wheel_r = float(stats["wheel_radius"])
    _gy = _wheel_r - float(stats["wheel_c"]) + CityMap.ROAD_Y
    _half_len = float(stats["length"]) * 0.5
    cruise = randf_range(11.0, 16.0)
    if id == "bus" or id == "truck":
        cruise *= 0.8
    var dirv: Vector3 = _dirv()
    var a: Vector3 = CityMap.node_pos(node_a.x, node_a.y)
    position = a + dirv * along + right_of(h) * CityMap.lane_off(ln)
    position.y = _gy
    rotation.y = yaw_of(dirv)
    speed = cruise * 0.6


func _dirv() -> Vector3:
    return Vector3(float(heading.x), 0.0, float(heading.y))


func _ready() -> void:
    add_to_group("traffic")
    sync_to_physics = true
    var mi := MeshInstance3D.new()
    mi.mesh = CarFactory.build_body_mesh(car_id, paint)
    add_child(mi)
    for box in stats["collision"]:
        var cs := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = box[0]
        cs.shape = shape
        cs.position = box[1]
        add_child(cs)
    var wmesh: ArrayMesh = CarFactory.build_wheel_mesh(stats)
    var wx: float = float(stats["wheel_x"])
    for ax in stats["axles"]:
        var a: Array = ax
        for sx in [-1.0, 1.0]:
            var w := MeshInstance3D.new()
            w.mesh = wmesh
            w.position = Vector3(float(sx) * wx, float(stats["wheel_c"]), float(a[0]))
            add_child(w)
            _wheels.append(w)


func _physics_process(delta: float) -> void:
    var dirv: Vector3 = -global_transform.basis.z
    dirv.y = 0.0
    dirv = dirv.normalized()
    if _check_player():
        return

    var v_target: float = cruise
    if _mode == 1:
        v_target = minf(v_target, 7.0)

    # препятствие впереди
    var reach: float = 5.0 + speed * 1.5
    var gap: float = _front_gap(dirv, reach)
    var ped_gap: float = city.ped_gap(global_position + dirv * _half_len, dirv, reach)
    gap = minf(gap, ped_gap)
    if gap < reach:
        v_target = minf(v_target, sqrt(2.0 * 7.0 * maxf(gap - 2.5, 0.0)))

    if _mode == 0:
        var c: Vector3 = CityMap.node_pos(tgt.x, tgt.y)
        var to_c: float = (c - global_position).dot(dirv)
        var d_stop: float = to_c - CityMap.STOP_DIST - _half_len
        var axis: int = 0 if heading.x != 0 else 1
        var st: int = city.light_state(axis)
        var must_stop: bool = false
        if st == 0:
            must_stop = d_stop > -1.5
        elif st == 1:
            must_stop = d_stop > speed * speed / 10.0 + 1.0
        if must_stop:
            var lim: float = maxf(d_stop, 0.0)
            v_target = minf(v_target, 0.0 if lim < 0.3 else sqrt(2.0 * 6.0 * lim))
        speed = move_toward(speed, v_target, (3.2 if v_target > speed else 9.0) * delta)
        var step: Vector3 = dirv * speed * delta
        var np: Vector3 = global_position + step
        # держим точную линию полосы
        var lane_pos: Vector3 = c + right_of(heading) * CityMap.lane_off(lane)
        if heading.x != 0:
            np.z = lane_pos.z
        else:
            np.x = lane_pos.x
        np.y = _gy
        vel = step / maxf(delta, 0.0001)
        global_position = np
        if to_c <= CityMap.ENTRY_DIST:
            _begin_turn(c)
    else:
        speed = move_toward(speed, v_target, (3.2 if v_target > speed else 9.0) * delta)
        _t += speed * delta / maxf(_blen, 1.0)
        var t: float = minf(_t, 1.0)
        var pos: Vector3 = _p0.lerp(_p1, t).lerp(_p1.lerp(_p2, t), t)
        var tangent: Vector3 = (_p1 - _p0).lerp(_p2 - _p1, t)
        pos.y = _gy
        vel = (pos - global_position) / maxf(delta, 0.0001)
        global_position = pos
        if tangent.length() > 0.01:
            rotation.y = yaw_of(tangent.normalized())
        if _t >= 1.0:
            heading = _next_heading
            lane = _next_lane
            tgt = tgt + heading
            _mode = 0
            rotation.y = yaw_of(_dirv())
    for w in _wheels:
        (w as Node3D).rotation.x -= speed / _wheel_r * delta


func _begin_turn(c: Vector3) -> void:
    var opts: Array = []
    var right_h := Vector2i(-heading.y, heading.x)
    var left_h := Vector2i(heading.y, -heading.x)
    for cand in [[heading, 0.6], [right_h, 0.2], [left_h, 0.2]]:
        var h: Vector2i = cand[0]
        var n: Vector2i = tgt + h
        if absi(n.x) <= CityMap.N and absi(n.y) <= CityMap.N:
            opts.append(cand)
    if opts.is_empty():
        opts.append([Vector2i(-heading.x, -heading.y), 1.0])
    var total: float = 0.0
    for o in opts:
        total += float((o as Array)[1])
    var roll: float = randf() * total
    var pick: Vector2i = (opts[0] as Array)[0]
    for o in opts:
        roll -= float((o as Array)[1])
        if roll <= 0.0:
            pick = (o as Array)[0]
            break
    _next_heading = pick
    if pick == right_h:
        _next_lane = 1
    elif pick == left_h:
        _next_lane = 0
    else:
        _next_lane = lane
    var d2 := Vector3(float(pick.x), 0.0, float(pick.y))
    _p0 = global_position
    _p0.y = 0.0
    _p2 = c + d2 * CityMap.ENTRY_DIST + right_of(pick) * CityMap.lane_off(_next_lane)
    if pick == heading:
        _p1 = (_p0 + _p2) * 0.5
    elif heading.x != 0:
        _p1 = Vector3(_p2.x, 0.0, _p0.z)
    else:
        _p1 = Vector3(_p0.x, 0.0, _p2.z)
    _blen = 0.5 * ((_p2 - _p0).length() + (_p1 - _p0).length() + (_p2 - _p1).length())
    _t = 0.0
    _mode = 1


func _front_gap(dirv: Vector3, reach: float) -> float:
    var from: Vector3 = global_position + dirv * (_half_len + 0.1) + Vector3(0.0, 0.7, 0.0)
    return TrafficUtil.front_gap(self, from, dirv, reach)


## Игрок врезается — становимся обломком. Возвращает true, если машина удалена.
func _check_player() -> bool:
    var p: Vehicle = city.player
    if p == null:
        return false
    if TrafficUtil.player_will_hit(self, _half_len, vel, p):
        var local: Vector3 = to_local(p.global_position)
        local.x = clampf(local.x, -0.95, 0.95)
        local.z = clampf(local.z, -_half_len, _half_len)
        local.y = 0.7
        city.wreck_traffic(self, p, (p.linear_velocity - vel).length(), to_global(local))
        return true
    return false


var _blasted: bool = false


## Взрыв/выстрел рядом: машина превращается в обломок.
func blast(origin: Vector3, power: float) -> void:
    if _blasted:
        return
    _blasted = true
    city.blast_car(self, origin, power)
