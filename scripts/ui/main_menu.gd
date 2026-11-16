extends Node3D
## Главное меню: вращающаяся машина на витрине + Play / Garage / Settings / About.

var _car_root: Node3D
var _panel: PanelContainer
var _box: VBoxContainer
var _cam: Camera3D
var _floor: MeshInstance3D


func _ready() -> void:
    var sky := SkyEnvironment.new()
    sky.hours = 16.5
    add_child(sky)
    _build_floor()
    _car_root = Node3D.new()
    add_child(_car_root)
    _cam = Camera3D.new()
    _cam.fov = 45.0
    add_child(_cam)
    _refresh_car()
    _build_ui()


func _process(delta: float) -> void:
    _car_root.rotate_y(delta * 0.45)


func _build_floor() -> void:
    var mi := MeshInstance3D.new()
    _floor = mi
    var cm := CylinderMesh.new()
    cm.top_radius = 10.0
    cm.bottom_radius = 10.0
    cm.height = 0.2
    mi.mesh = cm
    var m := StandardMaterial3D.new()
    m.albedo_color = Color(0.07, 0.08, 0.1)
    m.metallic = 0.3
    m.roughness = 0.35
    mi.material_override = m
    mi.position = Vector3(0.0, -0.1, 0.0)
    add_child(mi)


func _refresh_car() -> void:
    for c in _car_root.get_children():
        c.queue_free()
    var id: String = Game.selected_car
    var stats: Dictionary = CarData.get_stats(id)
    _car_root.add_child(CarFactory.make_showroom_car(id, Game.get_paint(id)))
    _car_root.position = Vector3(0.0, float(stats["wheel_radius"]) - float(stats["wheel_c"]), 0.0)
    var length: float = float(stats["length"])
    var dist: float = maxf(7.8, length * 1.6 + 2.0)
    var dir: Vector3 = Vector3(0.62, 0.0, 0.9).normalized()
    _cam.look_at_from_position(dir * dist + Vector3(0.0, 1.0 + dist * 0.14, 0.0), Vector3(0.0, 0.5 + length * 0.04, 0.0))
    var cm: CylinderMesh = _floor.mesh
    var rad: float = maxf(10.0, length * 1.1)
    cm.top_radius = rad
    cm.bottom_radius = rad


# ---------------------------------------------------------------- UI

func _sb(bg: Color, border: Color) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = border
    s.set_border_width_all(2)
    s.set_corner_radius_all(14)
    s.set_content_margin_all(14.0)
    return s


func _make_theme() -> Theme:
    var t := Theme.new()
    t.set_font_size("font_size", "Button", 28)
    t.set_font_size("font_size", "Label", 24)
    t.set_stylebox("normal", "Button", _sb(Color(0.12, 0.14, 0.18, 0.85), Color(1, 1, 1, 0.15)))
    t.set_stylebox("hover", "Button", _sb(Color(0.2, 0.3, 0.45, 0.95), Color(1, 1, 1, 0.3)))
    t.set_stylebox("pressed", "Button", _sb(Color(0.95, 0.6, 0.1, 1.0), Color(1, 1, 1, 0.5)))
    t.set_stylebox("disabled", "Button", _sb(Color(0.1, 0.1, 0.12, 0.5), Color(1, 1, 1, 0.05)))
    t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
    t.set_color("font_color", "Button", Color.WHITE)
    t.set_color("font_pressed_color", "Button", Color(0.05, 0.05, 0.05))
    t.set_color("font_hover_color", "Button", Color.WHITE)
    t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.35))
    t.set_stylebox("panel", "PanelContainer", _sb(Color(0.05, 0.06, 0.09, 0.88), Color(1, 1, 1, 0.12)))
    return t


