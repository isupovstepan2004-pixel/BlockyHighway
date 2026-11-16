class_name TouchControls
extends Control
## Сенсорное управление: руль, газ, тормоз, ручник, кнопки, жесты камеры (драг + щипок).

signal camera_pressed
signal reset_pressed
signal menu_pressed
signal time_pressed
signal exit_pressed
signal view_rotate(rel: Vector2)
signal view_zoom(factor: float)

const MAX_WHEEL: float = 2.1

var throttle: float = 0.0
var brake: float = 0.0
var steer: float = 0.0
var handbrake: bool = false
var speed_kmh: float = 0.0
var info_text: String = ""
var wheel_angle: float = 0.0
var active: bool = true

var _fingers: Dictionary = {}
var _view_pos: Dictionary = {}
var _wheel_finger: int = -1
var _wheel_last: float = 0.0

var _wheel_c: Vector2 = Vector2.ZERO
var _wheel_r: float = 140.0
var _r_gas: Rect2
var _r_brake: Rect2
var _r_hb: Rect2
var _r_menu: Rect2
var _r_cam: Rect2
var _r_reset: Rect2
var _r_time: Rect2
var _r_exit: Rect2
var _sb_idle: StyleBoxFlat
var _sb_down: StyleBoxFlat


func _ready() -> void:
    set_anchors_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _sb_idle = _make_sb(Color(1, 1, 1, 0.13))
    _sb_down = _make_sb(Color(1.0, 0.65, 0.1, 0.45))


func _make_sb(c: Color) -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = c
    sb.set_corner_radius_all(22)
    sb.set_border_width_all(2)
    sb.border_color = Color(1, 1, 1, 0.35)
    return sb


func _layout() -> void:
    var s: Vector2 = get_viewport_rect().size
    _wheel_c = Vector2(210.0, s.y - 200.0)
    _wheel_r = 140.0
    _r_gas = Rect2(s.x - 190.0, s.y - 340.0, 150.0, 290.0)
    _r_brake = Rect2(s.x - 370.0, s.y - 260.0, 150.0, 210.0)
    _r_hb = Rect2(s.x - 370.0, s.y - 390.0, 150.0, 100.0)
    _r_menu = Rect2(20.0, 20.0, 90.0, 80.0)
    _r_cam = Rect2(s.x - 110.0, 20.0, 90.0, 80.0)
    _r_reset = Rect2(s.x - 210.0, 20.0, 90.0, 80.0)
    _r_time = Rect2(s.x - 310.0, 20.0, 90.0, 80.0)
    _r_exit = Rect2(s.x - 410.0, 20.0, 90.0, 80.0)


func _role_at(pos: Vector2) -> String:
    if _r_menu.has_point(pos):
        return "menu"
    if _r_cam.has_point(pos):
        return "cam"
    if _r_reset.has_point(pos):
        return "reset"
    if _r_time.has_point(pos):
        return "time"
    if _r_exit.has_point(pos):
        return "exit"
    if _r_gas.has_point(pos):
        return "gas"
    if _r_brake.has_point(pos):
        return "brake"
    if _r_hb.has_point(pos):
        return "hb"
    if pos.distance_to(_wheel_c) < _wheel_r * 1.35:
        return "wheel"
    return "view"


func _input(event: InputEvent) -> void:
    if not active:
        return
    if event is InputEventScreenTouch:
        var t: InputEventScreenTouch = event
        if t.pressed:
            _press(t.index, t.position)
        else:
            _release(t.index)
    elif event is InputEventScreenDrag:
        var d: InputEventScreenDrag = event
        _drag(d.index, d.position, d.relative)


func _press(idx: int, pos: Vector2) -> void:
    _layout()
    var role: String = _role_at(pos)
    _fingers[idx] = role
    match role:
        "menu":
            menu_pressed.emit()
        "cam":
            camera_pressed.emit()
        "reset":
            reset_pressed.emit()
        "time":
            time_pressed.emit()
        "exit":
            exit_pressed.emit()
        "wheel":
            _wheel_finger = idx
            _wheel_last = (pos - _wheel_c).angle()
        "view":
            _view_pos[idx] = pos


func _release(idx: int) -> void:
    if not _fingers.has(idx):
        return
    if idx == _wheel_finger:
        _wheel_finger = -1
    _view_pos.erase(idx)
    _fingers.erase(idx)


