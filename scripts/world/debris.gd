class_name Debris
extends RefCounted
## Обломки: кубики-воксели, куски кузова, осколки ящиков/кирпичей.
## Живых тел не больше MAX_BODIES — старые убираются первыми.

const MAX_BODIES: int = 260

static var _live: Array = []
static var _mats: Dictionary = {}
static var _box_mesh: BoxMesh
static var _phys: PhysicsMaterial


static func _root() -> Node:
    var tree: SceneTree = Engine.get_main_loop() as SceneTree
    if tree == null:
        return null
    return tree.current_scene


static func _pm() -> PhysicsMaterial:
    if _phys == null:
        _phys = PhysicsMaterial.new()
        _phys.friction = 0.85
        _phys.bounce = 0.12
    return _phys


static func _unit_box() -> BoxMesh:
    if _box_mesh == null:
        _box_mesh = BoxMesh.new()
        _box_mesh.size = Vector3.ONE
    return _box_mesh


static func _mat(c: Color) -> StandardMaterial3D:
    var q := Color(snappedf(c.r, 0.08), snappedf(c.g, 0.08), snappedf(c.b, 0.08), 1.0 if c.a > 0.9 else 0.5)
    var key: String = q.to_html(true)
    if _mats.has(key):
        return _mats[key]
    var m := StandardMaterial3D.new()
    m.albedo_color = q
    m.roughness = 0.65
    m.metallic = 0.15
    if q.a < 0.9:
        m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _mats[key] = m
    return m


static func _register(rb: RigidBody3D, life: float, ignore: PhysicsBody3D) -> void:
    rb.add_to_group("debris")
    rb.collision_layer = 2
    rb.collision_mask = 3
    rb.physics_material_override = _pm()
    var alive: Array = []
    for o in _live:
        if is_instance_valid(o):
            alive.append(o)
    alive.append(rb)
    while alive.size() > MAX_BODIES:
        var old: Object = alive.pop_front()
        (old as Node).queue_free()
    _live = alive
    var tree: SceneTree = rb.get_tree()
    if life > 0.0:
        tree.create_timer(life).timeout.connect(func() -> void:
            if is_instance_valid(rb):
                rb.queue_free())
    if ignore != null and is_instance_valid(ignore):
        rb.add_collision_exception_with(ignore)
        tree.create_timer(0.7).timeout.connect(func() -> void:
            if is_instance_valid(rb) and is_instance_valid(ignore):
                rb.remove_collision_exception_with(ignore))


## Один кубик-обломок (мировые координаты).
static func spawn_cube(pos: Vector3, col: Color, size: float, vel: Vector3, ignore: PhysicsBody3D = null, life: float = 24.0) -> void:
    var root: Node = _root()
    if root == null:
        return
    var rb := RigidBody3D.new()
    rb.mass = clampf(size * size * size * 300.0, 0.05, 40.0)
    var mi := MeshInstance3D.new()
    mi.mesh = _unit_box()
    mi.scale = Vector3.ONE * size
    mi.material_override = _mat(col)
    if size < 0.2:
        mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    rb.add_child(mi)
    var cs := CollisionShape3D.new()
    var sh := BoxShape3D.new()
    sh.size = Vector3.ONE * size
    cs.shape = sh
    rb.add_child(cs)
    root.add_child(rb)
    rb.global_position = pos
    rb.global_rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
    rb.linear_velocity = vel
    rb.angular_velocity = Vector3(randf_range(-9.0, 9.0), randf_range(-9.0, 9.0), randf_range(-9.0, 9.0))
    _register(rb, life, ignore)


## Крупный кусок кузова (воксельный меш) с коробкой-коллизией.
static func spawn_fragment(xf: Transform3D, mesh: ArrayMesh, dims: Vector3, mass: float, vel: Vector3, ang: Vector3, ignore: PhysicsBody3D = null, life: float = 60.0) -> void:
    var root: Node = _root()
    if root == null:
        return
    var rb := RigidBody3D.new()
    rb.mass = mass
    # центр масс — центр коробки; меш сдвинут так, чтобы его угол был в (0,0,0)
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.position = -dims * 0.5
    rb.add_child(mi)
    var cs := CollisionShape3D.new()
    var sh := BoxShape3D.new()
    sh.size = dims
    cs.shape = sh
    rb.add_child(cs)
    root.add_child(rb)
    rb.global_transform = Transform3D(xf.basis, xf * (dims * 0.5))
    rb.linear_velocity = vel
    rb.angular_velocity = ang
    _register(rb, life, ignore)


## Ящик/кирпич разлетается на кубики.
static func shatter_box(xf: Transform3D, dims: Vector3, col: Color, count: int, vel: Vector3) -> void:
    for i in count:
        var lp := Vector3(randf_range(-0.5, 0.5) * dims.x, randf_range(-0.5, 0.5) * dims.y, randf_range(-0.5, 0.5) * dims.z)
        var wp: Vector3 = xf * lp
        var sz: float = minf(dims.x, minf(dims.y, dims.z)) * randf_range(0.28, 0.5)
        var c: Color = col * randf_range(0.8, 1.1)
        c.a = 1.0
        var dir: Vector3 = (wp - xf.origin).normalized()
        spawn_cube(wp, c, sz, vel + dir * randf_range(1.0, 4.0) + Vector3(0.0, randf_range(0.5, 2.5), 0.0), null, 18.0)
