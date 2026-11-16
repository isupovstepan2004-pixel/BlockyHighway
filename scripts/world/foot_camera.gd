class_name FootCamera
extends Node3D
## Камера от третьего лица «через плечо» для игры пешком.

var target: Node3D
var yaw: float = 0.0
var pitch: float = 0.18
var dist: float = 3.4

var _cam: Camera3D
var _trauma: float = 0.0


func _ready() -> void:
    _cam = Camera3D.new()
    _cam.far = 3000.0
    _cam.fov = 72.0
    add_child(_cam)


func activate() -> void:
    _cam.current = true
    if target != null:
        global_position = target.global_position + Vector3(0.0, 1.55, 0.0)


func rotate_view(rel: Vector2) -> void:
    yaw -= rel.x * 0.0045
    pitch = clampf(pitch + rel.y * 0.0035, -1.0, 1.2)


func shake(strength: float) -> void:
    _trauma = minf(1.0, _trauma + strength)


func kick(amount: float) -> void:
    pitch = clampf(pitch - amount, -1.0, 1.2)


## Луч из центра экрана (для прицеливания).
func aim_ray() -> Dictionary:
    return {"from": _cam.global_position, "dir": -_cam.global_transform.basis.z}


func _process(delta: float) -> void:
    if target == null:
        return
    var pivot: Vector3 = target.global_position + Vector3(0.0, 1.55, 0.0)
    global_position = global_position.lerp(pivot, 1.0 - exp(-delta * 18.0))
    rotation = Vector3(-pitch, yaw, 0.0)
    var desired := Vector3(0.6, 0.0, dist)
    var from: Vector3 = global_position
    var to: Vector3 = to_global(desired)
    var q := PhysicsRayQueryParameters3D.create(from, to)
    if target is CollisionObject3D:
        q.exclude = [(target as CollisionObject3D).get_rid()]
    var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
    var local: Vector3 = desired
    if not hit.is_empty():
        var full: float = from.distance_to(to)
        var got: float = maxf(from.distance_to(hit["position"]) - 0.25, 0.5)
        local = desired * clampf(got / maxf(full, 0.01), 0.1, 1.0)
    _cam.position = local
    _trauma = maxf(0.0, _trauma - delta * 1.6)
    var amp: float = _trauma * _trauma * 0.3
    _cam.h_offset = randf_range(-1.0, 1.0) * amp
    _cam.v_offset = randf_range(-1.0, 1.0) * amp
