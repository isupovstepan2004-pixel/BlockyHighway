class_name Fx
extends RefCounted
## Эффекты: пыль, искры, дым и огонь (CPUParticles3D — работают на Android Compatibility).

static var _soft: ImageTexture
static var _quad_smoke: QuadMesh
static var _quad_fire: QuadMesh
static var _spark_mesh: BoxMesh
static var _win_start: int = 0
static var _win_count: int = 0


static func _root() -> Node:
    var tree: SceneTree = Engine.get_main_loop() as SceneTree
    if tree == null:
        return null
    return tree.current_scene


static func _soft_tex() -> ImageTexture:
    if _soft != null:
        return _soft
    var n: int = 64
    var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
    for y in n:
        for x in n:
            var dx: float = (float(x) + 0.5) / float(n) * 2.0 - 1.0
            var dy: float = (float(y) + 0.5) / float(n) * 2.0 - 1.0
            var d: float = sqrt(dx * dx + dy * dy)
            var a: float = clampf(1.0 - d, 0.0, 1.0)
            a = a * a * (3.0 - 2.0 * a)
            var nz: float = fposmod(sin(float(x) * 12.9898 + float(y) * 78.233) * 43758.5453, 1.0)
            a *= 0.8 + 0.2 * nz
            img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
    _soft = ImageTexture.create_from_image(img)
    return _soft


static func _puff_material(additive: bool) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.vertex_color_use_as_albedo = true
    m.albedo_texture = _soft_tex()
    m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    m.billboard_keep_scale = true
    m.particles_anim_h_frames = 1
    m.particles_anim_v_frames = 1
    m.particles_anim_loop = false
    m.disable_receive_shadows = true
    if additive:
        m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    return m


static func _smoke_quad() -> QuadMesh:
    if _quad_smoke == null:
        _quad_smoke = QuadMesh.new()
        _quad_smoke.size = Vector2.ONE
        _quad_smoke.material = _puff_material(false)
    return _quad_smoke


static func _fire_quad() -> QuadMesh:
    if _quad_fire == null:
        _quad_fire = QuadMesh.new()
        _quad_fire.size = Vector2.ONE
        _quad_fire.material = _puff_material(true)
    return _quad_fire


static func _grow_curve(a: float, b: float) -> Curve:
    var c := Curve.new()
    c.add_point(Vector2(0.0, a))
    c.add_point(Vector2(1.0, b))
    return c


static func _ramp(stops: Array) -> Gradient:
    # stops: [[offset, Color], ...]
    var g := Gradient.new()
    var first: Array = stops[0]
    g.set_color(0, first[1])
    g.set_offset(0, float(first[0]))
    var last: Array = stops[stops.size() - 1]
    g.set_color(1, last[1])
    g.set_offset(1, float(last[0]))
    for i in range(1, stops.size() - 1):
        var s: Array = stops[i]
        g.add_point(float(s[0]), s[1])
    return g


static func _autofree(node: Node, t: float) -> void:
    var tree: SceneTree = node.get_tree()
    if tree == null:
        return
    tree.create_timer(t).timeout.connect(func() -> void:
        if is_instance_valid(node):
            node.queue_free())


## Облако пыли. power ~ 0.3 (мелкое) .. 2.5 (сильный удар).
static func dust(pos: Vector3, power: float, col: Color = Color(0.72, 0.68, 0.62)) -> void:
    var root: Node = _root()
    if root == null:
        return
    var now: int = Time.get_ticks_msec()
    if now - _win_start > 300:
        _win_start = now
        _win_count = 0
    _win_count += 1
    if _win_count > 7:
        return
    var p := CPUParticles3D.new()
    p.mesh = _smoke_quad()
    p.amount = clampi(int(8.0 + power * 14.0), 8, 40)
    p.lifetime = 1.3 + power * 0.5
    p.one_shot = true
    p.explosiveness = 0.92
    p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
    p.emission_sphere_radius = 0.25 + power * 0.2
    p.direction = Vector3.UP
    p.spread = 75.0
    p.initial_velocity_min = 0.5
    p.initial_velocity_max = 1.6 + power * 2.2
    p.gravity = Vector3(0.0, 0.25, 0.0)
    p.damping_min = 1.2
    p.damping_max = 2.4
    p.scale_amount_min = 0.5 + power * 0.25
    p.scale_amount_max = 1.0 + power * 0.5
    p.scale_amount_curve = _grow_curve(0.45, 1.7)
    p.color = col
    p.color_ramp = _ramp([[0.0, Color(1, 1, 1, 0.0)], [0.12, Color(1, 1, 1, 0.55)], [1.0, Color(1, 1, 1, 0.0)]])
    root.add_child(p)
    p.global_position = pos
    p.emitting = true
    _autofree(p, p.lifetime + 0.6)