func _drag(idx: int, pos: Vector2, rel: Vector2) -> void:
    if not _fingers.has(idx):
        return
    var role: String = _fingers[idx]
    if role == "wheel" and idx == _wheel_finger:
        var off: Vector2 = pos - _wheel_c
        if off.length() < 12.0:
            return
        var a: float = off.angle()
        wheel_angle = clampf(wheel_angle + angle_difference(_wheel_last, a), -MAX_WHEEL, MAX_WHEEL)
        _wheel_last = a
    elif role == "view":
        if _view_pos.size() >= 2:
            var keys: Array = _view_pos.keys()
            var p0: Vector2 = _view_pos[keys[0]]
            var p1: Vector2 = _view_pos[keys[1]]
            var old_d: float = p0.distance_to(p1)
            _view_pos[idx] = pos
            p0 = _view_pos[keys[0]]
            p1 = _view_pos[keys[1]]
            var new_d: float = p0.distance_to(p1)
            if old_d > 10.0 and new_d > 10.0:
                view_zoom.emit(old_d / new_d)
        else:
            _view_pos[idx] = pos
            view_rotate.emit(rel)


func _process(delta: float) -> void:
    if not active:
        _fingers.clear()
        _view_pos.clear()
        _wheel_finger = -1
        throttle = 0.0
        brake = 0.0
        handbrake = false
        return
    var vals: Array = _fingers.values()
    throttle = move_toward(throttle, 1.0 if vals.has("gas") else 0.0, delta * 6.0)
    brake = move_toward(brake, 1.0 if vals.has("brake") else 0.0, delta * 6.0)
    handbrake = vals.has("hb")
    if _wheel_finger == -1:
        wheel_angle = move_toward(wheel_angle, 0.0, delta * 4.0)
    steer = clampf(wheel_angle / MAX_WHEEL * float(Game.settings["steer_sensitivity"]), -1.0, 1.0)
    queue_redraw()


func _btn(rect: Rect2, label: String, down: bool, fs: int = 22) -> void:
    draw_style_box(_sb_down if down else _sb_idle, rect)
    var font: Font = ThemeDB.fallback_font
    draw_string(font, Vector2(rect.position.x, rect.position.y + rect.size.y * 0.5 + fs * 0.35), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, fs, Color(1, 1, 1, 0.9))


func _draw() -> void:
    if not active:
        return
    _layout()
    var vals: Array = _fingers.values()
    # руль
    draw_circle(_wheel_c, _wheel_r, Color(0, 0, 0, 0.18))
    draw_arc(_wheel_c, _wheel_r, 0.0, TAU, 64, Color(1, 1, 1, 0.55), 12.0, true)
    for i in 3:
        var a: float = wheel_angle + float(i) * TAU / 3.0 + PI * 0.5
        draw_line(_wheel_c, _wheel_c + Vector2.from_angle(a) * (_wheel_r - 6.0), Color(1, 1, 1, 0.45), 8.0, true)
    var ma: float = wheel_angle - PI * 0.5
    draw_line(_wheel_c + Vector2.from_angle(ma) * (_wheel_r - 28.0), _wheel_c + Vector2.from_angle(ma) * (_wheel_r + 6.0), Color(1.0, 0.3, 0.2, 0.95), 12.0, true)
    # педали и кнопки
    _btn(_r_gas, "GAS", vals.has("gas"), 28)
    _btn(_r_brake, "BRAKE", vals.has("brake"), 26)
    _btn(_r_hb, "HAND", vals.has("hb"), 22)
    _btn(_r_menu, "MENU", false)
    _btn(_r_cam, "CAM", false)
    _btn(_r_reset, "RESET", false, 20)
    _btn(_r_time, "TIME", false)
    _btn(_r_exit, "EXIT", false)
    # скорость
    var font: Font = ThemeDB.fallback_font
    var s: Vector2 = get_viewport_rect().size
    draw_string(font, Vector2(s.x * 0.5 - 150.0, 70.0), "%d" % int(speed_kmh), HORIZONTAL_ALIGNMENT_CENTER, 300.0, 64, Color(1, 1, 1, 0.95))
    draw_string(font, Vector2(s.x * 0.5 - 150.0, 98.0), "km/h   " + info_text, HORIZONTAL_ALIGNMENT_CENTER, 300.0, 22, Color(1, 1, 1, 0.7))
    if bool(Game.settings["show_fps"]):
        draw_string(font, Vector2(130.0, 50.0), "FPS %d" % Engine.get_frames_per_second(), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, Color(0.6, 1, 0.6, 0.9))
