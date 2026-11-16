class_name PlayerChar
extends CharacterBody3D
## Игрок пешком: воксельный человечек с инвентарём (молоток, дробовик, динамит, баллончик).

const WALK: float = 5.0
const SPRINT: float = 8.0
const JUMP: float = 6.4
const GRAV: float = 20.0

var move: Vector2 = Vector2.ZERO     # x — вправо, y — вперёд
var jump_req: bool = false
var cam_yaw: float = 0.0
var belt: ToolBelt
var hand: Node3D

var _visual: Node3D
var _legs: Array = []
var _phase: float = 0.0


func _ready() -> void:
    add_to_group("player")
    var cs := CollisionShape3D.new()
    var cap := CapsuleShape3D.new()
    cap.radius = 0.35
    cap.height = 1.75
    cs.shape = cap
    cs.position = Vector3(0.0, 0.875, 0.0)
    add_child(cs)
    floor_snap_length = 0.4
    _visual = Node3D.new()
    _visual.position = Vector3(0.0, 0.8, 0.0)
    add_child(_visual)
    var parts: Array = Pedestrian.make_parts(Color(0.15, 0.4, 0.8), Color(0.15, 0.22, 0.45), Color(0.95, 0.76, 0.6), Color(0.1, 0.07, 0.05))
    var mat: StandardMaterial3D = WorldKit.vc_mat()
    var bi := MeshInstance3D.new()
    bi.mesh = parts[0]
    bi.material_override = mat
    _visual.add_child(bi)
    for sx in [-1.0, 1.0]:
        var leg := MeshInstance3D.new()
        leg.mesh = parts[1]
        leg.material_override = mat
        leg.position = Vector3(float(sx) * 1.5 * Pedestrian.VS, 0.0, 0.0)
        _visual.add_child(leg)
        _legs.append(leg)
    hand = Node3D.new()
    hand.position = Vector3(0.4, 0.5, -0.3)
    _visual.add_child(hand)
    belt = ToolBelt.new()
    belt.player = self
    add_child(belt)


func chest() -> Vector3:
    return global_position + Vector3(0.0, 1.35, 0.0)


func _physics_process(delta: float) -> void:
    var yb := Basis(Vector3.UP, cam_yaw)
    var dir: Vector3 = yb * Vector3(move.x, 0.0, -move.y)
    var mag: float = clampf(move.length(), 0.0, 1.0)
    var spd: float = (SPRINT if mag > 0.92 else WALK) * mag
    var target: Vector3 = dir.normalized() * spd if dir.length() > 0.01 else Vector3.ZERO
    velocity.x = move_toward(velocity.x, target.x, 45.0 * delta)
    velocity.z = move_toward(velocity.z, target.z, 45.0 * delta)
    if is_on_floor():
        velocity.y = JUMP if jump_req else -1.0
    else:
        velocity.y -= GRAV * delta
    jump_req = false
    move_and_slide()
    _visual.rotation.y = lerp_angle(_visual.rotation.y, cam_yaw, 1.0 - exp(-12.0 * delta))
    var hs: float = Vector2(velocity.x, velocity.z).length()
    _phase += delta * hs * 1.6
    var sw: float = sin(_phase) * 0.7 * clampf(hs / 4.0, 0.0, 1.0)
    (_legs[0] as Node3D).rotation.x = sw
    (_legs[1] as Node3D).rotation.x = -sw
    if global_position.y < -80.0:
        global_position.y = 20.0
        velocity = Vector3.ZERO