func _build_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var root := Control.new()
    root.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.theme = _make_theme()
    layer.add_child(root)

    var margin := MarginContainer.new()
    margin.set_anchors_preset(Control.PRESET_FULL_RECT)
    for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
        margin.add_theme_constant_override(side, 36)
    root.add_child(margin)

    var hbox := HBoxContainer.new()
    hbox.add_theme_constant_override("separation", 24)
    margin.add_child(hbox)

    var left := VBoxContainer.new()
    left.custom_minimum_size = Vector2(360.0, 0.0)
    left.add_theme_constant_override("separation", 14)
    hbox.add_child(left)

    var title := Label.new()
    title.text = "BLOCKY\nHIGHWAY"
    title.add_theme_font_size_override("font_size", 64)
    left.add_child(title)
    var sub := Label.new()
    sub.text = "12 CARS. ENDLESS POSSIBILITIES."
    sub.add_theme_font_size_override("font_size", 18)
    sub.modulate = Color(1, 1, 1, 0.7)
    left.add_child(sub)
    var spacer := Control.new()
    spacer.custom_minimum_size = Vector2(0.0, 10.0)
    left.add_child(spacer)

    _add_menu_button(left, "PLAY", _open_play)
    _add_menu_button(left, "GARAGE", _open_garage)
    _add_menu_button(left, "SETTINGS", _open_settings)
    _add_menu_button(left, "ABOUT", _open_about)

    var mid := Control.new()
    mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    hbox.add_child(mid)

    _panel = PanelContainer.new()
    _panel.custom_minimum_size = Vector2(420.0, 0.0)
    _panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    _panel.visible = false
    hbox.add_child(_panel)
    _box = VBoxContainer.new()
    _box.add_theme_constant_override("separation", 8)
    _panel.add_child(_box)


func _add_menu_button(parent: Control, text: String, cb: Callable) -> void:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(0.0, 68.0)
    b.pressed.connect(cb)
    parent.add_child(b)


func _clear_panel(title_text: String) -> void:
    for c in _box.get_children():
        c.queue_free()
    _panel.visible = true
    var t := Label.new()
    t.text = title_text
    t.add_theme_font_size_override("font_size", 34)
    _box.add_child(t)


func _add_label(text: String, wrap: bool = false) -> Label:
    var l := Label.new()
    l.text = text
    if wrap:
        l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        l.custom_minimum_size = Vector2(380.0, 0.0)
    _box.add_child(l)
    return l


func _add_button(text: String, cb: Callable, disabled: bool = false) -> Button:
    var b := Button.new()
    b.text = text
    b.disabled = disabled
    b.custom_minimum_size = Vector2(0.0, 60.0)
    b.pressed.connect(cb)
    _box.add_child(b)
    return b


# ---------------------------------------------------------------- Play

func _open_play() -> void:
    _clear_panel("SELECT MAP")
    _add_button("TEST GROUND  (ramps, walls, crates)", _start_map.bind("proving"))
    _add_button("CITY  (traffic + pedestrians)", _start_map.bind("city"))
    _add_button("AMERICAN ROAD  (highway loop)", _start_map.bind("american"))
    _add_button("CRASH TEST  - coming soon", _start_test, true)


func _start_map(id: String) -> void:
    Game.selected_map = id
    _start_test()


func _start_test() -> void:
    Game.save_game()
    get_tree().change_scene_to_file("res://scenes/test_drive.tscn")


# ---------------------------------------------------------------- Garage

func _open_garage() -> void:
    var id: String = Game.selected_car
    var stats: Dictionary = CarData.get_stats(id)
    _clear_panel(str(stats["name"]))
    _add_stat("SPEED", float(stats["r_speed"]))
    _add_stat("ACCEL", float(stats["r_accel"]))
    _add_stat("HANDLING", float(stats["r_handling"]))
    _add_stat("DURABILITY", float(stats["r_durability"]))
    var info: Label = _add_label("%d kg   %s   %d km/h" % [int(stats["mass"]), str(stats["drive"]), int(float(stats["top_speed"]) * 3.6)])
    info.add_theme_font_size_override("font_size", 20)

    var grid := GridContainer.new()
    grid.columns = 3
    grid.add_theme_constant_override("h_separation", 8)
    grid.add_theme_constant_override("v_separation", 8)
    for car_id in CarData.ORDER:
        var cid: String = car_id
        var cs: Dictionary = CarData.get_stats(cid)
        var btn := Button.new()
        btn.text = str(cs["name"])
        btn.toggle_mode = true
        btn.button_pressed = cid == id
        btn.add_theme_font_size_override("font_size", 16)
        btn.custom_minimum_size = Vector2(130.0, 50.0)
        btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        btn.pressed.connect(func(): _select_car(cid))
        grid.add_child(btn)
    _box.add_child(grid)

    _add_label("PAINT")
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 6)
    var cur: int = int(Game.paints.get(id, -1))
    var swatches: Array = [CarData.default_paint(id)]
    swatches.append_array(CarData.PAINTS)
    for i in swatches.size():
        var idx: int = i - 1
        var sw := Button.new()
        sw.custom_minimum_size = Vector2(40.0, 44.0)
        sw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var col: Color = swatches[i]
        var border: Color = Color(1, 1, 1, 0.95) if idx == cur else Color(1, 1, 1, 0.15)
        for state in ["normal", "hover", "pressed"]:
            sw.add_theme_stylebox_override(state, _sb(col, border))
        sw.pressed.connect(func(): _set_paint(idx))
        row.add_child(sw)
    _box.add_child(row)


