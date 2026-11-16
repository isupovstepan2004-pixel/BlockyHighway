class_name Vehicle
extends VehicleBody3D
## Машина: воксельный кузов (VoxelBody) + VehicleBody3D.
## Перед = -Z. В Godot положительный engine_force толкает VehicleBody3D к +Z, поэтому DRIVE_SIGN = -1
## (+ автокалибровка при старте).
## Управление: 6-ступенчатая АКПП с кривой момента, антибуксовка (TCS), АБС, зависимый от скорости руль,
## помощь контрруля и стабилизация заноса, антикрен.
## Повреждения: вмятины вдоль направления удара, потеря мощности при разбитом перед, увод руля,
## отрыв колёс, дым -> огонь -> взрыв бензобака.

signal crashed(strength: float)

const DRIVE_SIGN: float = -1.0
const GEAR_TOP: Array = [0.2, 0.36, 0.52, 0.68, 0.84, 1.0]
const GEAR_MUL: Array = [1.5, 1.3, 1.15, 1.05, 0.97, 0.9]

var car_id: String = "sportcar"
var paint: Color = Color(0.78, 0.05, 0.05)
var stats: Dictionary = {}

# Ввод (заполняется сценой / сенсорным управлением)
var in_throttle: float = 0.0
var in_brake: float = 0.0
var in_steer: float = 0.0       # -1 влево, +1 вправо
var in_handbrake: bool = false
var parked: bool = false        # водитель вышел: стоим на ручнике

var forward_speed: float = 0.0
var gear: int = 0
var reversing: bool = false
var vbody: VoxelBody

var _wheels: Array = []
var _rear_wheels: Array = []
var _wheel_specs: Array = []
var _wheel_mesh: ArrayMesh
var _wheel_dmg: Dictionary = {}
var _lights: Array = []
var _rear_slip: float = 2.0
var _reset_pending: bool = false
var _reset_xform: Transform3D = Transform3D.IDENTITY
var _drive_sign: float = DRIVE_SIGN
var _calibrated: bool = false
var _calib_t: float = 0.0
var _prev_vel: Vector3 = Vector3.ZERO
var _hit_cd: float = 0.0
var _hit_threshold: float = 4.0
var _pending_hit: Dictionary = {}
var _repair_pending: bool = false
var _smoke_light: CPUParticles3D
var _smoke_dark: CPUParticles3D
var _fire: CPUParticles3D
var _shift_t: float = 0.0
var _wheelbase: float = 2.7
var _zone: Dictionary = {"front": 0.0, "rear": 0.0, "left": 0.0, "right": 0.0}
var _burn_t: float = 0.0
var _exploded: bool = false
var _engine_dead: bool = false


func _ready() -> void:
    stats = CarData.get_stats(car_id)
    mass = float(stats["mass"])
    center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
    center_of_mass = stats["com"]
    linear_damp = 0.03
    angular_damp = 0.9
    _rear_slip = float(stats["friction_rear"])
    _hit_threshold = 2.0 + 4.0 * float(stats["r_durability"])
    contact_monitor = true
    max_contacts_reported = 8
    add_to_group("vehicle")

    vbody = VoxelBody.new()
    vbody.host = self
    add_child(vbody)
    vbody.setup(CarFactory.make_builder(car_id, paint))

    for box in stats["collision"]:
        var cs := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = box[0]
        cs.shape = shape
        cs.position = box[1]
        add_child(cs)

    _wheel_mesh = CarFactory.build_wheel_mesh(stats)
    _build_wheels()
    var axles: Array = stats["axles"]
    _wheelbase = maxf(absf(float((axles[0] as Array)[0]) - float((axles[axles.size() - 1] as Array)[0])), 1.5)

    var wx: float = float(stats["wheel_x"])
    var half_len: float = float(stats["length"]) * 0.5
    for sx in [-1.0, 1.0]:
        var l := SpotLight3D.new()
        l.position = Vector3(float(sx) * wx * 0.75, float(stats["light_y"]), -half_len + 0.05)
        l.rotation_degrees = Vector3(-4.0, 0.0, 0.0)
        l.spot_range = 45.0
        l.spot_angle = 32.0
        l.light_energy = 3.0
        l.visible = false
        add_child(l)
        _lights.append(l)

    var hood := Vector3(0.0, float(stats["wheel_c"]) + 0.9, -half_len * 0.55)
    _smoke_light = Fx.make_emitter(self, hood, 0)
    _smoke_dark = Fx.make_emitter(self, hood, 1)
    _fire = Fx.make_emitter(self, hood + Vector3(0.0, -0.1, 0.0), 2)


