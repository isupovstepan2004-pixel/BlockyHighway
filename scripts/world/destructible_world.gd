class_name DestructibleWorld
extends Node3D
## Менеджер разрушаемых объектов карты. Объект (здание, дом, дерево, фонарь...) сначала — дешёвая
## «заглушка» (MultiMesh/коробка). При первом уроне он лениво превращается в воксельную конструкцию
## с настоящей коллизией, которую можно взрывать, бить, красить; куски отваливаются и падают.

signal exploded(pos: Vector3, power: float)

const CELL: float = 48.0

var building_material: Material
var _items: Array = []
var _grid: Dictionary = {}
var _col_body: StaticBody3D
var _mats: Dictionary = {}


func _ready() -> void:
    add_to_group("dworld")
    _col_body = StaticBody3D.new()
    _col_body.add_to_group("dstatic")
    add_child(_col_body)
    var vc: StandardMaterial3D = WorldKit.vc_mat()
    var glass: StandardMaterial3D = WorldKit.vc_mat(0.1)
    glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _mats = {"paint": vc, "trim": vc, "glass": glass}


func add_collision(xf: Transform3D, size: Vector3, off: Vector3) -> CollisionShape3D:
    var cs := CollisionShape3D.new()
    var sh := BoxShape3D.new()
    sh.size = size
    cs.shape = sh
    cs.transform = Transform3D(xf.basis, xf * off)
    _col_body.add_child(cs)
    return cs


## visuals: [[MultiMeshInstance3D, index], ...] или [Node3D] (скрывается целиком вместе с коллизией).
func register(kind: String, params: Dictionary, xf: Transform3D, aabb: AABB, visuals: Array, cs: Node = null) -> int:
    var it: Dictionary = {"kind": kind, "params": params, "xf": xf.orthonormalized(), "aabb": aabb, "vis": visuals, "cs": cs, "vb": null}
    var id: int = _items.size()
    _items.append(it)
    var lo: Vector3 = aabb.position
    var hi: Vector3 = aabb.end
    for gx in range(floori(lo.x / CELL), floori(hi.x / CELL) + 1):
        for gz in range(floori(lo.z / CELL), floori(hi.z / CELL) + 1):
            var key := Vector2i(gx, gz)
            if not _grid.has(key):
                _grid[key] = []
            (_grid[key] as Array).append(id)
    return id


## Регистрирует все экземпляры MultiMesh как объекты одного типа.
func register_multimesh(mmi: MultiMeshInstance3D, xforms: Array, kind: String, params: Dictionary, local_aabb: AABB, col_size: Vector3 = Vector3.ZERO, col_off: Vector3 = Vector3.ZERO) -> void:
    for i in xforms.size():
        var xf: Transform3D = xforms[i]
        var s: float = xf.basis.get_scale().x
        var pr: Dictionary = params.duplicate()
        pr["scale"] = s
        pr["seed"] = i * 7 + 3
        var cs: CollisionShape3D = null
        if col_size != Vector3.ZERO:
            cs = add_collision(xf.orthonormalized(), col_size * s, col_off * s)
        register(kind, pr, xf, xf * local_aabb, [[mmi, i]], cs)


func _dist_to_aabb(p: Vector3, box: AABB) -> float:
    return p.distance_to(p.clamp(box.position, box.end))


func _items_near(center: Vector3, radius: float) -> Array:
    var out: Array = []
    var seen: Dictionary = {}
    var span: int = ceili(radius / CELL)
    var cx: int = floori(center.x / CELL)
    var cz: int = floori(center.z / CELL)
    for gx in range(cx - span, cx + span + 1):
        for gz in range(cz - span, cz + span + 1):
            for id in _grid.get(Vector2i(gx, gz), []):
                if seen.has(id):
                    continue
                seen[id] = true
                var it: Dictionary = _items[id]
                if _dist_to_aabb(center, it["aabb"]) <= radius:
                    out.append(it)
    return out


func damage_sphere(center: Vector3, radius: float, soot: float, push: Vector3) -> int:
    var total: int = 0
    for it in _items_near(center, radius):
        var vb: VoxelBody = _ensure(it)
        total += vb.hit(vb.to_local(center), radius, soot, push)
    return total


func paint_sphere(center: Vector3, radius: float, col: Color) -> int:
    var total: int = 0
    for it in _items_near(center, radius):
        var vb: VoxelBody = _ensure(it)
        total += vb.paint(vb.to_local(center), radius, col)
    return total


func _ensure(it: Dictionary) -> VoxelBody:
    if it["vb"] != null:
        return it["vb"]
    var mats: Dictionary = _mats.duplicate()
    if str(it["kind"]) == "building" and building_material != null:
        mats["paint"] = building_material
    var builder: VoxelBuilder = VoxelProtos.make(str(it["kind"]), it["params"], mats)
    var holder := Node3D.new()
    holder.transform = it["xf"]
    add_child(holder)
    var vb := VoxelBody.new()
    vb.static_collision = true
    vb.anchor_y = 0
    vb.rigid_fragments = true
    holder.add_child(vb)
    vb.setup(builder, true)
    vb.built.connect(func() -> void: _on_built(it))
    it["vb"] = vb
    return vb


func _on_built(it: Dictionary) -> void:
    for v in it["vis"]:
        var a: Array = v if v is Array else [v]
        if a.size() == 2 and a[0] is MultiMeshInstance3D:
            ((a[0] as MultiMeshInstance3D).multimesh).set_instance_transform(int(a[1]), Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
        elif a.size() == 1 and a[0] is Node3D:
            (a[0] as Node3D).visible = false
            _disable_tree(a[0])
    var cs: Node = it["cs"]
    if cs != null and is_instance_valid(cs):
        _disable_tree(cs)


func _disable_tree(n: Node) -> void:
    if n is CollisionShape3D:
        (n as CollisionShape3D).set_deferred("disabled", true)
    elif n is CollisionObject3D:
        (n as CollisionObject3D).collision_layer = 0
        (n as CollisionObject3D).collision_mask = 0
    for c in n.get_children():
        _disable_tree(c)
