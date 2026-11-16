class_name ToolBelt
extends Node3D
## Инвентарь: молоток, дробовик, динамит, баллончик. Все инструменты есть всегда.

const NAMES: Array = ["HAMMER", "SHOTGUN", "DYNAMITE", "SPRAY"]
const SPRAY_COLORS: Array = [
    Color(1.0, 0.1, 0.1), Color(1.0, 0.55, 0.05), Color(1.0, 0.9, 0.1), Color(0.2, 0.85, 0.25),
    Color(0.1, 0.6, 1.0), Color(0.6, 0.25, 0.9), Color(1.0, 0.3, 0.7), Color(0.95, 0.95, 0.95), Color(0.05, 0.05, 0.05),
]

var player: PlayerChar
var cam: FootCamera
var current: int = 0
var spray_idx: int = 0

var _cd: float = 0.0
var _swing: float = 0.0
var _models: Array = []
var _spray_mat: StandardMaterial3D


func _ready() -> void:
    _build_models()
    _show_current()


func spray_color() -> Color:
    return SPRAY_COLORS[spray_idx]


func select(i: int) -> void:
    if i == current and i == 3:
        spray_idx = (spray_idx + 1) % SPRAY_COLORS.size()
        _spray_mat.albedo_color = spray_color()
    current = clampi(i, 0, 3)
    _show_current()


func _show_current() -> void:
    for i in _models.size():
        (_models[i] as Node3D).visible = i == current


func _build_models() -> void:
    var hand: Node3D = player.hand
    var wood := StandardMaterial3D.new()
    wood.albedo_color = Color(0.45, 0.3, 0.15)
    var steel := StandardMaterial3D.new()
    steel.albedo_color = Color(0.45, 0.47, 0.5)
    steel.metallic = 0.7
    steel.roughness = 0.4
    var dark := StandardMaterial3D.new()
    dark.albedo_color = Color(0.1, 0.1, 0.12)
    # молоток
    var hm := Node3D.new()
    hm.position = Vector3(0.0, 0.0, -0.1)
    _add_box(hm, Vector3(0.05, 0.45, 0.05), Vector3(0.0, 0.1, 0.0), wood)
    _add_box(hm, Vector3(0.2, 0.1, 0.1), Vector3(0.0, 0.34, 0.0), steel)
    hand.add_child(hm)
    # дробовик
    var sg := Node3D.new()
    _add_box(sg, Vector3(0.05, 0.05, 0.7), Vector3(0.0, 0.0, -0.3), dark)
    _add_box(sg, Vector3(0.07, 0.09, 0.3), Vector3(0.0, -0.02, 0.1), wood)
    _add_box(sg, Vector3(0.08, 0.06, 0.2), Vector3(0.0, -0.04, -0.2), wood)
    hand.add_child(sg)
    # динамит
    var dy := Node3D.new()
    var red := StandardMaterial3D.new()
    red.albedo_color = Color(0.8, 0.1, 0.08)
    for ox in [-0.05, 0.0, 0.05]:
        _add_box(dy, Vector3(0.045, 0.24, 0.045), Vector3(float(ox), 0.0, -0.1), red)
    hand.add_child(dy)
    # баллончик
    var sp := Node3D.new()
    _spray_mat = StandardMaterial3D.new()
    _spray_mat.albedo_color = spray_color()
    _add_box(sp, Vector3(0.09, 0.22, 0.09), Vector3(0.0, 0.0, -0.1), _spray_mat)
    _add_box(sp, Vector3(0.05, 0.05, 0.05), Vector3(0.0, 0.14, -0.1), steel)
    hand.add_child(sp)
    _models = [hm, sg, dy, sp]


func _add_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    mi.mesh = bm
    mi.material_override = mat
    mi.position = pos
    parent.add_child(mi)