func _build_wheels() -> void:
    var wx: float = float(stats["wheel_x"])
    var axles: Array = stats["axles"]
    var n_wheels: int = axles.size() * 2
    var sag: float = 9.8 / (float(n_wheels) * float(stats["suspension_stiffness"]))
    var wy: float = float(stats["wheel_c"]) + float(stats["rest_length"]) - sag
    for ax in axles:
        var a: Array = ax
        var az: float = float(a[0])
        _add_wheel(Vector3(-wx, wy, az), bool(a[1]), bool(a[2]))
        _add_wheel(Vector3(wx, wy, az), bool(a[1]), bool(a[2]))


func _add_wheel(pos: Vector3, steer: bool, trac: bool) -> void:
    var w := VehicleWheel3D.new()
    w.position = pos
    w.wheel_radius = float(stats["wheel_radius"])
    w.wheel_rest_length = float(stats["rest_length"])
    w.suspension_travel = float(stats["travel"])
    w.suspension_stiffness = float(stats["suspension_stiffness"])
    w.suspension_max_force = mass * 12.0
    w.damping_compression = float(stats["damping_compression"])
    w.damping_relaxation = float(stats["damping_relaxation"])
    w.wheel_roll_influence = float(stats["roll_influence"])
    w.wheel_friction_slip = float(stats["friction_front"]) if steer else float(stats["friction_rear"])
    w.use_as_steering = steer
    w.use_as_traction = trac
    var mi := MeshInstance3D.new()
    mi.mesh = _wheel_mesh
    w.add_child(mi)
    add_child(w)
    _wheels.append(w)
    if not steer:
        _rear_wheels.append(w)


func set_headlights(on: bool) -> void:
    for l in _lights:
        (l as SpotLight3D).visible = on


func get_speed_kmh() -> float:
    return linear_velocity.length() * 3.6


func gear_label() -> String:
    if reversing:
        return "R"
    return str(gear + 1)


func request_reset() -> void:
    var f: Vector3 = -global_transform.basis.z
    f.y = 0.0
    var yaw: float = 0.0
    if f.length() > 0.05:
        f = f.normalized()
        yaw = atan2(-f.x, -f.z)
    _reset_xform = Transform3D(Basis(Vector3.UP, yaw), global_position + Vector3(0.0, 1.0, 0.0))
    _reset_pending = true
    _repair_pending = true


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
    if _reset_pending:
        _reset_pending = false
        state.transform = _reset_xform
        state.linear_velocity = Vector3.ZERO
        state.angular_velocity = Vector3.ZERO
        _prev_vel = Vector3.ZERO
        return
    # резкое изменение скорости за шаг + контакт с чем-то твёрдым = удар
    var v: Vector3 = state.linear_velocity
    var dv: float = (v - _prev_vel).length()
    _prev_vel = v
    _hit_cd -= state.step
    if dv < _hit_threshold or _hit_cd > 0.0 or not _pending_hit.is_empty():
        return
    var sum := Vector3.ZERO
    var cnt: int = 0
    for i in state.get_contact_count():
        var obj: Object = state.get_contact_collider_object(i)
        if obj is Node and (obj as Node).is_in_group("debris"):
            continue
        sum += state.get_contact_local_position(i)
        cnt += 1
    if cnt == 0:
        return
    _hit_cd = 0.12
    _pending_hit = {"pos": sum / float(cnt), "dv": dv}