## Искры (удар металла).
static func sparks(pos: Vector3, power: float) -> void:
    var root: Node = _root()
    if root == null:
        return
    if _spark_mesh == null:
        _spark_mesh = BoxMesh.new()
        _spark_mesh.size = Vector3(0.025, 0.14, 0.025)
        var sm := StandardMaterial3D.new()
        sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        sm.vertex_color_use_as_albedo = true
        _spark_mesh.material = sm
    var p := CPUParticles3D.new()
    p.mesh = _spark_mesh
    p.amount = clampi(int(10.0 + power * 14.0), 10, 44)
    p.lifetime = 0.75
    p.one_shot = true
    p.explosiveness = 1.0
    p.direction = Vector3.UP
    p.spread = 90.0
    p.initial_velocity_min = 3.0
    p.initial_velocity_max = 8.0 + power * 3.0
    p.gravity = Vector3(0.0, -12.0, 0.0)
    p.particle_flag_align_y = true
    p.color_ramp = _ramp([[0.0, Color(1.0, 0.95, 0.6, 1.0)], [0.4, Color(1.0, 0.45, 0.08, 1.0)], [1.0, Color(0.3, 0.05, 0.0, 0.0)]])
    root.add_child(p)
    p.global_position = pos
    p.emitting = true
    _autofree(p, 1.6)


## Постоянный эмиттер дыма/огня на машине. kind: 0 светлый дым, 1 чёрный дым, 2 огонь.
static func make_emitter(parent: Node3D, local_pos: Vector3, kind: int) -> CPUParticles3D:
    var p := CPUParticles3D.new()
    p.emitting = false
    p.local_coords = false
    p.direction = Vector3.UP
    p.position = local_pos
    if kind == 2:
        p.mesh = _fire_quad()
        p.amount = 16
        p.lifetime = 0.7
        p.spread = 18.0
        p.initial_velocity_min = 1.0
        p.initial_velocity_max = 2.2
        p.gravity = Vector3(0.0, 1.5, 0.0)
        p.scale_amount_min = 0.5
        p.scale_amount_max = 0.9
        p.scale_amount_curve = _grow_curve(1.0, 0.1)
        p.color_ramp = _ramp([[0.0, Color(1.0, 0.85, 0.35, 0.9)], [0.35, Color(1.0, 0.35, 0.05, 0.7)], [1.0, Color(0.3, 0.02, 0.0, 0.0)]])
    else:
        p.mesh = _smoke_quad()
        p.amount = 22 if kind == 1 else 14
        p.lifetime = 2.6 if kind == 1 else 1.9
        p.spread = 14.0
        p.initial_velocity_min = 1.2
        p.initial_velocity_max = 2.6
        p.gravity = Vector3(0.0, 0.9, 0.0)
        p.scale_amount_min = 0.7
        p.scale_amount_max = 1.3
        p.scale_amount_curve = _grow_curve(0.5, 2.4)
        var base: Color = Color(0.06, 0.06, 0.06) if kind == 1 else Color(0.55, 0.55, 0.57)
        p.color = base
        p.color_ramp = _ramp([[0.0, Color(1, 1, 1, 0.0)], [0.15, Color(1, 1, 1, 0.6)], [1.0, Color(1, 1, 1, 0.0)]])
    parent.add_child(p)
    return p


