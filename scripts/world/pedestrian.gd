class_name Pedestrian
extends Node3D
## Пешеход-воксельный человечек: ходит по тротуарам вокруг кварталов, переходит дорогу на красный
## для машин. Сбитый игроком отлетает как твёрдое тело (без крови), потом исчезает.

const VS: float = 0.08
const SIGNS: Array = [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1)]
const SHIRTS: Array = [Color(0.8, 0.15, 0.15), Color(0.15, 0.4, 0.8), Color(0.9, 0.8, 0.2), Color(0.2, 0.65, 0.35), Color(0.9, 0.9, 0.9), Color(0.15, 0.15, 0.18), Color(0.85, 0.45, 0.1), Color(0.6, 0.25, 0.7)]
const PANTS: Array = [Color(0.15, 0.22, 0.45), Color(0.1, 0.1, 0.12), Color(0.45, 0.38, 0.25), Color(0.25, 0.25, 0.3)]
const SKINS: Array = [Color(0.95, 0.76, 0.6), Color(0.78, 0.58, 0.42), Color(0.55, 0.38, 0.27), Color(0.35, 0.24, 0.18)]
const HAIRS: Array = [Color(0.1, 0.07, 0.05), Color(0.35, 0.2, 0.08), Color(0.8, 0.65, 0.3), Color(0.15, 0.15, 0.15)]

var city: CityMap
var block: Vector2i = Vector2i.ZERO
var cur_corner: int = 0
var cw: int = 1
var body_mesh: ArrayMesh
var leg_mesh: ArrayMesh

var _state: int = 0              # 0 идёт по кольцу, 1 ждёт у перехода, 2 переходит дорогу
var _target: Vector3 = Vector3.ZERO
var _next_corner: int = 0
var _cross_block: Vector2i = Vector2i.ZERO
var _cross_corner: int = 0
var _cross_axis: int = 0         # ось движения МАШИН на пересекаемой дороге
var _wait: float = 0.0
var _speed: float = 1.4
var _phase: float = 0.0
var _legs: Array = []
var _visual: Node3D


func setup(c: CityMap, b: Vector2i, k: int, direction: int) -> void:
    city = c
    block = b
    cur_corner = k
    cw = direction
    _next_corner = (k + cw + 4) % 4
    var a: Vector3 = CityMap.corner_pos(b, k)
    var t: Vector3 = CityMap.corner_pos(b, _next_corner)
    position = a.lerp(t, randf())
    position.y = _hip_y(false)
    _target = t
    _speed = randf_range(1.2, 1.8)
    _phase = randf() * TAU


func _hip_y(on_road: bool) -> float:
    return 10.0 * VS + (0.0 if on_road else CityMap.SLAB_H)


func _ready() -> void:
    add_to_group("pedestrian")
    _build_meshes()
    _visual = Node3D.new()
    add_child(_visual)
    var mat: StandardMaterial3D = WorldKit.vc_mat()
    var bi := MeshInstance3D.new()
    bi.mesh = body_mesh
    bi.material_override = mat
    _visual.add_child(bi)
    for sx in [-1.0, 1.0]:
        var leg := MeshInstance3D.new()
        leg.mesh = leg_mesh
        leg.material_override = mat
        leg.position = Vector3(float(sx) * 1.5 * VS, 0.0, 0.0)
        _visual.add_child(leg)
        _legs.append(leg)
    rotation.y = atan2(-(_target.x - position.x), -(_target.z - position.z))


func _build_meshes() -> void:
    var parts: Array = make_parts(SHIRTS[randi() % SHIRTS.size()], PANTS[randi() % PANTS.size()], SKINS[randi() % SKINS.size()], HAIRS[randi() % HAIRS.size()])
    body_mesh = parts[0]
    leg_mesh = parts[1]


## Меши человечка: [тело+голова+руки, нога]. Нога имеет точку вращения у бедра.
static func make_parts(shirt: Color, pants: Color, skin: Color, hair: Color) -> Array:
    var mat: StandardMaterial3D = WorldKit.vc_mat()
    var b := VoxelBuilder.new()
    b.size = VS
    b.materials = {"paint": mat}
    b.fill(Vector3i(-3, 0, -2), Vector3i(2, 8, 1), "paint", shirt)
    b.fill(Vector3i(-5, 1, -2), Vector3i(-4, 8, 1), "paint", shirt)
    b.fill(Vector3i(3, 1, -2), Vector3i(4, 8, 1), "paint", shirt)
    b.fill(Vector3i(-5, 0, -2), Vector3i(-4, 0, 1), "paint", skin)
    b.fill(Vector3i(3, 0, -2), Vector3i(4, 0, 1), "paint", skin)
    b.fill(Vector3i(-2, 9, -2), Vector3i(1, 12, 1), "paint", skin)
    b.fill(Vector3i(-2, 12, -2), Vector3i(1, 12, 1), "paint", hair)
    b.fill(Vector3i(-2, 9, 1), Vector3i(1, 12, 1), "paint", hair)
    var l := VoxelBuilder.new()
    l.size = VS
    l.origin = Vector3(-1.5 * VS, 0.0, 0.0)
    l.materials = {"paint": mat}
    l.fill(Vector3i(-1, -10, -2), Vector3i(1, -2, 1), "paint", pants)
    l.fill(Vector3i(-1, -10, -2), Vector3i(1, -9, 1), "paint", Color(0.08, 0.08, 0.08))
    return [b.build(), l.build()]