func _apply_hit(h: Dictionary) -> void:
    var dv: float = float(h["dv"])
    var dur: float = float(stats["r_durability"])
    var sev: float = dv - _hit_threshold
    var radius: float = clampf(0.2 + sev * 0.075 * (1.4 - dur), 0.16, 2.2)
    var world_pos: Vector3 = h["pos"]
    var push: Vector3 = world_pos - global_position
    push = push.normalized() if push.length() > 0.01 else Vector3.UP
    _carve(world_pos, radius, sev, push)
    # удар по зданиям/деревьям/столбам (достаточно тяжёлый)
    var energy: float = 0.5 * mass * dv * dv
    var br: float = clampf(pow(energy / 70000.0, 0.45), 0.0, 3.5)
    if br > 0.8:
        var dw: DestructibleWorld = Destruct.dworld()
        if dw != null:
            dw.damage_sphere(world_pos, br, 0.8, push)
    crashed.emit(clampf(sev / 14.0, 0.05, 1.0))


## Урон от взрыва/оружия (из Destruct).
func take_hit(world_pos: Vector3, radius: float, push: Vector3) -> void:
    _carve(world_pos, radius, radius * 12.0, push)
    crashed.emit(clampf(radius * 0.3, 0.05, 1.0))


func _carve(world_pos: Vector3, radius: float, sev: float, push: Vector3) -> void:
    var local: Vector3 = to_local(world_pos)
    var core := Vector3(0.0, float(stats["wheel_c"]) + 0.5, 0.0)
    var inward: Vector3 = core - local
    var depth := Vector3.ZERO
    if inward.length() > 0.01:
        depth = inward.normalized()
        local += depth * radius * 0.25
    var spheres: int = 1 + mini(3, int(sev / 5.0))
    var removed: int = 0
    for i in spheres:
        var off := Vector3.ZERO
        var r: float = radius
        if i > 0:
            off = Vector3(randf_range(-1.0, 1.0), randf_range(-0.6, 0.6), randf_range(-1.0, 1.0)) * radius * 0.9
            r = radius * 0.7
        removed += vbody.hit(local + off, r, 1.0, push, depth)
    _register_zone_damage(local, removed)
    _wheel_damage(local, radius, sev)
    _update_damage_fx()


func _register_zone_damage(local: Vector3, removed: int) -> void:
    var frac: float = float(removed) / float(maxi(vbody.initial_cells, 1))
    var hl: float = float(stats["length"]) * 0.5
    if local.z < -hl * 0.25:
        _zone["front"] = float(_zone["front"]) + frac
    elif local.z > hl * 0.25:
        _zone["rear"] = float(_zone["rear"]) + frac
    if local.x < -0.2:
        _zone["left"] = float(_zone["left"]) + frac
    elif local.x > 0.2:
        _zone["right"] = float(_zone["right"]) + frac


func _wheel_damage(local: Vector3, radius: float, sev: float) -> void:
    for i in range(_wheels.size() - 1, -1, -1):
        var w: VehicleWheel3D = _wheels[i]
        var d: float = Vector2(local.x - w.position.x, local.z - w.position.z).length()
        if d > radius + 0.55:
            continue
        var key: int = w.get_instance_id()
        var acc: float = float(_wheel_dmg.get(key, 0.0)) + sev * (1.0 - d / (radius + 0.55))
        _wheel_dmg[key] = acc
        if acc > 6.0:
            _detach_wheel(w)


func _detach_wheel(w: VehicleWheel3D) -> void:
    var tree: SceneTree = get_tree()
    if tree == null or tree.current_scene == null:
        return
    var rb := RigidBody3D.new()
    rb.mass = 20.0
    var mi := MeshInstance3D.new()
    mi.mesh = _wheel_mesh
    rb.add_child(mi)
    var cs := CollisionShape3D.new()
    var cyl := CylinderShape3D.new()
    cyl.radius = float(stats["wheel_radius"])
    cyl.height = 0.3
    cs.shape = cyl
    cs.rotation_degrees = Vector3(0.0, 0.0, 90.0)
    rb.add_child(cs)
    tree.current_scene.add_child(rb)
    rb.global_transform = w.global_transform
    var out: Vector3 = w.global_position - global_position
    rb.linear_velocity = linear_velocity + out.normalized() * 3.0 + Vector3(0.0, 2.5, 0.0)
    rb.angular_velocity = Vector3(randf_range(-8.0, 8.0), randf_range(-4.0, 4.0), randf_range(-8.0, 8.0))
    tree.create_timer(40.0).timeout.connect(func() -> void:
        if is_instance_valid(rb):
            rb.queue_free())
    Fx.sparks(w.global_position, 1.5)
    _wheels.erase(w)
    _rear_wheels.erase(w)
    w.queue_free()