func _ray(from: Vector3, to: Vector3) -> Dictionary:
    var q := PhysicsRayQueryParameters3D.create(from, to)
    q.exclude = [player.get_rid()]
    return get_world_3d().direct_space_state.intersect_ray(q)


## Точка, на которую смотрит прицел.
func _aim_point(max_dist: float) -> Vector3:
    var r: Dictionary = cam.aim_ray()
    var from: Vector3 = r["from"]
    var dir: Vector3 = r["dir"]
    var hit: Dictionary = _ray(from + dir * 1.5, from + dir * max_dist)
    if hit.is_empty():
        return from + dir * max_dist
    return hit["position"]


func tick(delta: float, firing: bool) -> void:
    _cd = maxf(_cd - delta, 0.0)
    _swing = maxf(_swing - delta * 3.5, 0.0)
    player.hand.rotation.x = -_swing * 1.6 if current == 0 else 0.0
    if not firing or _cd > 0.0 or cam == null:
        return
    var chest: Vector3 = player.chest()
    var aim: Vector3 = _aim_point(80.0)
    var dir: Vector3 = (aim - chest).normalized()
    match current:
        0:
            _hammer(chest, dir)
        1:
            _shotgun(chest, dir)
        2:
            _dynamite(chest, dir)
        3:
            _spray(chest, dir)


func _hammer(chest: Vector3, dir: Vector3) -> void:
    _cd = 0.42
    _swing = 1.0
    var r: Dictionary = _ray(chest, chest + dir * 3.2)
    if r.is_empty():
        return
    var col: Object = r["collider"]
    var pos: Vector3 = r["position"]
    Destruct.hit(col, pos, 0.55, 0.5, dir)
    if col is RigidBody3D:
        (col as RigidBody3D).apply_impulse(dir * 160.0, pos - (col as RigidBody3D).global_position)
    Fx.sparks(pos, 0.4)
    cam.shake(0.12)


func _shotgun(chest: Vector3, dir: Vector3) -> void:
    _cd = 0.85
    cam.kick(0.07)
    cam.shake(0.18)
    var muzzle: Vector3 = chest + dir * 0.9
    Fx.sparks(muzzle, 0.4)
    var flash := OmniLight3D.new()
    flash.light_color = Color(1.0, 0.8, 0.4)
    flash.light_energy = 6.0
    flash.omni_range = 9.0
    get_tree().current_scene.add_child(flash)
    flash.global_position = muzzle
    get_tree().create_timer(0.06).timeout.connect(func() -> void:
        if is_instance_valid(flash):
            flash.queue_free())
    for i in 9:
        var d: Vector3 = (dir + Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 0.05).normalized()
        var r: Dictionary = _ray(chest, chest + d * 70.0)
        if r.is_empty():
            continue
        var col: Object = r["collider"]
        var pos: Vector3 = r["position"]
        Destruct.hit(col, pos, 0.24, 0.5, d)
        if col is RigidBody3D:
            (col as RigidBody3D).apply_impulse(d * 40.0, pos - (col as RigidBody3D).global_position)
        if i % 3 == 0:
            Fx.sparks(pos, 0.25)


func _dynamite(chest: Vector3, dir: Vector3) -> void:
    _cd = 0.9
    var d := Dynamite.new()
    get_tree().current_scene.add_child(d)
    d.global_position = chest + dir * 0.7
    d.linear_velocity = dir * 14.0 + Vector3(0.0, 3.5, 0.0) + player.velocity * 0.5
    d.angular_velocity = Vector3(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0), randf_range(-6.0, 6.0))
    _swing = 0.5


func _spray(chest: Vector3, dir: Vector3) -> void:
    _cd = 0.07
    var r: Dictionary = _ray(chest, chest + dir * 7.0)
    if r.is_empty():
        return
    var col: Color = spray_color()
    var pos: Vector3 = r["position"]
    Destruct.paint(r["collider"], pos, 0.34, col)
    Fx.puff(pos, col)
