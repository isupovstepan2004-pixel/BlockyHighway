extends Node
## Autoload "Game": сохранения, настройки, применение качества графики.

const SAVE_PATH := "user://blocky_highway.cfg"

var selected_car: String = "sportcar"
var selected_map: String = "proving"   # proving | city | american
var paints: Dictionary = {}   # id -> индекс в CarData.PAINTS (нет записи = заводской цвет)
var settings: Dictionary = {
    "quality": 1,
    "master_volume": 0.8,
    "steer_sensitivity": 1.0,
    "show_fps": false,
}


func _ready() -> void:
    load_game()
    apply_audio()
    apply_graphics()


func load_game() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(SAVE_PATH) != OK:
        return
    selected_car = str(cfg.get_value("garage", "car", selected_car))
    if not CarData.has_car(selected_car):
        selected_car = CarData.ORDER[0]
    for key in cfg.get_section_keys("paints"):
        paints[key] = int(cfg.get_value("paints", key, -1))
    for key in settings.keys():
        settings[key] = cfg.get_value("settings", key, settings[key])


func save_game() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("garage", "car", selected_car)
    for key in paints.keys():
        cfg.set_value("paints", key, paints[key])
    for key in settings.keys():
        cfg.set_value("settings", key, settings[key])
    cfg.save(SAVE_PATH)


func get_paint(id: String) -> Color:
    var idx: int = int(paints.get(id, -1))
    if idx >= 0 and idx < CarData.PAINTS.size():
        return CarData.PAINTS[idx]
    return CarData.default_paint(id)


func set_paint(id: String, idx: int) -> void:
    if idx < 0:
        paints.erase(id)
    else:
        paints[id] = idx


func apply_audio() -> void:
    var v: float = clampf(float(settings["master_volume"]), 0.0001, 1.0)
    AudioServer.set_bus_volume_db(0, linear_to_db(v))


func apply_graphics() -> void:
    var q: int = int(settings["quality"])
    var vp: Viewport = get_viewport()
    var msaa: Array = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X]
    vp.msaa_3d = msaa[clampi(q, 0, 2)]
    var atlas: Array = [1024, 2048, 4096]
    RenderingServer.directional_shadow_atlas_set_size(int(atlas[clampi(q, 0, 2)]), true)
    var soft: Array = [RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM]
    RenderingServer.directional_soft_shadow_filter_set_quality(soft[clampi(q, 0, 2)])
    Engine.max_fps = 60


func configure_sun(sun: DirectionalLight3D) -> void:
    var q: int = int(settings["quality"])
    var dist: Array = [0.0, 90.0, 140.0]
    sun.shadow_enabled = q > 0
    sun.directional_shadow_max_distance = float(dist[clampi(q, 0, 2)])
    sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if q >= 2 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
    sun.directional_shadow_blend_splits = true
    sun.shadow_normal_bias = 1.2
    sun.shadow_blur = 1.1
