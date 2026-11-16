class_name VoxelRigid
extends RigidBody3D
## Оторвавшийся крупный кусок воксельной конструкции (этаж здания, крона дерева...).
## Падает как твёрдое тело и сам разваливается при ударах.

const MAX_LIVE: int = 14
static var _live: Array = []
static var _pm: PhysicsMaterial

var builder: VoxelBuilder
var dims: Vector3 = Vector3.ONE
var vbody: VoxelBody

var _prev_vel: Vector3 = Vector3.ZERO
var _hit_cd: float = 0.6
var _pending: Dictionary = {}


static func spawn(b: VoxelBuilder, xf: Transform3D, d: Vector3, m: float, vel: Vector3, ang: Vector3) -> void:
    var tree: SceneTree = Engine.get_main_loop() as SceneTree
    if tree == null or tree.current_scene == null:
        return
    var r := VoxelRigid.new()
    r.builder = b
    r.dims = d
    r.mass = m
    tree.current_scene.add_child(r)
    r.global_transform = Transform3D(xf.basis, xf * (d * 0.5))
    r.linear_velocity = vel
    r.angular_velocity = ang
    _live = _live.filter(func(x: Variant) -> bool: return is_instance_valid(x))
    _live.append(r)
    while _live.size() > MAX_LIVE:
        var old: Node = _live.pop_front()
        old.queue_free()


func _ready() -> void:
    add_to_group("voxel_rigid")
    if _pm == null:
        _pm = PhysicsMaterial.new()
        _pm.friction = 0.8
        _pm.bounce = 0.02
    physics_material_override = _pm
    linear_damp = 0.1
    angular_damp = 0.5
    contact_monitor = true
    max_contacts_reported = 8
    vbody = VoxelBody.new()
    vbody.host = self
    vbody.rigid_fragments = true
    vbody.position = -dims * 0.5
    add_child(vbody)
    vbody.setup(builder)
    var cs := CollisionShape3D.new()
    var sh := BoxShape3D.new()
    sh.size = dims
    cs.shape = sh
    add_child(cs)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
    var v: Vector3 = state.linear_velocity
    var dv: float = (v - _prev_vel).length()
    _prev_vel = v
    _hit_cd -= state.step
    if dv < 3.5 or _hit_cd > 0.0 or not _pending.is_empty():
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
    _hit_cd = 0.25
    _pending = {"pos": sum / float(cnt), "dv": dv}


func _physics_process(_delta: float) -> void:
    if _pending.is_empty():
        return
    var h: Dictionary = _pending
    _pending = {}
    var dv: float = float(h["dv"])
    var radius: float = clampf(0.5 + (dv - 3.5) * 0.12, 0.5, 3.5)
    var wp: Vector3 = h["pos"]
    var push: Vector3 = wp - global_position
    push = push.normalized() if push.length() > 0.01 else Vector3.UP
    vbody.hit(vbody.to_local(wp), radius, 0.6, push)
