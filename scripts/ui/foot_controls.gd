class_name FootControls
extends Control
## Сенсорное управление пешком: джойстик, прыжок, кнопка применения инструмента, панель инвентаря,
## посадка в машину, обзор драгом. Клавиатура: WASD, пробел, F (применить), стрелки (обзор), 1-4, E.

signal view_rotate(rel: Vector2)
signal menu_pressed
signal enter_pressed
signal tool_selected(i: int)

var active: bool = false
var move: Vector2 = Vector2.ZERO
var firing: bool = false
var jump: bool = false
var near_car: bool = false
var selected: int = 0
var spray_color: Color = Color.RED

var _fingers: Dictionary = {}
var _stick_idx: int = -1
var _stick_pos: Vector2 = Vector2.ZERO
var _touch_move: Vector2 = Vector2.ZERO
var _stick_c: Vector2 = Vector2.ZERO
var _stick_r: float = 120.0
var _r_fire: Rect2
var _r_jump: Rect2
var _r_enter: Rect2
var _r_menu: Rect2
var _r_tools: Array = []
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
    sb.set_corner_radius_all(20)
    sb.set_border_width_all(2)
    sb.border_color = Color(1, 1, 1, 0.35)
    return sb


func _layout() -> void:
    var s: Vector2 = get_viewport_rect().size
    _stick_c = Vector2(200.0, s.y - 200.0)
    _r_fire = Rect2(s.x - 250.0, s.y - 250.0, 200.0, 200.0)
    _r_jump = Rect2(s.x - 130.0, s.y - 390.0, 100.0, 100.0)
    _r_menu = Rect2(20.0, 20.0, 90.0, 80.0)
    _r_enter = Rect2(s.x - 330.0, 20.0, 310.0, 80.0)
    _r_tools.clear()
    var x0: float = s.x * 0.5 - 270.0
    for i in 4:
        _r_tools.append(Rect2(x0 + float(i) * 138.0, s.y - 105.0, 126.0, 85.0))


func _role_at(pos: Vector2) -> String:
    if _r_menu.has_point(pos):
        return "menu"
    if near_car and _r_enter.has_point(pos):
        return "enter"
    for i in 4:
        if (_r_tools[i] as Rect2).has_point(pos):
            return "tool%d" % i
    if _r_fire.has_point(pos):
        return "fire"
    if _r_jump.has_point(pos):
        return "jump"
    if pos.distance_to(_stick_c) < _stick_r * 1.5:
        return "stick"
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
    if role == "menu":
        menu_pressed.emit()
    elif role == "enter":
        enter_pressed.emit()
    elif role.begins_with("tool"):
        tool_selected.emit(int(role.substr(4)))
    elif role == "stick":
        _stick_idx = idx
        _update_stick(pos)


func _release(idx: int) -> void:
    if not _fingers.has(idx):
        return
    if idx == _stick_idx:
        _stick_idx = -1
        _touch_move = Vector2.ZERO
    _fingers.erase(idx)


func _drag(idx: int, pos: Vector2, rel: Vector2) -> void:
    if not _fingers.has(idx):
        return
    if idx == _stick_idx:
        _update_stick(pos)
    elif _fingers[idx] == "view":
        view_rotate.emit(rel)


func _update_stick(pos: Vector2) -> void:
    var v: Vector2 = (pos - _stick_c) / _stick_r
    if v.length() > 1.0:
        v = v.normalized()
    _stick_pos = _stick_c + v * _stick_r
    _touch_move = Vector2(v.x, -v.y)


func _process(delta: float) -> void:
    if not active:
        _fingers.clear()
        _stick_idx = -1
        _touch_move = Vector2.ZERO
        move = Vector2.ZERO
        firing = false
        jump = false
        return
    var vals: Array = _fingers.values()
    var kb := Vector2.ZERO
    if Input.is_key_pressed(KEY_W):
        kb.y += 1.0
    if Input.is_key_pressed(KEY_S):
        kb.y -= 1.0
    if Input.is_key_pressed(KEY_D):
        kb.x += 1.0
    if Input.is_key_pressed(KEY_A):
        kb.x -= 1.0
    move = (_touch_move + kb).limit_length(1.0)
    firing = vals.has("fire") or Input.is_key_pressed(KEY_F)
    jump = vals.has("jump") or Input.is_key_pressed(KEY_SPACE)
    var look := Vector2.ZERO
    if Input.is_key_pressed(KEY_LEFT):
        look.x -= 1.0
    if Input.is_key_pressed(KEY_RIGHT):
        look.x += 1.0
    if Input.is_key_pressed(KEY_UP):
        look.y -= 1.0
    if Input.is_key_pressed(KEY_DOWN):
        look.y += 1.0
    if look != Vector2.ZERO:
        view_rotate.emit(look * 500.0 * delta)
    if _stick_idx == -1:
        _stick_pos = _stick_c
    queue_redraw()


func _btn(rect: Rect2, label: String, down: bool, fs: int = 22) -> void:
    draw_style_box(_sb_down if down else _sb_idle, rect)
    var font: Font = ThemeDB.fallback_font
    draw_string(font, Vector2(rect.position.x, rect.position.y + rect.size.y * 0.5 + fs * 0.35), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, fs, Color(1, 1, 1, 0.92))


func _draw() -> void:
    if not active:
        return
    _layout()
    var vals: Array = _fingers.values()
    var s: Vector2 = get_viewport_rect().size
    # прицел
    var c: Vector2 = s * 0.5
    draw_circle(c, 3.0, Color(1, 1, 1, 0.9))
    draw_arc(c, 14.0, 0.0, TAU, 24, Color(1, 1, 1, 0.6), 2.0, true)
    # джойстик
    draw_circle(_stick_c, _stick_r, Color(0, 0, 0, 0.2))
    draw_arc(_stick_c, _stick_r, 0.0, TAU, 48, Color(1, 1, 1, 0.5), 6.0, true)
    draw_circle(_stick_pos, 46.0, Color(1, 1, 1, 0.35))
    _btn(_r_fire, "USE", vals.has("fire"), 34)
    _btn(_r_jump, "JUMP", vals.has("jump"), 20)
    _btn(_r_menu, "MENU", false)
    if near_car:
        _btn(_r_enter, "ENTER CAR", false, 28)
    var names: Array = ToolBelt.NAMES
    for i in 4:
        var r: Rect2 = _r_tools[i]
        _btn(r, str(names[i]), i == selected, 18)
        if i == 3:
            draw_rect(Rect2(r.position.x + 8.0, r.position.y + r.size.y - 16.0, r.size.x - 16.0, 8.0), spray_color)