func _update_damage_fx() -> void:
    var d: float = vbody.damage_ratio()
    _smoke_light.emitting = d > 0.05 and d <= 0.2
    _smoke_dark.emitting = d > 0.2
    _fire.emitting = d > 0.38


func get_damage() -> float:
    return vbody.damage_ratio()


func _engine_factor() -> float:
    if _engine_dead:
        return 0.0
    return clampf(1.0 - 2.2 * float(_zone["front"]), 0.2, 1.0)


func _wheel_speed(w: VehicleWheel3D) -> float:
    return absf(w.get_rpm()) * TAU / 60.0 * w.wheel_radius


func _physics_process(delta: float) -> void:
    if _repair_pending:
        _repair_pending = false
        vbody.setup(CarFactory.make_builder(car_id, paint))
        for w in _wheels:
            (w as Node).queue_free()
        _wheels.clear()
        _rear_wheels.clear()
        _wheel_dmg.clear()
        _build_wheels()
        _zone = {"front": 0.0, "rear": 0.0, "left": 0.0, "right": 0.0}
        _burn_t = 0.0
        _exploded = false
        _engine_dead = false
        _pending_hit = {}
        _update_damage_fx()
    if not _pending_hit.is_empty():
        var h: Dictionary = _pending_hit
        _pending_hit = {}
        _apply_hit(h)
    # горит -> взрыв бензобака
    if _fire.emitting and not _exploded:
        _burn_t += delta
        if _burn_t > 7.0:
            _exploded = true
            _engine_dead = true
            Destruct.explosion(global_position + Vector3(0.0, 0.8, 0.0), 5.0, 0.9)

    var thr: float = in_throttle
    var brk: float = in_brake
    var hb: bool = in_handbrake
    if parked:
        thr = 0.0
        brk = 0.0
        hb = true

    var fwd: Vector3 = -global_transform.basis.z
    var right: Vector3 = global_transform.basis.x
    var up: Vector3 = global_transform.basis.y
    forward_speed = linear_velocity.dot(fwd)
    var lat_speed: float = linear_velocity.dot(right)
    var speed_abs: float = absf(forward_speed)
    var top: float = float(stats["top_speed"])
    var eng: float = float(stats["engine_force"]) * _engine_factor()
    var br: float = mass * float(stats["brake_factor"])

    # автокалибровка направления: газ с полной остановки должен ехать вперёд (-Z)
    if not _calibrated:
        if thr > 0.5:
            if _calib_t <= 0.0 and speed_abs < 0.3:
                _calib_t = 0.0001
            elif _calib_t > 0.0:
                _calib_t += delta
                if forward_speed > 0.8:
                    _calibrated = true
                elif forward_speed < -0.5 and _calib_t > 0.15:
                    _drive_sign = -_drive_sign
                    _calibrated = true
        else:
            _calib_t = 0.0

    # --- коробка передач
    _shift_t = maxf(_shift_t - delta, 0.0)
    var g_top: float = top * float(GEAR_TOP[gear])
    if gear < 5 and speed_abs > g_top * 0.88 and thr > 0.3 and _shift_t <= 0.0:
        gear += 1
        _shift_t = 0.2
    elif gear > 0 and speed_abs < top * float(GEAR_TOP[gear - 1]) * 0.62:
        gear -= 1
    var ratio: float = clampf(speed_abs / maxf(top * float(GEAR_TOP[gear]), 1.0), 0.0, 1.2)
    var torque_mul: float = float(GEAR_MUL[gear]) * clampf(1.0 - pow(ratio, 4.0), 0.0, 1.0)
    if _shift_t > 0.0:
        torque_mul = 0.0

    # --- газ / тормоз / задний ход
    var eng_out: float = 0.0
    var brake_out: float = 0.0
    reversing = false
    if thr > 0.01:
        if forward_speed < -1.0:
            brake_out = br * thr
        else:
            eng_out = thr * eng * torque_mul
    if brk > 0.01:
        if forward_speed > 1.0:
            brake_out = maxf(brake_out, br * brk)
        else:
            reversing = true
            eng_out = -brk * eng * 0.5 * clampf(1.0 - pow(speed_abs / (top * 0.3), 2.0), 0.0, 1.0)
    if thr < 0.01 and brk < 0.01:
        brake_out = br * (0.03 + 0.012 * float(gear))
    if parked:
        brake_out = br * 0.9

    # АБС: если колёса блокируются при торможении — ослабляем тормоз
    if brake_out > br * 0.2 and speed_abs > 6.0 and not hb:
        var min_ws: float = 1e9
        for w in _wheels:
            min_ws = minf(min_ws, _wheel_speed(w as VehicleWheel3D))
        if _wheels.size() > 0 and min_ws < speed_abs * 0.6:
            brake_out *= 0.55

    engine_force = eng_out * _drive_sign
    brake = brake_out
    # антибуксовка: режем момент на проскальзывающем колесе
    for w in _wheels:
        var wheel: VehicleWheel3D = w
        if wheel.use_as_traction and eng_out > 0.0 and not hb:
            var slip: float = (_wheel_speed(wheel) - speed_abs) / maxf(speed_abs, 4.0)
            var tcs: float = clampf(1.0 - maxf(slip - 0.2, 0.0) * 2.0, 0.45, 1.0)
            wheel.engine_force = eng_out * _drive_sign * tcs
    for w in _rear_wheels:
        var rw: VehicleWheel3D = w
        if hb:
            rw.brake = maxf(brake_out, br * 1.5)
            rw.wheel_friction_slip = _rear_slip * 0.5
        else:
            rw.brake = brake_out
            rw.wheel_friction_slip = _rear_slip

    # --- руль
    var max_steer: float = float(stats["max_steer"])
    var factor: float = clampf(1.0 / (1.0 + pow(speed_abs / (top * 0.33), 2.0)), 0.13, 1.0)
    var target: float = -in_steer * max_steer * factor
    if speed_abs > 6.0 and forward_speed > 0.0 and not hb:
        var beta: float = atan2(lat_speed, maxf(speed_abs, 2.0))
        target += -clampf(beta * 0.9, -0.35, 0.35) * (1.0 - absf(in_steer) * 0.5)
    if speed_abs > 3.0:
        var pull: float = -(float(_zone["right"]) - float(_zone["left"])) * 4.0
        target += clampf(pull, -0.12, 0.12)
    target = clampf(target, -max_steer, max_steer)
    var rate: float = lerpf(5.0, 2.4, clampf(speed_abs / top * 1.5, 0.0, 1.0))
    if absf(target) < absf(steering):
        rate *= 1.6
    steering = move_toward(steering, target, delta * rate)

    # --- стабилизация заноса и антикрен
    if speed_abs > 6.0 and not hb:
        var yaw_rate: float = angular_velocity.dot(up)
        var desired: float = forward_speed * tan(steering) / _wheelbase
        if absf(lat_speed) > 1.0 and (absf(yaw_rate) > absf(desired) or yaw_rate * desired < 0.0):
            var inertia: float = mass * _wheelbase * _wheelbase / 6.0
            apply_torque(-up * (yaw_rate - desired) * inertia * 0.8)
    if speed_abs > 8.0:
        apply_torque(-fwd * angular_velocity.dot(fwd) * mass * 0.9)

    # --- аэродинамика
    var v2: float = linear_velocity.length_squared()
    apply_central_force(-global_transform.basis.y * float(stats["downforce"]) * v2)
    if v2 > 0.01:
        apply_central_force(-linear_velocity.normalized() * v2 * float(stats["drag"]))
