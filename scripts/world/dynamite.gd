class_name Dynamite
extends RigidBody3D
## Динамитная шашка с запалом. Взрывается через FUSE секунд, цепная реакция с соседними шашками.

const FUSE: float = 3.0
const RADIUS: float = 8.0

var fuse: float = FUSE
var _tip: MeshInstance3D
var _tip_mat: StandardMaterial3D
static var _pm: PhysicsMaterial


func _ready() -> void:
    add_to_group("dynamite")
    mass = 0.8
    if _pm == null:
        _pm = PhysicsMaterial.new()
        _pm.friction = 0.9
        _pm.bounce = 0.25
    physics_material_override = _pm
    var red := StandardMaterial3D.new()
    red.albedo_color = Color(0.8, 0.1, 0.08)
    red.roughness = 0.7
    for ox in [-0.05, 0.0, 0.05]:
        var mi := MeshInstance3D.new()
        var bm := BoxMesh.new()
        bm.size = Vector3(0.045, 0.24, 0.045)
        mi.mesh = bm
        mi.material_override = red
        mi.position = Vector3(float(ox), 0.0, 0.0)
        add_child(mi)
    var band := MeshInstance3D.new()
    var bb := BoxMesh.new()
    bb.size = Vector3(0.17, 0.03, 0.06)
    band.mesh = bb
    band.material_override = StandardMaterial3D.new()
    add_child(band)
    _tip = MeshInstance3D.new()
    var tm := BoxMesh.new()
    tm.size = Vector3(0.03, 0.06, 0.03)
    _tip.mesh = tm
    _tip.position = Vector3(0.0, 0.15, 0.0)
    _tip_mat = StandardMaterial3D.new()
    _tip_mat.emission_enabled = true
    _tip_mat.emission = Color(1.0, 0.6, 0.1)
    _tip.material_override = _tip_mat
    add_child(_tip)
    var cs := CollisionShape3D.new()
    var sh := BoxShape3D.new()
    sh.size = Vector3(0.17, 0.24, 0.06)
    cs.shape = sh
    add_child(cs)


func _physics_process(delta: float) -> void:
    fuse -= delta
    var blink: float = 1.0 if int(fuse * 6.0) % 2 == 0 else 0.15
    _tip_mat.emission_energy_multiplier = 4.0 * blink
    if fuse <= 0.0:
        _explode()


func _explode() -> void:
    set_physics_process(false)
    for d in get_tree().get_nodes_in_group("dynamite"):
        if d != self and (d as Node3D).global_position.distance_to(global_position) < RADIUS * 1.2:
            (d as Dynamite).fuse = minf((d as Dynamite).fuse, 0.15)
    Destruct.explosion(global_position, RADIUS, 1.0)
    queue_free()
