class_name Destruct
extends RefCounted
## Единая точка применения урона: удар, покраска, взрыв. Работает с любыми объектами карты.

static func _tree() -> SceneTree:
    return Engine.get_main_loop() as SceneTree


static func dworld() -> DestructibleWorld:
    var t: SceneTree = _tree()
    if t == null:
        return null
    return t.get_first_node_in_group("dworld") as DestructibleWorld


static func vbody_of(obj: Object) -> VoxelBody:
    if obj == null:
        return null
    if obj.has_meta("vbody"):
        return obj.get_meta("vbody") as VoxelBody
    var v: Variant = obj.get("vbody")
    if v == null:
        return null
    return v as VoxelBody


## Удар по точке: collider — то, во что попал луч (может быть null).
static func hit(collider: Object, point: Vector3, radius: float, soot: float, push: Vector3) -> void:
    if collider != null and collider.has_method("blast"):
        collider.call("blast", point, 0.4)
        return
    if collider is Vehicle:
        (collider as Vehicle).take_hit(point, radius, push)
        return
    var vb: VoxelBody = vbody_of(collider)
    if vb != null:
        vb.hit(vb.to_local(point), radius, soot, push)
        return
    if collider is Breakable:
        (collider as Breakable).smash()
        return
    var dw: DestructibleWorld = dworld()
    if dw != null:
        dw.damage_sphere(point, radius, soot, push)


static func paint(collider: Object, point: Vector3, radius: float, col: Color) -> void:
    var vb: VoxelBody = vbody_of(collider)
    if vb != null:
        vb.paint(vb.to_local(point), radius, col)
        return
    var dw: DestructibleWorld = dworld()
    if dw != null and (collider == null or collider is StaticBody3D):
        dw.paint_sphere(point, radius, col)


static func explosion(origin: Vector3, radius: float, power: float) -> void:
    var t: SceneTree = _tree()
    if t == null:
        return
    var dw: DestructibleWorld = dworld()
    if dw != null:
        dw.damage_sphere(origin, radius * 0.85, 1.0, Vector3.UP)
        for i in 3:
            var off := Vector3(randf_range(-1.0, 1.0), randf_range(-0.3, 1.0), randf_range(-1.0, 1.0)) * radius * 0.45
            dw.damage_sphere(origin + off, radius * 0.5, 1.0, off.normalized())
        dw.exploded.emit(origin, power * radius)
    var reach: float = radius * 1.9
    for grp in ["vehicle", "wreck", "voxel_rigid"]:
        for n in t.get_nodes_in_group(grp):
            var rb := n as RigidBody3D
            if rb == null:
                continue
            var d: float = rb.global_position.distance_to(origin)
            if d > reach:
                continue
            var k: float = clampf(1.0 - d / reach, 0.0, 1.0)
            var dir: Vector3 = rb.global_position - origin
            dir = dir.normalized() if dir.length() > 0.01 else Vector3.UP
            var dv: float = 24.0 * power * k / (1.0 + rb.mass / 4000.0)
            rb.apply_central_impulse((dir + Vector3.UP * 0.5).normalized() * rb.mass * dv)
            rb.apply_torque_impulse(Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * rb.mass * 1.5 * k * power)
            if d < radius * 1.3:
                var r: float = radius * 0.5 * (1.0 - d / (radius * 1.3)) + 0.25
                if rb is Vehicle:
                    (rb as Vehicle).take_hit(origin, r, dir)
                else:
                    var vb: VoxelBody = vbody_of(rb)
                    if vb != null:
                        vb.hit(vb.to_local(origin), r, 1.0, dir)
    for n in t.get_nodes_in_group("debris"):
        var db := n as RigidBody3D
        if db == null:
            continue
        var d2: float = db.global_position.distance_to(origin)
        if d2 > reach:
            continue
        var dir2: Vector3 = (db.global_position - origin).normalized()
        db.apply_central_impulse((dir2 + Vector3.UP * 0.6) * db.mass * 22.0 * power * (1.0 - d2 / reach))
    for grp2 in ["breakable", "traffic", "pedestrian"]:
        for n in t.get_nodes_in_group(grp2):
            var n3 := n as Node3D
            if n3 == null or n3.global_position.distance_to(origin) > radius * 1.3:
                continue
            if n3 is Breakable:
                (n3 as Breakable).smash()
            elif n3.has_method("blast"):
                n3.call("blast", origin, power)
    Fx.blast(origin, radius)