func _add_stat(label_text: String, value: float) -> void:
    var row := HBoxContainer.new()
    var l := Label.new()
    l.text = label_text
    l.custom_minimum_size = Vector2(150.0, 0.0)
    l.add_theme_font_size_override("font_size", 20)
    var bar := ProgressBar.new()
    bar.min_value = 0.0
    bar.max_value = 1.0
    bar.value = value
    bar.show_percentage = false
    bar.custom_minimum_size = Vector2(240.0, 18.0)
    bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    row.add_child(l)
    row.add_child(bar)
    _box.add_child(row)


func _select_car(id: String) -> void:
    Game.selected_car = id
    Game.save_game()
    _refresh_car()
    _open_garage()


func _set_paint(idx: int) -> void:
    Game.set_paint(Game.selected_car, idx)
    Game.save_game()
    _refresh_car()
    _open_garage()


# ---------------------------------------------------------------- Settings

func _open_settings() -> void:
    _clear_panel("SETTINGS")
    _add_label("Graphics quality")
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    var grp := ButtonGroup.new()
    var names: Array = ["LOW", "MEDIUM", "HIGH"]
    for i in 3:
        var b := Button.new()
        b.text = str(names[i])
        b.toggle_mode = true
        b.button_group = grp
        b.button_pressed = int(Game.settings["quality"]) == i
        b.custom_minimum_size = Vector2(0.0, 56.0)
        b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        b.pressed.connect(func(): _set_quality(i))
        row.add_child(b)
    _box.add_child(row)

    _add_label("Master volume")
    _add_slider(0.0, 1.0, 0.05, float(Game.settings["master_volume"]), func(v: float):
        Game.settings["master_volume"] = v
        Game.apply_audio()
        Game.save_game())
    _add_label("Steering sensitivity")
    _add_slider(0.5, 1.5, 0.05, float(Game.settings["steer_sensitivity"]), func(v: float):
        Game.settings["steer_sensitivity"] = v
        Game.save_game())

    var fps := Button.new()
    fps.toggle_mode = true
    fps.button_pressed = bool(Game.settings["show_fps"])
    fps.text = "SHOW FPS: ON" if fps.button_pressed else "SHOW FPS: OFF"
    fps.custom_minimum_size = Vector2(0.0, 56.0)
    fps.toggled.connect(func(on: bool):
        Game.settings["show_fps"] = on
        fps.text = "SHOW FPS: ON" if on else "SHOW FPS: OFF"
        Game.save_game())
    _box.add_child(fps)


func _add_slider(lo: float, hi: float, step: float, value: float, cb: Callable) -> void:
    var s := HSlider.new()
    s.min_value = lo
    s.max_value = hi
    s.step = step
    s.value = value
    s.custom_minimum_size = Vector2(0.0, 44.0)
    s.value_changed.connect(cb)
    _box.add_child(s)


func _set_quality(q: int) -> void:
    Game.settings["quality"] = q
    Game.apply_graphics()
    Game.save_game()


# ---------------------------------------------------------------- About

func _open_about() -> void:
    _clear_panel("ABOUT")
    _add_label("Blocky Highway - voxel car sandbox.\nStage 2 build: 12 voxel cars with own physics setups, garage, test ground, touch controls.\n\nCamera: drag to rotate, pinch to zoom, CAM button to switch view.", true)
