class_name Breakable
extends RigidBody3D
## Ящик / кирпичный блок: при сильном ударе разлетается на кубики и пыль.

var dims: Vector3 = Vector3.ONE
var color: Color = Color(0.6, 0.4, 0.2)
var break_dv: float = 5.0
var shards: int = 8

var _prev_vel: Vector3 = Vector3.ZERO
var _warm: float = 0.6
var _pending: bool = false
static var _pm: PhysicsMaterial


func setup(d: Vector3, c: Color, m: float, dv: float, n_shards: int, mat: Material) -> void:
    dims = d
    color = c
    mass = m
    break_dv = dv
    shards = n_shards
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = d
    mi.mesh = bm
    mi.material_override = mat
    add_child(mi)
    var cs := CollisionShape3D.new()
    var sh := BoxShape3D.new()
    sh.size = d
    cs.shape = sh
    add_child(cs)
    if _pm == null:
        _pm = PhysicsMaterial.new()
        _pm.friction = 0.9
        _pm.bounce = 0.03
    physics_material_override = _pm
    contact_monitor = true
    max_contacts_reported = 3
    add_to_group("breakable")
    set_physics_process(false)


func smash() -> void:
    _pending = true
    set_physics_process(true)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
    var v: Vector3 = state.linear_velocity
    var dv: float = (v - _prev_vel).length()
    _prev_vel = v
    if _warm > 0.0:
        _warm -= state.step
        return
    if dv > break_dv and state.get_contact_count() > 0 and not _pending:
        _pending = true
        set_physics_process(true)


func _physics_process(_delta: float) -> void:
    if not _pending:
        return
    var xf: Transform3D = global_transform
    Debris.shatter_box(xf, dims, color, shards, linear_velocity * 0.6)
    Fx.dust(xf.origin, 0.45, color.lerp(Color(0.72, 0.7, 0.65), 0.65))
    queue_free()
