class_name TrafficUtil
extends RefCounted
## Общие функции трафика: превращение машины в обломок, поиск препятствия впереди.

static func make_wreck(parent: Node3D, car_id: String, paint: Color, xf: Transform3D, own_vel: Vector3, p: Vehicle, closing: float, contact_world: Vector3) -> WreckCar:
    var w := WreckCar.new()
    w.car_id = car_id
    w.paint = paint
    w.transform = xf
    var m: float = float(CarData.get_stats(car_id)["mass"])
    var share: float = p.mass / (p.mass + m)
    parent.add_child(w)
    w.linear_velocity = own_vel + (p.linear_velocity - own_vel) * share * 1.15
    w.angular_velocity = Vector3(0.0, randf_range(-1.5, 1.5), 0.0)
    w.apply_initial_hit(contact_world, closing * share * 1.15)
    return w


## Расстояние до машины/обломка/игрока впереди по лучу (иначе reach).
static func front_gap(body: PhysicsBody3D, from: Vector3, dirv: Vector3, reach: float) -> float:
    var to: Vector3 = from + dirv * reach
    var space: PhysicsDirectSpaceState3D = body.get_world_3d().direct_space_state
    var excl: Array[RID] = [body.get_rid()]
    for i in 2:
        var q := PhysicsRayQueryParameters3D.create(from, to)
        q.exclude = excl
        var hit: Dictionary = space.intersect_ray(q)
        if hit.is_empty():
            return reach
        var col: Object = hit["collider"]
        if col is Node:
            var n: Node = col
            if n.is_in_group("vehicle") or n.is_in_group("traffic") or n.is_in_group("wreck"):
                return from.distance_to(hit["position"])
        if col is CollisionObject3D:
            excl.append((col as CollisionObject3D).get_rid())
    return reach


## Попадает ли предсказанное положение игрока в габарит машины (для превращения в обломок).
static func player_will_hit(body: Node3D, half_len: float, own_vel: Vector3, p: Vehicle) -> bool:
    var rel: Vector3 = p.global_position - body.global_position
    rel.y = 0.0
    if rel.length() > 16.0:
        return false
    var v_rel: Vector3 = p.linear_velocity - own_vel
    if v_rel.length() < 4.0:
        return false
    var nxt: Vector3 = rel + v_rel * 0.05
    var fwd: Vector3 = -body.global_transform.basis.z
    var right: Vector3 = body.global_transform.basis.x
    var pl: float = float(p.stats["length"]) * 0.5
    return absf(nxt.dot(right)) < 2.4 and absf(nxt.dot(fwd)) < half_len + pl + 0.8


## Обломок после взрыва/выстрела (без игрока): летит от источника.
static func make_blast_wreck(parent: Node3D, car_id: String, paint: Color, xf: Transform3D, own_vel: Vector3, origin: Vector3, power: float) -> WreckCar:
    var w := WreckCar.new()
    w.car_id = car_id
    w.paint = paint
    w.transform = xf
    parent.add_child(w)
    var dir: Vector3 = xf.origin - origin
    dir = dir.normalized() if dir.length() > 0.01 else Vector3.UP
    w.linear_velocity = own_vel + (dir + Vector3.UP * 0.5).normalized() * 9.0 * power
    w.angular_velocity = Vector3(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0), randf_range(-2.0, 2.0)) * power
    w.apply_initial_hit(origin, 8.0 + 14.0 * power)
    return w
