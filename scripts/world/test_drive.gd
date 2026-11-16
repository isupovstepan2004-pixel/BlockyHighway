extends Node3D
## Игровая сцена: карта + машина + камеры + управление. Из машины можно выйти и ходить пешком
## с инвентарём (молоток, дробовик, динамит, баллончик).

const TIMES: Array = [12.0, 17.8, 21.5, 6.3]

var vehicle: Vehicle
var cam: ChaseCamera
var foot_cam: FootCamera
var hud: TouchControls
var foot_hud: FootControls
var player: PlayerChar
var sky: SkyEnvironment
var world: Node3D
var on_foot: bool = false
var _time_idx: int = 0


func _ready() -> void:
    match Game.selected_map:
        "city":
            world = CityMap.new()
        "american":
            world = AmericanRoad.new()
        _:
            world = ProvingGround.new()
    sky = SkyEnvironment.new()
    var sh: Variant = world.get("start_hour")
    sky.hours = float(sh) if sh != null else float(TIMES[0])
    var fs: Variant = world.get("fog_scale")
    if fs != null:
        sky.fog_scale = float(fs)
    add_child(sky)
    add_child(world)

    vehicle = Vehicle.new()
    vehicle.car_id = Game.selected_car
    vehicle.paint = Game.get_paint(Game.selected_car)
    if world.has_method("get_spawn"):
        vehicle.transform = world.call("get_spawn")
    else:
        vehicle.position = Vector3(0.0, 0.8, 40.0)
    add_child(vehicle)
    if world.has_method("set_player"):
        world.call("set_player", vehicle)
    world.call("set_night", sky.is_night())
    vehicle.set_headlights(sky.is_night())

    cam = ChaseCamera.new()
    cam.target = vehicle
    add_child(cam)
    foot_cam = FootCamera.new()
    add_child(foot_cam)

    var layer := CanvasLayer.new()
    hud = TouchControls.new()
    foot_hud = FootControls.new()
    layer.add_child(hud)
    layer.add_child(foot_hud)
    add_child(layer)

    vehicle.crashed.connect(cam.shake)
    hud.camera_pressed.connect(cam.cycle_mode)
    hud.view_rotate.connect(cam.rotate_view)
    hud.view_zoom.connect(cam.zoom)
    hud.reset_pressed.connect(vehicle.request_reset)
    hud.menu_pressed.connect(_to_menu)
    hud.time_pressed.connect(_cycle_time)
    hud.exit_pressed.connect(_exit_vehicle)
    foot_hud.view_rotate.connect(foot_cam.rotate_view)
    foot_hud.menu_pressed.connect(_to_menu)
    foot_hud.enter_pressed.connect(_enter_vehicle)
    foot_hud.tool_selected.connect(_select_tool)

    var dw: Variant = world.get("dworld")
    if dw != null:
        (dw as DestructibleWorld).exploded.connect(_on_explosion)


func _on_explosion(pos: Vector3, power: float) -> void:
    var ref: Vector3 = player.global_position if on_foot else vehicle.global_position
    var s: float = clampf(power * 0.12 / (1.0 + ref.distance_to(pos) * 0.08), 0.0, 1.2)
    cam.shake(s)
    foot_cam.shake(s)


func _physics_process(delta: float) -> void:
    if on_foot:
        vehicle.in_throttle = 0.0
        vehicle.in_brake = 0.0
        vehicle.in_steer = 0.0
        vehicle.in_handbrake = true
        player.move = foot_hud.move
        player.cam_yaw = foot_cam.yaw
        player.jump_req = foot_hud.jump
        player.belt.tick(delta, foot_hud.firing)
        return
    var thr: float = hud.throttle
    var brk: float = hud.brake
    var st: float = hud.steer
    var hb: bool = hud.handbrake
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
        thr = 1.0
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
        brk = 1.0
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
        st = -1.0
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
        st = 1.0
    if Input.is_key_pressed(KEY_SPACE):
        hb = true
    vehicle.in_throttle = thr
    vehicle.in_brake = brk
    vehicle.in_steer = st
    vehicle.in_handbrake = hb


func _process(_delta: float) -> void:
    hud.speed_kmh = vehicle.get_speed_kmh()
    hud.info_text = "%s   G%s   DMG %d%%" % [cam.mode_name(), vehicle.gear_label(), int(vehicle.get_damage() * 100.0)]
    if on_foot:
        foot_hud.near_car = player.global_position.distance_to(vehicle.global_position) < 5.5
        foot_hud.selected = player.belt.current
        foot_hud.spray_color = player.belt.spray_color()


func _exit_vehicle() -> void:
    if on_foot or vehicle.get_speed_kmh() > 30.0:
        return
    on_foot = true
    var f: Vector3 = -vehicle.global_transform.basis.z
    f.y = 0.0
    var yaw: float = atan2(-f.x, -f.z) if f.length() > 0.05 else 0.0
    if player == null:
        player = PlayerChar.new()
        add_child(player)
        player.belt.cam = foot_cam
        foot_cam.target = player
    player.process_mode = Node.PROCESS_MODE_INHERIT
    player.visible = true
    player.global_position = vehicle.global_position - vehicle.global_transform.basis.x * 2.6 + Vector3(0.0, 0.6, 0.0)
    player.velocity = Vector3.ZERO
    foot_cam.yaw = yaw
    foot_cam.pitch = 0.2
    foot_cam.activate()
    vehicle.parked = true
    hud.active = false
    foot_hud.active = true


func _enter_vehicle() -> void:
    if not on_foot:
        return
    if player.global_position.distance_to(vehicle.global_position) > 5.5:
        return
    on_foot = false
    player.visible = false
    player.process_mode = Node.PROCESS_MODE_DISABLED
    player.global_position = Vector3(0.0, -500.0, 0.0)
    vehicle.parked = false
    cam.activate()
    hud.active = true
    foot_hud.active = false


func _select_tool(i: int) -> void:
    if on_foot:
        player.belt.select(i)


func _unhandled_key_input(event: InputEvent) -> void:
    var k := event as InputEventKey
    if k == null or not k.pressed or k.echo:
        return
    match k.keycode:
        KEY_C:
            cam.cycle_mode()
        KEY_R:
            vehicle.request_reset()
        KEY_T:
            _cycle_time()
        KEY_E:
            if on_foot:
                _enter_vehicle()
            else:
                _exit_vehicle()
        KEY_1:
            _select_tool(0)
        KEY_2:
            _select_tool(1)
        KEY_3:
            _select_tool(2)
        KEY_4:
            _select_tool(3)
        KEY_ESCAPE:
            _to_menu()


func _cycle_time() -> void:
    _time_idx = (_time_idx + 1) % TIMES.size()
    sky.set_time(float(TIMES[_time_idx]))
    var night: bool = sky.is_night() or float(TIMES[_time_idx]) > 20.0
    vehicle.set_headlights(night)
    world.call("set_night", night)


func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_GO_BACK_REQUEST:
        _to_menu()


func _to_menu() -> void:
    get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