## Большой взрыв: огненный шар, дым, искры, вспышка света.
static func blast(pos: Vector3, radius: float) -> void:
    var root: Node = _root()
    if root == null:
        return
    var fire := CPUParticles3D.new()
    fire.mesh = _fire_quad()
    fire.amount = 40
    fire.lifetime = 0.9
    fire.one_shot = true
    fire.explosiveness = 0.95
    fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
    fire.emission_sphere_radius = radius * 0.25
    fire.direction = Vector3.UP
    fire.spread = 180.0
    fire.initial_velocity_min = radius * 0.8
    fire.initial_velocity_max = radius * 2.2
    fire.damping_min = 2.0
    fire.damping_max = 4.0
    fire.gravity = Vector3(0.0, 2.0, 0.0)
    fire.scale_amount_min = radius * 0.25
    fire.scale_amount_max = radius * 0.5
    fire.scale_amount_curve = _grow_curve(1.0, 0.3)
    fire.color_ramp = _ramp([[0.0, Color(1.0, 0.95, 0.6, 1.0)], [0.3, Color(1.0, 0.45, 0.08, 0.9)], [1.0, Color(0.25, 0.03, 0.0, 0.0)]])
    root.add_child(fire)
    fire.global_position = pos
    fire.emitting = true
    _autofree(fire, 2.0)
    var smoke := CPUParticles3D.new()
    smoke.mesh = _smoke_quad()
    smoke.amount = 36
    smoke.lifetime = 3.2
    smoke.one_shot = true
    smoke.explosiveness = 0.8
    smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
    smoke.emission_sphere_radius = radius * 0.3
    smoke.direction = Vector3.UP
    smoke.spread = 90.0
    smoke.initial_velocity_min = radius * 0.3
    smoke.initial_velocity_max = radius * 1.0
    smoke.damping_min = 0.8
    smoke.damping_max = 1.6
    smoke.gravity = Vector3(0.0, 1.2, 0.0)
    smoke.scale_amount_min = radius * 0.35
    smoke.scale_amount_max = radius * 0.7
    smoke.scale_amount_curve = _grow_curve(0.5, 2.2)
    smoke.color = Color(0.08, 0.08, 0.08)
    smoke.color_ramp = _ramp([[0.0, Color(1, 1, 1, 0.0)], [0.12, Color(1, 1, 1, 0.75)], [1.0, Color(1, 1, 1, 0.0)]])
    root.add_child(smoke)
    smoke.global_position = pos
    smoke.emitting = true
    _autofree(smoke, 4.2)
    sparks(pos, radius * 0.5)
    var light := OmniLight3D.new()
    light.light_color = Color(1.0, 0.6, 0.25)
    light.light_energy = 8.0
    light.omni_range = radius * 5.0
    root.add_child(light)
    light.global_position = pos + Vector3(0.0, 1.0, 0.0)
    var tw: Tween = light.create_tween()
    tw.tween_property(light, "light_energy", 0.0, 0.5)
    tw.tween_callback(light.queue_free)


## Крошечное цветное облачко (баллончик).
static func puff(pos: Vector3, col: Color) -> void:
    var root: Node = _root()
    if root == null:
        return
    var p := CPUParticles3D.new()
    p.mesh = _smoke_quad()
    p.amount = 4
    p.lifetime = 0.5
    p.one_shot = true
    p.explosiveness = 1.0
    p.direction = Vector3.UP
    p.spread = 60.0
    p.initial_velocity_min = 0.2
    p.initial_velocity_max = 0.8
    p.gravity = Vector3.ZERO
    p.scale_amount_min = 0.12
    p.scale_amount_max = 0.22
    p.color = col
    p.color_ramp = _ramp([[0.0, Color(1, 1, 1, 0.0)], [0.2, Color(1, 1, 1, 0.8)], [1.0, Color(1, 1, 1, 0.0)]])
    root.add_child(p)
    p.global_position = pos
    p.emitting = true
    _autofree(p, 1.0)