## Взрыв рядом: пешехода отбрасывает.
func blast(origin: Vector3, power: float) -> void:
    if city != null:
        city.blast_ped(self, origin, power)


func _physics_process(delta: float) -> void:
    if city == null:
        return
    if _check_hit():
        return
    var moving: bool = false
    if _state == 1:
        _wait -= delta
        if city.light_state(_cross_axis) == 0:
            _start_cross()
        elif _wait <= 0.0:
            _resume_ring()
    else:
        var flat: Vector3 = _target - position
        flat.y = 0.0
        if flat.length() < 0.35:
            _arrive()
        else:
            var dir: Vector3 = flat.normalized()
            var sp: float = _speed * (1.35 if _state == 2 else 1.0)
            position += dir * sp * delta
            rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 8.0 * delta)
            moving = true
        var want_y: float = _hip_y(_state == 2)
        position.y = lerpf(position.y, want_y, 6.0 * delta)
    _animate(delta, moving)


func _animate(delta: float, moving: bool) -> void:
    if moving:
        _phase += delta * _speed * 5.0
    var s: float = sin(_phase) * 0.7 if moving else 0.0
    if _legs.size() == 2:
        (_legs[0] as Node3D).rotation.x = s
        (_legs[1] as Node3D).rotation.x = -s
    _visual.position.y = absf(sin(_phase)) * 0.03 if moving else 0.0


func _arrive() -> void:
    if _state == 2:
        block = _cross_block
        cur_corner = _cross_corner
        cw = 1 if randf() < 0.5 else -1
        _state = 0
        _resume_ring()
        return
    cur_corner = _next_corner
    if randf() < 0.4 and _plan_cross():
        _state = 1
        _wait = randf_range(6.0, 12.0)
    else:
        _resume_ring()


func _resume_ring() -> void:
    _state = 0
    _next_corner = (cur_corner + cw + 4) % 4
    _target = CityMap.corner_pos(block, _next_corner) + Vector3(randf_range(-0.6, 0.6), 0.0, randf_range(-0.6, 0.6))


func _plan_cross() -> bool:
    var s: Vector2i = SIGNS[cur_corner]
    var along_x: bool = randf() < 0.5
    var nb: Vector2i
    var sign_new: Vector2i
    if along_x:
        nb = block + Vector2i(s.x, 0)
        sign_new = Vector2i(-s.x, s.y)
        _cross_axis = 1    # идём вдоль X → пересекаем дорогу, по которой машины едут вдоль Z
    else:
        nb = block + Vector2i(0, s.y)
        sign_new = Vector2i(s.x, -s.y)
        _cross_axis = 0
    if nb.x < -3 or nb.x > 2 or nb.y < -3 or nb.y > 2:
        return false
    _cross_block = nb
    _cross_corner = SIGNS.find(sign_new)
    return true


func _start_cross() -> void:
    _state = 2
    _target = CityMap.corner_pos(_cross_block, _cross_corner)


func _check_hit() -> bool:
    var p: Vehicle = city.player
    if p == null:
        return false
    var rel: Vector3 = p.global_position - global_position
    rel.y = 0.0
    if rel.length() > 7.0:
        return false
    var speed: float = p.linear_velocity.length()
    if speed < 2.5:
        return false
    var nxt: Vector3 = rel - p.linear_velocity * 0.05
    var fwd: Vector3 = -p.global_transform.basis.z
    var right: Vector3 = p.global_transform.basis.x
    var hl: float = float(p.stats["length"]) * 0.5
    if absf(nxt.dot(right)) < 1.1 and absf(nxt.dot(fwd)) < hl + 0.4:
        city.knock_ped(self, p)
        return true
    return false


## Твёрдое тело для «отлёта» после наезда.
func make_ragdoll() -> RigidBody3D:
    var rb := RigidBody3D.new()
    rb.mass = 70.0
    var mat: StandardMaterial3D = WorldKit.vc_mat()
    var bi := MeshInstance3D.new()
    bi.mesh = body_mesh
    bi.material_override = mat
    rb.add_child(bi)
    for sx in [-1.0, 1.0]:
        var leg := MeshInstance3D.new()
        leg.mesh = leg_mesh
        leg.material_override = mat
        leg.position = Vector3(float(sx) * 1.5 * VS, 0.0, 0.0)
        rb.add_child(leg)
    var cs := CollisionShape3D.new()
    var sh := BoxShape3D.new()
    sh.size = Vector3(0.5, 1.7, 0.4)
    cs.shape = sh
    cs.position = Vector3(0.0, 0.12, 0.0)
    rb.add_child(cs)
    return rb
