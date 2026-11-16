class_name RoadCar
extends AnimatableBody3D
## Машина на трассе (American Road): едет по своей полосе вдоль петли, притормаживает в поворотах
## и перед препятствиями. Сильный удар игрока превращает её в WreckCar.

var road: AmericanRoad
var car_id: String = "sedan"
var paint: Color = Color.WHITE
var stats: Dictionary = {}
var s: float = 0.0
var dir_sign: float = 1.0        # +1 по направлению трассы, -1 встречная
var cruise: float = 22.0
var speed: float = 0.0
var vel: Vector3 = Vector3.ZERO

var _half_len: float = 2.4
var _wheels: Array = []
var _wheel_r: float = 0.35
var _gy: float = 0.0


func setup(r: AmericanRoad, id: String, col: Color, s0: float, d: float) -> void:
    road = r
    car_id = id
    paint = col
    s = s0
    dir_sign = d
    stats = CarData.get_stats(id)
    _wheel_r = float(stats["wheel_radius"])
    _gy = _wheel_r - float(stats["wheel_c"])
    _half_len = float(stats["length"]) * 0.5
    cruise = randf_range(18.0, 27.0)
    if id == "bus" or id == "truck":
        cruise *= 0.75
    speed = cruise * 0.7
    _place(0.0)


func _lane_u() -> float:
    return 2.7 * dir_sign        # правая полоса относительно своего направления


func _place(delta: float) -> void:
    var f: Dictionary = road.frame_at(s, _lane_u())
    var pos: Vector3 = f["pos"]
    var tng: Vector3 = f["tan"] * dir_sign
    pos.y += _gy
    var prev: Vector3 = global_position if is_inside_tree() else pos
    vel = (pos - prev) / maxf(delta, 0.0001) if delta > 0.0 else Vector3.ZERO
    var bank: float = float(f["bank"])
    var yaw: float = atan2(-tng.x, -tng.z)
    var b := Basis(Vector3.UP, yaw)
    b = b * Basis(Vector3.FORWARD, -bank * dir_sign * 0.0)
    if is_inside_tree():
        global_transform = Transform3D(b, pos)
    else:
        transform = Transform3D(b, pos)


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
    var p: Vehicle = road.player
    if p != null and TrafficUtil.player_will_hit(self, _half_len, vel, p):
        var local: Vector3 = to_local(p.global_position)
        local.x = clampf(local.x, -0.95, 0.95)
        local.z = clampf(local.z, -_half_len, _half_len)
        local.y = 0.7
        road.wreck_traffic(self, p, (p.linear_velocity - vel).length(), to_global(local))
        return
    var fwd: Vector3 = -global_transform.basis.z
    var v_target: float = cruise
    var kappa: float = absf(road.turn_at(s))
    if kappa > 0.0005:
        v_target = minf(v_target, sqrt(4.2 / kappa))
    var reach: float = 8.0 + speed * 1.8
    var gap: float = TrafficUtil.front_gap(self, global_position + fwd * (_half_len + 0.1) + Vector3(0.0, 0.7, 0.0), fwd, reach)
    if gap < reach:
        v_target = minf(v_target, sqrt(2.0 * 7.0 * maxf(gap - 3.0, 0.0)))
    speed = move_toward(speed, v_target, (3.0 if v_target > speed else 8.0) * delta)
    s = fposmod(s + dir_sign * speed * delta, road.length)
    _place(delta)
    for w in _wheels:
        (w as Node3D).rotation.x -= speed / _wheel_r * delta


var _blasted: bool = false


## Взрыв/выстрел рядом: машина превращается в обломок.
func blast(origin: Vector3, power: float) -> void:
    if _blasted:
        return
    _blasted = true
    road.blast_car(self, origin, power)
