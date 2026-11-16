class_name WreckCar
extends RigidBody3D
## Разбитая машина трафика: обычное твёрдое тело с воксельным кузовом, которое можно ломать дальше.

var car_id: String = "sedan"
var paint: Color = Color.WHITE
var stats: Dictionary = {}
var vbody: VoxelBody

var _prev_vel: Vector3 = Vector3.ZERO
var _hit_cd: float = 0.3
var _hit_threshold: float = 4.0
var _pending: Dictionary = {}
var _smoke_light: CPUParticles3D
var _smoke_dark: CPUParticles3D
var _fire: CPUParticles3D
static var _pm: PhysicsMaterial


func _ready() -> void:
    stats = CarData.get_stats(car_id)
    mass = float(stats["mass"])
    center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
    center_of_mass = stats["com"]
    linear_damp = 0.2
    angular_damp = 0.7
    if _pm == null:
        _pm = PhysicsMaterial.new()
        _pm.friction = 0.7
        _pm.bounce = 0.05
    physics_material_override = _pm
    _hit_threshold = 2.0 + 4.0 * float(stats["r_durability"])
    contact_monitor = true
    max_contacts_reported = 8
    add_to_group("wreck")

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

    var wmesh: ArrayMesh = CarFactory.build_wheel_mesh(stats)
    var wx: float = float(stats["wheel_x"])
    var wr: float = float(stats["wheel_radius"])
    for ax in stats["axles"]:
        var a: Array = ax
        for sx in [-1.0, 1.0]:
            var p := Vector3(float(sx) * wx, float(stats["wheel_c"]), float(a[0]))
            var mi := MeshInstance3D.new()
            mi.mesh = wmesh
            mi.position = p
            add_child(mi)
            var cs2 := CollisionShape3D.new()
            var sp := SphereShape3D.new()
            sp.radius = wr * 0.9
            cs2.shape = sp
            cs2.position = p
            add_child(cs2)

    var half_len: float = float(stats["length"]) * 0.5
    var hood := Vector3(0.0, float(stats["wheel_c"]) + 0.9, -half_len * 0.55)
    _smoke_light = Fx.make_emitter(self, hood, 0)
    _smoke_dark = Fx.make_emitter(self, hood, 1)
    _fire = Fx.make_emitter(self, hood + Vector3(0.0, -0.1, 0.0), 2)


## Первый удар (из-за которого машина и стала обломком). dv — потеря скорости, м/с.
func apply_initial_hit(world_pos: Vector3, dv: float) -> void:
    _apply_hit(world_pos, dv)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
    var v: Vector3 = state.linear_velocity
    var dv: float = (v - _prev_vel).length()
    _prev_vel = v
    _hit_cd -= state.step
    if dv < _hit_threshold or _hit_cd > 0.0 or not _pending.is_empty():
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
    _hit_cd = 0.15
    _pending = {"pos": sum / float(cnt), "dv": dv}


func _physics_process(_delta: float) -> void:
    if not _pending.is_empty():
        var h: Dictionary = _pending
        _pending = {}
        _apply_hit(h["pos"], float(h["dv"]))


func _apply_hit(world_pos: Vector3, dv: float) -> void:
    var dur: float = float(stats["r_durability"])
    var sev: float = maxf(dv - _hit_threshold, 0.5)
    var radius: float = clampf(0.2 + sev * 0.075 * (1.4 - dur), 0.16, 2.2)
    var local: Vector3 = to_local(world_pos)
    var core := Vector3(0.0, float(stats["wheel_c"]) + 0.5, 0.0)
    var inward: Vector3 = core - local
    if inward.length() > 0.01:
        local += inward.normalized() * radius * 0.25
    var push: Vector3 = world_pos - global_position
    push = push.normalized() if push.length() > 0.01 else Vector3.UP
    var spheres: int = 1 + mini(3, int(sev / 5.0))
    for i in spheres:
        var off := Vector3.ZERO
        var r: float = radius
        if i > 0:
            off = Vector3(randf_range(-1.0, 1.0), randf_range(-0.6, 0.6), randf_range(-1.0, 1.0)) * radius * 0.9
            r = radius * 0.7
        vbody.hit(local + off, r, 1.0, push)
    var d: float = vbody.damage_ratio()
    _smoke_light.emitting = d > 0.05 and d <= 0.2
    _smoke_dark.emitting = d > 0.2
    _fire.emitting = d > 0.4
