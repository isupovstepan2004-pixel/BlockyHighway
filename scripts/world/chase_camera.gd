class_name ChaseCamera
extends Node3D
## Свободная камера: CHASE (за машиной), TOP (сверху), ORBIT (вращение вокруг, для наблюдения аварий).

enum Mode { CHASE, TOP, ORBIT }

var target: Node3D
var mode: int = Mode.CHASE

var user_yaw: float = 0.0
var user_pitch: float = 0.0
var _follow_yaw: float = 0.0
var _last_drag: float = -10.0
var _dist: Array = [7.0, 18.0, 9.0]
var _base_pitch: Array = [0.28, 1.35, 0.4]
var _cam: Camera3D
var _scale: float = 1.0
var _trauma: float = 0.0


func _ready() -> void:
    _cam = Camera3D.new()
    _cam.far = 3000.0
    _cam.fov = 72.0
    add_child(_cam)
    _cam.current = true
    if target:
        global_position = target.global_position
        _follow_yaw = _heading()
        if target is Vehicle:
            _scale = clampf(float((target as Vehicle).stats["length"]) / 4.5, 1.0, 3.2)
            for i in 3:
                _dist[i] = float(_dist[i]) * _scale


## Тряска камеры при ударе (0..1).
func shake(strength: float) -> void:
    _trauma = minf(1.0, _trauma + strength)


func activate() -> void:
    _cam.current = true


func mode_name() -> String:
    var names: Array = ["CHASE", "TOP", "ORBIT"]
    return str(names[mode])


func cycle_mode() -> void:
    mode = (mode + 1) % 3
    user_yaw = 0.0
    user_pitch = 0.0


func rotate_view(rel: Vector2) -> void:
    user_yaw -= rel.x * 0.005
    user_pitch = clampf(user_pitch + rel.y * 0.004, -0.6, 1.0)
    _last_drag = float(Time.get_ticks_msec()) / 1000.0


func zoom(factor: float) -> void:
    _dist[mode] = clampf(float(_dist[mode]) * factor, 3.0 * _scale, 45.0 * _scale)


func _heading() -> float:
    var f: Vector3 = -target.global_transform.basis.z
    f.y = 0.0
    if f.length() < 0.2:
        return _follow_yaw
    f = f.normalized()
    return atan2(-f.x, -f.z)


func _process(delta: float) -> void:
    if target == null:
        return
    global_position = global_position.lerp(target.global_position + Vector3(0.0, 0.9 * _scale, 0.0), 1.0 - exp(-delta * 12.0))
    var now: float = float(Time.get_ticks_msec()) / 1000.0
    var idle: bool = now - _last_drag > 2.0
    if mode != Mode.ORBIT:
        var rate: float = 4.0 if mode == Mode.CHASE else 2.0
        _follow_yaw = lerp_angle(_follow_yaw, _heading(), 1.0 - exp(-delta * rate))
        if idle:
            user_yaw = lerp_angle(user_yaw, 0.0, 1.0 - exp(-delta * 2.0))
            user_pitch = lerpf(user_pitch, 0.0, 1.0 - exp(-delta * 2.0))
    var pitch: float = clampf(float(_base_pitch[mode]) + user_pitch, 0.05, 1.5)
    rotation = Vector3(-pitch, _follow_yaw + user_yaw, 0.0)
    _cam.position = Vector3(0.0, 0.0, float(_dist[mode]))
    var spd: float = 0.0
    if target is RigidBody3D:
        spd = (target as RigidBody3D).linear_velocity.length()
    _cam.fov = lerpf(_cam.fov, 70.0 + clampf(spd, 0.0, 60.0) * 0.25, 1.0 - exp(-delta * 3.0))
    # тряска
    _trauma = maxf(0.0, _trauma - delta * 1.6)
    var amp: float = _trauma * _trauma * 0.35
    _cam.h_offset = randf_range(-1.0, 1.0) * amp
    _cam.v_offset = randf_range(-1.0, 1.0) * amp
    _cam.rotation.z = randf_range(-1.0, 1.0) * amp * 0.08
